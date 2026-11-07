"""Night-skyline art for Scenester: a violet-to-magenta dusk sky with streaky
clouds, lit towers and palm silhouettes. Draws the three city banners and the
app icon with fixed random seeds, so running it again gives the same pictures.

    python3 art/night.py    # writes art/<name>.svg and art/<name>.png
"""
import math
import os
import random
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
WINDOW_COLORS = ["#ffe7a8", "#ffd27a", "#fff4d6", "#ffcf8a", "#cfe8ff", "#a8d8ff"]


class Scene:
    def __init__(self, width, height, seed):
        self.w, self.h = width, height
        self.r = random.Random(seed)
        self.defs, self.layers = [], []

    def add(self, svg):
        self.layers.append(svg)

    # ---- sky

    def sky(self, stops):
        self.defs.append('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">%s</linearGradient>'
                         % "".join('<stop offset="%.2f" stop-color="%s"/>' % s for s in stops))
        self.add('<rect width="%d" height="%d" fill="url(#sky)"/>' % (self.w, self.h))

    def clouds(self, top, bottom, colors, count=60, blur=7):
        """Long wind-stretched streaks, brightest low in the sky like the last light of sunset."""
        self.defs.append('<filter id="soft" x="-20%%" y="-50%%" width="140%%" height="200%%"><feGaussianBlur stdDeviation="%d"/></filter>' % blur)
        parts = []
        for _ in range(count):
            y = self.r.uniform(top, bottom)
            length = self.r.uniform(self.w * 0.15, self.w * 0.6)
            x = self.r.uniform(-length * 0.3, self.w - length * 0.5)
            thick = self.r.uniform(4, 22) * (0.6 + (y - top) / (bottom - top))
            tilt = self.r.uniform(-0.12, 0.05) * length
            d = "M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z" % (
                x, y, x + length / 2, y - thick + tilt / 2, x + length, y + tilt,
                x + length / 2, y + thick * 0.6 + tilt / 2, x, y)
            parts.append('<path d="%s" fill="%s" opacity="%.2f"/>' % (d, self.r.choice(colors), self.r.uniform(0.6, 1.0)))
        self.add('<g filter="url(#soft)">%s</g>' % "".join(parts))

    def glow(self, cx, cy, rx, ry, color, opacity):
        gid = "g%d" % self.r.randrange(10 ** 8)
        self.defs.append('<radialGradient id="%s"><stop offset="0" stop-color="%s" stop-opacity="%.2f"/><stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient>'
                         % (gid, color, opacity, color))
        self.add('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="url(#%s)"/>' % (cx, cy, rx, ry, gid))

    # ---- buildings

    def windows(self, x, top, w, base, lit=0.55, cell=(7, 10), color_bias=None):
        cw, ch = cell
        out = []
        cols = max(1, int((w - 6) / cw))
        rows = max(1, int((base - top - 8) / ch))
        pad = (w - cols * cw) / 2
        bias = color_bias or WINDOW_COLORS
        # Whole floors tend to be on or off together, as in a real office tower at night.
        for j in range(rows):
            floor_lit = lit * self.r.uniform(0.3, 1.6)
            for i in range(cols):
                if self.r.random() < floor_lit:
                    out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" opacity="%.2f"/>'
                               % (x + pad + i * cw + 1.2, top + 6 + j * ch + 2, cw - 2.6, ch - 4.5,
                                  self.r.choice(bias), self.r.uniform(0.55, 1)))
        return "".join(out)

    def tower(self, x, base, w, h, fill="#1b1533", lit=0.55, cap=None, cell=(7, 10), edge="#3a2f63"):
        top = base - h
        svg = ['<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s"/>' % (x, top, w, h, fill)]
        svg.append('<rect x="%.1f" y="%.1f" width="2" height="%.1f" fill="%s" opacity="0.7"/>' % (x, top, h, edge))
        svg.append(self.windows(x, top, w, base, lit, cell))
        if cap:
            svg.append(cap(x, top, w))
        self.add("".join(svg))

    def crown_light(self, cx, y, radius=26, color="#ffffff"):
        self.glow(cx, y, radius * 2.4, radius * 1.6, color, 0.55)

    # ---- foreground

    def palm(self, x, base, height, lean=0.0, scale=1.0, color="#07050d"):
        """A tall, skinny fan palm silhouette: a slightly bowed trunk and a ragged tuft."""
        top_x, top_y = x + lean * height, base - height
        mid_x = x + lean * height * 0.4 + self.r.uniform(-8, 8)
        trunk_w = 7 * scale
        d = "M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z" % (
            x - trunk_w, base, mid_x - trunk_w * 0.7, base - height * 0.5, top_x - trunk_w * 0.45, top_y,
            top_x + trunk_w * 0.45, top_y, mid_x + trunk_w * 0.7, base - height * 0.5, x + trunk_w, base)
        parts = ['<path d="%s" fill="%s"/>' % (d, color)]
        # A dark ball of dead fronds under the crown, then the live fronds fanning out.
        parts.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (top_x, top_y + 10 * scale, 9 * scale, 16 * scale, color))
        for i in range(28):
            a = -math.pi + i / 27 * math.pi + self.r.uniform(-0.1, 0.1)
            length = self.r.uniform(26, 48) * scale
            side = math.cos(a)
            # Fronds rise a little, then droop under their own weight; the outer ones droop most.
            ex = top_x + side * length
            ey = top_y + math.sin(a) * length * 0.45 + length * 0.55 * abs(side) ** 1.5
            cx = top_x + side * length * 0.5
            cy = top_y + math.sin(a) * length * 0.7
            parts.append('<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f" stroke="%s" stroke-width="%.1f" fill="none" stroke-linecap="round"/>'
                         % (top_x, top_y, cx, cy, ex, ey, color, self.r.uniform(2.2, 4.2) * scale))
            # Fine leaflets along the outer half give the tuft its feathery edge.
            for k in range(4):
                t = 0.5 + k * 0.15
                fx = (1 - t) ** 2 * top_x + 2 * (1 - t) * t * cx + t * t * ex
                fy = (1 - t) ** 2 * top_y + 2 * (1 - t) * t * cy + t * t * ey
                parts.append('<path d="M%.1f %.1f L%.1f %.1f" stroke="%s" stroke-width="%.1f" stroke-linecap="round"/>'
                             % (fx, fy, fx + side * self.r.uniform(2, 7) * scale, fy + self.r.uniform(5, 11) * scale, color, 1.3 * scale))
        self.add("".join(parts))

    def ridge(self, base, amp, color, points=14):
        pts = [(0, self.h), (0, base)]
        for i in range(points + 1):
            x = self.w * i / points
            pts.append((x, base - amp * (0.5 + 0.5 * math.sin(i * 1.3 + self.r.uniform(-0.5, 0.5)))))
        pts += [(self.w, base), (self.w, self.h)]
        self.add('<path d="M%s Z" fill="%s"/>' % (" L".join("%.1f %.1f" % p for p in pts), color))

    def city_lights(self, top, bottom, count, colors=("#ffd27a", "#fff1c9", "#ff9e6b", "#a8d8ff")):
        dots = []
        for _ in range(count):
            dots.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" opacity="%.2f"/>'
                        % (self.r.uniform(0, self.w), self.r.uniform(top, bottom), self.r.uniform(0.8, 2.4),
                           self.r.choice(colors), self.r.uniform(0.5, 1)))
        self.add("".join(dots))

    def render(self, name):
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><defs>%s</defs>%s</svg>'
               % (self.w, self.h, self.w, self.h, "".join(self.defs), "".join(self.layers)))
        path = os.path.join(HERE, name + ".svg")
        with open(path, "w") as f:
            f.write(svg)
        subprocess.run(["swift", os.path.join(HERE, "render.swift"), path, os.path.join(HERE, name + ".png"),
                        str(self.w), str(self.h)], check=True)
        return path


