#!/usr/bin/env python3
"""Map every route to its screen, what a user can DO there, and how they got in.

Answers "does the information architecture make sense" with evidence instead of
impressions. Three questions per screen:

  1. WHERE IS IT      — the route, and the full path a user takes to reach it
  2. HOW DO YOU GET   — drawer / omnibox / settings / only-a-link-from-elsewhere
     THERE
  3. WHAT CAN YOU DO  — the verbs: buttons, taps that navigate, form submits

The interesting output is not the list, it is the SHAPE:

  - a screen with a route and no discovery surface is reachable only if
    something already links to it, which is how features ship invisible
  - (there is NO "dead end" check. There was one; it was wrong every single
    time. Actions in this codebase live in shared wrappers — GameScaffold
    drives the game screens, EdgeScaffold's `actions:` slot holds the primary
    verb — so a per-file scan cannot see them. And several screens are
    read-only reference views ON PURPOSE: RolesScreen's own doc calls it "a
    read-only directory". A checker that cannot tell "read-only by design"
    from "forgot the action" manufactures findings, and findings you have to
    re-verify every time are worse than none.)
  - two screens whose action sets are near-identical are one screen wearing
    two names (the Present/Brain Breaks split was exactly this)
  - a screen buried three drill-ins deep whose job is daily is misplaced

    python3 tool/map_screens.py            # the table
    python3 tool/map_screens.py --json     # machine-readable, for the artifact
    python3 tool/map_screens.py --problems # only the screens that look wrong
"""

from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ROUTER = ROOT / "lib" / "app" / "router.dart"
NAV = ROOT / "lib" / "shared" / "widgets" / "nav_destinations.dart"
OMNI = ROOT / "lib" / "features" / "omnibox" / "omnibox_catalog.dart"
SETTINGS = ROOT / "lib" / "features" / "settings" / "settings_screen.dart"

# A "verb" — something a user can actually do on the screen, as opposed to
# something the screen shows them.
ACTION_PATTERNS = [
    (r"PrimaryActionButton\(", "primary action"),
    (r"SecondaryActionButton\(", "secondary action"),
    (r"FilledButton|ElevatedButton|OutlinedButton", "button"),
    (r"TextButton\.icon|TextButton\(", "text button"),
    (r"FloatingActionButton", "FAB"),
    (r"DestructiveButton|confirmDestructive|deleteWithUndo", "delete"),
    (r"onTap:\s*\(\)\s*=>\s*(?:unawaited\()?(?:context|ctx)\.push", "drill-in"),
    (r"showGlassSheet|showModalBottomSheet", "opens a sheet"),
    (r"TextField|TextFormField", "text entry"),
    (r"Switch\(|CapSwitch|Checkbox|Radio<", "toggle"),
    (r"Slider\(|DropdownButton", "picker"),
    (r"onSubmitted|_submit|_save\b", "submit"),
    # A present/cast stage has no buttons by design — the room looks at it and
    # the host drives with a swipe or the arrow keys. Counting only buttons
    # marked every one of them a "dead end", which is the detector being wrong
    # about what a screen IS, not the screen being wrong.
    (r"PageView|PresenterShortcuts|onHorizontalDrag", "swipe / keys"),
    (r"GestureDetector\(", "tap gesture"),
    (r"MobileScanner|CameraController", "scan / capture"),
    # The catch-all, added last and deliberately broad. Every screen this
    # tool first called a "dead end" turned out to have one of these — the
    # checklist's `onChanged`, the routines board's cohort chips passing
    # `onSelected` into a shared widget. Four findings, four detector gaps,
    # zero real dead ends. A structural checker that manufactures findings is
    # worse than one that finds none.
    (r"onSelected:|onChanged:|onPressed:|onTap:", "interactive"),
]


ROUTE_JSON = ROOT / "build" / "route_map.json"


