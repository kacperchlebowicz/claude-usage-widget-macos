#!/usr/bin/env bash
# Generates the Xcode project and builds + installs the app into /Applications.
# Requires full Xcode (not just Command Line Tools) and xcodegen (brew install xcodegen).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

if ! xcode-select -p | grep -q "Xcode.app"; then
  echo "✗ Full Xcode is required. Install it from the App Store, then run:" >&2
  echo "    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

command -v xcodegen >/dev/null || { echo "→ installing xcodegen"; brew install xcodegen; }

echo "→ generating Xcode project"
xcodegen generate

echo "→ building (Release, ad-hoc signed to run locally — no Apple ID needed)"
xcodebuild -project ClaudeUsage.xcodeproj \
  -scheme ClaudeUsage \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="-" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  DEVELOPMENT_TEAM="" \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGNING_ALLOWED=YES \
  build

APP="build/Build/Products/Release/ClaudeUsage.app"
echo "→ installing to /Applications"
rm -rf "/Applications/ClaudeUsage.app"
cp -R "$APP" "/Applications/ClaudeUsage.app"
open "/Applications/ClaudeUsage.app"

echo "✓ built and launched. Now add the widget from the desktop widget gallery."
