"""Genera l'icona dell'app (1024x1024, opaca): AirPods + walkie-talkie in stile cartoon/inchiostro.
Uso: python3 tools/make_icon.py"""
import math
from PIL import Image, ImageDraw, ImageFilter

S, K = 1024, 2              # dimensione finale, supersampling
W = S * K
INK = (28, 24, 22)
CREAM = (243, 236, 224)
CLAY = (217, 119, 87)
CLAY_D = (186, 92, 64)
WHITE = (252, 250, 245)
SKY = (122, 170, 200)

def wob(x, y, amp=1.6):
    """Leggero tremolio da disegno a mano (deterministico)."""
    # solo onde lente: linee morbide con una leggera deriva, niente scatti
    return (x + amp * K * math.sin(y * 0.011 + x * 0.004),
            y + amp * K * math.cos(x * 0.010 - y * 0.003))

def rrect_pts(x0, y0, x1, y1, r, n=24):
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts

def ellipse_pts(cx, cy, rx, ry, n=160):
    return [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]

def shape(d, pts, fill, width=11, amp=1.6):
    pts = [wob(x * K, y * K, amp) for x, y in pts]
    d.polygon(pts, fill=fill)
    w = width * K
    d.line(pts + [pts[0]], fill=INK, width=w, joint="curve")
    for x, y in pts:                      # tondini ai vertici: contorno continuo senza spigoli
        d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=INK)

def sparkle(d, cx, cy, r, fill):
    pts = []
    for i in range(8):
        a = math.pi / 4 * i
        rr = r if i % 2 == 0 else r * 0.3
        pts.append(((cx + rr * math.cos(a)) * K, (cy + rr * math.sin(a)) * K))
    d.polygon(pts, fill=fill)

img = Image.new("RGB", (W, W), CREAM)
d = ImageDraw.Draw(img)

# macchia di colore morbida dietro (stile gouache)
blob = Image.new("L", (W, W), 0)
ImageDraw.Draw(blob).polygon([wob(x * K, y * K, 5) for x, y in ellipse_pts(512, 540, 400, 390, 240)], fill=255)
img.paste(Image.new("RGB", (W, W), (236, 198, 170)), mask=blob)

# --- walkie-talkie su layer separato, inclinato ---
wl = Image.new("RGBA", (W, W), (0, 0, 0, 0))
wd = ImageDraw.Draw(wl)
shape(wd, rrect_pts(572, 150, 622, 360, 22), INK, 8)                    # antenna
shape(wd, rrect_pts(572, 150, 622, 205, 22), CLAY_D, 8)
shape(wd, rrect_pts(560, 345, 640, 400, 14), INK, 8)                    # base antenna
shape(wd, rrect_pts(340, 360, 660, 900, 70), CLAY, 12)                   # corpo
shape(wd, rrect_pts(380, 400, 480, 440, 14), CREAM, 8)                  # display
for i in range(4):                                                      # griglia altoparlante
    y = 480 + i * 38
    wd.line([wob(400 * K, y * K, 1), wob(620 * K, y * K, 1)], fill=INK, width=11 * K)
    for x in (400, 620):
        wd.ellipse(((x - 5.5) * K, (y - 5.5) * K, (x + 5.5) * K, (y + 5.5) * K), fill=INK)
shape(wd, ellipse_pts(500, 770, 78, 78), CREAM, 11)                      # tasto PTT
shape(wd, ellipse_pts(500, 770, 40, 40), CLAY_D, 8)
shape(wd, rrect_pts(540, 405, 620, 435, 12), CLAY_D, 8)                  # manopola
wl = wl.rotate(7, resample=Image.BICUBIC, center=(W // 2, W // 2))
img.paste(wl, mask=wl)
d = ImageDraw.Draw(img)

# --- AirPods (due, speculari) ---
def airpod(cx, cy, flip):
    s = -1 if flip else 1
    stem = [(cx + s * 30, cy + 20), (cx + s * 78, cy + 20), (cx + s * 78, cy + 195)]
    shape(d, rrect_pts(cx + s * 24 if not flip else cx - 78, cy + 10, cx + 78 if not flip else cx - 24, cy + 215, 28), WHITE, 11)
    shape(d, ellipse_pts(cx, cy, 82, 74), WHITE, 11)
    # griglia altoparlante
    shape(d, ellipse_pts(cx - s * 12, cy - 4, 30, 26), SKY, 7)
    d.ellipse(((cx - s * 12 - 8) * K, (cy - 12) * K, (cx - s * 12 + 4) * K, (cy - 2) * K), fill=(220, 236, 246))
airpod(225, 690, True)
airpod(805, 640, False)

# --- onde sonore a pennello ---
def arc(cx, cy, r, a0, a1, w):
    pts = []
    for i in range(30):
        a = math.radians(a0 + (a1 - a0) * i / 29)
        pts.append(wob((cx + r * math.cos(a)) * K, (cy + r * math.sin(a)) * K, 1))
    d.line(pts, fill=INK, width=w * K, joint="curve")
    for p in (pts[0], pts[-1]):
        d.ellipse((p[0] - w * K / 2, p[1] - w * K / 2, p[0] + w * K / 2, p[1] + w * K / 2), fill=INK)
for r, w in ((78, 12), (128, 12), (180, 12)):
    arc(630, 215, r, -75, -5, w)
    arc(560, 215, r, -175, -105, w)

sparkle(d, 160, 200, 36, CLAY)
sparkle(d, 880, 360, 28, CLAY)
sparkle(d, 120, 420, 20, INK)
sparkle(d, 895, 900, 24, CLAY_D)

img = img.resize((S, S), Image.LANCZOS)
img.save("AirPodsWalkie/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
