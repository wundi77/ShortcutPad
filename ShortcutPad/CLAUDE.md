# ShortcutPad – Hinweise für Claude Code

Projekt: Mac-App (`MacHelper/`) + gemeinsamer Code (`Shared/`). Der Mac liefert im lokalen Netz eine Webseite aus
(Port 8765, Kopplung per QR-Code und 6-stelligem Code); ein Tipp auf der Webseite löst am Mac per CGEvent ein Tastenkürzel im aktiven
Programm aus. Sets, Buttons, Ordner und Kürzel werden nur in der Mac-App bearbeitet. Sprache in UI und Kommentaren: Deutsch.

Es gibt **keine iOS-App und keine USB-Verbindung mehr** (bewusst entfernt, Bluetooth oder eine App kommen eventuell später).

## Stand

Neu und **noch nicht kompiliert** (ohne Xcode geschrieben, nur auf Syntax geprüft): die Mac-App mit Sets, Ordnern und
Menüleiste (`Shared/Models.swift`, `Shared/PadLayout.swift`, `MacHelper/SetStore.swift`, `DefaultSets.swift`, `EditorView.swift`,
`EditorSheets.swift`, `ShortcutRecorder.swift`, `PadViews.swift`, `EditorComponents.swift`, `MenuBarView.swift` sowie Änderungen
in `HelperController`, `WebAPI`, `ShortcutPadHelperApp`). Der Nutzer hat eine frühere Fassung gebaut und gestartet; nach dem
Entfernen von USB und iOS-App ist noch nicht neu gebaut worden. Design-Vorlage: `design/canvas/`, Beschlüsse in
`docs/Designentscheidungen.md`.

**Nächster Schritt:** Die Webseite (`MacHelper/WebAssets.swift`) zeigt noch den alten Ein-Button-Test. Sie soll die Sets laden
(`GET /api/library`), das aktive Set zeigen, Ordnerseiten mit der „<“-Kachel kennen und beim Antippen `POST /api/trigger` senden.

## Projekt erzeugen und bauen

```
# Team-ID ist optional: setup.sh liest sie aus dem Zertifikat oder weist darauf hin (Personal Team, kostenlose Apple-ID)
xcodegen generate
xcodebuild -project ShortcutPad.xcodeproj -scheme ShortcutPadHelper -destination 'platform=macOS' build
```

Zum reinen Kompilieren ohne Signing: `CODE_SIGNING_ALLOWED=NO` an `xcodebuild` anhängen.

## Regeln

* Swift-Sprachmodus bleibt 5 (`SWIFT_VERSION: "5.0"` in `project.yml`); Mindestversion macOS 13.
  Keine APIs verwenden, die neuer sind (kein `@Observable`, kein `onChange(of:initial:)` usw.).
* `Shared/`: dort nur Foundation/Darwin, kein AppKit/SwiftUI (der Code soll später wieder von anderen Clients nutzbar sein).
* Die Mac-App läuft ohne App-Sandbox (Tastendrücke an andere Programme). Nicht wieder einschalten.
* Der Webserver im Helper (`WebServer.swift`, Port 8765) bindet bewusst auf alle Interfaces, ist aber standardmäßig aus
  und nur mit Kopplungscode/Token nutzbar (`WebAPI.swift`). Die Seite steckt als Raw-String in `WebAssets.swift`
  (`#"""…"""#`, damit JavaScript-Backslashes unverändert bleiben). Das JS nutzt bewusst kein Framework und nur ältere Syntax.
* Jeder Tastendruck läuft über `HelperController.executeShortcut(_:source:)`; neue Wege dort anschließen, nicht daran vorbei.
* TIS-/UCKeyTranslate-Aufrufe (`KeyMap`) gehören auf den Main-Thread.
* Sets, Buttons und Kürzel werden nur in der Mac-App bearbeitet (`SetStore`, Main-Thread). Die Webseite zeigt nur an.
  Gespeichert wird in `~/Library/Application Support/ShortcutPad/sets.json`; Export/Import als `.shortcutpad` (JSON, `PadFile`).
* Ein Set hat `items` (Buttons und Ordner gemischt, `PadItem`); Ordner (`PadFolder`) liegen nur auf der Hauptebene.
  Dateiformat 2; Format 1 (flache Liste `buttons`) wird beim Lesen übernommen (`PadSet.init(from:)`). Beim Ziehen entscheidet
  `PadPreview`, ob umsortiert (gleiche Ebene) oder in einen Ordner abgelegt wird; die „<“-Kachel (`BackTileView`) steht in Ordnerseiten
  an erster Stelle und ist Ablageziel für die Hauptebene. Die Webseite muss dieselbe Kachel zeigen.
* Das Fenster „Verbindung und Kopplung“ wird am Titel erkannt (`HelperController`, Selbsttest). Titel nicht ohne Anpassung ändern.
* `project.yml` ist die Quelle der Wahrheit; das `.xcodeproj` ist generiert und nicht eingecheckt.

## Schnittstelle

* Browser ⇄ Mac: HTTP/1.1, JSON, eine Anfrage pro Verbindung. `GET /`, `POST /api/pair {pin}`, `GET /api/status`,
  `GET /api/library` (Sets plus aktives Set, `PadLibraryPayload`), `POST /api/trigger {shortcut}`; Token im Header `X-Pad-Token`.
  Das `Shortcut`-JSON steht in `Shared/Protocol.swift` (`modifiers` als String-Array).
* Die Webseite fragt `GET /api/status` alle 1,5 s; daran erkennt die Mac-App, dass ein Gerät verbunden ist (`webClientActive`).
