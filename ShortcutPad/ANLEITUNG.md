# ShortcutPad – Schritt für Schritt

Ziel: Auf dem iPad oder iPhone im Safari einen Button antippen → das Tastaturkürzel wird am Mac im aktiven Programm ausgelöst.
Du brauchst: Mac mit Xcode 27, eine Apple-ID (kostenlos reicht) und ein iPad/iPhone im **selben WLAN/LAN** wie der Mac.
Auf dem iPad läuft nur Safari: keine App, kein Kabel, kein Entwicklerkonto auf dem Gerät.

---

## Teil 1 – Vorbereitung am Mac

1. **Repository holen** (github.com/wundi77/ShortcutPad, z. B. nach `~/Developer/ShortcutPad`); das Xcode-Projekt liegt im Unterordner `ShortcutPad/`.
2. **Xcode einmal öffnen** und die Lizenz sowie zusätzliche Komponenten bestätigen, falls Xcode danach fragt.
3. **Apple-ID in Xcode hinzufügen:** Xcode → Settings → Accounts → **+** → Apple-ID anmelden.
   Danach steht dort ein „Personal Team“.
4. **Homebrew** muss installiert sein (siehe brew.sh). Das Skript braucht es, um XcodeGen zu installieren.
5. **Terminal öffnen** und ausführen:
   ```
   cd ~/Developer/ShortcutPad/ShortcutPad
   chmod +x setup.sh
   xattr -dr com.apple.quarantine .
   ./setup.sh
   ```
   * Der Hinweis „Es ist noch keine Team-ID vorhanden“ ist in Ordnung.
   * Danach öffnet sich das Projekt in Xcode.
   * Alte Projektdateien aus früheren Ständen (`ShortcutPadTest.xcodeproj`) kannst du löschen. Das Projekt hat jetzt nur noch ein Ziel: die Mac-App.

## Teil 2 – Signatur einstellen (einmalig)

6. Links in der Dateileiste ganz oben auf **ShortcutPad** klicken (blaues Symbol).
7. Unter **Targets** das Ziel **ShortcutPadHelper** wählen → Tab **Signing & Capabilities** →
   bei **Team** dein **Personal Team** auswählen.
   Falls Xcode eine Bundle-ID als „nicht verfügbar“ meldet, ändere den Präfix in `Config/Signing.xcconfig`
   (`PAD_BUNDLE_PREFIX`) auf etwas Eigenes und führe `./setup.sh` erneut aus.

## Teil 3 – Mac-App starten

8. In der Werkzeugleiste oben: Schema **ShortcutPadHelper**, Ziel **My Mac** (ohne Zusatz „Designed for iPad“).
9. **⌘R** drücken. Die App baut und öffnet das Fenster **ShortcutPad**; in der Menüleiste erscheint ein Raster-Symbol.
10. **Bedienungshilfen erlauben:** Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen →
    **ShortcutPadHelper** einschalten. Der Button „Systemeinstellungen öffnen“ im Fenster „Verbindung und Kopplung“ bringt dich dorthin.
    Wenn weiter „nicht freigegeben“ steht: App beenden und neu starten.
11. Wenn der erste Build durch ist, im Terminal erneut `./setup.sh` ausführen. Es liest die Team-ID aus deinem Zertifikat und trägt
    sie in `Config/Signing.xcconfig` ein. Danach bleibt die Signatur-Einstellung auch erhalten, wenn das Projekt neu erzeugt wird.

## Teil 4 – Webseite am iPad oder iPhone (Kopplung per QR-Code)

Der Mac liefert die Seite im lokalen Netz aus. Voraussetzung: Mac und Gerät sind im **selben Netzwerk**.

12. Menüleisten-Symbol → **Verbindung und Kopplung** (oder Chip oben rechts im Editor).
13. Schalter **„Webseite im lokalen Netzwerk anbieten“** einschalten.
    * Beim ersten Mal fragt macOS evtl. „Möchten Sie, dass ShortcutPadHelper eingehende Netzwerkverbindungen akzeptiert?“ → **Erlauben**.
    * Im Fenster erscheinen **Adresse** (z. B. `http://192.168.178.25:8765/`), **Kopplungscode** und **QR-Code**.
