#!/usr/bin/env bash
# Removes the LaunchAgent and installed helper. Leaves the built app alone.
set -euo pipefail

LABEL="com.example.claude-usage"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$HOME/Library/Application Support/ClaudeUsageWidget"
echo "✓ helper + LaunchAgent removed. (App Group data and the app, if installed, are left in place.)"
