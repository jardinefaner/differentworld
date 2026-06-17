"""Composite every gallery component (light render) into one labeled contact
sheet, grouped by atomic tier. Faithful — uses the real golden PNGs."""
import glob
import os

from PIL import Image, ImageDraw, ImageFont

TIERS = ["atoms", "molecules", "organisms"]
CELL_W, CELL_H, LABEL_H = 300, 220, 30
GAP, PAD, HEADER_H = 16, 28, 52
COLS = 4
BG = (246, 249, 248)
CELL_BG = (255, 255, 255)
INK = (20, 30, 28)
MUTED = (110, 120, 118)
ACCENT = (42, 157, 143)


def font(size, bold=False):
    paths = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for p in paths:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()


F_LABEL = font(15)
F_HEADER = font(24)
F_TITLE = font(34)


def comps(tier):
    files = sorted(glob.glob(f"gallery/{tier}/*__light.png"))
    return [(os.path.basename(f).replace("__light.png", ""), f) for f in files]


# ── measure total height ───────────────────────────────────────────────
groups = [(t, comps(t)) for t in TIERS]
groups = [(t, c) for t, c in groups if c]
width = PAD * 2 + COLS * CELL_W + (COLS - 1) * GAP

y = PAD + 60  # title band
for _, cs in groups:
    rows = (len(cs) + COLS - 1) // COLS
    y += HEADER_H + rows * (CELL_H + LABEL_H + GAP)
height = y + PAD

img = Image.new("RGB", (width, height), BG)
d = ImageDraw.Draw(img)

# ── title ──────────────────────────────────────────────────────────────
d.text((PAD, PAD), "The component bible", font=F_TITLE, fill=INK)
total = sum(len(c) for _, c in groups)
d.text((PAD, PAD + 42), f"{total} components · light render · open gallery/ for light+dark",
       font=F_LABEL, fill=MUTED)

