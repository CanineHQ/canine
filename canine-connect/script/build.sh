#!/usr/bin/env bash
# Builds "Canine Connect.app" into dist/, bundling a pinned telepresence CLI.
#
#   script/build.sh            build dist/Canine Connect.app
#   script/build.sh --install  also copy it to ~/Applications and launch it
#   script/build.sh --zip      also package dist/CanineConnect-macos-<arch>.zip for a release
#
# ARCH=arm64|x86_64 cross-builds for that architecture (default: this Mac's).
set -euo pipefail

cd "$(dirname "$0")/.."

# Must match the telepresence chart_version in ../resources/helm/system_packages.yml, so the CLI the app
# ships talks to the same Traffic Manager version Canine installs on clusters.
TELEPRESENCE_VERSION=2.21.1

APP_NAME="Canine Connect"
APP="dist/${APP_NAME}.app"

ARCH="${ARCH:-$(uname -m)}"
case "$ARCH" in
  arm64) TP_ARCH=arm64 ;;
  x86_64) TP_ARCH=amd64 ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

echo "==> Building (${ARCH})"
swift build -c release --arch "$ARCH"
BIN_DIR="$(swift build -c release --arch "$ARCH" --show-bin-path)"

TP_CACHE=".build/telepresence/telepresence-${TELEPRESENCE_VERSION}-${TP_ARCH}"
if [[ ! -x "$TP_CACHE" ]]; then
  echo "==> Downloading telepresence v${TELEPRESENCE_VERSION} (${TP_ARCH})"
  mkdir -p "$(dirname "$TP_CACHE")"
  curl -fL --progress-bar -o "${TP_CACHE}.tmp" \
    "https://github.com/telepresenceio/telepresence/releases/download/v${TELEPRESENCE_VERSION}/telepresence-darwin-${TP_ARCH}"
  chmod +x "${TP_CACHE}.tmp"
  if [[ "$ARCH" == "$(uname -m)" ]]; then
    "${TP_CACHE}.tmp" version 2>/dev/null | grep -q "v${TELEPRESENCE_VERSION}" || {
      echo "Downloaded telepresence doesn't report v${TELEPRESENCE_VERSION}" >&2; exit 1;
    }
  fi
  mv "${TP_CACHE}.tmp" "$TP_CACHE"
fi

echo "==> Assembling ${APP}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bin"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$BIN_DIR/CanineConnect" "$APP/Contents/MacOS/CanineConnect"
cp "$TP_CACHE" "$APP/Contents/Resources/bin/telepresence"
cp Resources/logo.png "$APP/Contents/Resources/logo.png"

# App icon (Finder, the password prompt) from the Canine logo
ICONSET=".build/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size Resources/logo.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) Resources/logo.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature: enough to run on this Mac. Distributing to others needs a Developer ID and notarization.
codesign --force --sign - "$APP/Contents/Resources/bin/telepresence"
codesign --force --sign - "$APP"

echo "==> Built ${APP}"

if [[ "${1:-}" == "--zip" ]]; then
  ZIP="dist/CanineConnect-macos-${ARCH}.zip"
  rm -f "$ZIP"
  # ditto keeps the bundle's symlinks, permissions and signature intact, unlike zip
  ditto -c -k --keepParent "$APP" "$ZIP"
  echo "==> Packaged ${ZIP}"
fi

if [[ "${1:-}" == "--install" ]]; then
  DEST="$HOME/Applications/${APP_NAME}.app"
  mkdir -p "$HOME/Applications"
  osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
  sleep 1
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  open "$DEST"
  echo "==> Installed and launched ${DEST}"
fi
