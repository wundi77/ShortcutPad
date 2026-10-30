# ShortcutPad

Auf dem iPad oder iPhone (im Safari) einen Button antippen → am Mac wird ein Tastaturkürzel im gerade aktiven Programm ausgelöst.
Sets, Buttons, Ordner und Kürzel werden ausschließlich in der Mac-App verwaltet. Gekoppelt wird per QR-Code.

| Ordner | Inhalt |
| --- | --- |
| `ShortcutPad/` | Xcode-Projekt (per XcodeGen): Mac-App `MacHelper/`, gemeinsamer Code `Shared/`. Einrichtung in `ShortcutPad/ANLEITUNG.md` |
| `design/canvas/` | Quellen des Design-Canvas (Mac-App, iOS/Web, Zustände) |
| `docs/Designentscheidungen.md` | Festgelegte Design- und Bedienentscheidungen |
| `docs/Projektprotokoll.md` | Projektprotokoll und Basis-Prompt |
| `docs/referenz/` | Design-Referenzen (Stream-Deck-Layouts, Elgato-App) |

## Stand

- Mac-App mit Sets, Ordnern, Import/Export und Menüleiste ist geschrieben, aber noch nicht neu in Xcode gebaut.
- USB und iOS-App sind entfernt; die Webseite ist der einzige Client.
- Nächster Schritt: Die Webseite zeigt die Sets und Ordner an (bisher noch der Ein-Button-Test).
