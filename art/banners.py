"""Draws the city banners at the top of each screen: ink splatter, scratchy
pen lines and loose color washes, loosely in the spirit of gonzo-era ink
illustration. Each city is drawn from simple shapes with a fixed random seed,
so running this again gives the same pictures.

    python3 art/banners.py      # writes art/<city>.svg and art/<city>.png
"""
import math
import os
import random
import subprocess

W, H = 1500, 900
HERE = os.path.dirname(os.path.abspath(__file__))
INK = "#17110d"
PAPER = "#efe6d2"


class Sketch:
    def __init__(self, seed):
        self.r = random.Random(seed)
        self.back, self.wash, self.ink, self.splat = [], [], [], []

    def j(self, amount):
        return self.r.uniform(-amount, amount)

    # ---- pen work

    def line(self, x1, y1, x2, y2, width=2.4, passes=2, wobble=3.0, overshoot=10, layer=None, color=INK):
        layer = self.ink if layer is None else layer
        for _ in range(passes):
            dx, dy = x2 - x1, y2 - y1
            length = math.hypot(dx, dy) or 1
            ux, uy = dx / length, dy / length
            o1, o2 = self.r.uniform(0, overshoot), self.r.uniform(0, overshoot)
            ax, ay = x1 - ux * o1 + self.j(wobble), y1 - uy * o1 + self.j(wobble)
            bx, by = x2 + ux * o2 + self.j(wobble), y2 + uy * o2 + self.j(wobble)
            steps = max(2, int(length / 40))
            pts = []
            for i in range(steps + 1):
                t = i / steps
                pts.append((ax + (bx - ax) * t + self.j(wobble * 0.6), ay + (by - ay) * t + self.j(wobble * 0.6)))
            d = "M%.1f %.1f " % pts[0] + " ".join("L%.1f %.1f" % p for p in pts[1:])
            w = width * self.r.uniform(0.55, 1.25)
            layer.append('<path d="%s" stroke="%s" stroke-width="%.2f" fill="none" stroke-linecap="round" opacity="%.2f"/>'
                         % (d, color, w, self.r.uniform(0.75, 1)))

    def poly(self, pts, width=2.4, closed=True, **kw):
        pairs = list(zip(pts, pts[1:] + (pts[:1] if closed else [])))
        for (a, b) in pairs:
            self.line(a[0], a[1], b[0], b[1], width=width, **kw)

    def curve(self, pts, width=2.6, passes=2, wobble=3, color=INK, layer=None):
        layer = self.ink if layer is None else layer
        for _ in range(passes):
            q = [(x + self.j(wobble), y + self.j(wobble)) for x, y in pts]
            d = "M%.1f %.1f " % q[0] + " ".join("L%.1f %.1f" % p for p in q[1:])
            layer.append('<path d="%s" stroke="%s" stroke-width="%.2f" fill="none" stroke-linecap="round" stroke-linejoin="round" opacity="%.2f"/>'
                         % (d, color, width * self.r.uniform(0.6, 1.3), self.r.uniform(0.7, 1)))

    def hatch(self, pts, spacing=9, angle=None, width=1.2, density=1.0, cross=False):
        """Scratchy parallel strokes clipped to a polygon."""
        clip = "c%d" % self.r.randrange(10 ** 9)
        d = "M" + " L".join("%.1f %.1f" % p for p in pts) + " Z"
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        span = math.hypot(max(xs) - min(xs), max(ys) - min(ys))
        group = ['<clipPath id="%s"><path d="%s"/></clipPath><g clip-path="url(#%s)">' % (clip, d, clip)]
        for a in [angle if angle is not None else self.r.uniform(-1.1, -0.4)] + ([self.r.uniform(0.3, 1.0)] if cross else []):
            ux, uy = math.cos(a), math.sin(a)
            nx, ny = -uy, ux
            k = -span / 2
            while k < span / 2:
                if self.r.random() < density:
                    px, py = cx + nx * k, cy + ny * k
                    half = span / 2 * self.r.uniform(0.7, 1.1)
                    group.append('<path d="M%.1f %.1f L%.1f %.1f" stroke="%s" stroke-width="%.2f" stroke-linecap="round" opacity="%.2f"/>'
                                 % (px - ux * half + self.j(4), py - uy * half + self.j(4), px + ux * half + self.j(4), py + uy * half + self.j(4),
                                    INK, width * self.r.uniform(0.5, 1.4), self.r.uniform(0.45, 0.95)))
                k += spacing * self.r.uniform(0.6, 1.5)
        group.append("</g>")
        self.ink.append("".join(group))

    # ---- color and splatter

    def blot(self, x, y, radius, color, opacity=0.55, layer=None, lumps=14):
        layer = self.wash if layer is None else layer
        pts = []
        for i in range(lumps):
            a = i / lumps * math.tau
            rr = radius * self.r.uniform(0.55, 1.25)
            pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr * self.r.uniform(0.6, 1.0)))
        d = "M%.1f %.1f " % pts[0]
        for i in range(len(pts)):
            p0, p1 = pts[i], pts[(i + 1) % len(pts)]
            mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
            d += "Q%.1f %.1f %.1f %.1f " % (p0[0], p0[1], mx, my)
        layer.append('<path d="%sZ" fill="%s" opacity="%.2f"/>' % (d, color, opacity))

    def wash_rect(self, x, y, w, h, color, opacity=0.5, strokes=18):
        for _ in range(strokes):
            sx = x + self.r.uniform(0, w)
            sy = y + self.r.uniform(0, h)
            size = min(w, h, 260)
            self.blot(sx, sy, self.r.uniform(size * 0.35, size * 0.7), color, opacity * self.r.uniform(0.3, 0.7))

    def fill(self, pts, color, opacity=0.8):
        """A loose wash of color inside a shape, slightly off its outline like a quick brush."""
        for _ in range(2):
            q = [(x + self.j(8), y + self.j(8)) for x, y in pts]
            self.wash.append('<path d="M%s Z" fill="%s" opacity="%.2f"/>' % (" L".join("%.1f %.1f" % p for p in q), color, opacity * self.r.uniform(0.5, 0.8)))

    def splatter(self, x, y, size, color=INK, drips=True):
        self.blot(x, y, size, color, opacity=0.92, layer=self.splat, lumps=18)
        for _ in range(int(size * 1.4)):
            a = self.r.uniform(0, math.tau)
            dist = size * self.r.uniform(1.0, 3.6)
            rr = max(0.8, size * 0.16 * (1 - (dist / (size * 3.6))) * self.r.uniform(0.3, 1.4))
            self.splat.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" opacity="%.2f"/>'
                              % (x + math.cos(a) * dist, y + math.sin(a) * dist, rr, color, self.r.uniform(0.7, 1)))
        for _ in range(int(size * 0.8)):
            a = self.r.uniform(0, math.tau)
            dist = size * self.r.uniform(1.2, 2.6)
            ex, ey = x + math.cos(a) * dist, y + math.sin(a) * dist
            self.splat.append('<path d="M%.1f %.1f L%.1f %.1f" stroke="%s" stroke-width="%.1f" stroke-linecap="round"/>'
                              % (x + math.cos(a) * size * 0.8, y + math.sin(a) * size * 0.8, ex, ey, color, self.r.uniform(1, size * 0.15)))
        if drips:
            for _ in range(self.r.randint(1, 3)):
                dx = x + self.j(size * 0.7)
                length = self.r.uniform(size * 1.5, size * 5)
                w = self.r.uniform(2, size * 0.22)
                self.splat.append('<path d="M%.1f %.1f L%.1f %.1f" stroke="%s" stroke-width="%.1f" stroke-linecap="round"/>'
                                  % (dx, y, dx + self.j(2), y + length, color, w))
                self.splat.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (dx, y + length, w * 0.9, color))

    def spray(self, x, y, w, h, n, color=INK, maxr=1.8):
        for _ in range(n):
            self.splat.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" opacity="%.2f"/>'
                              % (x + self.r.uniform(0, w), y + self.r.uniform(0, h), self.r.uniform(0.4, maxr), color, self.r.uniform(0.4, 0.9)))

    # ---- shared scenery

    def building(self, x, base, w, h, windows=True, hatch_side=True, top=None):
        pts = [(x, base), (x, base - h), (x + w, base - h), (x + w, base)]
        self.poly(pts, width=2.6)
        if hatch_side:
            side = [(x + w * 0.62, base), (x + w * 0.62, base - h), (x + w, base - h), (x + w, base)]
            self.hatch(side, spacing=self.r.uniform(5, 9), angle=self.r.uniform(-1.4, -1.2), density=0.9)
        if windows:
            rows = int(h / self.r.uniform(18, 30))
            for i in range(1, rows):
                yy = base - h + i * h / rows
                if self.r.random() < 0.7:
                    self.line(x + 4, yy, x + w * 0.6, yy, width=1.0, passes=1, wobble=1.5, overshoot=3)
        if top:
            top(x, base - h, w)

    def palm(self, x, base, h, lean=0.0):
        top = (x + lean * h, base - h)
        pts = []
        for i in range(12):
            t = i / 11
            pts.append((x + lean * h * t * t + math.sin(t * 5) * 2, base - h * t))
        self.curve(pts, width=5, passes=3, wobble=1.5)
        for i in range(10):
            a = -math.pi / 2 + (i - 4.5) * 0.42 + self.j(0.15)
            length = self.r.uniform(55, 95)
            frond = []
            for k in range(8):
                t = k / 7
                frond.append((top[0] + math.cos(a) * length * t, top[1] + math.sin(a) * length * t + (length * 0.55) * t * t))
            self.curve(frond, width=3.2, passes=2, wobble=2)
            for k in range(2, 8):
                t = k / 7
                fx, fy = frond[k]
                self.line(fx, fy, fx + self.j(6), fy + self.r.uniform(8, 18) * (1 - t * 0.3), width=1.1, passes=1, wobble=1, overshoot=0)

    def hills(self, base, amp, color, n=5, opacity=0.5):
        pts = [(0, base)]
        for i in range(n * 4 + 1):
            x = W * i / (n * 4)
            pts.append((x, base - amp * (0.5 + 0.5 * math.sin(i * 0.9 + self.r.uniform(-0.3, 0.3))) * self.r.uniform(0.7, 1.1)))
        pts.append((W, base))
        d = "M" + " L".join("%.1f %.1f" % p for p in pts) + " Z"
        self.back.append('<path d="%s" fill="%s" opacity="%.2f"/>' % (d, color, opacity))
        self.curve(pts[1:-1], width=1.8, passes=2, wobble=4)

    def sun(self, x, y, r, color):
        self.blot(x, y, r, color, opacity=0.8)
        for i in range(26):
            a = i / 26 * math.tau
            self.line(x + math.cos(a) * r * 1.15, y + math.sin(a) * r * 1.15,
                      x + math.cos(a) * r * self.r.uniform(1.5, 2.4), y + math.sin(a) * r * self.r.uniform(1.5, 2.4),
                      width=1.6, passes=1, wobble=2, overshoot=2)

    def render(self, name):
        svg = [
            '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (W, H, W, H),
            "<defs>",
            '<filter id="rough" filterUnits="userSpaceOnUse" x="0" y="0" width="1500" height="900"><feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="4"/>'
            '<feDisplacementMap in="SourceGraphic" scale="5"/></filter>',
            '<filter id="bleed" filterUnits="userSpaceOnUse" x="0" y="0" width="1500" height="900"><feTurbulence type="fractalNoise" baseFrequency="0.02" numOctaves="3" seed="9"/>'
            '<feDisplacementMap in="SourceGraphic" scale="22"/><feGaussianBlur stdDeviation="1.2"/></filter>',
            '<filter id="grain" filterUnits="userSpaceOnUse" x="0" y="0" width="1500" height="900"><feTurbulence type="fractalNoise" baseFrequency="0.8" numOctaves="2" seed="2"/>'
            '<feColorMatrix values="0 0 0 0 0.35  0 0 0 0 0.28  0 0 0 0 0.2  0 0 0 0.22 0"/></filter>',
            "</defs>",
            '<rect width="100%%" height="100%%" fill="%s"/>' % PAPER,
            '<g filter="url(#bleed)">' + "".join(self.back) + "</g>",
            '<g filter="url(#bleed)" style="mix-blend-mode:multiply">' + "".join(self.wash) + "</g>",
            '<g filter="url(#rough)">' + "".join(self.ink) + "</g>",
            '<g filter="url(#rough)">' + "".join(self.splat) + "</g>",
            '<rect width="100%" height="100%" filter="url(#grain)"/>',
            "</svg>",
        ]
        path = os.path.join(HERE, name + ".svg")
        with open(path, "w") as f:
            f.write("".join(svg))
        subprocess.run(["swift", os.path.join(HERE, "render.swift"), path, os.path.join(HERE, name + ".png"), str(W), str(H)], check=True)
        return path


