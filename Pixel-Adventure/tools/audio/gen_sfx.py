#!/usr/bin/env python3
"""Tổng hợp các SFX nhỏ mà không asset pack nào trong repo có (nhặt quả, bước chân).

Chạy: python3 tools/audio/gen_sfx.py   (từ thư mục Pixel-Adventure/)
Ghi ra audio/sfx/<tên>.wav — .wav vì máy dev không có bộ mã hoá ogg. Chỉ dùng stdlib.
Sau khi chạy, mở editor (hoặc `Godot --headless --import`) để sinh sidecar .import.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "audio", "sfx")


def write_wav(name: str, samples: list[float]) -> None:
    path = os.path.normpath(os.path.join(OUT_DIR, name + ".wav"))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))
    print("wrote", path, f"{len(samples) / RATE * 1000:.0f}ms")


def tone(freq: float, dur: float, vol: float, decay: float) -> list[float]:
    """Sóng vuông làm mềm (sine + hài bậc 3) — nghe "chip" hợp đồ hoạ pixel mà không chói."""
    out = []
    for i in range(int(dur * RATE)):
        t = i / RATE
        env = math.exp(-t * decay) * min(1.0, i / (0.002 * RATE))  # attack 2ms tránh tiếng "bụp"
        wave_v = math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(2 * math.pi * freq * 3 * t)
        out.append(wave_v * env * vol)
    return out


def fruit() -> list[float]:
    # 2 nốt đi lên (Mi6 → Si6): "ting-ting" vui tai, đủ ngắn để nhặt liên tiếp không chồng lộn xộn.
    return tone(1318.5, 0.055, 0.28, 30.0) + tone(1975.5, 0.12, 0.28, 22.0)


def step() -> list[float]:
    # Tiếng bước: tiếng ồn qua lọc thông thấp (sột soạt) + sine trầm tắt nhanh (lực chân).
    # Nhỏ hơn hẳn các SFX khác vì phát liên tục khi chạy.
    rnd = random.Random(7)
    out, lp = [], 0.0
    n = int(0.06 * RATE)
    for i in range(n):
        t = i / RATE
        lp += 0.18 * (rnd.uniform(-1, 1) - lp)
        env = math.exp(-t * 70.0) * min(1.0, i / (0.001 * RATE))
        thump = math.sin(2 * math.pi * 110 * t) * math.exp(-t * 90.0)
        out.append((lp * 0.9 + thump * 0.6) * env * 0.35)
    return out


if __name__ == "__main__":
    write_wav("fruit", fruit())
    write_wav("step", step())
