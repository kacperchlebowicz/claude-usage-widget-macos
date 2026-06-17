#!/usr/bin/env bash
# Installs the Claude usage helper + LaunchAgent.
# Safe to re-run; it overwrites the installed copy and reloads the agent.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPPORT_DIR="$HOME/Library/Application Support/ClaudeUsageWidget"
LOG_DIR="$HOME/Library/Logs/ClaudeUsageWidget"
AGENTS_DIR="$HOME/Library/LaunchAgents"
LABEL="com.example.claude-usage"
PLIST="$AGENTS_DIR/$LABEL.plist"
HELPER="$SUPPORT_DIR/claude-usage-helper.py"

mkdir -p "$SUPPORT_DIR" "$LOG_DIR" "$AGENTS_DIR"

echo "→ installing helper to $HELPER"
cp "$REPO_DIR/helper/claude-usage-helper.py" "$HELPER"
chmod +x "$HELPER"

echo "→ writing LaunchAgent to $PLIST"
sed -e "s|__HELPER_PATH__|$HELPER|g" \
    -e "s|__LOG_DIR__|$LOG_DIR|g" \
    "$REPO_DIR/LaunchAgents/$LABEL.plist.template" > "$PLIST"

echo "→ (re)loading agent"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo "→ running once now"
/usr/bin/python3 "$HELPER" >/dev/null 2>&1 || true

echo "✓ done. usage.json:"
cat "$HOME/Library/Application Support/ClaudeUsageWidget/usage.json" 2>/dev/null || echo "  (not written yet — check $LOG_DIR/helper.err.log)"
echo ""