def los_angeles():
    s = Sketch(213)
    s.wash_rect(0, 0, W, 420, "#e8a24a", 0.55, 30)          # smoggy orange sky
    s.wash_rect(0, 0, W, 200, "#d9583b", 0.45, 14)
    s.sun(1180, 170, 70, "#d9452f")
    s.hills(560, 140, "#9a7a55", opacity=0.45)
    base = 760
    # Skyline, left to right, with the tall ones in the middle.
    x = 60
    for w, h in [(90, 230), (70, 300), (110, 260)]:
        s.building(x, base, w, h)
        x += w + s.r.uniform(6, 18)
    # City Hall: stepped tower with a pyramid cap.
    ch = 430
    s.building(ch, base, 120, 250, hatch_side=True)
    s.building(ch + 20, base - 250, 80, 110)
    s.poly([(ch + 30, base - 360), (ch + 60, base - 450), (ch + 90, base - 360)], width=2.6)
    s.line(ch + 60, base - 450, ch + 60, base - 500, width=2)
    # US Bank Tower: a cylinder with a stepped crown.
    ub = 640
    s.poly([(ub, base), (ub, base - 560), (ub + 120, base - 560), (ub + 120, base)], width=3)
    for k in range(5):
        y = base - 560 - k * 14
        s.line(ub + 8 * k, y, ub + 120 - 8 * k, y, width=2.4)
    s.hatch([(ub + 75, base), (ub + 75, base - 560), (ub + 120, base - 560), (ub + 120, base)], spacing=6, angle=-1.5, density=0.95)
    for k in range(1, 25):
        s.line(ub + 6, base - k * 22, ub + 70, base - k * 22, width=0.9, passes=1, wobble=1.5, overshoot=2)
    # Wilshire Grand: tapered with a sail and a spire.
    wg = 800
    s.poly([(wg, base), (wg + 10, base - 600), (wg + 110, base - 560), (wg + 120, base)], width=3)
    s.line(wg + 10, base - 600, wg + 60, base - 690, width=2.2)
    s.line(wg + 60, base - 690, wg + 60, base - 760, width=1.6)
    s.hatch([(wg + 70, base), (wg + 65, base - 580), (wg + 110, base - 560), (wg + 120, base)], spacing=7, angle=-1.3, density=0.9)
    x = 960
    for w, h in [(100, 380), (80, 290), (130, 330), (90, 220), (120, 260)]:
        s.building(x, base, w, h)
        x += w + s.r.uniform(6, 16)
    # A freeway sweeping across the front, with palms.
    road = [(0, 800), (300, 785), (700, 805), (1100, 780), (1500, 795)]
    s.curve(road, width=4, passes=3)
    s.curve([(x0, y0 + 26) for x0, y0 in road], width=3, passes=2)
    for px in range(40, W, 140):
        s.line(px, 830, px + s.j(6), 900, width=3, passes=2)
    for px, h, lean in [(330, 470, -0.04), (395, 400, 0.05), (1325, 520, 0.06), (1420, 430, -0.05)]:
        s.palm(px, 880, h, lean)
    s.splatter(1260, 540, 26, "#c0392b")
    s.splatter(140, 330, 18)
    s.splatter(905, 300, 12)
    s.spray(0, 0, W, H, 380)
    return s.render("los-angeles")


