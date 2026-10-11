"""Genera l'icona dell'app (1024x1024, opaca). Uso: python3 tools/make_icon.py"""
from PIL import Image, ImageDraw, ImageFilter
import math
S = 1024
def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))
# sfondo: gradiente diagonale notte -> viola
bg = Image.new("RGB", (S, S))
px = bg.load()
c1, c2 = (10, 14, 40), (62, 24, 110)
for y in range(S):
    for x in range(S):
        px[x, y] = lerp(c1, c2, (x * 0.45 + y * 0.9) / (S * 1.35))
# alone luminoso al centro
glow = Image.new("RGB", (S, S), (0, 0, 0))
ImageDraw.Draw(glow).ellipse((212, 212, 812, 812), fill=(255, 90, 140))
glow = glow.filter(ImageFilter.GaussianBlur(160))
bg = Image.blend(bg, Image.eval(glow, lambda v: v), 0.0)
from PIL import ImageChops
bg = ImageChops.add(bg, glow.point(lambda v: int(v * 0.35)))
d = ImageDraw.Draw(bg, "RGBA")
# onde radio concentriche
for i, r in enumerate((250, 340, 430)):
    a = 70 - i * 18
    d.ellipse((S/2 - r, S/2 - r, S/2 + r, S/2 + r), outline=(255, 255, 255, a), width=6)
# barre waveform a gradiente ciano -> rosa
heights = [120, 250, 400, 560, 400, 250, 120]
bw, gap = 70, 34
total = len(heights) * bw + (len(heights) - 1) * gap
x0 = (S - total) / 2
layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
mask = Image.new("L", (S, S), 0)
md = ImageDraw.Draw(mask)
for i, h in enumerate(heights):
    x = x0 + i * (bw + gap)
    md.rounded_rectangle((x, S/2 - h/2, x + bw, S/2 + h/2), radius=bw/2, fill=255)
grad = Image.new("RGB", (S, S))
gp = grad.load()
for y in range(S):
    col = lerp((70, 220, 255), (255, 90, 160), max(0, min(1, (y - 230) / 560)))
    for x in range(S): gp[x, y] = col
shadow = mask.filter(ImageFilter.GaussianBlur(28)).point(lambda v: int(v * 0.5))
bg.paste((255, 120, 180), mask=shadow)
bg.paste(grad, mask=mask)
bg.save("AirPodsWalkie/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
