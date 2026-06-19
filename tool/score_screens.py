"""Score every gallery screen 0-100 for "confidently good".

Measures each screen from TWO sources and combines them into one explainable
score (each deduction carries a reason):

  • SOURCE metrics (grep over the screen's .dart file): hardcoded-color count
    (allowlist-gated + scrim-stripped — the DRY / theme-adherence signal),
    EdgeScaffold vs raw Scaffold, ContentHeader/SafeArea clearance, the four
    states (loading / empty / error), icon-only-without-tooltip.
  • PIXEL metrics (PIL over the light + dark plates): theme_delta (does the
    rendered surface actually respond to the theme — catches "hardcoded, reads
    identical light vs dark"), low-contrast regions (the board-pill light-on-
    light class — emitted as evidence, gated to high-confidence for deductions),
    dead_fraction (sparseness).

The raw-canvas allowlist in scripts/check_theme_adherence.sh is the single
source of truth for which screens are legit dark stages (camera viewfinders,
projection/cast stages) — those are exempt from theme/contrast deductions so a
dark stage is never dinged for being dark.

Run:    python3 tool/score_screens.py
Writes: gallery/screen_scores.md (ranked, worst-first) + gallery/screen_scores.json

Spec + pixel logic validated by the screen-quality-scorecard pilot
(today/settings 100, board/cast 96 after the theme fix, photography_runner 100
[raw canvas]).
"""
import glob
import json
import os
import re

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

W, H = 440, 900
TOP_CHROME, BOT_CHROME = 96, 88  # floating top pills / bottom omnibox bar


# ── raw-canvas allowlist (single source of truth) ───────────────────────────
def load_allow():
    txt = open("scripts/check_theme_adherence.sh").read()
    m = re.search(r"ALLOW='([^']*)'", txt)
    return re.compile(m.group(1)) if m else re.compile(r"\Z\A")


ALLOW = load_allow()


# ── name → (source file, class) from the gallery harness ────────────────────
def build_registry():
    txt = open("test/golden/screens_gallery_test.dart").read()
    plate = dict(
        re.findall(
            r"_(?:bareScreen|screen)Plate\('screens/([a-z0-9_]+)',\s*"
            r"const ([A-Za-z0-9]+)\(",
            txt,
        )
    )
    imports = re.findall(
        r"import 'package:differentworld/(features/[^']+\.dart)'", txt
    )
    cls_file = {}
    for path in imports:
        try:
            src = open("lib/" + path).read()
        except FileNotFoundError:
            continue
        for cm in re.finditer(r"class ([A-Za-z0-9]+) extends", src):
            cls_file.setdefault(cm.group(1), "lib/" + path)
    reg = {}
    for name, cls in plate.items():
        f = cls_file.get(cls)
        if f:
            reg[name] = (f, cls)
    # Plates rendered by bespoke SEEDED helpers (_bentoPlate / _scheduleGridPlate
    # / _rosterPlate) don't pass a `const Screen(` the regex can bind to — so
    # without this the audit SILENTLY skips them and the average excludes them.
    # Map each to the source worth scoring (the new widget, not the host screen
    # for the schedule grid).
    extra = {
        "today_bento": (
            "lib/features/today/today_bento_screen.dart", "TodayBentoScreen"),
        "today_bento_wide": (
            "lib/features/today/today_bento_screen.dart", "TodayBentoScreen"),
        # The grid is a WIDGET rendered inside ScheduleScreen (which owns the
        # EdgeScaffold + header), so score the host for structure — the grid's
        # own theme-cleanliness is covered by the diff-scoped guard.
        "schedule_time_grid": (
            "lib/features/schedule/schedule_screen.dart", "ScheduleScreen"),
        "group_detail": (
            "lib/features/groups/group_detail_screen.dart", "GroupDetailScreen"),
        "subject_detail": (
            "lib/features/subjects/subject_detail_screen.dart",
            "SubjectDetailScreen"),
    }
    for name, (f, cls) in extra.items():
        if name not in reg and os.path.exists(f):
            reg[name] = (f, cls)
    return reg


_COLOR = re.compile(
    r"\bColors\.(?:white|black|grey|gray|red|blue|green|amber|orange|cyan|"
    r"teal|pink|purple|indigo|yellow|lime)[A-Za-z0-9]*|\bColor\(0x[0-9A-Fa-f]{8}\)"
)


