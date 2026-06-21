#!/usr/bin/env bash
# Read the in-app dev flags the user saved by tapping the floating flag button
# (debug build only — see lib/features/dev_flags/dev_flags.dart).
#
# The app writes each flag to its sandboxed docs dir on the Pixel; this pulls
# the JSON via `run-as` (works because debug builds are debuggable). Output is
# the flags array — route + label + note + timestamp — so Claude Code knows
# exactly which screens to look at this session.
#
# Usage: scripts/read_dev_flags.sh        (defaults to the Pixel 6 wireless)
#        DW_DEVICE=<id> scripts/read_dev_flags.sh
set -uo pipefail
DEV="${DW_DEVICE:-adb-1A291FDF6002RQ-JYcM2v._adb-tls-connect._tcp}"
PKG="com.jardine.differentworld"
ADB="$(command -v adb 2>/dev/null || echo "$HOME/Library/Android/sdk/platform-tools/adb")"
"$ADB" -s "$DEV" exec-out run-as "$PKG" cat app_flutter/dw_flags.json 2>/dev/null \
  || echo '[]  (no flags yet, or the app has not run since install)'