def route_table() -> list[dict]:
    """Every route, with its FULL path, from the router itself.

    `build/route_map.json` is produced by `test/tool/dump_routes_test.dart`,
    which walks `router.configuration`. That indirection is the whole point:
    go_router NESTS routes and a child's `path` is relative, so regexing
    `path:` out of the source yields bare segments — `'now'` instead of
    `/now`, `'block'` instead of `/schedule/block`. Every depth and
    reachability judgement built on those is wrong. Ask the router.
    """
    if not ROUTE_JSON.exists():
        raise SystemExit(
            "Missing build/route_map.json. Run:\n"
            "  flutter test test/tool/dump_routes_test.dart"
        )
    routes = json.loads(ROUTE_JSON.read_text())

    # The screen CLASS still comes from the source — a builder closure has no
    # useful runtime type. Match each full path back to its `path:` literal.
    src = ROUTER.read_text()
    by_segment = {}
    for m in re.finditer(r"path:\s*'([^']+)'", src):
        tail = src[m.end() : m.end() + 700]
        w = re.search(r"child:\s*(?:const\s+)?(_?[A-Z]\w+)\(", tail) or re.search(
            r"builder:\s*\([^)]*\)\s*=>\s*(?:const\s+)?(_?[A-Z]\w+)\(", tail
        )
        widget = w.group(1) if w else None
        if widget in {"RouteTitle", "SizedBox"} and w:
            w2 = re.search(r"child:\s*(?:const\s+)?(_?[A-Z]\w+)\(", tail[w.end():])
            widget = w2.group(1) if w2 else widget
        by_segment.setdefault(m.group(1), widget)

    out = []
    for r in routes:
        exact = by_segment.get(r["path"])
        seg = r["path"].rstrip("/").split("/")[-1]
        # `new` / `edit` / `:id` occur under a dozen different parents; the
        # first one the regex happened to see is not this route's screen.
        # Better to report "?" than to name the wrong file confidently.
        if seg in {"new", "edit", "run", "play"} or seg.startswith(":"):
            seg = ""
        # Root has no segment of its own; falling back would inherit a child's
        # screen, which is exactly how `/` reported MorningChecklistScreen.
        widget = exact or (by_segment.get(seg) if seg else None)
        out.append({"path": r["path"], "widget": widget, "depth": r["depth"]})
    return out


def widget_files() -> dict[str, Path]:
    """Screen class name → the file that declares it."""
    found = {}
    for p in (ROOT / "lib").rglob("*.dart"):
        if p.name.endswith((".g.dart", ".freezed.dart")):
            continue
        for m in re.finditer(# Riverpod's is `ConsumerWidget`, NOT `ConsumerStatelessWidget` — the
        # earlier pattern silently missed every one of them, which is most of
        # the app's screens, and reported them as having no actions at all.
        r"^class (_?\w+) extends "
        r"(?:ConsumerWidget|ConsumerStatefulWidget|StatelessWidget|StatefulWidget)\b",
                             p.read_text(errors="ignore"), re.M):
            found.setdefault(m.group(1), p)
    return found


def actions_in(path: Path) -> list[str]:
    src = path.read_text(errors="ignore")
    verbs = []
    for pat, label in ACTION_PATTERNS:
        n = len(re.findall(pat, src))
        if n:
            verbs.append(f"{label}×{n}" if n > 1 else label)
    return verbs


def discovery() -> dict[str, set[str]]:
    """route → the surfaces that offer it."""
    d = defaultdict(set)
    for label, f in (("drawer", NAV), ("omnibox", OMNI), ("settings", SETTINGS)):
        if not f.exists():
            continue
        for m in re.finditer(r"'(/[^']*)'", f.read_text()):
            d[m.group(1)].add(label)
    return d


def main() -> int:
    as_json = "--json" in sys.argv
    only_problems = "--problems" in sys.argv

    routes = route_table()
    files = widget_files()
    disc = discovery()

    rows = []
    for r in routes:
        w = r["widget"]
        f = files.get(w) if w else None
        verbs = actions_in(f) if f else []
        surfaces = sorted(disc.get(r["path"], set()))
        depth = r["depth"]
        problems = []
        if w and not surfaces and depth <= 1:
            problems.append("top-level route with NO discovery surface")
        if depth >= 4:
            problems.append(f"buried {depth} levels deep")
        rows.append({
            "path": r["path"],
            "screen": w,
            "file": str(f.relative_to(ROOT)) if f else None,
            "actions": verbs,
            "reached_by": surfaces,
            "depth": depth,
            "problems": problems,
        })

    if as_json:
        print(json.dumps(rows, indent=2))
        return 0

    shown = [r for r in rows if r["problems"]] if only_problems else rows
    print(f"{len(rows)} routes · {sum(1 for r in rows if r['problems'])} with a "
          f"structural question\n")
    for r in shown:
        surf = ",".join(r["reached_by"]) or "—"
        print(f"{r['path']:<44} {str(r['screen'] or '?'):<30} [{surf}]")
        if r["actions"]:
            print(f"    do: {', '.join(r['actions'])}")
        for p in r["problems"]:
            print(f"    ⚠  {p}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
