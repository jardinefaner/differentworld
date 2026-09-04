#!/usr/bin/env python3
"""Score every feature folder on the five PLATFORM_RUBRIC axes, from source.

The rubric's first pass (2026-06-01) was read by hand, which is why it covered
33 of what are now 67 feature folders and then sat still for three months. A
hand pass does not get repeated; a script does.

This does NOT replace judgement — it produces the EVIDENCE (which files call a
camera plugin, which screens have no LayoutBuilder, which have no error state)
so the judgement is made against greps rather than memory. Read its output,
then write the rubric row.

    python3 tool/score_platform.py            # every feature
    python3 tool/score_platform.py --unscored # only ones missing from the rubric
    python3 tool/score_platform.py picker     # one feature, with the evidence

Axes, and what the script can and cannot see:

  Web       a `dart:io` / native-plugin call with no `kIsWeb` guard IN THE SAME
            FILE. Cannot see a guard that lives in a helper the file calls, so
            a hit is a "look here", not a verdict.
  Desktop   camera / mic / QR plugins, which have no desktop implementation,
            MINUS the ones already behind `isMobileCapturePlatform` — gating
            with a gallery fallback is the correct shape, not a finding.
  Adaptive  presence of any width-awareness at all. Its absence is reliable;
            its presence does not prove the layout is GOOD on a wide screen.
  Pointer   a touch-only affordance (long-press, swipe-to-dismiss) with no
            keyboard or hover sibling in the same folder.
  States    loading / empty / error. Absence of an error path is the one this
            catches best, and is the defect the project has shipped most.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FEATURES = ROOT / "lib" / "features"

# dart:io + native-only surfaces that break a web build at RUNTIME when hit.
WEB_RISK = re.compile(
    r"\b(File|Directory|Platform\.(is|environment)|HttpClient|"
    r"getApplicationDocumentsDirectory|getTemporaryDirectory)\b"
)
WEB_GUARD = re.compile(r"kIsWeb|isMobileCapturePlatform|defaultTargetPlatform")

# No desktop implementation exists for any of these.
DESKTOP_RISK = re.compile(
    r"package:camera/|package:mobile_scanner/|package:record/|"
    r"ImageSource\.camera|MobileScanner|CameraController"
)

DESKTOP_GATE = re.compile(r"isMobileCapturePlatform|kIsWeb")

ADAPTIVE = re.compile(
    r"LayoutBuilder|Breakpoints|ResponsiveGrid|ResponsivePage|BentoGrid|"
    r"maxWidth:|FormFactor|MediaQuery\.sizeOf|constraints\.maxWidth"
)

TOUCH_ONLY = re.compile(r"onLongPress|Dismissible|onHorizontalDrag|onPanUpdate")
POINTER_KB = re.compile(
    r"Shortcuts\(|CallbackAction|MouseRegion|onHover|FocusNode|"
    r"KeyboardListener|RawKeyboardListener|onSecondaryTap|PresenterShortcuts|"
    r"actions:.*Intent|LogicalKeyboardKey"
)

# Does this feature READ anything asynchronous? A static content screen (the
# breathing exercise, the tools index) has no loading/empty/error to design,
# and scoring it "⚠️" buries the screens that genuinely drop an error on the
# floor. Absence of async is the difference between "—" and a finding.
ASYNC = re.compile(
    r"AsyncValue|\.when\(|StreamProvider|FutureProvider|AsyncNotifier|"
    r"\.value \?\?|hasError"
)

LOADING = re.compile(r"LoadingSlot|CircularProgressIndicator|Skeleton|\.when\(")
EMPTY = re.compile(r"EmptyState|isEmpty")
ERROR = re.compile(r"ErrorState|error:|hasError|onRetry")


def dart_files(folder: Path) -> list[Path]:
    return [
        p
        for p in folder.rglob("*.dart")
        if not p.name.endswith((".g.dart", ".freezed.dart"))
    ]


def score(folder: Path) -> dict:
    files = dart_files(folder)
    blobs = {p: p.read_text(errors="ignore") for p in files}
    joined = "\n".join(blobs.values())

    web_hits = [
        p.relative_to(ROOT)
        for p, t in blobs.items()
        if WEB_RISK.search(t) and not WEB_GUARD.search(t)
    ]
    # A camera call that sits behind `isMobileCapturePlatform` is the DESIRED
    # shape, not a defect — the project's P1 policy is "gate it and fall back
    # to the gallery", which daily/ and heroes/ already do. Without this the
    # script cries wolf on the files that got it right, and the two that
    # genuinely offered a dead "Take a photo" button (game_content, poster)
    # would have been lost in the noise.
    desktop_hits = [
        p.relative_to(ROOT)
        for p, t in blobs.items()
        if DESKTOP_RISK.search(t) and not DESKTOP_GATE.search(t)
    ]
    # A screen is a file that builds a Scaffold — the thing a layout axis
    # applies to. A pure provider/model folder scores "—", not "⚠️".
    screens = [p for p, t in blobs.items() if "EdgeScaffold(" in t or "Scaffold(" in t]

    return {
        "files": len(files),
        "lines": joined.count("\n"),
        "screens": len(screens),
        "web": web_hits,
        "desktop": desktop_hits,
        "adaptive": bool(ADAPTIVE.search(joined)),
        "touch_only": bool(TOUCH_ONLY.search(joined)),
        "pointer_kb": bool(POINTER_KB.search(joined)),
        "loading": bool(LOADING.search(joined)),
        "empty": bool(EMPTY.search(joined)),
        "error": bool(ERROR.search(joined)),
        "async": bool(ASYNC.search(joined)),
    }


def verdict(s: dict) -> tuple[str, str, str, str, str]:
    if s["screens"] == 0:
        layout = pointer = "—"
    else:
        layout = "✅" if s["adaptive"] else "⚠️"
        if s["touch_only"] and not s["pointer_kb"]:
            pointer = "⚠️"
        else:
            pointer = "✅"
    web = "⚠️" if s["web"] else "✅"
    desktop = "⚠️" if s["desktop"] else "✅"
    if s["screens"] == 0 or not s["async"]:
        states = "—"
    elif s["loading"] and s["empty"] and s["error"]:
        states = "✅"
    else:
        states = "⚠️"
    return web, desktop, layout, pointer, states


def rubric_scored() -> set[str]:
    doc = (ROOT / "docs" / "PLATFORM_RUBRIC.md").read_text()
    return set(re.findall(r"^\| ([a-z_]+) \|", doc, re.M))


def main() -> int:
    args = [a for a in sys.argv[1:]]
    only_unscored = "--unscored" in args
    named = [a for a in args if not a.startswith("--")]

    scored = rubric_scored()
    folders = sorted(p for p in FEATURES.iterdir() if p.is_dir())
    if named:
        folders = [p for p in folders if p.name in named]
    elif only_unscored:
        folders = [p for p in folders if p.name not in scored]

    print(f"{'feature':<20} {'web':<4} {'desk':<5} {'adapt':<6} "
          f"{'ptr':<4} {'states':<7} scr  lines")
    print("-" * 72)
    for f in folders:
        s = score(f)
        w, d, a, p, st = verdict(s)
        print(f"{f.name:<20} {w:<4} {d:<5} {a:<6} {p:<4} {st:<7} "
              f"{s['screens']:<4} {s['lines']}")
        if named:
            for label, key in (("web-risk", "web"), ("desktop-risk", "desktop")):
                for hit in s[key]:
                    print(f"    {label}: {hit}")
            missing = [k for k in ("loading", "empty", "error") if not s[k]]
            if missing:
                print(f"    states missing: {', '.join(missing)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
