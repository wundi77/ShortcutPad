# Browsertest der Webseite

Prüft die Seite aus `MacHelper/WebAssets.swift` ohne Mac-App: ein kleiner Mock-Server liefert die Seite und die Schnittstellen
(`/api/pair`, `/api/status`, `/api/library`, `/api/select`, `/api/trigger`) mit denselben JSON-Formen wie die Mac-App.

```
python3 extract.py          # Seite aus WebAssets.swift nach index.html
node mock.js &              # Mock-Server auf Port 8799
mkdir -p out && node run.js # Kopplung, Ordner, Set-Wahl, Zustände, Größen; Bilder landen in out/
```

Voraussetzung: Node.js und das Paket `playwright` (mit installiertem Chromium). `index.html` und `out/` sind nicht eingecheckt.
