# ShortcutPad – Schritt für Schritt

Ziel: Button auf dem iPhone/iPad antippen → Tastaturkürzel wird am Mac im aktiven Programm ausgelöst.
Du brauchst: Mac mit Xcode 27, iPhone oder iPad, USB-Kabel (Daten, nicht nur Laden), eine Apple-ID (kostenlos reicht).
Teil 1–6: USB-App. Teil 7: Webseite im Safari (ohne iPad-App und ohne Kabel).

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

## Teil 2 – Signatur einstellen (einmalig)

6. Links in der Dateileiste ganz oben auf **ShortcutPad** klicken (blaues Symbol).
7. Unter **Targets** zuerst **ShortcutPad** wählen → Tab **Signing & Capabilities** →
   bei **Team** dein **Personal Team** auswählen.
8. Dasselbe beim Target **ShortcutPadHelper**.
   Rote Signatur-Fehler sollten danach verschwinden. Falls Xcode eine Bundle-ID als „nicht verfügbar“ meldet,
   ändere den Präfix in `Config/Signing.xcconfig` (`PAD_BUNDLE_PREFIX`) auf etwas Eigenes und führe `./setup.sh` erneut aus.

## Teil 3 – Mac-Helper starten

9. In der Werkzeugleiste oben: Schema **ShortcutPadHelper**, Ziel **My Mac**.
10. **⌘R** drücken. Der Helper baut und öffnet ein Fenster.
11. **Bedienungshilfen erlauben:** Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen →
    **ShortcutPadHelper** einschalten. Der Button „Systemeinstellungen öffnen“ im Helper-Fenster bringt dich dorthin.
    Wenn der Helper weiter „nicht freigegeben“ zeigt: beenden und neu starten.

## Teil 4 – iPhone/iPad vorbereiten und App starten

12. Gerät **per Kabel anschließen, entsperren**, am Gerät **„Diesem Computer vertrauen“** bestätigen.
13. In Xcode: Window → **Devices and Simulators** öffnen und warten, bis dein Gerät dort erscheint.
14. **Entwicklermodus am Gerät** (nicht am Mac!): Einstellungen → Datenschutz & Sicherheit → ganz unten
    **Entwicklermodus** einschalten → Gerät startet neu → nach dem Neustart „Einschalten“ bestätigen.
    Der Eintrag erscheint erst, wenn das Gerät mit Xcode am Mac verbunden war.
15. In Xcode: Schema **ShortcutPad**, Ziel **dein Gerät**, **⌘R**.
16. Beim ersten Start meldet iOS evtl. „Nicht vertrauenswürdiger Entwickler“:
    Einstellungen → Allgemein → **VPN & Geräteverwaltung** → deine Apple-ID antippen → **Vertrauen**.
    Danach die App erneut starten.

## Teil 5 – Testen

Beide Apps laufen, Gerät entsperrt und ShortcutPad im Vordergrund.

| Test | Vorgehen | Erwartung |
|---|---|---|
| A – Verbindung | Beide Apps offen | iPhone: grüner Punkt „Mac verbunden“; Helper: „verbunden: <Gerätename>“ |
| B – Selbsttest | Helper-Fenster anklicken, am iPhone den großen Button tippen | Helper zeigt „⌘B“ bei „Letzte Taste hier“ |
| C – Echtes Programm | TextEdit öffnen, Format → Rich Text, Text eintippen und markieren, in TextEdit klicken, am iPhone tippen | Text wird fett |
| D – Eigenes Kürzel | Am iPhone Modifier und Taste ändern (z. B. ⌘⇧A oder F5), in einem Programm mit diesem Kürzel testen | Kürzel wird ausgelöst |
| E – Layout | Zeichen „z“ oder „y“ einstellen | Es wird die Taste gedrückt, die auf deinem Layout dieses Zeichen ergibt |

## Teil 6 – Team-ID dauerhaft eintragen

17. Wenn der erste Build durch ist, im Terminal erneut `./setup.sh` ausführen.
    Es liest die Team-ID aus deinem Zertifikat und trägt sie in `Config/Signing.xcconfig` ein.
    Danach bleibt die Signatur-Einstellung auch erhalten, wenn das Projekt neu erzeugt wird.

---

## Teil 7 – Variante „Webseite“ (ohne App, ohne Kabel)

Hier läuft nichts auf dem iPad außer Safari. Der Mac-Helper liefert die Seite im lokalen Netz aus.
Voraussetzung: Mac und iPad sind im **selben Netzwerk** (gleiches WLAN oder LAN).
Die USB-Variante bleibt unverändert; beide können gleichzeitig laufen.

18. **Helper neu bauen und starten** (Schema ShortcutPadHelper, My Mac, ⌘R), damit die neuen Dateien enthalten sind.
    Bedienungshilfen bleiben wie bisher freigegeben (sonst erneut erlauben).
19. Im Helper-Fenster den Schalter **„Webseite im lokalen Netzwerk anbieten“** einschalten.
    * Beim ersten Mal fragt macOS evtl. „Möchten Sie, dass ShortcutPadHelper eingehende Netzwerkverbindungen akzeptiert?“ → **Erlauben**.
    * Im Fenster erscheinen eine **Adresse** (z. B. `http://192.168.178.25:8765/`), ein **Kopplungscode** und ein **QR-Code**.
