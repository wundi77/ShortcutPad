# ShortcutPad – Projektprotokoll und Basis-Prompt

Oct 29, 2026 · @Jens

## Auftrag

Die Technik steht und ist getestet: Ein Button auf iPad oder iPhone löst ein Tastaturkürzel im gerade aktiven Mac-Programm aus. Darauf baust du jetzt Bedienerführung und UX auf; das technische Gerüst wird nicht neu erfunden.

- **Produktidee:** Anklickbare Kürzel-Buttons für kreative Workflows (Photoshop und andere Adobe-CC-Programme). Der Button wirkt immer auf das Programm, das am Mac gerade vorne ist.
- **Nutzer:** Jens Wunderwald, Mediengestalter und Freelancer. macOS 27, Xcode 27, kostenlose Apple-ID (Personal Team), noch kein bezahlter Developer-Account.
- **Nächste Phase:** Optik, Bedienung, mehrere Buttons, Sammlungen pro Programm, Verwaltung der Kürzel. Bisher gibt es bewusst nur einen großen Button mit einem frei wählbaren Kürzel.
- **Zusammenarbeit:** Antworten auf Deutsch und knapp. Bei Architekturänderungen zuerst begründen. Die Regeln im Abschnitt „Entscheidungen und feste Regeln“ gelten weiter.

## Ziel und Stand

Zwei Wege vom Touch-Gerät zum Mac laufen in einem gemeinsamen Mac-Helper. Der Nutzer meldet, dass der Funktionstest gut funktioniert hat.

| Baustein | Status |
| --- | --- |
| USB-Variante: iOS-App + Mac-Helper | gebaut, installiert und getestet (Tests A–E funktionieren laut Nutzer) |
| Web-Variante: Mac-Helper liefert Seite im selben WLAN/LAN, iPad nutzt Safari | geschrieben, Seite im Browser gegen Mock-Server geprüft; Swift-Teil von mir nicht kompiliert |
| Signierung ohne Team-ID (`setup.sh`, Personal Team) | funktioniert |
| Schritt-für-Schritt-Anleitung (`ANLEITUNG.md`, Teile 1–7) | geliefert |
| Bedienung | bewusst roh: ein großer Button, ein Kürzel, Kürzel-Editor darunter |

Nicht vorhanden: mehrere Buttons, Sammlungen, programmabhängige Seiten, Speichern auf dem Mac, Design, Einstellungen.

## Architektur

&#91;embedded content: Architektur · zwei Wege, ein Helper\]

Der USB-Weg und der Web-Weg unterscheiden sich nur im Transport. Prüfung der Berechtigung, Tastencode und Tastendruck passieren für beide in `executeShortcut`.

## Komponenten und Dateien

Projekt `ShortcutPadTest`, erzeugt mit XcodeGen aus `project.yml` (Quelle der Wahrheit). Zwei Targets: `ShortcutPad` (iOS) und `ShortcutPadHelper` (macOS).

| Datei | Aufgabe |
| --- | --- |
| `Shared/Protocol.swift` | Kürzel-Modell (`Shortcut`, `KeyModifier`, `NamedKey`), Nachrichten (`PadMessage`, `MacStatus`, `TriggerRequest/Result`), Port 49737 |
| `Shared/FrameSocket.swift` | Rahmen aus 4 Byte Länge + JSON über POSIX-Sockets, `FDIO.readExactly/writeAll` |
| `iOSApp/PadServer.swift` | Hört auf `127.0.0.1:49737`, nimmt die Verbindung vom Mac an |
| `iOSApp/PadModel.swift` | Zustand, Kürzel in `UserDefaults` (`pad.shortcut.v1`, Standard ⌘B), Auslösen, Haptik |
| `iOSApp/ContentView.swift` | Statuskarte, großer Button, Ergebniszeile, Kürzel-Editor |
| `MacHelper/USBMux.swift` | Gespräch mit `usbmuxd`: Geräte beobachten, Tunnel zum iOS-Port öffnen |
| `MacHelper/KeyInjector.swift` | Zeichen → Tastencode je nach Tastaturlayout, Tastendruck per CGEvent |
| `MacHelper/HelperController.swift` | Zentrale: USB-Schleife, Berechtigung, aktives Programm, `executeShortcut(_:source:)` für USB und Web |
| `MacHelper/WebServer.swift` | Minimaler HTTP-Server auf Port 8765 |
| `MacHelper/WebAPI.swift` | Routen, Kopplungscode, Tokens, Sperre nach Fehlversuchen |
| `MacHelper/WebAssets.swift` | Die komplette Webseite (HTML, CSS, JavaScript) als Raw-String |
| `MacHelper/LocalNetwork.swift`, `QRCode.swift` | Eigene IPv4-Adressen, QR-Code für Adresse plus Code |
| `MacHelper/HelperView.swift` | Helper-Fenster: Verbindung, Web-Schalter, Berechtigung, Selbsttest, Protokoll |
| `setup.sh`, `Config/Signing.xcconfig` | Team-ID erkennen (falls vorhanden), XcodeGen, Projekt öffnen |
| `README.md`, `ANLEITUNG.md`, `CLAUDE.md` | Übersicht, Schritt-für-Schritt-Anleitung, Regeln für Claude Code |

