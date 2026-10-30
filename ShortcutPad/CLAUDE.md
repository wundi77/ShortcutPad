# ShortcutPad – Hinweise für Claude Code

Projekt: iOS-App (`iOSApp/`) + Mac-Helper (`MacHelper/`) + gemeinsamer Code (`Shared/`).
Der iOS-Button schickt ein Tastenkürzel per USB (usbmuxd-Tunnel) an den Mac-Helper, der es per CGEvent
an das aktive Programm sendet. Alternativ liefert der Helper eine Webseite im lokalen Netz aus (Safari statt App). Sprache in UI und Kommentaren: Deutsch.

## Stand

Die USB-Variante wurde vom Nutzer gebaut und getestet (funktioniert). Die Web-Variante (`Web*.swift`, `LocalNetwork.swift`,
`QRCode.swift`) wurde ohne Xcode geschrieben, ihr Test F ist noch nicht bestätigt. Neu und **noch nicht kompiliert** (ohne Xcode geschrieben, nur auf Syntax geprüft):
die Mac-App mit Sets (`Shared/Models.swift`, `Shared/PadLayout.swift`, `MacHelper/SetStore.swift`, `DefaultSets.swift`,
`EditorView.swift`, `EditorSheets.swift`, `ShortcutRecorder.swift`, `PadViews.swift`, `EditorComponents.swift`, `MenuBarView.swift`
sowie Änderungen in `HelperController`, `WebAPI`, `ShortcutPadHelperApp`). Erste Aufgabe dort: bauen und Fehler beheben,
ohne die Architektur zu ändern. Design-Vorlage: `design/canvas/` und `docs/Designentscheidungen.md`.

Noch offen: iOS-App und Webseite zeigen die Sets an (Daten liefert `GET /api/library`; für USB fehlt noch eine Nachricht
in `PadMessage`, die die iOS-App mitbehandeln muss).

## Projekt erzeugen und bauen

```
# Team-ID ist optional: setup.sh liest sie aus dem Zertifikat oder weist darauf hin (Personal Team, kostenlose Apple-ID)
xcodegen generate
xcodebuild -project ShortcutPad.xcodeproj -scheme ShortcutPadHelper -destination 'platform=macOS' build
xcodebuild -project ShortcutPad.xcodeproj -scheme ShortcutPad -destination 'generic/platform=iOS' build
```

Zum reinen Kompilieren ohne Signing: `CODE_SIGNING_ALLOWED=NO` an `xcodebuild` anhängen.

## Regeln

* Swift-Sprachmodus bleibt 5 (`SWIFT_VERSION: "5.0"` in `project.yml`); Mindestversionen iOS 16 / macOS 13.
  Keine APIs verwenden, die neuer sind (kein `@Observable`, kein `onChange(of:initial:)` usw.).
* `Shared/` wird von beiden Targets kompiliert: dort nur Foundation/Darwin, kein UIKit/AppKit/SwiftUI.
* Der Mac-Helper läuft ohne App-Sandbox (usbmuxd-Socket, Tastendrücke). Nicht wieder einschalten.
* Der iOS-Listener bindet bewusst nur `127.0.0.1`; nicht auf alle Interfaces ändern.
* Der Webserver im Helper (`WebServer.swift`, Port 8765) bindet bewusst auf alle Interfaces, ist aber standardmäßig aus
  und nur mit Kopplungscode/Token nutzbar (`WebAPI.swift`). Die Seite steckt als Raw-String in `WebAssets.swift`
  (`#"""…"""#`, damit JavaScript-Backslashes unverändert bleiben). Das JS nutzt bewusst kein Framework und nur ältere Syntax.
* USB und Web teilen sich `HelperController.executeShortcut(_:source:)`; neue Wege dort anschließen, nicht dort vorbei.
* TIS-/UCKeyTranslate-Aufrufe (`KeyMap`) gehören auf den Main-Thread.
* Sets, Buttons und Kürzel werden nur in der Mac-App bearbeitet (`SetStore`, Main-Thread). iOS-App und Webseite zeigen nur an.
  Gespeichert wird in `~/Library/Application Support/ShortcutPad/sets.json`; Export/Import als `.shortcutpad` (JSON, `PadFile`).
* Das Fenster „Verbindung und Kopplung“ wird am Titel erkannt (`HelperController`, Selbsttest). Titel nicht ohne Anpassung ändern.
* `project.yml` ist die Quelle der Wahrheit; das `.xcodeproj` ist generiert und nicht eingecheckt.

## Paketformat

* iOS ⇄ Mac: 4 Byte Länge (Big-Endian) + JSON (`PadMessage`), siehe `Shared/FrameSocket.swift`.
* Browser ⇄ Mac: HTTP/1.1, JSON. `GET /`, `POST /api/pair {pin}`, `GET /api/status`, `GET /api/library` (Sets plus aktives Set), `POST /api/trigger {shortcut}`;
  Token im Header `X-Pad-Token`. Das `Shortcut`-JSON ist dasselbe wie in `Shared/Protocol.swift` (`modifiers` als String-Array).
* Mac ⇄ usbmuxd: 16-Byte-Header (Länge, Version 1, Typ 8, Tag; Little-Endian) + XML-Plist, siehe `MacHelper/USBMux.swift`.
