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
