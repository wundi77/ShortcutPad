# ShortcutPad – Designentscheidungen (Stand 29.10.2026)

Canvas: https://claude.ai/artifact/Au7yi2PJPHhkVB5KEScm15 (Quellen in `design/canvas/`)

## Festgelegt (mit Jens abgestimmt)

- **Format:** klickbarer Canvas mit Artboards für Mac-App, iPhone/iPad (hoch/quer), Zustände.
- **Programmbezug:** Sets sind einem Programm zugeordnet und wechseln automatisch mit dem vordersten Mac-Programm.
  Manuell wählen und per Pin „fixieren“ geht jederzeit.
- **Gruppierung:** nur über Farbe, keine Abschnittsüberschriften. Gruppen sind benannte Farb-Tags; ein Button kann die
  Gruppenfarbe überschreiben. Neuanordnen per Ziehen in der Mac-Vorschau.
- **Mac-App:** Fenster-App (Sets links, Pad-Vorschau Mitte, Button-Eigenschaften rechts) plus Menüleisten-Symbol.
- **Button-Stil:** pro Set wählbar (Balken, Voll, Betont).
- **Import/Export:** Sets als Datei (.shortcutpad) sichern, teilen und auf anderem Mac importieren (als neues Set oder ersetzen).
- **Kürzel auf dem Button:** klein unter der Beschriftung, pro Set abschaltbar.
- **Farben:** Gelb und Hellorange entfallen. Acht Farben: Rot, Orange, Pink, Blau, Indigo, Grün, Türkis, Grau.

## Ordner (Entwurf im Canvas, noch nicht umgesetzt)

- Auf der Hauptebene eines Sets stehen Buttons und Ordner gemischt, in einer gemeinsamen Reihenfolge.
- **Eine Ordner-Ebene**: Ordner liegen nur auf der Hauptebene, nicht in anderen Ordnern.
- Ein Ordner hat Name und eigene Farbe. Auf dem Pad erkennt man ihn an der Lasche oben links und der Angabe „n Buttons“ statt des Kürzels.
- **Eigene Ordnerseite**: Ein Tipp öffnet die Seite mit Titel und Zurück-Taste (am Gerät) bzw. mit Brotkrümel „Photoshop › Ordner“ (am Mac).
  Welcher Ordner offen ist, merkt sich nur das Gerät.
- Mac-Editor: Buttons und Ordner lassen sich im Raster frei verschieben. Ein Button auf einen Ordner ziehen legt ihn dort ab.
  In der Ordnerseite wird ein Button auf „Photoshop“ im Brotkrümel gezogen, um ihn auf die Hauptebene zu legen.
  Alternative ohne Ziehen: „Ablegen in“ im Inspektor.
- Umsetzung in Schritten: erst Datenmodell und Datei-Umstellung (alte Dateien werden übernommen), dann Anzeige und Ordner anlegen, zuletzt das Ziehen.

## Regeln aus dem Briefing

- Sets, Buttons, Kürzel, Farben werden **ausschließlich am Mac** bearbeitet. iOS-App und Webseite zeigen nur an und lösen aus.
- Webseite und iOS-App haben dieselbe Optik, responsiv für alle Größen und Ausrichtungen.
- Buttons haben **kein Symbol**, nur Text (Beschriftung) und Farbe. Optional steht das Kürzel klein darunter.

## Entwurf im Canvas (noch zu bestätigen)

- Stile pro Set: Balken (dunkel mit Farbbalken), Voll, Betont (wichtige Buttons voll).
- Mindestgröße: 80 pt iPhone, 128 pt iPad. Spaltenzahl = so viele wie mit Mindestgröße passen, Rest scrollt.
- Acht Farben, weiße Schrift auf Farbe mindestens 4,5:1.
- Rückmeldung: Haptik, gedrückter Button, Toast mit gesendetem Kürzel; Zustände für Offline und fehlende Freigabe.

## Technische Folgen für die Umsetzung

- Datenhaltung auf dem Mac (JSON in Application Support). Neue Routen/Nachrichten: Sets abrufen, aktives Set melden.
  `executeShortcut` bleibt der einzige Auslöse-Pfad (USB und Web).
- Das Kürzel-Modell bekommt Beschriftung, Farbe, Gruppe; `Shared/Protocol.swift` wird um Set/Button erweitert.
- Offen laut Projektprotokoll: Zeichen mit Zusatztaste („/“, „#“) im Aufnahme-Dialog warnen statt still scheitern.
