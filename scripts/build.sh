#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Rojo Inicio.app"
rm -rf "$APP" "$ROOT/dist"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ROOT/dist"
swiftc -parse-as-library -O -target arm64-apple-macos13.0 "$ROOT/Sources/MenuInicio/MenuInicioApp.swift" -framework SwiftUI -framework ServiceManagement -o "$APP/Contents/MacOS/MenuInicio"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Rojo Inicio</string>
<key>CFBundleDisplayName</key><string>Rojo Inicio</string>
<key>CFBundleIdentifier</key><string>com.menuinicio.rojoinicio</string>
<key>CFBundleExecutable</key><string>MenuInicio</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
swift "$ROOT/scripts/make-icon.swift" "$APP/Contents/Resources/AppIcon.iconset"
iconutil -c icns "$APP/Contents/Resources/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$APP/Contents/Resources/AppIcon.iconset"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$APP/Contents/Info.plist"
hdiutil create -volname "Rojo Inicio" -srcfolder "$APP" -ov -format UDZO "$ROOT/dist/Rojo-Inicio-1.0.0.dmg"
printf 'App: %s\nDMG: %s\n' "$APP" "$ROOT/dist/Rojo-Inicio-1.0.0.dmg"
