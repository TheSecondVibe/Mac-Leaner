#!/bin/bash
# Builds build/Mac-Leaner.app as a universal binary (Apple silicon + Intel).
#
#   VERSION=1.2.0 ./scripts/build_app.sh   # override the version in ./VERSION
#   ARCHS=arm64 ./scripts/build_app.sh     # single-architecture build
#   BUILD_NUMBER=42 ./scripts/build_app.sh # CFBundleVersion (default 1)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Mac-Leaner"
EXECUTABLE="MacLeaner"
BUNDLE_ID="io.github.thesecondvibe.macleaner"
VERSION="${VERSION:-$(tr -d '[:space:]' < "$PROJECT_DIR/VERSION")}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCHS="${ARCHS:-arm64 x86_64}"

APP_DIR="$PROJECT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"

ARCH_FLAGS=()
for arch in $ARCHS; do
    ARCH_FLAGS+=(--arch "$arch")
done

cd "$PROJECT_DIR"
echo "==> Building $APP_NAME $VERSION ($ARCHS)"
swift build -c release "${ARCH_FLAGS[@]}"
BIN_DIR="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"

echo "==> Assembling $APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$BIN_DIR/$EXECUTABLE" "$CONTENTS_DIR/MacOS/$EXECUTABLE"
cp "$PROJECT_DIR/Assets/AppIcon.icns" "$CONTENTS_DIR/Resources/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Mac-Leaner contributors. MIT License.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>Mac-Leaner looks for large files on your Desktop. Nothing is removed without your review.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>Mac-Leaner looks for large files in Documents. Nothing is removed without your review.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>Mac-Leaner looks for large files in Downloads. Nothing is removed without your review.</string>
</dict>
</plist>
EOF
plutil -lint "$CONTENTS_DIR/Info.plist" > /dev/null

echo "==> Signing (ad-hoc)"
codesign --force --sign - "$APP_DIR"

echo "==> Built $APP_DIR"
echo "    Run it with: open '$APP_DIR'"
