#!/bin/bash
set -euo pipefail

BINARY="${1:-.build/release/open-wispr}"
APP_DIR="${2:-OpenWispr Globe Universal.app}"
VERSION="${3:-0.3.0}"
RUNTIME_DIR="${4:-}"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BINARY" "$APP_DIR/Contents/MacOS/open-wispr"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cp "$REPO_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp -R "$REPO_DIR"/Resources/*.lproj "$APP_DIR/Contents/Resources/"
if [[ -n "$RUNTIME_DIR" ]]; then
    mkdir -p "$APP_DIR/Contents/Helpers"
    install -m 755 "$RUNTIME_DIR/whisper-cli" "$APP_DIR/Contents/Helpers/whisper-cli"
    cp "$RUNTIME_DIR/whisper.cpp.LICENSE" "$APP_DIR/Contents/Resources/"
    codesign --force --sign - "$APP_DIR/Contents/Helpers/whisper-cli"
fi

cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>open-wispr</string>
    <key>CFBundleIdentifier</key>
    <string>com.human37.open-wispr</string>
    <key>CFBundleName</key>
    <string>OpenWispr Globe</string>
    <key>CFBundleDisplayName</key>
    <string>OpenWispr Globe Universal</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>OpenWispr Globe Universal uses the microphone to record speech for local dictation.</string>
</dict>
</plist>
PLIST

codesign --force --sign - --identifier com.human37.open-wispr "$APP_DIR"

echo "Built $APP_DIR"
