import Foundation

// MARK: - Grenzen

/// Obergrenzen, damit importierte Dateien und die Oberfläche beherrschbar bleiben.
enum PadLimits {
    static let maxSets = 100
    static let maxButtonsPerSet = 300
    static let maxItemsPerSet = 300
    static let maxFoldersPerSet = 50
    static let maxGroupsPerSet = 30
    static let maxNameLength = 60
    static let maxLabelLength = 40
    static let maxFileBytes = 5_000_000
}

// MARK: - Farben und Stile

/// Die Farbpalette für Gruppen, Buttons und Sets (acht Farben, weiße Schrift mindestens 4,5:1).
enum PadColor: String, Codable, CaseIterable, Identifiable {
    case rot, orange, pink, blau, indigo, gruen, tuerkis, grau

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rot: return "Rot"
        case .orange: return "Orange"
        case .pink: return "Pink"
        case .blau: return "Blau"
        case .indigo: return "Indigo"
        case .gruen: return "Grün"
        case .tuerkis: return "Türkis"
        case .grau: return "Grau"
        }
    }

    /// RGB als 0xRRGGBB.
    var hex: UInt32 {
        switch self {
        case .rot: return 0xE11D48
        case .orange: return 0xCC420C
        case .pink: return 0xDB2777
        case .blau: return 0x0B63F0
        case .indigo: return 0x6D4DE6
        case .gruen: return 0x15803D
        case .tuerkis: return 0x0E7490
        case .grau: return 0x64748B
        }
    }

    var hexString: String {
        let text = String(hex, radix: 16, uppercase: true)
        return "#" + String(repeating: "0", count: max(0, 6 - text.count)) + text
    }
}

/// Wie Buttons gezeichnet werden: dunkel mit Farbbalken, ganz farbig oder gemischt.
enum PadStyle: String, Codable, CaseIterable, Identifiable {
    case bar, fill, mix

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bar: return "Balken"
        case .fill: return "Voll"
        case .mix: return "Betont"
        }
    }

    var summary: String {
        switch self {
        case .bar: return "Dunkle Buttons mit Farbbalken"
        case .fill: return "Komplett in der Gruppenfarbe"
        case .mix: return "Wichtige voll, Rest als Balken"
        }
    }
}

enum PadSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "Klein"
        case .medium: return "Mittel"
        case .large: return "Groß"
        }
    }

    /// Mindestkantenlänge eines Buttons in Punkten. Kleiner werden Buttons nie, es kommen eher Zeilen dazu.
    func minTile(tablet: Bool) -> Double {
        switch (self, tablet) {
        case (.small, false): return 64
        case (.medium, false): return 80
        case (.large, false): return 104
        case (.small, true): return 96
        case (.medium, true): return 128
        case (.large, true): return 160
        }
    }
}

// MARK: - Gruppen, Buttons, Sets

struct PadGroup: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var color: PadColor

    init(id: UUID = UUID(), name: String, color: PadColor) {
        self.id = id
        self.name = name
        self.color = color
    }
}

struct PadButton: Codable, Identifiable, Equatable {
    var id: UUID
    /// Text auf dem Button (kein Symbol).
    var label: String
    var shortcut: Shortcut
    var groupID: UUID?
    /// Eigene Farbe; ohne sie gilt die Farbe der Gruppe.
    var colorOverride: PadColor?
    /// Im Stil „Betont“ wird der Button voll gezeichnet.
    var emphasized: Bool

    init(
        id: UUID = UUID(),
        label: String,
        shortcut: Shortcut,
        groupID: UUID? = nil,
        colorOverride: PadColor? = nil,
        emphasized: Bool = false
    ) {
        self.id = id
        self.label = label
        self.shortcut = shortcut
        self.groupID = groupID
        self.colorOverride = colorOverride
        self.emphasized = emphasized
    }
}

/// Ein Ordner auf der Hauptebene eines Sets. Ordner liegen nicht in Ordnern (eine Ebene).
struct PadFolder: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var color: PadColor
    var buttons: [PadButton]

    init(id: UUID = UUID(), name: String, color: PadColor, buttons: [PadButton] = []) {
        self.id = id
        self.name = name
        self.color = color
        self.buttons = buttons
    }
}

/// Ein Eintrag auf der Hauptebene: Button oder Ordner. Die Reihenfolge im Set ist die Reihenfolge im Raster.
enum PadItem: Codable, Identifiable, Equatable {
    case button(PadButton)
    case folder(PadFolder)

