# ShortcutPad – Schritt für Schritt

Ziel: Button auf dem iPhone/iPad antippen → Tastaturkürzel wird am Mac im aktiven Programm ausgelöst.
Du brauchst: Mac mit Xcode 27, iPhone oder iPad, USB-Kabel (Daten, nicht nur Laden), eine Apple-ID (kostenlos reicht).
Teil 1–6: USB-App. Teil 7: Webseite im Safari (ohne iPad-App und ohne Kabel).

---

## Teil 1 – Vorbereitung am Mac

1. **ZIP entpacken**, z. B. nach `~/Developer/ShortcutPadTest`.
2. **Xcode einmal öffnen** und die Lizenz sowie zusätzliche Komponenten bestätigen, falls Xcode danach fragt.
3. **Apple-ID in Xcode hinzufügen:** Xcode → Settings → Accounts → **+** → Apple-ID anmelden.
   Danach steht dort ein „Personal Team“.
4. **Homebrew** muss installiert sein (siehe brew.sh). Das Skript braucht es, um XcodeGen zu installieren.
5. **Terminal öffnen** und ausführen:
   ```
   cd ~/Developer/ShortcutPadTest
   chmod +x setup.sh
   xattr -dr com.apple.quarantine .
   ./setup.sh
   ```
   * Der Hinweis „Es ist noch keine Team-ID vorhanden“ ist in Ordnung.
   * Danach öffnet sich das Projekt in Xcode.

## Teil 2 – Signatur einstellen (einmalig)

6. Links in der Dateileiste ganz oben auf **ShortcutPadTest** klicken (blaues Symbol).
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
