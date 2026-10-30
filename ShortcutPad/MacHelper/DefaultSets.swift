import Foundation

/// Startsets beim ersten Programmstart: Photoshop als Beispiel und ein Rückfall-Set für alle anderen Programme.
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

        let rows: [(group: String, label: String, keys: String, star: Bool)] = [
            ("Datei", "Neu", "⌘N", false),
            ("Datei", "Speichern", "⌘S", true),
            ("Datei", "Speichern als", "⇧⌘S", false),
            ("Datei", "Für Web", "⌥⇧⌘S", false),
            ("Bearbeiten", "Zurück", "⌘Z", true),
            ("Bearbeiten", "Vor", "⇧⌘Z", false),
            ("Bearbeiten", "Verlauf", "⌥⌘Z", false),
            ("Bearbeiten", "Kopieren", "⌘C", false),
            ("Bearbeiten", "Einfügen", "⌘V", false),
            ("Ebenen", "Neue Ebene", "⇧⌘N", true),
            ("Ebenen", "Duplikat", "⌘J", false),
            ("Ebenen", "Gruppe", "⌘G", false),
            ("Ebenen", "Maske", "⌥⌘G", false),
            ("Ebenen", "Reduzieren", "⇧⌘E", false),
            ("Auswahl", "Alles", "⌘A", true),
            ("Auswahl", "Aufheben", "⌘D", false),
            ("Auswahl", "Umkehren", "⇧⌘I", false),
            ("Auswahl", "Verfeinern", "⌥⌘R", false),
            ("Auswahl", "Transform", "⌘T", false),
            ("Werkzeug", "Pinsel", "B", true),
            ("Werkzeug", "Radierer", "E", false),
            ("Werkzeug", "Bewegen", "V", false),
            ("Werkzeug", "Lasso", "L", false),
            ("Werkzeug", "Farben tauschen", "X", false),
            ("Ansicht", "Einpassen", "⌘0", true),
            ("Ansicht", "100 %", "⌘1", false),
            ("Ansicht", "Lineale", "⌘R", false),
            ("Ansicht", "Bildgröße", "⌥⌘I", false)
        ]

        var buttons = [PadButton]()
        for row in rows {
            guard let shortcut = Shortcut.parse(row.keys) else { continue }
            buttons.append(PadButton(
                label: row.label,
                shortcut: shortcut,
                groupID: groupID(row.group),
                colorOverride: nil,
                emphasized: row.star
            ))
        }

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
            buttons: buttons
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
        var buttons = [PadButton]()
        for row in rows {
            guard let shortcut = Shortcut.parse(row.keys) else { continue }
            buttons.append(PadButton(label: row.label, shortcut: shortcut, groupID: group.id))
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
            buttons: buttons
        )
    }
}