14. **Am iPad/iPhone:** Kamera auf den QR-Code richten und den Link antippen (öffnet Safari und koppelt automatisch).
    Alternativ in Safari die Adresse eintippen und den 6-stelligen Code eingeben.
15. Die Seite zeigt oben **„Mac verbunden“** und das aktive Programm. Hinweis: Die Seite zeigt vorerst noch den einen Test-Button.
    Sets und Ordner aus der Mac-App folgen im nächsten Schritt.
16. Optional: In Safari **Teilen → Zum Home-Bildschirm** legt ein Symbol an, das die Seite ohne Safari-Leiste öffnet.

| Test | Vorgehen | Erwartung |
|---|---|---|
| F1 – Seite erreichbar | QR scannen oder Adresse öffnen | Seite lädt, nach Kopplung „Mac verbunden“ |
| F2 – Auslösen | TextEdit öffnen (Rich Text), Text markieren, in TextEdit klicken, am iPad den Button tippen | Text wird fett; im Fenster „Verbindung und Kopplung“ steht `[Web]` |
| F3 – Kürzel ändern | „Ändern“ antippen, Modifier und Taste wählen | Beschriftung des Buttons ändert sich, bleibt nach Neuladen erhalten |
| F4 – Schutz | Zweites Gerät mit falschem Code koppeln | „Falscher Code“; nach 5 Fehlversuchen 30 Sekunden Sperre |
| F5 – Zurücksetzen | „Kopplungen löschen“ im Mac-Fenster | Gerät meldet „Kopplung nicht mehr gültig“ |

Gut zu wissen:
* Die Verbindung ist **unverschlüsselt (HTTP)**. Im Heimnetz in Ordnung, in fremden Netzen nicht verwenden.
* Der Mac darf nicht schlafen, sonst ist die Seite nicht erreichbar.
* Die Seite funktioniert nur, solange die Mac-App läuft und der Schalter an ist.

---

## Teil 5 – Mac-App: Sets und Buttons bearbeiten

Der Mac-Helper ist die Mac-App. Beim Start öffnet sich das Fenster **ShortcutPad** (Editor), und in der Menüleiste
erscheint ein Symbol. Das Fenster darf geschlossen werden, die App läuft weiter.

1. **Sets:** Links stehen die Sets (zuerst „Photoshop“ als Beispiel und „Allgemein“ als Rückfall). Ein Set gehört zu einem
   Programm und wechselt automatisch, sobald dieses Programm am Mac vorne ist. „Allgemein“ gilt für alle anderen Programme.
2. **Buttons:** In der Vorschau in der Mitte anklicken zum Bearbeiten, ziehen zum Neuanordnen, „+ Button“ legt einen neuen an
   (der Dialog „Kürzel aufnehmen“ öffnet sich gleich). Das Gerät oben (iPhone/iPad, hoch/quer) zeigt, wie viele Spalten die Webseite dort hat.
3. **Rechts** stehen Beschriftung, Kürzel, Farbe und Gruppe des gewählten Buttons. „Am Mac testen“ holt das Programm des Sets
   nach vorne und sendet das Kürzel.
4. **Gruppen** sind Farben: Unten in der Vorschau auf eine Gruppe klicken, um Name und Farbe zu ändern. Ein Button kann die
   Gruppenfarbe mit einer eigenen Farbe überschreiben.
5. **Set-Einstellungen:** Name, Programm, automatisches Umschalten, Set-Farbe, Stil (Balken, Voll, Betont), Buttongröße und ob
   das Kürzel klein auf dem Button steht.
6. **Ordner:** Auf der Hauptebene stehen Buttons und Ordner gemischt. „Ordner“ im Kopf legt einen neuen an; Doppelklick auf einen Ordner
   (oder „Ordner öffnen“ rechts) öffnet seine Seite. Dort steht als **erste Kachel ein hellgrauer Button mit „<“**: Ein Klick springt
   zurück auf die Hauptebene. Buttons lassen sich auf einen Ordner ziehen (legt sie dort ab) und in der Ordnerseite auf die „<“-Kachel
   (legt sie auf die Hauptebene). Ohne Ziehen: im Feld „Ablegen in“ rechts. Ordner gibt es nur eine Ebene tief.
