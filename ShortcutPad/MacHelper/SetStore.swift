import AppKit
import SwiftUI

enum ImportMode {
    /// Importierte Sets kommen als neue Sets dazu (bei gleichem Namen mit Zusatz „(Import)“).
    case addAsNew
    /// Ein Set mit gleichem Namen wird ersetzt, alle anderen kommen neu dazu.
    case replaceSameName
}

enum SetStoreError: LocalizedError {
    case tooLarge
    case wrongFormat
    case tooNew(Int)
    case empty

    var errorDescription: String? {
        switch self {
        case .tooLarge: return "Die Datei ist zu groß."
        case .wrongFormat: return "Das ist keine ShortcutPad-Datei."
        case .tooNew(let version): return "Die Datei stammt aus einer neueren Version (Format \(version)). Bitte ShortcutPad aktualisieren."
        case .empty: return "Die Datei enthält keine Sets."
        }
    }
}

/// Speichert alle Sets auf dem Mac (Application Support/ShortcutPad/sets.json).
/// Die Oberfläche und der Helper ändern die Sets nur über diese Klasse, und zwar auf dem Main-Thread.
final class SetStore: ObservableObject {
    static let shared = SetStore()

    @Published var sets: [PadSet] = [] {
        didSet {
            revision += 1
            scheduleSave()
        }
    }

    /// Zähler, der bei jeder Änderung steigt. Geräte erkennen daran, ob sie neu laden müssen.
    private(set) var revision = 0
    @Published private(set) var note: String?

    private var saveWork: DispatchWorkItem?