# ── tiers ──────────────────────────────────────────────────────────────
y = PAD + 60
for tier, cs in groups:
    d.text((PAD, y + 12), tier.upper(), font=F_HEADER, fill=ACCENT)
    d.line((PAD, y + HEADER_H - 8, width - PAD, y + HEADER_H - 8), fill=(220, 228, 226), width=1)
    y += HEADER_H
    for i, (name, path) in enumerate(cs):
        col = i % COLS
        row = i // COLS
        cx = PAD + col * (CELL_W + GAP)
        cy = y + row * (CELL_H + LABEL_H + GAP)
        # cell background
        d.rounded_rectangle((cx, cy, cx + CELL_W, cy + CELL_H), radius=12, fill=CELL_BG,
                            outline=(228, 234, 232), width=1)
        # fit the render into the cell (contain)
        try:
            src = Image.open(path).convert("RGB")
        except Exception:
            continue
        pad = 10
        maxw, maxh = CELL_W - pad * 2, CELL_H - pad * 2
        scale = min(maxw / src.width, maxh / src.height)
        nw, nh = max(1, int(src.width * scale)), max(1, int(src.height * scale))
        src = src.resize((nw, nh), Image.LANCZOS)
        img.paste(src, (cx + (CELL_W - nw) // 2, cy + (CELL_H - nh) // 2))
        # label
        d.text((cx + 4, cy + CELL_H + 6), name, font=F_LABEL, fill=INK)
    rows = (len(cs) + COLS - 1) // COLS
    y += rows * (CELL_H + LABEL_H + GAP)

out = "gallery/contact_sheet.png"
img.save(out)
print(f"wrote {out} — {width}x{height}, {total} components")


# ── games sheet ─────────────────────────────────────────────────────────
# The experience layer: one render per game (games own their dark surface).
gfiles = sorted(glob.glob("gallery/games/*.png"))
gfiles = [(os.path.basename(f).replace("stage_", "").replace(".png", ""), f)
          for f in gfiles if "contact" not in f]
if gfiles:
    GCOLS, GCW, GCH = 4, 300, 300
    gw = PAD * 2 + GCOLS * GCW + (GCOLS - 1) * GAP
    grows = (len(gfiles) + GCOLS - 1) // GCOLS
    gh = PAD + 60 + grows * (GCH + LABEL_H + GAP) + PAD
    gimg = Image.new("RGB", (gw, gh), BG)
    gd = ImageDraw.Draw(gimg)
    gd.text((PAD, PAD), "The games — every stage", font=F_TITLE, fill=INK)
    gd.text((PAD, PAD + 42), f"{len(gfiles)} surfaces · the experience layer",
            font=F_LABEL, fill=MUTED)
    gy = PAD + 60
    for i, (name, path) in enumerate(gfiles):
        col, row = i % GCOLS, i // GCOLS
        cx = PAD + col * (GCW + GAP)
        cy = gy + row * (GCH + LABEL_H + GAP)
        gd.rounded_rectangle((cx, cy, cx + GCW, cy + GCH), radius=12,
                             fill=(15, 15, 20), outline=(42, 44, 52), width=1)
        try:
            src = Image.open(path).convert("RGB")
        except Exception:
            continue
        scale = min((GCW - 16) / src.width, (GCH - 16) / src.height)
        nw, nh = max(1, int(src.width * scale)), max(1, int(src.height * scale))
        src = src.resize((nw, nh), Image.LANCZOS)
        gimg.paste(src, (cx + (GCW - nw) // 2, cy + (GCH - nh) // 2))
        gd.text((cx + 4, cy + GCH + 6), name, font=F_LABEL, fill=INK)
    gimg.save("gallery/games_contact_sheet.png")
    print(f"wrote gallery/games_contact_sheet.png — {len(gfiles)} games")


# ── game organisms sheet ─────────────────────────────────────────────────
# The full assembled surfaces (stage + control bar) — the complete games.
ofiles = sorted(glob.glob("gallery/games/organism_*.png"))
ofiles = [(os.path.basename(f).replace("organism_", "").replace(".png", ""), f)
          for f in ofiles]
if ofiles:
    OCOLS, OCW, OCH = 4, 230, 420
    ow = PAD * 2 + OCOLS * OCW + (OCOLS - 1) * GAP
    orows = (len(ofiles) + OCOLS - 1) // OCOLS
    oh = PAD + 60 + orows * (OCH + LABEL_H + GAP) + PAD
    oimg = Image.new("RGB", (ow, oh), BG)
    od = ImageDraw.Draw(oimg)
    od.text((PAD, PAD), "The game organisms — the whole game", font=F_TITLE, fill=INK)
    od.text((PAD, PAD + 42), f"{len(ofiles)} surfaces · stage + control bar (GameScaffold)",
            font=F_LABEL, fill=MUTED)
    oy = PAD + 60
    for i, (name, path) in enumerate(ofiles):
        col, row = i % OCOLS, i // OCOLS
        cx = PAD + col * (OCW + GAP)
        cy = oy + row * (OCH + LABEL_H + GAP)
        od.rounded_rectangle((cx, cy, cx + OCW, cy + OCH), radius=12,
                             fill=(15, 15, 20), outline=(42, 44, 52), width=1)
        try:
            src = Image.open(path).convert("RGB")
        except Exception:
            continue
        scale = min((OCW - 12) / src.width, (OCH - 12) / src.height)
        nw, nh = max(1, int(src.width * scale)), max(1, int(src.height * scale))
        src = src.resize((nw, nh), Image.LANCZOS)
        oimg.paste(src, (cx + (OCW - nw) // 2, cy + (OCH - nh) // 2))
        od.text((cx + 4, cy + OCH + 6), name, font=F_LABEL, fill=INK)
    oimg.save("gallery/games_organisms_contact_sheet.png")
    print(f"wrote gallery/games_organisms_contact_sheet.png — {len(ofiles)} organisms")


# ── worlds sheet ─────────────────────────────────────────────────────────
# The curriculum layer: the action-words atoms + molecules (dark surface).
wfiles = sorted(glob.glob("gallery/worlds/*.png"))
wfiles = [(os.path.basename(f).replace(".png", ""), f)
          for f in wfiles if "contact" not in f]
if wfiles:
    WCOLS, WCW, WCH = 3, 300, 300
    ww = PAD * 2 + WCOLS * WCW + (WCOLS - 1) * GAP
    wrows = (len(wfiles) + WCOLS - 1) // WCOLS
    wh = PAD + 60 + wrows * (WCH + LABEL_H + GAP) + PAD
    wimg = Image.new("RGB", (ww, wh), BG)
    wd = ImageDraw.Draw(wimg)
    wd.text((PAD, PAD), "The worlds — action-words layer", font=F_TITLE, fill=INK)
    wd.text((PAD, PAD + 42), f"{len(wfiles)} surfaces · the curriculum vocabulary",
            font=F_LABEL, fill=MUTED)
    wy = PAD + 60
    for i, (name, path) in enumerate(wfiles):
        col, row = i % WCOLS, i // WCOLS
        cx = PAD + col * (WCW + GAP)
        cy = wy + row * (WCH + LABEL_H + GAP)
        wd.rounded_rectangle((cx, cy, cx + WCW, cy + WCH), radius=12,
                             fill=(15, 15, 20), outline=(42, 44, 52), width=1)
        try:
            src = Image.open(path).convert("RGB")
        except Exception:
            continue
        scale = min((WCW - 16) / src.width, (WCH - 16) / src.height)
        nw, nh = max(1, int(src.width * scale)), max(1, int(src.height * scale))
        src = src.resize((nw, nh), Image.LANCZOS)
        wimg.paste(src, (cx + (WCW - nw) // 2, cy + (WCH - nh) // 2))
        wd.text((cx + 4, cy + WCH + 6), name, font=F_LABEL, fill=INK)
    wimg.save("gallery/worlds_contact_sheet.png")
    print(f"wrote gallery/worlds_contact_sheet.png — {len(wfiles)} worlds")
