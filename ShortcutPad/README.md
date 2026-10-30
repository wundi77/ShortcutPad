# ShortcutPad – Technik-Test

Ziel dieses Tests: klären, ob ein Button auf dem iPhone/iPad per USB-Kabel einen frei wählbaren
Tastaturbefehl am Mac auslösen kann – in dem Programm, das gerade vorne ist. Optik ist absichtlich nur grob.

```
iPhone/iPad (ShortcutPad)  ──USB-Kabel──  Mac (ShortcutPad Helper)  ──Tastendruck──►  aktives Programm
 Button + Kürzel-Editor      usbmuxd         CGEvent                                    (Photoshop, TextEdit …)
```

* **iOS-App** (`iOSApp/`): ein großer Button, darunter ein Editor für Modifier (⌃⌥⇧⌘) und Taste.
  Sie lauscht nur auf `127.0.0.1:49737` – also weder im WLAN noch sonst im Netz erreichbar.
* **Mac-Helper** (`MacHelper/`): findet per `usbmuxd` angeschlossene Geräte, verbindet sich durchs Kabel
  mit der iOS-App und sendet empfangene Kürzel als Tastendruck an das aktive Programm.
* **Shared** (`Shared/`): Kürzel-Modell, Nachrichten und das Paketformat (identisch auf beiden Seiten).

## Zweite Variante: Webseite statt App (gleiches WLAN/LAN)

Der Mac-Helper kann zusätzlich eine kleine Webseite anbieten. Das iPad öffnet sie im Safari – ohne App,
ohne Kabel und ohne Entwicklerkonto. Beide Wege (USB-App und Webseite) laufen parallel im selben Helper.

```
iPad/iPhone (Safari)  ──HTTP im lokalen Netz──  Mac (ShortcutPad Helper, Port 8765)  ──Tastendruck──►  aktives Programm
```

* Schalter im Helper-Fenster: „Webseite im lokalen Netzwerk anbieten“ (standardmäßig aus).
* Der Helper zeigt Adresse, 6-stelligen Kopplungscode und einen QR-Code. Der Code wird einmal eingegeben
  (oder per QR automatisch übernommen); danach merkt sich der Browser ein Token.
* Das Kürzel wird im Browser gespeichert (localStorage) und mit jedem Tipp an den Mac geschickt.
* Nicht verschlüsselt (HTTP). Nur in einem vertrauenswürdigen Netz verwenden.

Zeichen-Tasten ("z", "7", …) werden am Mac über das aktuelle Tastaturlayout aufgelöst, damit auch auf einem
deutschen Layout die richtige Taste gedrückt wird. Sondertasten (Return, Pfeile, F1–F12 …) haben feste Codes.

Mindestversionen: iOS 16 / macOS 13 (in `project.yml` änderbar, dann Code gegebenenfalls anpassen).

## Einrichtung

1. Im Terminal: `./setup.sh`
   (installiert bei Bedarf XcodeGen über Homebrew, erzeugt `ShortcutPad.xcodeproj` und öffnet es.)
   Eine Team-ID brauchst du dafür nicht. Das Bundle-Präfix kannst du in `Config/Signing.xcconfig` ändern.
2. Kostenlose Apple-ID in Xcode hinzufügen (Settings → Accounts). Dann bei **beiden Targets**
   (ShortcutPad und ShortcutPadHelper) unter „Signing & Capabilities“ das **Personal Team** wählen.
3. iPhone/iPad per Kabel anschließen, entsperren, am Gerät „Diesem Computer vertrauen“ bestätigen.
   Auf dem Gerät muss der Entwicklermodus aktiv sein (Einstellungen → Datenschutz & Sicherheit).
4. In Xcode das Schema **ShortcutPad** auf dein Gerät starten.
   (Mit der kostenlosen Apple-ID läuft die iOS-App 7 Tage; danach einfach erneut „Run“.)
