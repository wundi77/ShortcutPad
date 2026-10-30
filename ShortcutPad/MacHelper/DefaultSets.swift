import Foundation

/// Startsets beim ersten Programmstart: Photoshop als Beispiel (mit Ordnern) und ein Rückfall-Set für alle anderen Programme.
enum DefaultSets {
    static func make() -> [PadSet] {
        [photoshop(), general()]
    }

    private static func photoshop() -> PadSet {
        let groups: [PadGroup] = [
            PadGroup(name: "Datei", color: .blau),
            PadGroup(name: "Bearbeiten", color: .indigo),
            PadGroup(name: "Ebenen", color: .orange),
            PadGroup(name: "Auswahl", color: .rot),
            PadGroup(name: "Werkzeug", color: .gruen),
            PadGroup(name: "Ansicht", color: .tuerkis)
        ]

        func groupID(_ name: String) -> UUID? {
            groups.first { $0.name == name }?.id
        }

        func makeButton(_ label: String, _ keys: String, _ group: String, _ star: Bool) -> PadButton? {
            guard let shortcut = Shortcut.parse(keys) else { return nil }
            return PadButton(label: label, shortcut: shortcut, groupID: groupID(group), emphasized: star)
        }

        func single(_ label: String, _ keys: String, _ group: String, star: Bool = false) -> PadItem? {
            guard let button = makeButton(label, keys, group, star) else { return nil }
            return PadItem.button(button)
        }

        func folder(_ name: String, _ color: PadColor, _ rows: [(String, String)]) -> PadItem {
            var buttons = [PadButton]()
            for row in rows {
                if let button = makeButton(row.0, row.1, name, false) {
                    buttons.append(button)
                }
            }
            return PadItem.folder(PadFolder(name: name, color: color, buttons: buttons))
        }

        let entries: [PadItem?] = [
            single("Speichern", "⌘S", "Datei", star: true),
            single("Zurück", "⌘Z", "Bearbeiten", star: true),
            single("Neue Ebene", "⇧⌘N", "Ebenen", star: true),
            single("Pinsel", "B", "Werkzeug", star: true),
            folder("Datei", .blau, [("Neu", "⌘N"), ("Öffnen", "⌘O"), ("Speichern als", "⇧⌘S"), ("Für Web", "⌥⇧⌘S")]),
            folder("Bearbeiten", .indigo, [("Verlauf", "⌥⌘Z"), ("Kopieren", "⌘C"), ("Einfügen", "⌘V")]),
            folder("Ebenen", .orange, [("Duplikat", "⌘J"), ("Gruppe", "⌘G"), ("Maske", "⌥⌘G"), ("Reduzieren", "⇧⌘E")]),
            folder("Auswahl", .rot, [("Alles", "⌘A"), ("Aufheben", "⌘D"), ("Umkehren", "⇧⌘I"), ("Verfeinern", "⌥⌘R"), ("Transform", "⌘T")]),
            folder("Werkzeug", .gruen, [("Lasso", "L"), ("Farben tauschen", "X")]),
            folder("Ansicht", .tuerkis, [("100 %", "⌘1"), ("Lineale", "⌘R"), ("Bildgröße", "⌥⌘I")]),
            single("Vor", "⇧⌘Z", "Bearbeiten"),
            single("Radierer", "E", "Werkzeug"),
            single("Bewegen", "V", "Werkzeug"),
            single("Einpassen", "⌘0", "Ansicht", star: true)
        ]
        let items = entries.compactMap { $0 }

        return PadSet(
            name: "Photoshop",
            appBundleID: "com.adobe.Photoshop",
            appName: "Adobe Photoshop",
            autoSwitch: true,
            color: .blau,
            style: .bar,
            size: .medium,
            showShortcuts: true,
            groups: groups,
            items: items
        )
    }

    private static func general() -> PadSet {
        let group = PadGroup(name: "Allgemein", color: .grau)
        let rows: [(label: String, keys: String)] = [
            ("Zurück", "⌘Z"),
            ("Kopieren", "⌘C"),
            ("Einfügen", "⌘V"),
            ("Sichern", "⌘S")
        ]
        var items = [PadItem]()
        for row in rows {
            guard let shortcut = Shortcut.parse(row.keys) else { continue }
            items.append(PadItem.button(PadButton(label: row.label, shortcut: shortcut, groupID: group.id)))
        }
        return PadSet(
            name: "Allgemein",
            appBundleID: nil,
            appName: nil,
            autoSwitch: true,
            color: .grau,
            style: .bar,
            size: .medium,
            showShortcuts: true,
            groups: [group],
            items: items
        )
    }
}