def bay_area():
    s = Sketch(415)
    s.wash_rect(0, 0, W, 450, "#8fb6c9", 0.5, 26)          # cold blue sky
    s.wash_rect(0, 520, W, 380, "#3f6f86", 0.55, 26)       # the bay
    s.hills(560, 170, "#7f8c63", opacity=0.5)
    # Fog rolling over the hills.
    for _ in range(22):
        s.blot(s.r.uniform(0, W), s.r.uniform(380, 520), s.r.uniform(60, 140), "#f7f3ea", 0.75, layer=s.back)
    water = 640
    towers = [(380, 120), (1060, 120)]
    top = 150
    for tx, tw in towers:
        legs = [(tx, water + 40), (tx + 14, top), (tx + tw - 14, top), (tx + tw, water + 40)]
        s.fill([(tx, water + 40), (tx + 14, top), (tx + tw - 14, top), (tx + tw, water + 40)], "#c4452c", 0.95)
        s.poly(legs, width=3.4, closed=False)
        s.line(tx, water + 40, tx + tw, water + 40, width=3)
        # The deco portals: stacked cross-bracing between the legs.
        for k, y in enumerate([top + 30, top + 140, top + 250, top + 360]):
            h = 70 - k * 4
            s.poly([(tx + 18, y), (tx + tw - 18, y), (tx + tw - 18, y + h), (tx + 18, y + h)], width=2.4)
            s.hatch([(tx + 22, y + 6), (tx + tw - 22, y + 6), (tx + tw - 22, y + h - 6), (tx + 22, y + h - 6)], spacing=6, cross=True, density=0.8)
    deck = 520
    s.curve([(0, deck + 6), (W, deck - 6)], width=5, passes=3)
    s.curve([(0, deck + 30), (W, deck + 16)], width=3, passes=2)
    s.hatch([(0, deck + 6), (W, deck - 6), (W, deck + 16), (0, deck + 30)], spacing=10, angle=1.4, density=0.9)
    # Main cables: a sag between the towers and down to the anchorages.
    left, right = towers[0][0] + 60, towers[1][0] + 60

    def cable(x0, y0, x1, y1, sag, n=40):
        return [(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n + sag * math.sin(math.pi * i / n)) for i in range(n + 1)]
    main = cable(left, top, right, top, deck - top - 20)
    for part in [cable(-80, deck - 10, left, top, 40), main, cable(right, top, W + 80, deck - 20, 40)]:
        s.curve(part, width=3.2, passes=3, color="#7d1f12")
        for (x, y) in part[1:-1:2]:
            if y < deck - 4:
                s.line(x, y, x, deck - 2, width=1.0, passes=1, wobble=1.2, overshoot=0, color="#7d1f12")
    # Waves and a sailboat.
    for _ in range(40):
        x, y = s.r.uniform(0, W), s.r.uniform(660, 880)
        s.curve([(x, y), (x + 14, y - 6), (x + 28, y), (x + 42, y - 5)], width=1.6, passes=1, wobble=1)
    s.poly([(1260, 760), (1300, 640), (1300, 760)], width=2)
    s.curve([(1230, 765), (1330, 765), (1310, 785), (1250, 785), (1230, 765)], width=2.4)
    s.splatter(720, 300, 24, "#b0301f")
    s.splatter(230, 760, 16)
    s.splatter(1380, 220, 12)
    s.spray(0, 0, W, H, 380)
    return s.render("bay-area")


