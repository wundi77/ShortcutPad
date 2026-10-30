# ShortcutPad

Touch-Buttons auf iPhone/iPad (App oder Webseite) lösen Tastaturkürzel im gerade aktiven Mac-Programm aus.
Sets, Buttons und Kürzel werden ausschließlich in der Mac-App verwaltet.

| Ordner | Inhalt |
| --- | --- |
| `ShortcutPad/` | Xcode-Projekt (per XcodeGen): Mac-App `MacHelper/`, iOS-App `iOSApp/`, gemeinsamer Code `Shared/`. Einrichtung in `ShortcutPad/ANLEITUNG.md` |
| `design/canvas/` | Quellen des Design-Canvas (Mac-App, iOS/Web, Zustände) |
| `docs/Designentscheidungen.md` | Festgelegte Design- und Bedienentscheidungen |
| `docs/Projektprotokoll.md` | Projektprotokoll und Basis-Prompt |
| `docs/referenz/` | Design-Referenzen (Stream-Deck-Layouts, Elgato-App) |

## Stand

- Mac-App mit Sets, Editor, Import/Export und Menüleiste ist geschrieben, aber noch nicht in Xcode gebaut.
- iOS-App und Webseite zeigen die Sets noch nicht an (nächster Schritt).