def source_metrics(path):
    src = open(path).read()
    # The allowlist regex anchors on `lib/...` (the repo-relative path the
    # theme-adherence script greps), so match the full path.
    is_raw = bool(ALLOW.search(path))
    # hardcoded solid colors: a color literal on a line that ISN'T a scrim
    # (.withValues(alpha:/.withOpacity) and isn't Colors.transparent.
    solid = 0
    for line in src.splitlines():
        if "Colors.transparent" in line:
            continue
        if ".withValues(alpha:" in line or ".withOpacity(" in line:
            continue
        if "raw-canvas" in line:  # line-level exemption — matches the guard
            continue
        solid += len(_COLOR.findall(line))
    states = sum(
        src.count(p + "(")
        for p in ("EmptyState", "ErrorState", "LoadingSlot")
    )
    if "SkeletonList(" in src or "SkeletonCards(" in src:
        states += 1
    states = min(3, states)
    data_strong = bool(
        re.search(r"ref\.watch", src)
        and re.search(r"ListView|SliverList|GridView|\.when\(", src)
    )
    # icon-only IconButtons without a tooltip on the same call (rough).
    icon_btns = src.count("IconButton(")
    tooltips = src.count("tooltip:")
    return {
        "is_raw": is_raw,
        "solid": 0 if is_raw else solid,
        "solid_raw": solid,
        "edge": "EdgeScaffold(" in src,
        "header": "ContentHeader(" in src or "SafeArea(" in src,
        "states": states,
        "data": data_strong or states >= 1,
        "icon_unlabeled": max(0, icon_btns - tooltips),
    }


# ── pixel metrics ───────────────────────────────────────────────────────────
def _load(name, mode):
    p = f"gallery/screens/{name}__{mode}.png"
    if not os.path.exists(p):
        p = f"gallery/screens/{name}.png"  # dark-only single plate
    im = Image.open(p).convert("RGB")
    if im.size != (W, H):
        im = im.resize((W, H))
    return np.asarray(im, dtype=np.float32)


def _lum(arr):
    c = arr / 255.0
    lin = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]


def _contrast(a, b):
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def _body(a):
    return a[TOP_CHROME : H - BOT_CHROME, :, :]


def pixel_metrics(name):
    has_pair = os.path.exists(f"gallery/screens/{name}__light.png") and os.path.exists(
        f"gallery/screens/{name}__dark.png"
    )
    delta = None
    if has_pair:
        L = _lum(_body(_load(name, "light")))
        D = _lum(_body(_load(name, "dark")))
        delta = float(np.mean(np.abs(L - D)))
    # low-contrast (glyph-aware) + dead fraction on the light plate (or single).
    mode = "light" if has_pair else "single"
    arr = _body(_load(name, mode))
    lum = _lum(arr)
    cell = 28
    lc_hits = []
    flat = total = 0
    for y in range(0, lum.shape[0] - cell, cell):
        for x in range(0, lum.shape[1] - cell, cell):
            patch = lum[y : y + cell, x : x + cell].ravel()
            total += 1
            if float(patch.max() - patch.min()) < 0.04:
                flat += 1
            bg = float(np.median(patch))
            diff = np.abs(patch - bg)
            thr = max(0.05, float(np.quantile(diff, 0.85)))
            ink = diff >= thr
            frac = ink.mean()
            if frac < 0.03 or frac > 0.45:
                continue
            ink_lum = float(np.median(patch[ink]))
            if abs(ink_lum - bg) < 0.02:
                continue
            cr = _contrast(ink_lum, bg)
            if cr < 2.0:  # high-confidence illegible (soft 2-3:1 labels excluded)
                lc_hits.append((x, y + TOP_CHROME, round(cr, 2)))
    return {
        "delta": delta,
        "dead": flat / total if total else 0.0,
        "lc_hits": lc_hits,
    }


