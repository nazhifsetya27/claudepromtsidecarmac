#!/bin/bash
# bundle.sh — build PromtSidecar.app from the SPM executable.
# Usage: ./bundle.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="PromtSidecar"
APP_BUNDLE="$ROOT/build/$APP_NAME.app"

echo "==> Building release binary"
swift build -c release --package-path "$ROOT"

BIN="$ROOT/.build/release/$APP_NAME"
if [ ! -f "$BIN" ]; then
  echo "Build failed: $BIN not found"
  exit 1
fi

echo "==> Assembling .app bundle at $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

CERT_NAME="PromtSidecarDev"
if security find-identity -v -p codesigning login.keychain-db 2>/dev/null | grep -q "$CERT_NAME"; then
  echo "==> Signing with stable identity ($CERT_NAME)"
  codesign --force --deep --sign "$CERT_NAME" "$APP_BUNDLE"
else
  echo "==> WARNING: stable cert '$CERT_NAME' not found, falling back to ad-hoc"
  echo "    Run ./setup-cert.sh once to install it. Without it, AX permission"
  echo "    will be revoked on every rebuild."
  codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo
echo "Done."
echo "App: $APP_BUNDLE"
echo
echo "Next steps:"
echo "  1. Move to ~/Applications for stable Accessibility permission:"
echo "     mv \"$APP_BUNDLE\" ~/Applications/"
echo "  2. Launch:    open ~/Applications/$APP_NAME.app"
echo "  3. Grant Accessibility permission when prompted (System Settings > Privacy & Security > Accessibility)"
echo "  4. Relaunch after granting."
