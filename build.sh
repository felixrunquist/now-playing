#!/bin/sh
set -e
cd "$(dirname "$0")"
APP=NowPlaying.app
rm -rf $APP
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
swiftc -O main.swift -o $APP/Contents/MacOS/NowPlaying
clang -shared helper.c -o $APP/Contents/Resources/helper.dylib -F/System/Library/PrivateFrameworks -framework MediaRemote -framework CoreFoundation
cat > $APP/Contents/Info.plist <<P
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>NowPlaying</string>
<key>CFBundleIdentifier</key><string>local.nowplaying</string>
<key>CFBundleName</key><string>NowPlaying</string>
<key>LSUIElement</key><true/>
</dict></plist>
P
codesign -s - $APP
echo "Built $APP. Run: open $APP"
