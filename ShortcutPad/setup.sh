#!/bin/bash
# Erzeugt das Xcode-Projekt aus project.yml und öffnet es (außer mit --no-open).
# Funktioniert auch ohne Team-ID (kostenlose Apple-ID): Dann wählst du das „Personal Team“
# einmal in Xcode aus, und ein erneuter Lauf dieses Skripts übernimmt die ID selbst.
set -e
cd "$(dirname "$0")"

CONFIG="Config/Signing.xcconfig"

# Liest die Team-ID aus dem Entwicklerzertifikat im Schlüsselbund (steht im Feld „OU“).
# Bei mehreren Zertifikaten wird das erste verwendet.
detect_team_id() {
  security find-certificate -a -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null \
    | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' \
    | head -n 1
}

if grep -Eq '^DEVELOPMENT_TEAM *= *[A-Z0-9]{10}' "$CONFIG"; then
  echo "Team-ID aus $CONFIG wird verwendet."
else
  TEAM_ID="$(detect_team_id || true)"
  if [ -n "$TEAM_ID" ]; then
    sed -i.bak "s/^DEVELOPMENT_TEAM *=.*/DEVELOPMENT_TEAM = $TEAM_ID/" "$CONFIG"
    rm -f "$CONFIG.bak"
    echo "Team-ID $TEAM_ID im Zertifikat gefunden und in $CONFIG eingetragen."
  else
    cat <<'EOF'

Hinweis: Es ist noch keine Team-ID vorhanden. Das ist für den ersten Start in Ordnung.
Nach dem Öffnen des Projekts in Xcode:

  1. Xcode → Settings → Accounts: Apple-ID hinzufügen (die kostenlose reicht).
  2. Bei beiden Targets (ShortcutPad und ShortcutPadHelper) unter „Signing & Capabilities“
     das „Personal Team“ auswählen und einmal bauen.
  3. Danach ./setup.sh erneut ausführen. Das Skript liest die Team-ID dann selbst aus dem
     Zertifikat und trägt sie ein, damit die Auswahl beim Neuerzeugen erhalten bleibt.

EOF
  fi
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen fehlt – installiere über Homebrew …"
  brew install xcodegen
fi

xcodegen generate

# Mit --no-open (von build.command benutzt) wird Xcode nicht geöffnet.
if [ "$1" != "--no-open" ]; then
  open ShortcutPad.xcodeproj
fi
