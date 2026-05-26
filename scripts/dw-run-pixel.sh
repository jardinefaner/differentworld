#!/usr/bin/env bash
# Different World — quiet Pixel deploy
#
# `flutter run -d <pixel>` is noisy on Android: the platform pipes
# its own informational chatter (Davey jank logs, userfaultfd VM
# warnings, Choreographer frame-skip notes, FlutterRenderer
# "Width is zero" probes) that aren't bugs in our code and that
# bury the actually-useful Flutter `[flutter]` lines.
#
# This wrapper runs the normal deploy command but pipes through grep
# to keep only the signal:
#   - Flutter app logs (`I/flutter`, `[flutter]`)
#   - Build progress (`Built build`, `Installing`, `Syncing files`)
#   - Hot reload prompts
#   - Anything that looks like an error (Exception, Error, Failed)
#
# Full log still lands at /tmp/dw-pixel.log if you need to grep it.

set -euo pipefail

DEVICE="adb-1A291FDF6002RQ-JYcM2v._adb-tls-connect._tcp"
LOG="/tmp/dw-pixel.log"

# Patterns we KEEP — anything else is silenced from the terminal.
# (The full output still streams to $LOG.)
KEEP_PATTERN='I/flutter|^\[flutter\]|Built build|Installing build|Syncing files|Hot reload|Hot restart|Lost connection|Exception|Error[: ]|Failed|^Performing hot|Reloaded|^r |^R |To hot reload|To quit'

cd "$(dirname "$0")/.."
flutter run -d "$DEVICE" 2>&1 | tee "$LOG" | grep -E --line-buffered "$KEEP_PATTERN" || true
