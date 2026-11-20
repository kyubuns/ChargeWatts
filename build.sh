#!/bin/sh
set -eu

cd "$(dirname "$0")"
app="build/ChargeWatts.app"
mkdir -p "$app/Contents/MacOS"
cp Info.plist "$app/Contents/Info.plist"

xcrun swiftc -target arm64-apple-macosx12.0 -O \
    -module-cache-path build/module-cache \
    Sources/PowerReading.swift Sources/main.swift \
    -o "$app/Contents/MacOS/ChargeWatts"

codesign --force --sign - "$app"