5. Schema **ShortcutPadHelper** auf „My Mac“ starten.
6. Im Helper die Berechtigung **Bedienungshilfen** erteilen (Systemeinstellungen → Datenschutz & Sicherheit).
7. Einmalig danach: `./setup.sh` erneut ausführen. Es liest die Team-ID aus deinem Zertifikat und trägt sie
   in `Config/Signing.xcconfig` ein. So bleibt die Team-Auswahl erhalten, wenn das Projekt neu erzeugt wird.

## Testablauf

| Test | Vorgehen | Erwartung |
|---|---|---|
| A – Verbindung | Beide Apps laufen | iPhone: grüner Punkt „Mac verbunden“. Helper: „verbunden: <Gerätename>“ |
| B – Selbsttest | Helper-Fenster anklicken, am iPhone den Button tippen | Helper zeigt „⌘B“ bei „Letzte Taste hier“ |
| C – Echtes Programm | TextEdit (Rich Text), Text markieren, **in TextEdit klicken**, am iPhone tippen (⌘B) | Text wird fett |
| D – Eigenes Kürzel | Am iPhone z. B. ⌘⇧A oder F5 einstellen und in einem Programm mit diesem Kürzel testen | Kürzel wird dort ausgelöst |
| E – Layout | Zeichen wie „z“ oder „y“ einstellen | Es wird die Taste gedrückt, die auf deinem Layout dieses Zeichen ergibt |
| F – Webseite | Schalter im Helper an, Adresse oder QR-Code am iPad öffnen, koppeln, Button tippen | Wie Test B/C, im Protokoll steht `[Web]` |

Das Protokoll im Helper-Fenster zeigt jeden Verbindungsschritt und jeden Befehl mit Ergebnis.

## Wenn etwas nicht klappt

* **„iOS-App nicht erreichbar“ im Helper-Protokoll:** App am Gerät im Vordergrund öffnen und Gerät entsperren.
  Die iOS-App hört nur, solange sie vorne ist (im Hintergrund beendet iOS die Verbindung).
* **Kein USB-Gerät erkannt:** Kabel prüfen (Datenkabel, nicht nur Ladekabel), „Vertrauen“ bestätigen.
* **Tasten kommen nicht an, obwohl der Helper „✓ Freigegeben“ zeigt:** Helper nicht aus Xcode starten,
  sondern in Xcode über Product → Show Build Folder in Finder die App öffnen (oder in „Programme“ kopieren)
  und dort die Bedienungshilfen-Freigabe erteilen. Danach Helper neu starten.
* **Freigabe verschwindet nach jedem Build:** Es muss ein echtes Team (Apple Development) eingetragen sein,
  nicht „Sign to Run Locally“, sonst ändert sich die Signatur bei jedem Build.
* **iOS-Listener meldet „Port nicht verfügbar“:** App komplett schließen und neu starten.
* **Webseite lädt nicht:** Mac und iPad im selben Netz? Manche Router trennen WLAN-Geräte voneinander („Client-Isolation“,
  „Gastnetz“). Mac-Firewall: eingehende Verbindungen für ShortcutPadHelper erlauben. Mac nicht im Ruhezustand.

## Bewusste Einschränkungen dieses Tests

* Nur ein Button, nur ein Kürzel, kein Wechsel pro Programm.
* Zeichen werden nur ohne Zusatztasten aufgelöst (z. B. „/“ auf dem deutschen Layout braucht Shift+7
  und funktioniert deshalb noch nicht; auf einem französischen Layout trifft das auch auf Ziffern zu).
* Der Helper hat die Sandbox aus (nötig für usbmuxd und Tastendrücke) und ist damit nur für die
  Verbreitung außerhalb des Mac App Store gedacht (Developer ID + Notarisierung).
* Das Projekt wurde ohne Xcode geschrieben und noch nicht kompiliert. Siehe `CLAUDE.md` für den ersten Build.