    private static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return base.appendingPathComponent("ShortcutPad", isDirectory: true)
    }

    private static var fileURL: URL {
        directoryURL.appendingPathComponent("sets.json")
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    init() {
        var firstStart = false
        if let data = try? Data(contentsOf: SetStore.fileURL) {
            if let file = try? JSONDecoder().decode(PadFile.self, from: data), file.format == PadFile.formatName {
                sets = file.sets.map { $0.sanitized() }
            } else {
                // Defekte Datei nicht überschreiben, sondern zur Seite legen.
                let backup = SetStore.fileURL.appendingPathExtension("defekt")
                try? FileManager.default.removeItem(at: backup)
                try? FileManager.default.moveItem(at: SetStore.fileURL, to: backup)
                sets = DefaultSets.make()
                note = "Die gespeicherten Sets waren nicht lesbar. Die alte Datei liegt als sets.json.defekt im Ordner ShortcutPad."
                firstStart = true
            }
        } else {
            sets = DefaultSets.make()
            firstStart = true
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveNow()
        }

        if firstStart { scheduleSave() }
    }

    // MARK: Speichern

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        saveWork = nil
        let file = PadFile(format: PadFile.formatName, version: PadFile.currentVersion, sets: sets)
        do {
            let data = try SetStore.encoder.encode(file)
            try FileManager.default.createDirectory(at: SetStore.directoryURL, withIntermediateDirectories: true)
            try data.write(to: SetStore.fileURL, options: .atomic)
        } catch {
            note = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: Sets

    func set(withID id: UUID?) -> PadSet? {
        guard let id = id else { return nil }
        return sets.first { $0.id == id }
    }

    /// Ändert ein Set an Ort und Stelle.
    func mutate(_ id: UUID, _ change: (inout PadSet) -> Void) {
        guard let index = sets.firstIndex(where: { $0.id == id }) else { return }
        var copy = sets[index]
        change(&copy)
        if copy != sets[index] {
            sets[index] = copy
        }
    }

    func replace(_ set: PadSet) {
        guard let index = sets.firstIndex(where: { $0.id == set.id }) else { return }
        sets[index] = set
    }

    @discardableResult
    func addSet() -> UUID? {
        guard sets.count < PadLimits.maxSets else { return nil }
        let name = uniqueName("Neues Set", existing: sets.map { $0.name })
        let set = PadSet(name: name)
        sets.append(set)
        return set.id
    }

    func deleteSet(_ id: UUID) {
        sets.removeAll { $0.id == id }
    }

    func moveSet(_ id: UUID, by delta: Int) {
        guard let index = sets.firstIndex(where: { $0.id == id }) else { return }
        let target = index + delta
        guard target >= 0, target < sets.count else { return }
        let item = sets.remove(at: index)
        sets.insert(item, at: target)
    }

    /// Welches Set gehört zum vordersten Programm? Erst ein Set mit dieser Programm-ID, sonst das Rückfall-Set.
    func setForApp(bundleID: String?) -> PadSet? {
        if let bundleID = bundleID,
           let match = sets.first(where: { $0.autoSwitch && $0.appBundleID == bundleID }) {
            return match
        }
        return sets.first { $0.appBundleID == nil }
    }

    // MARK: Buttons und Ordner

    /// Wo ein Eintrag liegt: auf der Hauptebene (Index) oder in einem Ordner (Ordner-Index, Button-Index).
    private enum Place {
        case top(Int)
        case folder(Int, Int)
    }

    private func place(of id: UUID, in set: PadSet) -> Place? {
        for (index, item) in set.items.enumerated() {
            if item.id == id { return .top(index) }
            if case .folder(let folder) = item,
               let inner = folder.buttons.firstIndex(where: { $0.id == id }) {
                return .folder(index, inner)
            }
        }
        return nil
    }

    /// Entfernt einen Button von seinem Platz (Hauptebene oder Ordner) und gibt ihn zurück.
    private func removeButton(_ id: UUID, from set: inout PadSet) -> PadButton? {
        guard let found = place(of: id, in: set) else { return nil }
        switch found {
        case .top(let index):
            if case .button(let button) = set.items[index] {
                set.items.remove(at: index)
                return button
            }
            return nil
        case .folder(let folderIndex, let inner):
            if case .folder(var folder) = set.items[folderIndex] {
                let button = folder.buttons.remove(at: inner)
                set.items[folderIndex] = PadItem.folder(folder)
                return button
            }
            return nil
        }
    }

    /// Legt einen neuen Button an: auf der Hauptebene oder, wenn `folderID` gesetzt ist, in diesem Ordner.
    @discardableResult
    func addButton(to setID: UUID, in folderID: UUID? = nil) -> UUID? {
        var newID: UUID?
        mutate(setID) { set in
            guard set.buttonCount < PadLimits.maxButtonsPerSet else { return }
            let button = PadButton(
                label: "Neuer Button",
                shortcut: Shortcut(key: "n", modifiers: [.command]),
                groupID: set.groups.first?.id
            )
            if let folderID = folderID {
                guard let index = set.items.firstIndex(where: { $0.id == folderID }),
                      case .folder(var folder) = set.items[index] else { return }
                folder.buttons.append(button)
                set.items[index] = PadItem.folder(folder)
            } else {
                guard set.items.count < PadLimits.maxItemsPerSet else { return }
                set.items.append(PadItem.button(button))
            }
            newID = button.id
        }
        return newID
    }

    func deleteButton(_ buttonID: UUID, in setID: UUID) {
        mutate(setID) { set in
            _ = removeButton(buttonID, from: &set)
        }
    }

    @discardableResult
    func duplicateButton(_ buttonID: UUID, in setID: UUID) -> UUID? {
        var newID: UUID?
        mutate(setID) { set in
            guard set.buttonCount < PadLimits.maxButtonsPerSet, let found = place(of: buttonID, in: set) else { return }
            switch found {
            case .top(let index):
                guard set.items.count < PadLimits.maxItemsPerSet,
                      case .button(var copy) = set.items[index] else { return }
                copy.id = UUID()
                set.items.insert(PadItem.button(copy), at: index + 1)
                newID = copy.id
            case .folder(let folderIndex, let inner):
                guard case .folder(var folder) = set.items[folderIndex] else { return }
                var copy = folder.buttons[inner]
                copy.id = UUID()
                folder.buttons.insert(copy, at: inner + 1)
                set.items[folderIndex] = PadItem.folder(folder)
                newID = copy.id
            }
        }
        return newID
    }

    /// Ändert einen Button, egal ob auf der Hauptebene oder in einem Ordner.
    func updateButton(_ buttonID: UUID, in setID: UUID, _ change: (inout PadButton) -> Void) {
        mutate(setID) { set in
            guard let found = place(of: buttonID, in: set) else { return }
            switch found {
            case .top(let index):
                if case .button(var button) = set.items[index] {
                    change(&button)
                    set.items[index] = PadItem.button(button)
                }
            case .folder(let folderIndex, let inner):
                if case .folder(var folder) = set.items[folderIndex] {
                    change(&folder.buttons[inner])
                    set.items[folderIndex] = PadItem.folder(folder)
                }
            }
        }
    }

    /// Ordnet um (Ziehen in der Vorschau): Der gezogene Eintrag nimmt den Platz des Ziels ein.
    /// Gilt nur innerhalb einer Ebene, also auf der Hauptebene oder im selben Ordner.
    func reorder(_ draggedID: UUID, onto targetID: UUID, in setID: UUID) {
        guard draggedID != targetID else { return }
        mutate(setID) { set in
            guard let from = place(of: draggedID, in: set), let to = place(of: targetID, in: set) else { return }
            switch (from, to) {
            case (.top(let a), .top(let b)):
                let item = set.items.remove(at: a)
                set.items.insert(item, at: b)
            case (.folder(let folderA, let a), .folder(let folderB, let b)):
                guard folderA == folderB, case .folder(var folder) = set.items[folderA] else { return }
                let item = folder.buttons.remove(at: a)
                folder.buttons.insert(item, at: b)
                set.items[folderA] = PadItem.folder(folder)
            default:
                return
            }
        }
    }

    /// Verschiebt einen Button in einen Ordner oder (bei `folderID == nil`) auf die Hauptebene.
    /// Auf der Hauptebene landet er direkt hinter dem Ordner, aus dem er kommt.
    func moveButton(_ buttonID: UUID, to folderID: UUID?, in setID: UUID) {
        mutate(setID) { set in
            guard let origin = place(of: buttonID, in: set) else { return }
            if let target = folderID {
                guard set.folder(withID: target) != nil else { return }
                if case .folder(let current, _) = origin, set.items[current].id == target { return }
                guard let button = removeButton(buttonID, from: &set) else { return }
                guard let index = set.items.firstIndex(where: { $0.id == target }),
                      case .folder(var folder) = set.items[index] else { return }
                folder.buttons.append(button)
                set.items[index] = PadItem.folder(folder)
            } else {
                guard case .folder(let current, _) = origin else { return }
                let folderItemID = set.items[current].id
                guard set.items.count < PadLimits.maxItemsPerSet,
                      let button = removeButton(buttonID, from: &set) else { return }
                let after = (set.items.firstIndex(where: { $0.id == folderItemID }) ?? (set.items.count - 1)) + 1
                set.items.insert(PadItem.button(button), at: min(after, set.items.count))
            }
        }
    }

    /// Ordnet die Buttons einer Ebene nach der Reihenfolge der Gruppen. Auf der Hauptebene bleiben Ordner an ihrem Platz.
    func sortByGroup(in setID: UUID, folderID: UUID? = nil) {
        mutate(setID) { set in
            let order = set.groups.map { $0.id }
            func rank(_ button: PadButton) -> Int {
                if let gid = button.groupID, let index = order.firstIndex(of: gid) { return index }
                return order.count
            }
            func sortedButtons(_ buttons: [PadButton]) -> [PadButton] {
                let sorted = buttons.enumerated().sorted { left, right in
                    let a = rank(left.element)
                    let b = rank(right.element)
                    return a != b ? a < b : left.offset < right.offset
                }
                return sorted.map { $0.element }
            }

            if let folderID = folderID {
                guard let index = set.items.firstIndex(where: { $0.id == folderID }),
                      case .folder(var folder) = set.items[index] else { return }
                folder.buttons = sortedButtons(folder.buttons)
                set.items[index] = PadItem.folder(folder)
            } else {
                var slots = [Int]()
                var singles = [PadButton]()
                for (index, item) in set.items.enumerated() {
                    if case .button(let button) = item {
                        slots.append(index)
                        singles.append(button)
                    }
                }
                let ordered = sortedButtons(singles)
                for (n, index) in slots.enumerated() {
                    set.items[index] = PadItem.button(ordered[n])
                }
            }
        }
    }

    // MARK: Ordner

    @discardableResult
    func addFolder(to setID: UUID) -> UUID? {
        var newID: UUID?
        mutate(setID) { set in
            guard set.folders.count < PadLimits.maxFoldersPerSet,
                  set.items.count < PadLimits.maxItemsPerSet else { return }
            let used = Set(set.folders.map { $0.color })
            let color = PadColor.allCases.first { !used.contains($0) } ?? set.color
            let name = uniqueName("Neuer Ordner", existing: set.folders.map { $0.name })
            let folder = PadFolder(name: name, color: color)
            set.items.append(PadItem.folder(folder))
            newID = folder.id
        }
        return newID
    }

    func updateFolder(_ folderID: UUID, in setID: UUID, _ change: (inout PadFolder) -> Void) {
        mutate(setID) { set in
            guard let index = set.items.firstIndex(where: { $0.id == folderID }),
                  case .folder(var folder) = set.items[index] else { return }
            change(&folder)
            set.items[index] = PadItem.folder(folder)
        }
    }

    /// Löscht den Ordner samt seinen Buttons.
    func deleteFolder(_ folderID: UUID, in setID: UUID) {
        mutate(setID) { set in
            set.items.removeAll { item in
                if case .folder(let folder) = item { return folder.id == folderID }
                return false
            }
        }
    }

    /// Löst den Ordner auf: Seine Buttons stehen danach an seiner Stelle auf der Hauptebene.
    func dissolveFolder(_ folderID: UUID, in setID: UUID) {
        mutate(setID) { set in
            guard let index = set.items.firstIndex(where: { $0.id == folderID }),
                  case .folder(let folder) = set.items[index] else { return }
            let free = PadLimits.maxItemsPerSet - (set.items.count - 1)
            guard folder.buttons.count <= free else { return }
            let released = folder.buttons.map { PadItem.button($0) }
            set.items.replaceSubrange(index...index, with: released)
        }
    }

    // MARK: Gruppen

    @discardableResult
    func addGroup(to setID: UUID) -> UUID? {
        var newID: UUID?
        mutate(setID) { set in
            guard set.groups.count < PadLimits.maxGroupsPerSet else { return }
            let used = Set(set.groups.map { $0.color })
            let color = PadColor.allCases.first { !used.contains($0) } ?? set.color
            let name = uniqueName("Neue Gruppe", existing: set.groups.map { $0.name })
            let group = PadGroup(name: name, color: color)
            set.groups.append(group)
            newID = group.id
        }
        return newID
    }

    func updateGroup(_ groupID: UUID, in setID: UUID, _ change: (inout PadGroup) -> Void) {
        mutate(setID) { set in
            guard let index = set.groups.firstIndex(where: { $0.id == groupID }) else { return }
            change(&set.groups[index])
        }
    }

    func deleteGroup(_ groupID: UUID, in setID: UUID) {
        mutate(setID) { set in
            set.groups.removeAll { $0.id == groupID }
            func release(_ button: PadButton) -> PadButton {
                var b = button
                if b.groupID == groupID { b.groupID = nil }
                return b
            }
            set.items = set.items.map { item in
                switch item {
                case .button(let button):
                    return PadItem.button(release(button))
                case .folder(var folder):
                    folder.buttons = folder.buttons.map { release($0) }
                    return PadItem.folder(folder)
                }
            }
        }
    }

    // MARK: Export und Import

    func exportData(setIDs: [UUID]) throws -> Data {
        let chosen = sets.filter { setIDs.contains($0.id) }
        let file = PadFile(format: PadFile.formatName, version: PadFile.currentVersion, sets: chosen)
        return try SetStore.encoder.encode(file)
    }

    /// Liest eine .shortcutpad-Datei. Wirft einen verständlichen Fehler, wenn sie nicht passt.
    /// Gibt die neu hinzugekommenen oder ersetzten Sets zurück.
    @discardableResult
    func importData(_ data: Data, mode: ImportMode) throws -> [PadSet] {
        guard data.count <= PadLimits.maxFileBytes else { throw SetStoreError.tooLarge }
        guard let file = try? JSONDecoder().decode(PadFile.self, from: data),
              file.format == PadFile.formatName else { throw SetStoreError.wrongFormat }
        guard file.version <= PadFile.currentVersion else { throw SetStoreError.tooNew(file.version) }
        guard !file.sets.isEmpty else { throw SetStoreError.empty }

        var working = sets
        var result = [PadSet]()
        for item in file.sets.prefix(PadLimits.maxSets) {
            var incoming = item.sanitized().regenerated()
            let sameName = working.firstIndex { $0.name.caseInsensitiveCompare(incoming.name) == .orderedSame }

            if mode == .replaceSameName, let index = sameName {
                incoming.id = working[index].id
                working[index] = incoming
            } else {
                guard working.count < PadLimits.maxSets else { break }
                if sameName != nil {
                    incoming.name = uniqueName(incoming.name + " (Import)", existing: working.map { $0.name })
                }
                working.append(incoming)
            }
            result.append(incoming)
        }
        sets = working
        return result
    }

    // MARK: Hilfen

    private func uniqueName(_ base: String, existing: [String]) -> String {
        let lowered = Set(existing.map { $0.lowercased() })
        if !lowered.contains(base.lowercased()) { return base }
        var number = 2
        while lowered.contains("\(base) \(number)".lowercased()) { number += 1 }
        return "\(base) \(number)"
    }
}