20. **Am iPad:** Kamera auf den QR-Code richten und den Link antippen (öffnet Safari und koppelt automatisch).
    Alternativ in Safari die Adresse eintippen und den 6-stelligen Code eingeben.
21. Es erscheint der große Button mit ⌘B. Oben muss **„Mac verbunden“** und das aktive Programm stehen.
22. Optional: In Safari **Teilen → Zum Home-Bildschirm** legt ein Symbol an, das die Seite ohne Safari-Leiste öffnet.

| Test | Vorgehen | Erwartung |
|---|---|---|
| F1 – Seite erreichbar | QR scannen oder Adresse öffnen | Seite lädt, nach Kopplung „Mac verbunden“ |
| F2 – Auslösen | Wie Test C (TextEdit, markieren, in TextEdit klicken, am iPad tippen) | Text wird fett; im Helper-Protokoll steht `[Web]` |
| F3 – Kürzel ändern | „Ändern“ antippen, Modifier und Taste wählen | Beschriftung des Buttons ändert sich, bleibt nach Neuladen erhalten |
| F4 – Schutz | Zweites Gerät mit falschem Code koppeln | „Falscher Code“; nach 5 Fehlversuchen 30 Sekunden Sperre |
| F5 – Zurücksetzen | Im Helper „Kopplungen löschen“ | iPad meldet „Kopplung nicht mehr gültig“ |

Gut zu wissen:
* Die Verbindung ist **unverschlüsselt (HTTP)**. Für den Test im Heimnetz in Ordnung, in fremden Netzen nicht verwenden.
* Der Mac darf nicht schlafen, sonst ist die Seite nicht erreichbar.
* Die Seite funktioniert nur, solange der Helper läuft und der Schalter an ist.
* Es gibt kein 7-Tage-Limit wie bei der iOS-App.

---

## Teil 8 – Mac-App: Sets und Buttons bearbeiten

Der Mac-Helper ist jetzt die Mac-App. Beim Start öffnet sich das Fenster **ShortcutPad** (Editor), und in der Menüleiste
erscheint ein Symbol. Das Fenster darf geschlossen werden, die App läuft weiter.

1. **Sets:** Links stehen die Sets (zuerst „Photoshop“ als Beispiel und „Allgemein“ als Rückfall). Ein Set gehört zu einem
   Programm und wechselt automatisch, sobald dieses Programm am Mac vorne ist. „Allgemein“ gilt für alle anderen Programme.
2. **Buttons:** In der Vorschau in der Mitte anklicken zum Bearbeiten, ziehen zum Neuanordnen, „+ Button“ legt einen neuen an
   (der Dialog „Kürzel aufnehmen“ öffnet sich gleich). Das Gerät oben (iPhone/iPad, hoch/quer) zeigt Spalten und Mindestgröße.
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
9. **Verbindung und Kopplung** (Menüleiste oder Chip oben rechts im Editor): USB, Webseite, Kopplungscode, Berechtigung, Protokoll.

Die Sets liegen in `~/Library/Application Support/ShortcutPad/sets.json`. iPad, iPhone und Webseite zeigen die Sets in
einem späteren Schritt an; die Webseite kann sie schon über `GET /api/library` abrufen (mit Token).

### Test der Mac-App

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
| Gerät erscheint nicht in der Zielliste | Kabel wechseln, Gerät entsperren, „Vertrauen“ bestätigen, Entwicklermodus prüfen, Xcode neu starten |
| Helper-Protokoll: „iOS-App nicht erreichbar“ | ShortcutPad am Gerät im Vordergrund öffnen und Gerät entsperren (im Hintergrund lauscht die App nicht) |
| Kein USB-Gerät erkannt | Datenkabel verwenden, „Vertrauen“ erneut bestätigen |
| Helper zeigt „✓ Freigegeben“, aber es passiert nichts | Helper nicht aus Xcode starten: Product → Show Build Folder in Finder → `ShortcutPadHelper.app` von dort starten, Freigabe dort erteilen |
| Bedienungshilfen-Freigabe verschwindet nach jedem Build | Es muss das Personal Team als Signatur eingestellt sein (nicht „Sign to Run Locally“) |
| „Port nicht verfügbar“ am iPhone | ShortcutPad komplett schließen und neu starten |
| Webseite lädt nicht | Gleiches Netz? Kein Gastnetz und keine „Client-Isolation“ im Router? Schalter im Helper an? Adresse exakt mit `http://` und `:8765`? |
| Webseite: „Mac nicht erreichbar“ | Mac im Ruhezustand oder Helper beendet; macOS-Firewall-Abfrage mit „Erlauben“ bestätigen (Systemeinstellungen → Netzwerk → Firewall → Optionen) |
| Helper: „Port ist bereits belegt“ | Zweite Helper-Instanz läuft noch: alle beenden, neu starten |
| Mehrere Adressen im Helper | Die erste ist meist WLAN. Notfalls die andere probieren (z. B. LAN-Kabel) |
| iOS-App startet nach 7 Tagen nicht mehr | Normal bei kostenloser Apple-ID: Gerät anschließen und in Xcode erneut ⌘R |
