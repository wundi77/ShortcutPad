# ShortcutPad

Auf dem iPad oder iPhone (im Safari) einen Button antippen → am Mac wird ein Tastaturkürzel im gerade aktiven Programm ausgelöst.
Sets, Buttons, Ordner und Kürzel werden ausschließlich in der Mac-App verwaltet.

```
iPad/iPhone (Safari)  ──HTTP im lokalen Netz──  Mac-App (Port 8765)  ──Tastendruck (CGEvent)──►  aktives Programm
```

* **Mac-App** (`MacHelper/`): Editor für Sets, Menüleisten-Symbol, Webserver mit Kopplung per QR-Code und 6-stelligem Code.
* **Shared** (`Shared/`): Datenmodell (Sets, Buttons, Ordner), Rasterregeln und Kürzel-Modell. Nur Foundation, keine Oberfläche.
* Es gibt keine iOS-App und keine USB-Verbindung mehr. Die Webseite ist der einzige Client.

Einrichtung und Tests: `ANLEITUNG.md`. Regeln für die Weiterentwicklung: `CLAUDE.md`.

Mindestversion: macOS 13. Die Mac-App läuft ohne Sandbox (nötig für Tastendrücke) und ist damit nur für die Verbreitung außerhalb des
Mac App Store gedacht (Developer ID plus Notarisierung).

Zeichen-Tasten ("z", "7", …) werden am Mac über das aktuelle Tastaturlayout aufgelöst. Zeichen, die selbst Shift brauchen
(z. B. „/“ auf dem deutschen Layout), funktionieren noch nicht; die Mac-App warnt beim Aufnehmen.
