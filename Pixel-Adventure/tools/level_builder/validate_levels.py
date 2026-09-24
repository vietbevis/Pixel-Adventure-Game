#!/usr/bin/env python3
"""Kiểm chứng màn chơi đi được bằng cách MÔ PHỎNG vật lý của player.gd trên lưới ô.

Đầu vào: các file <id>.json do build_levels.gd ghi ra (--json=<dir>).
    python3 tools/level_builder/validate_levels.py <json_dir> [id ...] [--dash] [--verbose]

Mô hình (khớp player.gd + player.tscn):
  collider 22x32, bàn chân = gốc + 20; SPEED 140, JUMP -320, GRAVITY 900, rơi tối đa 500,
  nhảy đôi, bám tường (trượt 60), wall-jump đẩy 180 + khoá input 0.18s và không nhảy lại
  cùng một mặt tường; Dash 340 px/s trong 0.16s (chỉ khi --dash hoặc màn sau khi có Dash).
  Lò xo bật -520, quạt nâng tới -180, ván một chiều, ván sập / bệ di động coi là ván.
  Gai / cưa đứng yên = chết; quái bỏ qua (giết được).

Tìm kiếm: từ mỗi "đoạn đứng" (dải ô cùng hàng có đất bên dưới, bị cắt bởi gai / tường)
thử một bộ chuỗi thao tác (hướng, thời điểm nhảy đôi, trễ hướng, wall-jump, dash) và
ghi lại đoạn đáp xuống. Mục tiêu: S → mọi checkpoint → cờ (và báo kim cương / di vật).
"""
import json
import math
import sys
from collections import deque

T = 16
DT = 1.0 / 60.0
SPEED, JUMP, GRAV, MAXFALL = 140.0, -320.0, 900.0, 500.0
WJ_PUSH, WSLIDE, WJ_LOCK = 180.0, 60.0, 0.18
DASH_V, DASH_T = 340.0, 0.16
HW, HH = 11.0, 16.0  # nửa kích thước collider
FEET = 20.0          # gốc → bàn chân; tâm collider = gốc + 4


