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

    // MARK: Buttons

    @discardableResult
    func addButton(to setID: UUID) -> UUID? {
        var newID: UUID?
        mutate(setID) { set in
            guard set.buttons.count < PadLimits.maxButtonsPerSet else { return }
            let button = PadButton(
                label: "Neuer Button",
                shortcut: Shortcut(key: "n", modifiers: [.command]),
                groupID: set.groups.first?.id
            )
            set.buttons.append(button)
            newID = button.id
        }
        return newID
    }

    func deleteButton(_ buttonID: UUID, in setID: UUID) {
        mutate(setID) { set in
            set.buttons.removeAll { $0.id == buttonID }
        }
    }

    @discardableResult
    func duplicateButton(_ buttonID: UUID, in setID: UUID) -> UUID? {
        var newID: UUID?
        mutate(setID) { set in
            guard set.buttons.count < PadLimits.maxButtonsPerSet,
                  let index = set.buttons.firstIndex(where: { $0.id == buttonID }) else { return }
            var copy = set.buttons[index]
            copy.id = UUID()
            set.buttons.insert(copy, at: index + 1)
            newID = copy.id
        }
        return newID
    }

    func updateButton(_ buttonID: UUID, in setID: UUID, _ change: (inout PadButton) -> Void) {
        mutate(setID) { set in
            guard let index = set.buttons.firstIndex(where: { $0.id == buttonID }) else { return }
            change(&set.buttons[index])
        }
    }

    /// Zieht einen Button an die Stelle eines anderen (Neuanordnen per Ziehen in der Vorschau).
    func moveButton(_ draggedID: UUID, onto targetID: UUID, in setID: UUID) {
        guard draggedID != targetID else { return }
        mutate(setID) { set in
            guard let from = set.buttons.firstIndex(where: { $0.id == draggedID }),
                  let to = set.buttons.firstIndex(where: { $0.id == targetID }) else { return }
            let item = set.buttons.remove(at: from)
            set.buttons.insert(item, at: to)
        }
    }

    /// Ordnet die Buttons nach der Reihenfolge der Gruppen. Innerhalb einer Gruppe bleibt die Reihenfolge.
    func sortByGroup(in setID: UUID) {
        mutate(setID) { set in
            let order = set.groups.map { $0.id }
            func rank(_ button: PadButton) -> Int {
                if let gid = button.groupID, let index = order.firstIndex(of: gid) { return index }
                return order.count
            }
            let sorted = set.buttons.enumerated().sorted { left, right in
                let a = rank(left.element)
                let b = rank(right.element)
                return a != b ? a < b : left.offset < right.offset
            }
            set.buttons = sorted.map { $0.element }
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
            for index in set.buttons.indices where set.buttons[index].groupID == groupID {
                set.buttons[index].groupID = nil
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