DUSK = [(0.0, "#0b0b2e"), (0.28, "#2a1660"), (0.5, "#5b1f7a"), (0.68, "#a3277a"), (0.82, "#e0466f"), (1.0, "#ff7a59")]
CLOUDS = ["#ff4f7b", "#ff3d6e", "#e2307c", "#ff7a8a", "#b22d93", "#ff5e62", "#ff9a8a"]


def la_skyline(s, base, scale=1.0, x0=0.0):
    """Downtown LA from the hills: the US Bank Tower's glowing crown, the Wilshire Grand's
    spire and a crowd of lit office towers."""
    def at(x):
        return x0 + x * scale
    towers = [
        (60, 90, 170), (150, 70, 230), (225, 95, 290), (330, 60, 210), (395, 85, 330),
        (700, 80, 300), (790, 105, 380), (905, 70, 250), (985, 95, 340), (1090, 75, 270),
        (1175, 110, 230), (1295, 70, 180), (1375, 90, 210),
    ]
    for x, w, h in towers:
        s.tower(at(x), base, w * scale, h * scale, lit=s.r.uniform(0.35, 0.65), cell=(7 * scale, 10 * scale))
    # Wilshire Grand: tapered sides and a lit spire.
    wx = at(500)
    s.add('<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="#17122e"/>' % (
        wx, base, wx + 8 * scale, base - 470 * scale, wx + 92 * scale, base - 440 * scale, wx + 100 * scale, base))
    s.add(s.windows(wx + 10 * scale, base - 430 * scale, 80 * scale, base, 0.5, (7 * scale, 10 * scale), ["#a8d8ff", "#cfe8ff", "#ffffff"]))
    s.add('<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="#cfe8ff" opacity="0.9"/>' % (
        wx + 8 * scale, base - 470 * scale, wx + 50 * scale, base - 540 * scale, wx + 92 * scale, base - 440 * scale))
    s.add('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="#ffffff"/>' % (wx + 48 * scale, base - 600 * scale, 3 * scale, 62 * scale))
    s.crown_light(wx + 50 * scale, base - 520 * scale, 22 * scale, "#bfe3ff")
    # US Bank Tower: a cylinder with a stepped, glowing crown.
    ux = at(605)
    s.tower(ux, base, 88 * scale, 500 * scale, fill="#1d1638", lit=0.55, cell=(7 * scale, 10 * scale))
    for k in range(4):
        s.add('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="#ffffff" opacity="%.2f"/>' % (
            ux + 6 * k * scale, base - (500 + 12 + 12 * k) * scale, (88 - 12 * k) * scale, 9 * scale, 0.95 - 0.12 * k))
    s.crown_light(ux + 44 * scale, base - 520 * scale, 30 * scale)
    # City Hall: stepped tower with a lit pyramid cap.
    cx = at(1225)
    s.tower(cx, base, 60 * scale, 360 * scale, fill="#211a3d", lit=0.7, cell=(7 * scale, 10 * scale))
    s.add('<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="#ffe7a8" opacity="0.85"/>' % (
        cx + 6 * scale, base - 360 * scale, cx + 30 * scale, base - 420 * scale, cx + 54 * scale, base - 360 * scale))
    s.crown_light(cx + 30 * scale, base - 390 * scale, 18 * scale, "#ffd27a")