class Level:
    def __init__(self, data, dash):
        self.id = data["id"]
        self.w, self.h = data["w"], data["h"]
        self.rows = data["rows"]
        self.dash = dash
        self.solid = [[c == "#" for c in r] for r in self.rows]
        self.plank = [[c == "=" for c in r] for r in self.rows]
        self.hazard = set()          # ô gây chết (gai)
        self.hazard_circles = []     # (cx, cy, r) cưa đứng yên
        self.tramp = set()
        self.fan_cols = []           # (x0, x1, ytop, ybottom)
        self.ents = data["entities"]
        for e in self.ents:
            x, y, t = e["x"], e["y"], e["type"]
            if t == "spikes" or t == "spikes_ceiling":
                self.hazard.add((x, y))
            elif t == "ability_gate" and not dash:
                for k in range(4):
                    if 0 <= y - k < self.h:
                        self.solid[y - k][x] = True
            elif t == "dash_wall":
                # Coi là tường kín; nếu có Dash thì là tường "xuyên được khi lướt" — mô phỏng
                # gần đúng: có Dash thì bỏ tường (người chơi luôn lướt vào phá được).
                if not dash:
                    for k in range(3):
                        if 0 <= y - k < self.h:
                            self.solid[y - k][x] = True
            elif t == "trampoline":
                self.tramp.add((x, y))
            elif t == "fan":
                self.fan_cols.append((x * T - 2, x * T + 18, (y + 1) * T - 154, (y + 1) * T - 4))
            elif t in ("falling_platform", "moving_platform"):
                md = e.get("move_distance", [0, 0])
                steps = max(1, int(max(abs(md[0]), abs(md[1])) // T))
                for i in range(steps + 1):
                    px = x + round(md[0] / T * i / steps)
                    py = y + round(md[1] / T * i / steps)
                    for dx in (-1, 0, 1):
                        if 0 <= px + dx < self.w and 0 <= py < self.h:
                            self.plank[py][px + dx] = True
            elif t == "saw" and not e.get("move_distance"):
                self.hazard_circles.append((x * T + 8, y * T + 8, 17))

    def is_solid(self, cx, cy):
        if cx < 0 or cx >= self.w:
            return True
        if cy < 0:
            return False
        if cy >= self.h:
            return self.solid[self.h - 1][cx]
        return self.solid[cy][cx]

    def is_plank(self, cx, cy):
        return 0 <= cx < self.w and 0 <= cy < self.h and self.plank[cy][cx]

    # --- vật lý ---------------------------------------------------------------
    def collide_x(self, x, y, vx):
        """Di chuyển ngang; trả (x, chạm_tường_hướng)."""
        nx = x + vx * DT
        top, bot = y - HH, y + HH - 0.01
        wall = 0
        if vx > 0:
            edge = nx + HW
            c = int(math.floor(edge / T))
            for r in range(int(math.floor(top / T)), int(math.floor(bot / T)) + 1):
                if self.is_solid(c, r):
                    nx = c * T - HW - 0.001
                    wall = 1
                    break
        elif vx < 0:
            edge = nx - HW
            c = int(math.floor(edge / T))
            for r in range(int(math.floor(top / T)), int(math.floor(bot / T)) + 1):
                if self.is_solid(c, r):
                    nx = (c + 1) * T + HW + 0.001
                    wall = -1
                    break
        return nx, wall

    def collide_y(self, x, y, vy):
        """Di chuyển dọc; trả (y, vy, trên_đất)."""
        ny = y + vy * DT
        left, right = x - HW + 0.01, x + HW - 0.01
        c0, c1 = int(math.floor(left / T)), int(math.floor(right / T))
        if vy > 0:
            old_bot = y + HH
            edge = ny + HH
            r = int(math.floor(edge / T))
            for c in range(c0, c1 + 1):
                if self.is_solid(c, r) or (self.is_plank(c, r) and old_bot <= r * T + 0.5):
                    return r * T - HH, 0.0, True
        elif vy < 0:
            edge = ny - HH
            r = int(math.floor(edge / T))
            for c in range(c0, c1 + 1):
                if self.is_solid(c, r):
                    return (r + 1) * T + HH + 0.001, 0.0, False
        return ny, vy, False

    def deadly(self, x, y):
        top, bot = y - HH + 4, y + HH - 1
        for r in range(int(top // T), int(bot // T) + 1):
            for c in range(int((x - HW + 3) // T), int((x + HW - 3) // T) + 1):
                if (c, r) in self.hazard:
                    # gai chiếm ~7px dưới đáy ô
                    if bot > r * T + 9:
                        return True
        for (sx, sy, sr) in self.hazard_circles:
            dx = max(abs(x - sx) - HW, 0)
            dy = max(abs(y - sy) - HH, 0)
            if dx * dx + dy * dy < sr * sr:
                return True
        return y - HH > self.h * T

    def on_tramp(self, x, y):
        bot = y + HH
        r = int((bot - 1) // T)
        for c in range(int((x - HW) // T), int((x + HW) // T) + 1):
            if (c, r) in self.tramp and bot > r * T + 2:
                return True
        return False

    def fan_lift(self, x, y):
        for (x0, x1, yt, yb) in self.fan_cols:
            if x + HW > x0 and x - HW < x1 and y + HH > yt and y - HH < yb:
                return True
        return False

    def simulate(self, x, y, plan):
        """Chạy 1 kế hoạch từ tư thế đứng tại (x, y=tâm collider). Trả điểm đáp hoặc None.

        plan: dict dir, delay (khung), dj (khung nhảy đôi hoặc -1), wj (bool),
              dash (khung dash hoặc -1), jump (bool — nhảy ngay hay bước khỏi mép).
        """
        d = plan["dir"]
        vx, vy = 0.0, (JUMP if plan["jump"] else 0.0)
        jumps = 1 if plan["jump"] else 2
        lock = 0.0
        last_wall = 0
        dash_left = -1.0
        dashed = False
        path = []
        for f in range(720):
            cur_dir = d if f >= plan["delay"] else 0
            if dash_left > 0:
                dash_left -= DT
                vx, vy = plan["dash_dir"] * DASH_V, 0.0
                x, _ = self.collide_x(x, y, vx)
                path.append((x, y))
                if self.deadly(x, y):
                    return None, path
                continue
            if plan["dash"] == f and self.dash and not dashed:
                dashed = True
                dash_left = DASH_T
                plan["dash_dir"] = d if d != 0 else 1
                continue
            vy = min(vy + GRAV * DT, MAXFALL)
            if self.fan_lift(x, y):
                vy = max(vy - 1400.0 * DT, -180.0)
            lock = max(lock - DT, 0.0)
            # tường
            probe_x, wall = self.collide_x(x, y, (cur_dir or 1) * 1.0 / DT * 0.2) if cur_dir else (x, 0)
            touching = wall != 0 and cur_dir == wall
            if touching and vy > WSLIDE:
                vy = WSLIDE
            if f == plan["dj"] and jumps > 0:
                vy = JUMP
                jumps -= 1
            elif plan["wj"] and touching and lock <= 0 and -wall != last_wall and f > 2:
                vy = JUMP
                vx = -wall * WJ_PUSH
                lock = WJ_LOCK
                last_wall = -wall
                jumps = 1
                d = -d  # đổi hướng giữ phím: zig-zag giữa 2 tường
            if lock <= 0:
                vx = cur_dir * SPEED if cur_dir else 0.0
            x, _ = self.collide_x(x, y, vx)
            y, vy, grounded = self.collide_y(x, y, vy)
            path.append((x, y))
            if self.deadly(x, y):
                return None, path
            if grounded:
                if self.on_tramp(x, y):
                    vy = -520.0
                    jumps = 1
                    continue
                if f > 0:
                    return (x, y), path
        return None, path


def segments(lv):
    """Các đoạn đứng: (row, x0, x1) — ô trống cao 2 ô, đất/ván bên dưới, không gai."""
    segs = []
    for r in range(1, lv.h - 1):
        c = 0
        while c < lv.w:
            def ok(cc):
                return (not lv.is_solid(cc, r) and not lv.is_solid(cc, r - 1)
                        and (lv.is_solid(cc, r + 1) or lv.is_plank(cc, r + 1))
                        and (cc, r) not in lv.hazard)
            if ok(c):
                s = c
                while c < lv.w and ok(c):
                    c += 1
                segs.append((r, s, c - 1))
            else:
                c += 1
    return segs


def seg_of(segs, px, py):
    feet_row = int((py + HH) // T)  # hàng đất
    r = feet_row - 1
    cx = int(px // T)
    best = None
    for i, (sr, a, b) in enumerate(segs):
        if sr == r and a - 1 <= cx <= b + 1:
            if a <= cx <= b:
                return i
            best = i
    return best


PLANS = None


def plans(dash):
    out = []
    djs = [-1] + list(range(6, 44, 3))
    for d in (-1, 1, 0):
        for jump in (True, False):
            for delay in ((0, 8, 18) if jump else (0,)):
                for dj in djs:
                    for wj in (False, True):
                        if wj and d == 0:
                            continue
                        dashes = [-1]
                        if dash and d != 0:
                            dashes = [-1, 10, 22, 34]
                        for ds in dashes:
                            out.append({"dir": d, "jump": jump, "delay": delay, "dj": dj, "wj": wj, "dash": ds})
    return out


def validate(data, dash, verbose=False):
    lv = Level(data, dash)
    segs = segments(lv)
    ps = plans(dash)
    ent = {e["type"]: e for e in lv.ents}
    start = next(e for e in lv.ents if e["type"] == "start")
    sx, sy = start["x"] * T + 8, (start["y"] + 1) * T - HH
    s0 = seg_of(segs, sx, sy)
    seen = {s0}
    q = deque([s0])
    touched = set()  # ô mà quỹ đạo đi qua (để tính vật nhặt giữa trời)
    while q:
        i = q.popleft()
        r, a, b = segs[i]
        y = (r + 1) * T - HH
        xs = sorted(set([a * T + HW + 0.5, (b + 1) * T - HW - 0.5, a * T + 1, (b + 1) * T - 1]
                        + [c * T + 8 for c in range(a, b + 1, 3)]))
        for c in range(a, b + 1):
            touched.add((c, r))
            touched.add((c, r - 1))
        for x in xs:
            if x - HW < a * T - 12 or x + HW > (b + 1) * T + 12:
                pass
            for p in ps:
                if not p["jump"]:
                    # bước khỏi mép: chỉ ở 2 mép, đi ra ngoài
                    if not ((p["dir"] < 0 and x < a * T + 8) or (p["dir"] > 0 and x > b * T + 8)):
                        continue
                    nc = a - 1 if p["dir"] < 0 else b + 1
                    if lv.is_solid(nc, r) or lv.is_solid(nc, r - 1):
                        continue  # mép là tường, không phải vực — không "bước" xuyên qua được
                    xx = (a * T - HW + 2) if p["dir"] < 0 else ((b + 1) * T + HW - 2)
                else:
                    xx = x
                land, path = lv.simulate(xx, y, dict(p))
                for (px, py) in path[::2]:
                    touched.add((int(px // T), int(py // T)))
                    touched.add((int(px // T), int((py - 12) // T)))
                    touched.add((int(px // T), int((py + 12) // T)))
                if land is None:
                    continue
                j = seg_of(segs, land[0], land[1])
                if j is not None and j not in seen:
                    seen.add(j)
                    q.append(j)
    ok = True
    report = []
    for e in lv.ents:
        t = e["type"]
        if t in ("checkpoint", "goal", "diamond", "relic", "fruit"):
            hit = (e["x"], e["y"]) in touched
            if not hit and t in ("checkpoint", "goal"):
                ok = False
            if not hit:
                report.append("  KHÔNG tới được %s tại ô (%d,%d)" % (t, e["x"], e["y"]))
    reach = len(seen)
    return ok, reach, len(segs), report


def main():
    global HW, HH
    # --margin=N: phình thân người chơi thêm N px mỗi phía để lộ các khe chỉ lọt khi khít
    # từng pixel (trong game thật sẽ kẹt / cụng góc).
    for a in sys.argv[1:]:
        if a.startswith("--margin="):
            m = float(a.split("=")[1])
            HW += m
            HH += m
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dash_all = "--dash" in sys.argv
    jdir = args[0]
    ids = args[1:]
    import os
    if not ids:
        ids = sorted(f[:-5] for f in os.listdir(jdir) if f.endswith(".json"))
    dash_levels = {"level_3", "level_4", "boss_forest", "level_5", "level_6", "boss_dungeon"}
    bad = 0
    for i in ids:
        data = json.load(open(os.path.join(jdir, i + ".json")))
        dash = dash_all or i in dash_levels
        ok, reach, total, report = validate(data, dash)
        note = "  (có Dash)" if dash else ""
        has_relic = any(e["type"] == "relic" for e in data["entities"])
        if not ok and not dash and has_relic:
            # Di vật Dash nằm giữa màn: hợp lệ nếu tới được di vật khi CHƯA có Dash và
            # tới được cờ khi ĐÃ có Dash (phần sau di vật chơi với Dash).
            relic_ok = not any("relic" in line for line in report)
            ok2, reach, total, report = validate(data, True)
            ok = relic_ok and ok2
            note = "  (tới di vật không cần Dash → phần sau dùng Dash)"
        print("[%s] %s  đoạn đứng tới được %d/%d%s" % ("OK" if ok else "LỖI", i, reach, total, note))
        for line in report:
            print(line)
        bad += 0 if ok else 1
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
