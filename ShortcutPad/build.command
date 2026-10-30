#!/bin/bash
# ShortcutPad bauen: Doppelklick im Finder genügt.
# Erzeugt das Xcode-Projekt, baut die Mac-App ohne Xcode-Fenster und startet sie.
#
# Das Ergebnis liegt in build/Build/Products/Release/ShortcutPadHelper.app,
# das vollständige Protokoll in build/build.log.
# Optionen:  --no-start   nach dem Bauen nicht starten
#            --debug      Debug- statt Release-Build

cd "$(dirname "$0")" || exit 1

START=1
CONFIG="Release"
for arg in "$@"; do
  case "$arg" in
    --no-start) START=0 ;;
    --debug) CONFIG="Debug" ;;
  esac
done

APP_NAME="ShortcutPadHelper"
SCHEME="ShortcutPadHelper"
PROJECT="ShortcutPad.xcodeproj"
LOG="build/build.log"
APP="build/Build/Products/$CONFIG/$APP_NAME.app"

finish() {
  echo
  read -n 1 -s -r -p "Beliebige Taste drücken, um das Fenster zu schließen …"
  echo
  exit "${1:-0}"
}

echo "=== ShortcutPad bauen ==="
echo

# 1. Xcode vorhanden?
if ! command -v xcodebuild >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
  echo "✗ Xcode wurde nicht gefunden oder ist nicht eingerichtet."
  echo "  Xcode aus dem App Store installieren, einmal öffnen und die Lizenz bestätigen."
  echo "  Falls Xcode schon installiert ist, im Terminal ausführen:"
  echo "    sudo xcode-select -s /Applications/Xcode.app"
  echo "    sudo xcodebuild -license accept"
  finish 1
fi
echo "Xcode: $(xcodebuild -version | head -n 1)"

# 2. Projekt erzeugen (Team-ID automatisch erkennen, XcodeGen bei Bedarf über Homebrew installieren)
echo
echo "→ Projekt erzeugen …"
if [ ! -x ./setup.sh ]; then
  chmod +x ./setup.sh 2>/dev/null
fi
if ! ./setup.sh --no-open; then
  echo "✗ Das Projekt konnte nicht erzeugt werden (siehe Meldungen oben)."
  finish 1
fi

# 3. Alte Instanz beenden, damit das Ergebnis ersetzt werden kann
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  echo
  echo "→ Laufende Instanz von $APP_NAME wird beendet …"
  pkill -x "$APP_NAME"
  sleep 1
fi

# 4. Bauen
mkdir -p build
HAS_TEAM=0
if grep -Eq '^DEVELOPMENT_TEAM *= *[A-Z0-9]{10}' Config/Signing.xcconfig 2>/dev/null; then
  HAS_TEAM=1
fi

run_build() {
  # $@: zusätzliche xcodebuild-Argumente (Signatur)
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination 'platform=macOS' \
    -derivedDataPath build \
    "$@" \
    build > "$LOG" 2>&1
}

echo
BUILD_OK=1
if [ "$HAS_TEAM" = "1" ]; then
  echo "→ Bauen mit deinem Entwicklerzertifikat … (kann einige Minuten dauern)"
  run_build -allowProvisioningUpdates && BUILD_OK=0
  if [ "$BUILD_OK" != "0" ] && grep -qiE "signing|provisioning|No Account|certificate" "$LOG"; then
    echo "  Signatur mit Zertifikat nicht möglich, versuche es lokal ohne Zertifikat …"
    HAS_TEAM=0
  fi
fi
if [ "$BUILD_OK" != "0" ] && [ "$HAS_TEAM" = "0" ]; then
  echo "→ Bauen mit lokaler Signatur … (kann einige Minuten dauern)"
  run_build CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" && BUILD_OK=0
  SIGNED_LOCAL=1
fi

# 5. Ergebnis
if [ "$BUILD_OK" != "0" ] || [ ! -d "$APP" ]; then
  echo
  echo "✗ Der Build ist fehlgeschlagen. Fehlermeldungen:"
  echo
  ERRORS="$(grep -E "error:" "$LOG" | sed 's#^.*/ShortcutPad/##' | sort -u | head -n 40)"
  if [ -z "$ERRORS" ]; then
    ERRORS="$(tail -n 30 "$LOG")"
  fi
  echo "$ERRORS"
  echo
  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s\n' "$ERRORS" | pbcopy
    echo "Die Meldungen liegen in der Zwischenablage. Einfach im Chat einfügen."
  fi
  echo "Das vollständige Protokoll: $(pwd)/$LOG"
  finish 1
fi

echo
echo "✓ Fertig: $(pwd)/$APP"
if [ "${SIGNED_LOCAL:-0}" = "1" ]; then
  echo
  echo "Hinweis: Die App ist nur lokal signiert. macOS vergisst dann bei jedem neuen Build die"
  echo "Freigabe unter „Bedienungshilfen“. Danach in den Systemeinstellungen (Datenschutz & Sicherheit →"
  echo "Bedienungshilfen) ShortcutPadHelper aus- und wieder einschalten, oder ein Personal Team einrichten"
  echo "(siehe ANLEITUNG.md, Teil 2)."
fi

if [ "$START" = "1" ]; then
  echo
  echo "→ App starten …"
  open "$APP"
else
  open -R "$APP"
fi

finish 0