# ── scoring ─────────────────────────────────────────────────────────────────
def score(src, px):
    pts, ded = 100.0, []
    raw = src["is_raw"]
    # Tier 1 — theme / contrast (heaviest)
    if not raw and src["solid"] > 0:
        d = min(40, 12 * src["solid"])
        pts -= d
        ded.append((-d, f"{src['solid']} hardcoded color(s) on a themed surface"))
    if not raw and px["delta"] is not None and px["delta"] < 0.15:
        # Near-zero delta is AMBIGUOUS on its own: a screen can read identical
        # light/dark because it hardcodes (bad) OR because a content-driven
        # color dominates (a world accent, a photo — legit). Only condemn it
        # (-35) when CORROBORATED by ≥2 hardcoded literals; otherwise flag it
        # softly (-12) for a human to verify it's genuinely content-driven.
        if src["solid"] >= 2:
            pts -= 35
            ded.append(
                (-35, f"near-zero light/dark delta ({px['delta']:.2f}) + hardcodes — not following theme")
            )
        else:
            pts -= 12
            ded.append(
                (-12, f"near-zero light/dark delta ({px['delta']:.2f}) — verify it's content-driven, not hardcoded")
            )
    # NOTE: low-contrast regions (px["lc_hits"]) are EVIDENCE, not a deduction —
    # the glyph detector over-fires on anti-aliased text + soft AA secondary
    # labels (88 "hits" on a board lobby that's actually legible). They're
    # surfaced as a flag for human / agent confirmation, not auto-scored.
    # Tier 2 — chrome / structure (raw stages legitimately own a bare Scaffold)
    if not raw and not src["edge"]:
        pts -= 20
        ded.append((-20, "rendered root is a raw Scaffold, not EdgeScaffold"))
    if not raw and not src["header"]:
        pts -= 4
        ded.append((-4, "no ContentHeader / SafeArea top-clearance signal"))
    # Tier 3 — four states. Only flag PARTIAL handling (1-2 of the three present
    # = an incomplete data screen); 0 present is treated as n/a (static / form /
    # immersive) so static settings-style screens aren't false-dinged.
    if 1 <= src["states"] <= 2:
        miss = 3 - src["states"]
        d = 6 * miss
        pts -= d
        ded.append((-d, f"{miss} of loading/empty/error states missing"))
    # Tier 4 — polish
    if not raw and px["dead"] >= 0.985 and src["states"] == 0:
        pts -= 3
        ded.append((-3, f"body {px['dead']*100:.0f}% flat (sparse / unfinished)"))
    if src["icon_unlabeled"] >= 3:
        d = min(9, 3 * (src["icon_unlabeled"] // 3))
        pts -= d
        ded.append((-d, f"~{src['icon_unlabeled']} icon-only control(s) without a tooltip"))
    return max(0, round(pts)), ded


def band(s):
    return (
        "ship-confident" if s >= 90 else
        "minor work" if s >= 70 else
        "needs a pass" if s >= 50 else
        "real defects"
    )


def main():
    reg = build_registry()
    rows = []
    for name in sorted(reg):
        path, cls = reg[name]
        src = source_metrics(path)
        px = pixel_metrics(name)
        sc, ded = score(src, px)
        rows.append(
            dict(
                name=name, cls=cls, file=path, score=sc, band=band(sc),
                is_raw=src["is_raw"], delta=px["delta"], dead=round(px["dead"], 2),
                solid=src["solid_raw"], states=src["states"],
                low_contrast_evidence=len(px["lc_hits"]),
                deductions=[{"pts": d, "why": w} for d, w in ded],
            )
        )
    rows.sort(key=lambda r: (r["score"], r["name"]))

    with open("gallery/screen_scores.json", "w") as f:
        json.dump(rows, f, indent=2)

    lines = ["# Screen quality scoreboard", ""]
    lines.append(f"{len(rows)} screens scored · worst-first · `tool/score_screens.py`")
    lines.append("")
    avg = round(sum(r["score"] for r in rows) / len(rows), 1)
    bands = {}
    for r in rows:
        bands[r["band"]] = bands.get(r["band"], 0) + 1
    lines.append(f"Average: **{avg}** · " + " · ".join(
        f"{k}: {v}" for k, v in sorted(bands.items())))
    lines.append("")
    lines.append("| Score | Band | Screen | Why (top deductions) |")
    lines.append("|---|---|---|---|")
    for r in rows:
        tag = " ⟨raw canvas⟩" if r["is_raw"] else ""
        why = "; ".join(f"{d['pts']:+d} {d['why']}" for d in r["deductions"][:3]) or "—"
        lines.append(f"| {r['score']} | {r['band']} | `{r['name']}`{tag} | {why} |")
    open("gallery/screen_scores.md", "w").write("\n".join(lines) + "\n")

    print(f"scored {len(rows)} screens · avg {avg}")
    print("bottom 12:")
    for r in rows[:12]:
        tag = " [raw]" if r["is_raw"] else ""
        print(f"  {r['score']:>3}  {r['name']}{tag}  "
              f"({'; '.join(d['why'] for d in r['deductions'][:2]) or 'clean'})")


if __name__ == "__main__":
    main()
