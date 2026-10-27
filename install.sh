#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
command -v swiftc >/dev/null || { echo 'Install Xcode Command Line Tools with xcode-select --install first.' >&2; exit 1; }
app="$PWD/build/Codex Usage.app"
mkdir -p "$app/Contents/MacOS" "$PWD/build/module-cache"
swiftc -module-cache-path "$PWD/build/module-cache" main.swift -o "$app/Contents/MacOS/Codex Usage"
cp Info.plist "$app/Contents/Info.plist"
codesign --force --deep --sign - "$app"
printf '\nBuilt: %s\nOpen it with: open "%s"\n' "$app" "$app"
