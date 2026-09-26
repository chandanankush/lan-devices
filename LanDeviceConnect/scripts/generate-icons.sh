#!/usr/bin/env bash
set -euo pipefail

app_dir="$(cd "$(dirname "$0")/.." && pwd)"
icon_temp="$(mktemp -d "${TMPDIR:-/tmp}/ldc-icons.XXXXXX")"
trap 'rm -rf "$icon_temp"' EXIT

xcrun swiftc "$app_dir/LDCIconGenerator.swift" "$app_dir/scripts/generate-icons.swift" -o "$icon_temp/generate-icons"
"$icon_temp/generate-icons" "$app_dir/App/Assets.xcassets/AppIcon.appiconset"