## Protokolle

**USB, Mac ⇄ usbmuxd:** Unix-Socket `/var/run/usbmuxd`, 16-Byte-Header (Länge, Version 1, Typ 8, Tag; Little-Endian) plus XML-Plist. `Listen` meldet `Attached` und `Detached`. `Connect` mit `DeviceID` und `PortNumber` (UInt16, Big-Endian) macht daraus einen rohen TCP-Tunnel.

**USB, Mac ⇄ iOS-App:** 4 Byte Länge (Big-Endian) plus JSON. Nachrichten: `hello`, `status`, `trigger`, `result`. Die iOS-App lauscht nur auf `127.0.0.1:49737` und nur im Vordergrund; im Hintergrund schließt sie den Listener.

**Web, Browser ⇄ Mac:** HTTP/1.1, JSON, eine Anfrage pro Verbindung, Port 8765. Das Token gehört in den Header `X-Pad-Token`.

| Route | Zweck |
| --- | --- |
| `GET /` | die Webseite |
| `POST /api/pair` mit `{pin}` | Kopplung, Antwort `{token}`; 6-stelliger Code, nach 5 Fehlversuchen 30 Sekunden gesperrt |
| `GET /api/status` | `MacStatus`: Mac-Name, Bedienungshilfen freigegeben, aktives Programm; Seite fragt alle 1,5 s |
| `POST /api/trigger` mit `{shortcut}` | löst das Kürzel aus, Antwort `{ok, message}` |

Das Kürzel-JSON ist überall gleich: `{"key":"b","modifiers":["command"]}`. `key` ist ein einzelnes Zeichen oder ein Name wie `return`, `f5`, `left`.

**Tastendruck:** `CGEvent` über `.cghidEventTap`. Modifier werden als eigene Tasten gedrückt (⌃ ⌥ ⇧ ⌘), danach Taste runter und hoch, mit kurzen Pausen. Zeichen werden über das aktuelle Tastaturlayout (`UCKeyTranslate`) aufgelöst, Sondertasten haben feste Codes.

## Entscheidungen und feste Regeln

- **Zwei Wege, ein Helper:** USB und Web bleiben nebeneinander. Beide laufen über `executeShortcut(_:source:)`; neue Wege dort anschließen, nicht daran vorbei.
- **Mindestversionen:** iOS 16 und macOS 13. Swift-Sprachmodus 5 (`SWIFT_VERSION: "5.0"`), `ObservableObject` und `@Published`, kein `@Observable`, kein `onChange(of:initial:)`.
- **`Shared/`** wird von beiden Targets kompiliert: nur Foundation und Darwin, kein UIKit, AppKit oder SwiftUI.
- **Mac-Helper ohne Sandbox und ohne Hardened Runtime** (nötig für `usbmuxd` und Tastendrücke). Nicht wieder einschalten. Folge: Verbreitung nur außerhalb des Mac App Store (Developer ID plus Notarisierung).
- **Netz:** Der iOS-Listener bindet nur `127.0.0.1`. Der Webserver bindet auf alle Schnittstellen, ist aber standardmäßig aus und nur mit Kopplungscode und Token nutzbar; HTTP ohne Verschlüsselung, nur für vertrauenswürdige Netze.
- **Tastaturlayout:** Aufrufe von `TISCopyCurrentASCIICapableKeyboardLayoutInputSource` und `UCKeyTranslate` gehören auf den Main-Thread.
- **Webseite:** ein einziges Dokument in `WebAssets.swift`, kein Framework, nur ältere JavaScript-Syntax, Zustand in `localStorage` (immer mit `try/catch`).
- **Plattform:** nativ mit Xcode. SideStore wurde geprüft und vorerst verworfen; ein bezahlter Developer-Account bleibt als spätere Option.
- **Sprache:** Oberfläche und Kommentare auf Deutsch.

## Build, Signierung, Test

1. ZIP entpacken, im Terminal `./setup.sh` ausführen. Es erkennt eine Team-ID aus dem Zertifikat, installiert bei Bedarf XcodeGen über Homebrew, erzeugt `ShortcutPadTest.xcodeproj` und öffnet es. Ohne Team-ID kein Abbruch.
2. In Xcode bei beiden Targets das **Personal Team** wählen. Bundle-Präfix steht in `Config/Signing.xcconfig` (`com.wundi77.shortcutpad`).
3. Helper (`ShortcutPadHelper`, My Mac) mit ⌘R starten, Bedienungshilfen freigeben.
4. iOS-App: Gerät per Kabel, „Vertrauen“, Entwicklermodus am Gerät einschalten, Schema `ShortcutPad` auf das Gerät starten, Entwickler in den iOS-Einstellungen als vertrauenswürdig markieren.
5. Web-Variante: im Helper den Schalter einschalten, Adresse oder QR-Code am iPad öffnen, koppeln.

