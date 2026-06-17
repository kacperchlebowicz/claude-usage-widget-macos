#!/usr/bin/env python3
"""Claude usage helper.

Reads the Claude Code OAuth token from the macOS Keychain, refreshes it when
expired, fetches the subscription usage limits, and writes a normalized
usage.json into the widget's shared App Group container.

This runs as a LaunchAgent on a fixed interval. It is intentionally dependency
free (stdlib only) so it can run under /usr/bin/python3 with no venv.
"""

import json
import os
import subprocess
import sys
import time
import urllib.request
import urllib.error

# --- Constants ---------------------------------------------------------------

KEYCHAIN_SERVICE = "Claude Code-credentials"
USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
TOKEN_URL = "https://console.anthropic.com/v1/oauth/token"
# Public OAuth client id used by Claude Code's PKCE flow.
OAUTH_CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
OAUTH_BETA = "oauth-2025-04-20"

# Where the widget reads from. A normal (non-TCC-protected) folder the launchd
# helper can write to; the sandboxed widget reads it via a scoped
# temporary-exception entitlement for exactly this path.
OUT_DIR = os.path.expanduser("~/Library/Application Support/ClaudeUsageWidget")
OUT_FILE = os.path.join(OUT_DIR, "usage.json")

# Refresh a little before actual expiry so a poll never races the deadline.
REFRESH_SKEW_MS = 5 * 60 * 1000


# --- Keychain ----------------------------------------------------------------

def read_keychain():
    out = subprocess.run(
        ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
        capture_output=True, text=True,
    )
    if out.returncode != 0:
        raise RuntimeError(f"keychain read failed: {out.stderr.strip()}")
    return json.loads(out.stdout)


def write_keychain(blob):
    """Overwrite the keychain item, preserving the JSON envelope."""
    payload = json.dumps(blob)
    # -U updates if present; -A keeps it readable without per-call prompts once trusted.
    res = subprocess.run(
        ["security", "add-generic-password", "-U",
         "-s", KEYCHAIN_SERVICE, "-a", KEYCHAIN_SERVICE, "-w", payload],
        capture_output=True, text=True,
    )
    if res.returncode != 0:
        raise RuntimeError(f"keychain write failed: {res.stderr.strip()}")


# --- OAuth -------------------------------------------------------------------

def refresh_token(blob):
    """Rotate the access token using the refresh token; write it back to the
    keychain so Claude Code and the widget stay in sync."""
    oauth = blob["claudeAiOauth"]
    body = json.dumps({
        "grant_type": "refresh_token",
        "refresh_token": oauth["refreshToken"],
        "client_id": OAUTH_CLIENT_ID,
    }).encode()
    req = urllib.request.Request(
        TOKEN_URL, data=body, method="POST",
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.loads(r.read())
    oauth["accessToken"] = data["access_token"]
    if data.get("refresh_token"):
        oauth["refreshToken"] = data["refresh_token"]
    if data.get("expires_in"):
        oauth["expiresAt"] = int(time.time() * 1000) + int(data["expires_in"]) * 1000
    blob["claudeAiOauth"] = oauth
    write_keychain(blob)
    return oauth["accessToken"]


def valid_token(blob):
    oauth = blob["claudeAiOauth"]
    now_ms = int(time.time() * 1000)
    if now_ms >= int(oauth.get("expiresAt", 0)) - REFRESH_SKEW_MS:
        return refresh_token(blob)
    return oauth["accessToken"]


# --- Usage -------------------------------------------------------------------

def fetch_usage(token):
    req = urllib.request.Request(
        USAGE_URL,
        headers={
            "Authorization": f"Bearer {token}",
            "anthropic-beta": OAUTH_BETA,
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def normalize(raw):
    """Flatten the API response into exactly what the widget needs."""
    def block(node):
        if not node:
            return None
        return {
            "percent": round(node.get("utilization") or 0),
            "resets_at": node.get("resets_at"),
        }

    return {
        "updated_at": int(time.time()),
        "five_hour": block(raw.get("five_hour")),
        "weekly": block(raw.get("seven_day")),
        "weekly_opus": block(raw.get("seven_day_opus")),
        "weekly_sonnet": block(raw.get("seven_day_sonnet")),
        "ok": True,
    }


def write_out(payload):
    os.makedirs(OUT_DIR, exist_ok=True)
    tmp = OUT_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(payload, f)
    os.replace(tmp, OUT_FILE)  # atomic so the widget never reads a half file


def main():
    try:
        blob = read_keychain()
        token = valid_token(blob)
        payload = normalize(fetch_usage(token))
        write_out(payload)
        print("ok", json.dumps(payload))
    except Exception as e:  # noqa: BLE001 - persist the error for the widget UI
        os.makedirs(OUT_DIR, exist_ok=True)
        err = {"updated_at": int(time.time()), "ok": False, "error": str(e)}
        try:
            with open(OUT_FILE, "w") as f:
                json.dump(err, f)
        except Exception:
            pass
        print("error", e, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
