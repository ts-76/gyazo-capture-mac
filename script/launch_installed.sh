#!/usr/bin/env bash
set -euo pipefail

INSTALLED_APP="/Applications/GyazoCapture.app"

if [[ ! -d "$INSTALLED_APP" ]]; then
  echo "Gyazo Capture is not installed in /Applications." >&2
  exit 1
fi

pkill -x GyazoCaptureDev >/dev/null 2>&1 || true
pkill -x GyazoCapture >/dev/null 2>&1 || true
/usr/bin/open -n "$INSTALLED_APP"