Mit der kostenlosen Apple-ID läuft die iOS-App 7 Tage, danach erneut aus Xcode starten. Die Web-Variante hat dieses Limit nicht. Zum reinen Kompilieren ohne Signatur: `CODE_SIGNING_ALLOWED=NO` an `xcodebuild` hängen.

Tests: A Verbindung, B Selbsttest im Helper-Fenster, C TextEdit fett, D eigenes Kürzel, E Layout (z/y), F Web (Seite, Auslösen, Kürzel ändern, falscher Code, Zurücksetzen). Details stehen in `ANLEITUNG.md`.

## Bekannte Einschränkungen und Risiken

- **iOS-App im Hintergrund:** iOS beendet den Listener. Die App muss vorne und das Gerät entsperrt sein. Die Web-Variante hat dieses Problem nicht, solange Safari offen ist.
- **Kostenlose Apple-ID:** 7 Tage Gültigkeit der iOS-App, höchstens 3 Apps, 10 App-IDs pro Woche. Beim Mac-Helper ohne besondere Berechtigungen ist ein Limit nicht bestätigt.
- **Bedienungshilfen-Freigabe:** hängt an der Signatur. Mit „Sign to Run Locally“ geht sie nach jedem Build verloren. Der Helper läuft zuverlässiger aus dem Build-Ordner als aus Xcode.
- **Zeichen mit Zusatztaste:** Zeichen werden nur ohne Zusatztasten aufgelöst. Beispiel: „/“ braucht auf dem deutschen Layout Shift+7 und geht noch nicht.
- **Web-Variante:** unverschlüsselt, braucht gleiches Netz, scheitert an Gastnetzen und Router-Client-Isolation, Mac darf nicht schlafen, macOS-Firewall fragt beim ersten Mal. Die Seite zeigt nur den Mac, der sie ausliefert.
- **Ein Kopplungscode pro Helper-Start:** ein neuer Code entsteht nur bei „Kopplungen löschen“ und bei jedem Start; bestehende Tokens bleiben gespeichert.
- **Nur ein Button, ein Mac, ein Kanal pro Gerät:** keine Speicherung von Sammlungen, keine Synchronisierung.
- **Code-Prüfung:** Die Swift-Dateien der Web-Variante habe ich ohne Compiler geschrieben. Beim ersten Build können kleine Fehler auftreten.

## Offene Punkte für die UX-Phase

Diese Fragen sind noch nicht entschieden. Kläre sie mit Jens, bevor du große Teile baust.

- [ ] **Hauptweg:** USB-App, Web-Seite oder beides weiterentwickeln? Die UX sollte für beide dieselbe Datenbasis nutzen.
- [ ] **Datenmodell:** Buttons, Gruppen und Sammlungen (z. B. pro Programm wie Photoshop, Illustrator, InDesign). Wo liegen die Daten: auf dem Mac, im Gerät oder in beiden?
- [ ] **Programmbezug:** Sollen Sammlungen automatisch wechseln, wenn sich das aktive Programm am Mac ändert? Das aktive Programm meldet der Helper bereits.
- [ ] **Bearbeiten:** Kürzel aufnehmen statt einstellen, Beschriftung, Symbol, Farbe, Anordnung, Größe der Buttons.
- [ ] **Rückmeldung:** Haptik, Farbe, Ton, Fehlermeldungen (Freigabe fehlt, Mac nicht erreichbar, Kürzel existiert im Layout nicht).
- [ ] **Layouts:** iPhone hoch und quer, iPad, mehrere Seiten, Wischen zwischen Sammlungen.
- [ ] **Mac-Seite:** Helper als Menüleisten-App ohne Fenster? Autostart? Einstellungen und Kopplung getrennt von der Diagnose.
- [ ] **Sondertasten und Zeichen mit Zusatztaste:** Auflösung für „/“, „#“ u. ä. verbessern.
- [ ] **Verbreitung:** privat testen, später Developer ID und Notarisierung; iOS-App über TestFlight oder App Store erst mit bezahltem Account.

**Arbeitsweise für die nächste Sitzung:** Zuerst das Projekt bauen und Fehler der Web-Dateien beheben, ohne die Architektur zu ändern. Danach UX-Konzept (Ablauf und Bildschirme) vorschlagen und mit Jens abstimmen, dann umsetzen. Nach jeder Änderung `project.yml` und `ANLEITUNG.md` aktuell halten.