def los_angeles():
    s = Scene(1500, 900, 90026)
    s.sky(DUSK)
    s.clouds(90, 600, CLOUDS, count=120, blur=5)
    s.glow(750, 760, 900, 260, "#ff8a5c", 0.55)
    la_skyline(s, 760)
    s.city_lights(740, 800, 260)
    s.ridge(805, 30, "#07050d")
    for x, h, lean, sc in [(70, 620, 0.03, 1.0), (205, 700, -0.02, 1.05), (355, 560, 0.04, 0.9), (1080, 640, -0.03, 1.0),
                           (1210, 720, 0.02, 1.1), (1395, 600, -0.04, 0.95)]:
        s.palm(x, 900, h, lean, sc)
    return s.render("los-angeles")


def bay_area():
    """The Golden Gate at dusk: its towers dark against a pink sky, lights strung along the cables."""
    s = Scene(1500, 900, 94115)
    s.sky([(0.0, "#0d1033"), (0.3, "#24205f"), (0.55, "#5a2a7d"), (0.75, "#c23c74"), (0.9, "#ff7058"), (1.0, "#ffa060")])
    s.clouds(80, 560, ["#ff6a7f", "#ff4f7b", "#b23a8f", "#ff8f80", "#ffb07a"], count=100, blur=5)
    s.glow(1100, 640, 700, 200, "#ff9a62", 0.5)
    # Marin hills, then the water.
    s.ridge(640, 120, "#191233", 10)
    s.city_lights(560, 640, 70)
    s.add('<rect x="0" y="640" width="1500" height="260" fill="#120d2a"/>')
    for _ in range(90):
        y = s.r.uniform(650, 900)
        x = s.r.uniform(0, 1500)
        s.add('<rect x="%.1f" y="%.1f" width="%.1f" height="2" fill="%s" opacity="%.2f"/>' % (
            x, y, s.r.uniform(20, 90), s.r.choice(["#ff7a6a", "#c23c74", "#ffd27a"]), s.r.uniform(0.15, 0.45)))
    deck, top = 600, 130
    color = "#3a0f1c"
    for tx in (330, 1030):
        s.add('<path d="M%d 690 L%d %d L%d %d L%d 690 Z" fill="%s"/>' % (tx, tx + 12, top, tx + 118, top, tx + 130, color))
        for k, y in enumerate([top + 40, top + 160, top + 280, top + 390]):
            s.add('<rect x="%d" y="%d" width="%d" height="%d" fill="#1a0710" opacity="0.9"/>' % (tx + 26, y, 78, 70 - 6 * k))
        s.crown_light(tx + 65, top + 4, 14, "#ff5a4a")
    s.add('<rect x="0" y="%d" width="1500" height="18" fill="%s"/>' % (deck, color))

    def cable(x0, y0, x1, y1, sag, n=60):
        return [(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n + sag * math.sin(math.pi * i / n)) for i in range(n + 1)]
    left, right = 395, 1095
    for part in [cable(-60, deck - 10, left, top + 8, 50), cable(left, top + 8, right, top + 8, deck - top - 40),
                 cable(right, top + 8, 1560, deck - 10, 50)]:
        s.add('<path d="M%s" stroke="%s" stroke-width="5" fill="none"/>' % (" L".join("%.1f %.1f" % p for p in part), color))
        for x, y in part[1:-1]:
            if y < deck - 6:
                s.add('<rect x="%.1f" y="%.1f" width="1.4" height="%.1f" fill="%s" opacity="0.8"/>' % (x, y, deck - y, color))
        for x, y in part[::3]:
            s.add('<circle cx="%.1f" cy="%.1f" r="2.2" fill="#ffd9a0"/>' % (x, y))
    for x in range(10, 1500, 26):
        s.add('<circle cx="%d" cy="%d" r="2" fill="#ffe2a8"/>' % (x, deck + 9))
    return s.render("bay-area")


