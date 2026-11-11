#!/bin/sh
# Builds PrayerTimes.app (menu bar only). Usage: ./build.sh && open build/PrayerTimes.app
# VERSION=1.2.0 ./build.sh sets the app version (CI passes the git tag).
set -e
cd "$(dirname "$0")"
APP=build/PrayerTimes.app
VERSION="${VERSION:-1.0}"
rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp AppIcon.icns "$APP/Contents/Resources/"
swiftc -parse-as-library -Osize -target arm64-apple-macos14 PrayerTimes.swift -o build/pt-arm64
swiftc -parse-as-library -Osize -target x86_64-apple-macos14 PrayerTimes.swift -o build/pt-x86
lipo -create build/pt-arm64 build/pt-x86 -output "$APP/Contents/MacOS/PrayerTimes"
strip -x "$APP/Contents/MacOS/PrayerTimes"
rm build/pt-arm64 build/pt-x86
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>id.mqdd.prayertimes</string>
  <key>CFBundleName</key><string>Prayer Times</string>
  <key>CFBundleExecutable</key><string>PrayerTimes</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSUIElement</key><true/>
  <key>NSLocationUsageDescription</key><string>Used to calculate prayer times for your location.</string>
  <key>NSLocationWhenInUseUsageDescription</key><string>Used to calculate prayer times for your location.</string>
</dict></plist>
EOF
codesign -s - --force "$APP"
du -sh "$APP"