    var id: UUID {
        switch self {
        case .button(let button): return button.id
        case .folder(let folder): return folder.id
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, button, folder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        if type == "folder" {
            self = .folder(try container.decode(PadFolder.self, forKey: .folder))
        } else {
            self = .button(try container.decode(PadButton.self, forKey: .button))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .button(let button):
            try container.encode("button", forKey: .type)
            try container.encode(button, forKey: .button)
        case .folder(let folder):
            try container.encode("folder", forKey: .type)
            try container.encode(folder, forKey: .folder)
        }
    }
}

struct PadSet: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    /// Programm, dem das Set zugeordnet ist (Bundle-ID, z. B. com.adobe.Photoshop). Ohne Programm: Rückfall-Set.
    var appBundleID: String?
    var appName: String?
    /// Set wechselt automatisch, wenn das Programm am Mac nach vorne kommt.
    var autoSwitch: Bool
    var color: PadColor
    var style: PadStyle
    var size: PadSize
    var showShortcuts: Bool
    var groups: [PadGroup]
    /// Hauptebene: Buttons und Ordner gemischt.
    var items: [PadItem]

    init(
        id: UUID = UUID(),
        name: String,
        appBundleID: String? = nil,
        appName: String? = nil,
        autoSwitch: Bool = true,
        color: PadColor = .blau,
        style: PadStyle = .bar,
        size: PadSize = .medium,
        showShortcuts: Bool = true,
        groups: [PadGroup] = [],
        items: [PadItem] = []
    ) {
        self.id = id
        self.name = name
        self.appBundleID = appBundleID
        self.appName = appName
        self.autoSwitch = autoSwitch
        self.color = color
        self.style = style
        self.size = size
        self.showShortcuts = showShortcuts
        self.groups = groups
        self.items = items
    }

    // MARK: Lesen und Schreiben (Dateiformat 2; Format 1 hatte eine flache Liste „buttons“)

    private enum CodingKeys: String, CodingKey {
        case id, name, appBundleID, appName, autoSwitch, color, style, size, showShortcuts, groups, items, buttons
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        appBundleID = try c.decodeIfPresent(String.self, forKey: .appBundleID)
        appName = try c.decodeIfPresent(String.self, forKey: .appName)
        autoSwitch = try c.decode(Bool.self, forKey: .autoSwitch)
        color = try c.decode(PadColor.self, forKey: .color)
        style = try c.decode(PadStyle.self, forKey: .style)
        size = try c.decode(PadSize.self, forKey: .size)
        showShortcuts = try c.decode(Bool.self, forKey: .showShortcuts)
        groups = try c.decode([PadGroup].self, forKey: .groups)
        if let decoded = try c.decodeIfPresent([PadItem].self, forKey: .items) {
            items = decoded
        } else {
            let legacy = try c.decodeIfPresent([PadButton].self, forKey: .buttons) ?? []
            items = legacy.map { PadItem.button($0) }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(appBundleID, forKey: .appBundleID)
        try c.encodeIfPresent(appName, forKey: .appName)
        try c.encode(autoSwitch, forKey: .autoSwitch)
        try c.encode(color, forKey: .color)
        try c.encode(style, forKey: .style)
        try c.encode(size, forKey: .size)
        try c.encode(showShortcuts, forKey: .showShortcuts)
        try c.encode(groups, forKey: .groups)
        try c.encode(items, forKey: .items)
    }

    // MARK: Abfragen

    /// Alle Buttons des Sets, auch die in Ordnern.
    var allButtons: [PadButton] {
        var result = [PadButton]()
        for item in items {
            switch item {
            case .button(let button): result.append(button)
            case .folder(let folder): result.append(contentsOf: folder.buttons)
            }
        }
        return result
    }

    var buttonCount: Int { allButtons.count }

    var folders: [PadFolder] {
        var result = [PadFolder]()
        for item in items {
            if case .folder(let folder) = item { result.append(folder) }
        }
        return result
    }

    func folder(withID id: UUID?) -> PadFolder? {
        guard let id = id else { return nil }
        return folders.first { $0.id == id }
    }

    func button(withID id: UUID?) -> PadButton? {
        guard let id = id else { return nil }
        return allButtons.first { $0.id == id }
    }

    /// In welchem Ordner liegt der Button? Nil, wenn er auf der Hauptebene liegt (oder es ihn nicht gibt).
    func folderID(containing buttonID: UUID) -> UUID? {
        for folder in folders where folder.buttons.contains(where: { $0.id == buttonID }) {
            return folder.id
        }
        return nil
    }

    func group(for button: PadButton) -> PadGroup? {
        guard let id = button.groupID else { return nil }
        return groups.first { $0.id == id }
    }

    /// Eigene Farbe, sonst Gruppenfarbe, sonst Set-Farbe.
    func color(for button: PadButton) -> PadColor {
        if let own = button.colorOverride { return own }
        if let group = group(for: button) { return group.color }
        return color
    }

    /// Wird der Button voll in seiner Farbe gezeichnet?
    func isFilled(_ button: PadButton) -> Bool {
        switch style {
        case .fill: return true
        case .bar: return false
        case .mix: return button.emphasized
        }
    }

    /// Ordner sind im Stil „Betont“ immer voll gezeichnet.
    func isFilled(_ folder: PadFolder) -> Bool {
        style != .bar
    }