7. **Import/Export:** Sets werden als Datei `.shortcutpad` gesichert und auf einem anderen Mac importiert (als neues Set oder
   ein gleichnamiges Set ersetzen).
8. **Menüleiste:** zeigt den Status, das vorderste Programm und das aktive Set. „Fixieren“ hält das Set fest, auch wenn das
   Programm wechselt. Ein Klick auf ein Set fixiert es ebenfalls; „Wieder automatisch wählen“ hebt das auf.
9. **Verbindung und Kopplung** (Menüleiste oder Chip oben rechts im Editor): Webseite, Kopplungscode, QR-Code, Berechtigung, Protokoll.

Die Sets liegen in `~/Library/Application Support/ShortcutPad/sets.json`. Die Webseite zeigt die Sets in einem
nächsten Schritt an; die Daten liefert der Mac schon über `GET /api/library` (mit Token).

### Tests der Mac-App

| Test | Vorgehen | Erwartung |
|---|---|---|
| G – Start | App starten | Editor mit Set „Photoshop“, 28 Buttons, Symbol in der Menüleiste |
| H – Umschalten | Photoshop (oder TextEdit nach Zuordnung) nach vorne holen | Set wird in der Seitenleiste und im Menüleistenfenster „aktiv“ |
| I – Kürzel aufnehmen | Button wählen, „Aufnehmen“, ⇧⌘N drücken | Tastenköpfe zeigen ⇧ ⌘ N, „Übernehmen“ speichert |
| J – Warnung | Beim Aufnehmen „/“ auf deutschem Layout drücken | Warnung statt stiller Fehler |
| K – Neuanordnen | Button in der Vorschau auf einen anderen ziehen | Reihenfolge ändert sich |
| L – Export/Import | Set exportieren, in „Import“ als neues Set laden | Set erscheint mit „(Import)“ im Namen |
| M – Neustart | App beenden und neu starten | Sets sind unverändert |
| N – Ordner | „Ordner“ anklicken, benennen, per Doppelklick öffnen | Ordnerseite mit hellgrauer „<“-Kachel an erster Stelle |
| O – Zurück | Auf die „<“-Kachel klicken | Hauptebene, der Ordner ist ausgewählt |
| P – Hinein ziehen | Einen Button auf eine Ordner-Kachel ziehen und loslassen | Ordner zeigt eine Zahl mehr, Button ist von der Hauptebene verschwunden |
| Q – Heraus ziehen | In einem Ordner einen Button auf „<“ ziehen und loslassen | Button steht auf der Hauptebene hinter dem Ordner |
| R – Alte Datei | Eine alte `sets.json` (Format 1, nur Buttons) laden | Alle Buttons stehen auf der Hauptebene |

## Wenn etwas nicht klappt

| Problem | Lösung |
|---|---|
| Rote Fehler beim Bauen | Meldungen aus dem Issue Navigator (Warndreieck links) kopieren oder Screenshot machen. Der Code wurde ohne Compiler geschrieben, einzelne Fehler sind beim ersten Build möglich. |
| App zeigt „✓ Freigegeben“, aber es passiert nichts | App nicht aus Xcode starten: Product → Show Build Folder in Finder → `ShortcutPadHelper.app` von dort starten, Freigabe dort erteilen |
| Bedienungshilfen-Freigabe verschwindet nach jedem Build | Es muss das Personal Team als Signatur eingestellt sein (nicht „Sign to Run Locally“) |
| Webseite lädt nicht | Gleiches Netz? Kein Gastnetz und keine „Client-Isolation“ im Router? Schalter in der Mac-App an? Adresse exakt mit `http://` und `:8765`? |
| Webseite: „Mac nicht erreichbar“ | Mac im Ruhezustand oder Helper beendet; macOS-Firewall-Abfrage mit „Erlauben“ bestätigen (Systemeinstellungen → Netzwerk → Firewall → Optionen) |
| Helper: „Port ist bereits belegt“ | Zweite Helper-Instanz läuft noch: alle beenden, neu starten |
| Mehrere Adressen im Helper | Die erste ist meist WLAN. Notfalls die andere probieren (z. B. LAN-Kabel) |