def san_diego():
    """San Diego Bay at dusk: the Coronado Bridge's long lit curve in front of the downtown towers."""
    s = Scene(1500, 900, 92101)
    s.sky([(0.0, "#0a0f33"), (0.3, "#232066"), (0.55, "#53308a"), (0.75, "#c2477c"), (0.9, "#ff7d5c"), (1.0, "#ffb164")])
    s.clouds(80, 560, ["#ff7a7f", "#ff4f7b", "#b23a8f", "#ffa080"], count=100, blur=5)
    s.glow(820, 640, 800, 220, "#ff9a62", 0.5)
    base = 640
    for x, w, h in [(420, 70, 200), (495, 90, 300), (590, 70, 250), (665, 100, 380), (770, 80, 290), (855, 110, 340),
                    (970, 70, 220), (1045, 95, 270), (1145, 80, 200), (1230, 70, 160)]:
        s.tower(x, base, w, h, lit=s.r.uniform(0.4, 0.7))
    s.add('<rect x="0" y="%d" width="1500" height="%d" fill="#100c28"/>' % (base, 900 - base))
    for _ in range(120):
        y = s.r.uniform(base + 6, 900)
        x = s.r.uniform(300, 1350)
        s.add('<rect x="%.1f" y="%.1f" width="%.1f" height="2" fill="%s" opacity="%.2f"/>' % (
            x, y, s.r.uniform(10, 60), s.r.choice(["#ffd27a", "#ff9e6b", "#c2477c"]), s.r.uniform(0.15, 0.5)))
    pts = [(-40 + t / 60 * 1580, 830 - 300 * math.sin(math.pi * min(1, t / 60 * 1.15)) * (1 - 0.35 * t / 60)) for t in range(61)]
    road = " L".join("%.1f %.1f" % p for p in pts)
    s.add('<path d="M%s" stroke="#07050d" stroke-width="16" fill="none"/>' % road)
    for x, y in pts[1:-1:2]:
        s.add('<rect x="%.1f" y="%.1f" width="9" height="%.1f" fill="#07050d"/>' % (x - 4, y, 900 - y))
    for x, y in pts[::1]:
        s.add('<circle cx="%.1f" cy="%.1f" r="2.4" fill="#ffd9a0"/>' % (x, y - 9))
    for x, h, lean, sc in [(80, 640, 0.03, 1.0), (190, 560, -0.03, 0.9), (1430, 600, -0.03, 1.0)]:
        s.palm(x, 900, h, lean, sc)
    return s.render("san-diego")


def app_icon():
    """1024px icon: the LA skyline at dusk framed by two palms, no text."""
    s = Scene(1024, 1024, 213)
    s.sky([(0.0, "#100c3a"), (0.35, "#3a1a72"), (0.6, "#8e2580"), (0.8, "#e5456f"), (1.0, "#ff8a5c")])
    s.clouds(120, 640, CLOUDS, count=60, blur=6)
    s.glow(512, 880, 700, 240, "#ff8a5c", 0.6)
    la_skyline(s, 930, scale=0.86, x0=-130)
    s.city_lights(920, 960, 120)
    s.ridge(965, 18, "#07050d", 8)
    s.palm(130, 1024, 860, 0.03, 1.9)
    s.palm(905, 1024, 780, -0.04, 1.75)
    return s.render("app-icon")


if __name__ == "__main__":
    for draw in (los_angeles, bay_area, san_diego, app_icon):
        print(draw())