    // MARK: Kopien

    /// Kopie mit neuen IDs für Set, Gruppen, Ordner und Buttons (Gruppenverweise bleiben stimmig).
    func regenerated() -> PadSet {
        var copy = self
        copy.id = UUID()
        var mapping = [UUID: UUID]()
        copy.groups = groups.map { group in
            var g = group
            g.id = UUID()
            mapping[group.id] = g.id
            return g
        }
        func fresh(_ button: PadButton) -> PadButton {
            var b = button
            b.id = UUID()
            if let old = button.groupID { b.groupID = mapping[old] }
            return b
        }
        copy.items = items.map { item in
            switch item {
            case .button(let button):
                return PadItem.button(fresh(button))
            case .folder(let folder):
                var f = folder
                f.id = UUID()
                f.buttons = folder.buttons.map { fresh($0) }
                return PadItem.folder(f)
            }
        }
        return copy
    }

    /// Bereinigte Kopie für importierte Daten: Texte kürzen, Grenzen einhalten, ungültige Kürzel und Verweise entfernen.
    func sanitized() -> PadSet {
        var copy = self
        copy.name = PadSet.clean(name, limit: PadLimits.maxNameLength, fallback: "Set")
        copy.appName = appName.map { PadSet.clean($0, limit: PadLimits.maxNameLength, fallback: "") }
        if let bundle = appBundleID, bundle.isEmpty || bundle.count > 200 { copy.appBundleID = nil }

        copy.groups = Array(groups.prefix(PadLimits.maxGroupsPerSet)).map { group in
            var g = group
            g.name = PadSet.clean(group.name, limit: PadLimits.maxNameLength, fallback: "Gruppe")
            return g
        }
        let knownGroups = Set(copy.groups.map { $0.id })

        var remaining = PadLimits.maxButtonsPerSet
        var folderCount = 0
        var cleanedItems = [PadItem]()
        for item in items.prefix(PadLimits.maxItemsPerSet) {
            switch item {
            case .button(let button):
                guard remaining > 0, let cleaned = PadSet.cleanButton(button, known: knownGroups) else { continue }
                remaining -= 1
                cleanedItems.append(PadItem.button(cleaned))
            case .folder(let folder):
                guard folderCount < PadLimits.maxFoldersPerSet else { continue }
                folderCount += 1
                var f = folder
                f.name = PadSet.clean(folder.name, limit: PadLimits.maxNameLength, fallback: "Ordner")
                var kids = [PadButton]()
                for child in folder.buttons {
                    guard remaining > 0, let cleaned = PadSet.cleanButton(child, known: knownGroups) else { continue }
                    remaining -= 1
                    kids.append(cleaned)
                }
                f.buttons = kids
                cleanedItems.append(PadItem.folder(f))
            }
        }
        copy.items = cleanedItems
        return copy
    }

    private static func cleanButton(_ button: PadButton, known groups: Set<UUID>) -> PadButton? {
        guard button.shortcut.isValid else { return nil }
        var b = button
        b.label = clean(button.label, limit: PadLimits.maxLabelLength, fallback: "Button")
        if let gid = b.groupID, !groups.contains(gid) { b.groupID = nil }
        return b
    }

    private static func clean(_ text: String, limit: Int, fallback: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return fallback }
        return String(trimmed.prefix(limit))
    }
}

// MARK: - Datei und Austausch

/// Inhalt einer .shortcutpad-Datei (Export und Import von Sets).
struct PadFile: Codable {
    static let formatName = "shortcutpad"
    /// 1: flache Liste „buttons“. 2: „items“ mit Buttons und Ordnern. Format 1 wird weiter gelesen.
    static let currentVersion = 2

    var format: String
    var version: Int
    var sets: [PadSet]
}

/// Was der Mac an iPad/iPhone/Webseite ausliefert: alle Sets und das gerade aktive.
struct PadLibraryPayload: Codable {
    var revision: Int
    var sets: [PadSet]
    var activeSetID: UUID?
    /// true, wenn das Set am Mac fixiert ist (kein automatischer Wechsel).
    var pinned: Bool
}

// MARK: - Kürzel aus Text

extension Shortcut {
    /// Liest Schreibweisen wie „⇧⌘N“, „⌥⌘G“ oder „B“. Gibt nil zurück, wenn das Ergebnis kein gültiges Kürzel ist.
    static func parse(_ text: String) -> Shortcut? {
        var modifiers = Set<KeyModifier>()
        var rest = ""
        for character in text {
            switch character {
            case "⌃": modifiers.insert(.control)
            case "⌥": modifiers.insert(.option)
            case "⇧": modifiers.insert(.shift)
            case "⌘": modifiers.insert(.command)
            default: rest.append(character)
            }
        }
        let key = rest.count == 1 ? rest.lowercased() : rest
        let shortcut = Shortcut(key: key, modifiers: modifiers)
        return shortcut.isValid ? shortcut : nil
    }
}
