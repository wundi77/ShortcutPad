# ShortcutPad

Auf dem iPad oder iPhone (im Safari) einen Button antippen → am Mac wird ein Tastaturkürzel im gerade aktiven Programm ausgelöst.
Sets, Buttons, Ordner und Kürzel werden ausschließlich in der Mac-App verwaltet. Gekoppelt wird per QR-Code.

| Ordner | Inhalt |
| --- | --- |
| `ShortcutPad/` | Xcode-Projekt (per XcodeGen): Mac-App `MacHelper/`, gemeinsamer Code `Shared/`. Bauen per Doppelklick auf `build.command`. Einrichtung in `ShortcutPad/ANLEITUNG.md` |
| `ShortcutPad/tools/webtest/` | Browsertest der Webseite gegen einen Mock-Server |
| `design/canvas/` | Quellen des Design-Canvas (Mac-App, iOS/Web, Zustände) |
| `docs/Designentscheidungen.md` | Festgelegte Design- und Bedienentscheidungen |
| `docs/Projektprotokoll.md` | Projektprotokoll und Basis-Prompt |
| `docs/referenz/` | Design-Referenzen (Stream-Deck-Layouts, Elgato-App) |

## Stand

- Mac-App mit Sets, Ordnern, Import/Export und Menüleiste ist geschrieben, aber noch nicht neu in Xcode gebaut.
- USB und iOS-App sind entfernt; die Webseite ist der einzige Client.
- Die Webseite zeigt Sets, Buttons und Ordner an (im Browser gegen einen Mock getestet, auf dem Mac noch nicht).
- Nächster Schritt: Mac-App bauen, mit dem iPad testen (`ShortcutPad/ANLEITUNG.md`).
