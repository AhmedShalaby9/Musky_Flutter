#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building Musky macOS release..."
flutter build macos --release

release="$SCRIPT_DIR/build/macos/Build/Products/Release"
archive="$SCRIPT_DIR/musky-client-macos.zip"
app="$release/musky.app"

if [[ ! -d "$app" ]]; then
  app="$(find "$release" -maxdepth 1 -type d -name '*.app' -print -quit)"
fi

if [[ -z "${app:-}" || ! -d "$app" ]]; then
  echo "Build output was not found: $release/*.app" >&2
  exit 1
fi

rm -f "$archive"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"

echo "Package created: $archive"