def san_diego():
    """The Coronado Bridge's long blue curve in front of the downtown towers, with palms."""
    s = Sketch(619)
    s.wash_rect(0, 0, W, 420, "#f0c26a", 0.55, 26)
    s.wash_rect(0, 0, W, 180, "#e07b4f", 0.4, 12)
    s.wash_rect(0, 600, W, 300, "#4f8fb0", 0.6, 26)
    s.sun(260, 150, 64, "#e2683c")
    base = 600
    x = 480
    for w, h in [(80, 220), (100, 330), (70, 260), (120, 400), (90, 300), (110, 350), (70, 210), (100, 270)]:
        s.building(x, base, w, h)
        x += w + s.r.uniform(4, 14)
    # The bridge: a high arc on many piers, rising from the left.
    pts = []
    for i in range(41):
        t = i / 40
        pts.append((-40 + t * (W + 80), 760 - 300 * math.sin(math.pi * min(1, t * 1.15)) * (1 - 0.35 * t)))
    s.curve(pts, width=6, passes=3, color="#1f4f7a")
    s.curve([(x, y + 22) for x, y in pts], width=3, passes=2, color="#1f4f7a")
    for x, y in pts[2:-2:3]:
        s.line(x - 6, y + 22, x - 10, 900, width=3.2, passes=2, color="#1f4f7a")
        s.line(x + 6, y + 22, x + 10, 900, width=3.2, passes=2, color="#1f4f7a")
    for _ in range(36):
        x, y = s.r.uniform(0, W), s.r.uniform(640, 880)
        s.curve([(x, y), (x + 16, y - 6), (x + 32, y), (x + 48, y - 5)], width=1.6, passes=1, wobble=1)
    for px, h, lean in [(90, 560, 0.05), (170, 470, -0.04), (1400, 520, -0.06)]:
        s.palm(px, 900, h, lean)
    s.splatter(1150, 160, 22, "#c0392b")
    s.splatter(640, 760, 14)
    s.spray(0, 0, W, H, 380)
    return s.render("san-diego")


if __name__ == "__main__":
    for draw in (los_angeles, bay_area, san_diego):
        print(draw())
