#!/usr/bin/env python3
"""Генератор визуальных ассетов Project Deadworld.

Создаёт PNG для предметов, UI и поверхностей из процедурных описаний.
Только стандартная библиотека: PNG пишется вручную через zlib, поэтому
генерация воспроизводима на любой машине и в CI без установки пакетов.

Детерминированность обязательна: один и тот же запуск всегда даёт
побайтово одинаковые файлы, иначе каждый прогон создавал бы шум в git.

    python3 scripts/generate_assets.py          # сгенерировать всё
    python3 scripts/generate_assets.py --check  # проверить, что файлы актуальны

Арт-направление и палитра описаны в docs/ART_DIRECTION.md.
"""
from __future__ import annotations

import argparse
import math
import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "client" / "assets" / "generated"

# Палитра дублирует client/scripts/data/Palette.gd.
# Значения обязаны совпадать: расхождение сразу заметно как разнотон
# между сгенерированными иконками и процедурной отрисовкой мира.
P = {
    "void": (10, 12, 11),
    "concrete": (58, 60, 57),
    "concrete_dark": (46, 48, 46),
    "metal": (74, 77, 80),
    "metal_dark": (52, 55, 58),
    "rust": (107, 65, 38),
    "rust_light": (138, 87, 48),
    "wood": (61, 50, 39),
    "wood_light": (86, 70, 54),
    "cloth": (90, 82, 62),
    "blood": (110, 28, 24),
    "glass": (108, 132, 138),
    "glass_dark": (70, 90, 96),
    "ui_bg": (16, 19, 15),
    "ui_border": (44, 51, 42),
    "ui_text": (205, 211, 196),
    "ui_dim": (125, 135, 120),
    "accent": (184, 160, 90),
    "danger": (163, 58, 44),
    "ok": (111, 148, 85),
    "steel": (140, 146, 150),
    "steel_dark": (95, 100, 104),
    "brass": (150, 118, 58),
    "leaf": (74, 88, 60),
    "white": (235, 238, 230),
    "black": (12, 14, 12),
}


class Canvas:
    """RGBA-холст с примитивами рисования.

    Координаты — целые пиксели, начало в левом верхнем углу.
    Альфа-композитинг выполняется вручную, чтобы не тянуть зависимости.
    """

    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.pixels = bytearray(width * height * 4)

    def blend(self, x: int, y: int, rgb: tuple[int, int, int], alpha: float = 1.0) -> None:
        if not (0 <= x < self.width and 0 <= y < self.height) or alpha <= 0.0:
            return
        index = (y * self.width + x) * 4
        src_a = min(1.0, alpha)
        dst_a = self.pixels[index + 3] / 255.0
        out_a = src_a + dst_a * (1.0 - src_a)
        if out_a <= 0.0:
            return
        for channel in range(3):
            src_c = rgb[channel] / 255.0
            dst_c = self.pixels[index + channel] / 255.0
            out_c = (src_c * src_a + dst_c * dst_a * (1.0 - src_a)) / out_a
            self.pixels[index + channel] = int(round(out_c * 255.0))
        self.pixels[index + 3] = int(round(out_a * 255.0))

    def rect(self, x: int, y: int, w: int, h: int, rgb, alpha: float = 1.0) -> None:
        for py in range(y, y + h):
            for px in range(x, x + w):
                self.blend(px, py, rgb, alpha)

    def outline(self, x: int, y: int, w: int, h: int, rgb, alpha: float = 1.0) -> None:
        for px in range(x, x + w):
            self.blend(px, y, rgb, alpha)
            self.blend(px, y + h - 1, rgb, alpha)
        for py in range(y, y + h):
            self.blend(x, py, rgb, alpha)
            self.blend(x + w - 1, py, rgb, alpha)

    def circle(self, cx: float, cy: float, radius: float, rgb, alpha: float = 1.0) -> None:
        for py in range(int(cy - radius) - 1, int(cy + radius) + 2):
            for px in range(int(cx - radius) - 1, int(cx + radius) + 2):
                distance = math.hypot(px + 0.5 - cx, py + 0.5 - cy)
                if distance <= radius:
                    # Сглаживание края: последний пиксель гасится по расстоянию.
                    edge = min(1.0, radius - distance)
                    self.blend(px, py, rgb, alpha * edge)

    def line(self, x0: float, y0: float, x1: float, y1: float, rgb, width: float = 1.0, alpha: float = 1.0) -> None:
        steps = max(2, int(math.hypot(x1 - x0, y1 - y0) * 2))
        for step in range(steps + 1):
            t = step / steps
            self.circle(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, width / 2.0, rgb, alpha)

    def to_png(self) -> bytes:
        raw = bytearray()
        for y in range(self.height):
            raw.append(0)  # фильтр строки: None
            start = y * self.width * 4
            raw.extend(self.pixels[start:start + self.width * 4])

        def chunk(tag: bytes, data: bytes) -> bytes:
            return (struct.pack(">I", len(data)) + tag + data
                    + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

        header = struct.pack(">IIBBBBB", self.width, self.height, 8, 6, 0, 0, 0)
        return (b"\x89PNG\r\n\x1a\n"
                + chunk(b"IHDR", header)
                + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
                + chunk(b"IEND", b""))


def noise(seed: int) -> float:
    """Детерминированный псевдослучайный шум в диапазоне 0..1."""
    value = (seed * 2654435761) % 4294967296
    value ^= value >> 13
    value = (value * 1274126177) % 4294967296
    return (value % 10000) / 10000.0


# --- Иконки предметов -----------------------------------------------------
# Каждая иконка рисуется в 48x48. Силуэт важнее деталей: на мобильном
# экране игрок узнаёт предмет по форме, а не по мелким пикселям.

def icon_base(size: int = 48) -> Canvas:
    return Canvas(size, size)


def icon_pistol() -> Canvas:
    c = icon_base()
    c.rect(10, 20, 26, 8, P["metal"])
    c.rect(10, 20, 26, 3, P["steel_dark"])
    c.rect(12, 22, 20, 3, P["steel"])
    c.rect(14, 28, 8, 12, P["wood"])
    c.rect(15, 29, 5, 10, P["wood_light"])
    c.rect(22, 27, 3, 5, P["metal_dark"])
    c.circle(33, 24, 2.0, P["black"], 0.7)
    return c


def icon_ammo() -> Canvas:
    c = icon_base()
    for index, x in enumerate((12, 21, 30)):
        c.rect(x, 18, 7, 18, P["brass"])
        c.rect(x + 1, 19, 3, 16, (176, 142, 74))
        c.circle(x + 3.5, 17.5, 3.5, P["steel"])
        c.circle(x + 3.5, 17.0, 2.0, (168, 174, 178))
        c.rect(x, 33, 7, 3, P["steel_dark"], 0.6)
    return c


def icon_bat() -> Canvas:
    c = icon_base()
    c.line(12, 36, 34, 12, P["wood"], 7.0)
    c.line(12, 36, 22, 25, P["wood_light"], 4.0)
    c.line(30, 16, 35, 11, (98, 80, 60), 8.0)
    c.line(11, 37, 16, 32, P["metal_dark"], 5.0)
    return c


def icon_bandage() -> Canvas:
    c = icon_base()
    c.rect(10, 14, 28, 20, (218, 214, 200))
    c.rect(10, 14, 28, 4, (196, 192, 178))
    c.rect(10, 30, 28, 4, (196, 192, 178))
    c.rect(21, 18, 6, 12, P["danger"])
    c.rect(16, 21, 16, 6, P["danger"])
    return c


def icon_food_can() -> Canvas:
    c = icon_base()
    c.rect(14, 12, 20, 26, P["steel_dark"])
    c.rect(15, 13, 18, 24, P["steel"])
    c.rect(15, 18, 18, 12, P["rust"])
    c.rect(15, 20, 18, 3, P["rust_light"])
    c.rect(14, 12, 20, 3, (168, 174, 178))
    c.rect(14, 35, 20, 3, P["steel_dark"])
    return c


def icon_water() -> Canvas:
    c = icon_base()
    c.rect(17, 10, 14, 6, P["glass_dark"])
    c.rect(15, 16, 18, 24, P["glass"], 0.55)
    c.rect(15, 24, 18, 16, P["glass_dark"], 0.75)
    c.rect(17, 26, 3, 12, (150, 180, 190), 0.6)
    c.outline(15, 16, 18, 24, P["glass_dark"])
    return c


def icon_scrap() -> Canvas:
    c = icon_base()
    c.line(12, 30, 26, 16, P["steel_dark"], 6.0)
    c.line(20, 34, 34, 22, P["rust"], 5.0)
    c.line(14, 20, 30, 32, P["steel"], 3.0)
    c.circle(16, 18, 3.0, P["rust_light"])
    return c


def icon_generic() -> Canvas:
    c = icon_base()
    c.rect(13, 15, 22, 20, P["wood"])
    c.rect(13, 15, 22, 4, P["wood_light"])
    c.line(13, 25, 35, 25, P["black"], 1.5, 0.4)
    return c


ITEM_ICONS = {
    "pistol": icon_pistol,
    "pistol_ammo": icon_ammo,
    "baseball_bat": icon_bat,
    "bandage": icon_bandage,
    "canned_food": icon_food_can,
    "water_bottle": icon_water,
    "scrap_metal": icon_scrap,
    "generic": icon_generic,
}


# --- Поверхности ----------------------------------------------------------
# Тайлы 64x64, бесшовные по краям. Рисуем зернистость и трещины, чтобы
# большие площади не выглядели плоской заливкой.

def surface_tile(base: tuple[int, int, int], seed_offset: int, *, cracks: bool = True) -> Canvas:
    size = 64
    c = Canvas(size, size)
    c.rect(0, 0, size, size, base)
    for y in range(size):
        for x in range(size):
            n = noise(x * 71 + y * 131 + seed_offset)
            if n > 0.82:
                c.blend(x, y, P["black"], 0.10)
            elif n < 0.14:
                c.blend(x, y, P["white"], 0.045)
    if cracks:
        for index in range(3):
            sx = int(noise(seed_offset + index * 17) * size)
            sy = int(noise(seed_offset + index * 29) * size)
            length = 10 + int(noise(seed_offset + index * 41) * 18)
            angle = noise(seed_offset + index * 53) * math.tau
            ex = sx + math.cos(angle) * length
            ey = sy + math.sin(angle) * length
            c.line(sx, sy, ex, ey, P["black"], 1.0, 0.22)
    return c


def surface_asphalt() -> Canvas:
    return surface_tile((52, 57, 62), 1301)


def surface_concrete() -> Canvas:
    c = surface_tile((78, 80, 76), 2711)
    # Стыки плит: подчёркивают масштаб и направление.
    c.line(0, 32, 64, 32, P["black"], 1.0, 0.25)
    c.line(32, 0, 32, 64, P["black"], 1.0, 0.18)
    return c


def surface_soil() -> Canvas:
    return surface_tile((64, 57, 46), 3907, cracks=False)


def surface_grass() -> Canvas:
    c = surface_tile((74, 74, 52), 4507, cracks=False)
    for index in range(70):
        x = noise(index * 13 + 4507) * 64
        y = noise(index * 29 + 4507) * 64
        c.line(x, y, x + 0.6, y - 2.2, P["leaf"], 1.0, 0.5)
    return c


def surface_wood() -> Canvas:
    c = Canvas(64, 64)
    c.rect(0, 0, 64, 64, (82, 67, 52))
    for plank in range(4):
        y = plank * 16
        c.rect(0, y, 64, 15, (82 + plank % 2 * 6, 67 + plank % 2 * 5, 52 + plank % 2 * 4))
        c.line(0, y + 15, 64, y + 15, P["black"], 1.0, 0.35)
        for index in range(6):
            gx = noise(plank * 31 + index * 17) * 64
            c.line(gx, y + 2, gx + 3, y + 12, (64, 52, 40), 1.0, 0.3)
    return c


def surface_tile_clinic() -> Canvas:
    c = Canvas(64, 64)
    c.rect(0, 0, 64, 64, (68, 84, 83))
    for row in range(2):
        for col in range(2):
            x, y = col * 32, row * 32
            shade = 4 if (row + col) % 2 == 0 else 0
            c.rect(x + 1, y + 1, 30, 30, (68 + shade, 84 + shade, 83 + shade))
            c.outline(x, y, 32, 32, (48, 60, 60))
    return c


SURFACES = {
    "asphalt": surface_asphalt,
    "concrete": surface_concrete,
    "soil": surface_soil,
    "grass": surface_grass,
    "wood": surface_wood,
    "tile_clinic": surface_tile_clinic,
}


# --- UI -------------------------------------------------------------------

def ui_slot() -> Canvas:
    """Слот хотбара/инвентаря. 9-slice: углы 6px."""
    size = 64
    c = Canvas(size, size)
    c.rect(0, 0, size, size, P["ui_bg"], 0.92)
    c.outline(0, 0, size, size, P["ui_border"])
    c.outline(1, 1, size - 2, size - 2, (24, 28, 22), 0.6)
    # Уголки: подсказывают, что это интерактивная ячейка.
    for cx, cy in ((3, 3), (size - 9, 3), (3, size - 9), (size - 9, size - 9)):
        c.rect(cx, cy, 6, 1, P["ui_dim"], 0.5)
        c.rect(cx, cy, 1, 6, P["ui_dim"], 0.5)
    return c


def ui_slot_active() -> Canvas:
    c = ui_slot()
    c.outline(0, 0, 64, 64, P["accent"])
    c.outline(1, 1, 62, 62, P["accent"], 0.4)
    return c


def ui_panel() -> Canvas:
    """Фон панели. 9-slice: углы 8px."""
    size = 64
    c = Canvas(size, size)
    c.rect(0, 0, size, size, P["ui_bg"], 0.95)
    c.outline(0, 0, size, size, P["ui_border"])
    c.rect(2, 2, size - 4, 1, P["ui_dim"], 0.18)
    return c


def ui_vignette() -> Canvas:
    """Затемнение краёв экрана. Растягивается на весь viewport."""
    size = 256
    c = Canvas(size, size)
    center = size / 2.0
    max_distance = math.hypot(center, center)
    for y in range(size):
        for x in range(size):
            distance = math.hypot(x + 0.5 - center, y + 0.5 - center) / max_distance
            # Гасим центр полностью, к краям выводим плотную тень.
            alpha = max(0.0, (distance - 0.42) / 0.58) ** 1.7
            if alpha > 0.004:
                c.blend(x, y, P["void"], min(0.88, alpha))
    return c


def ui_light_falloff() -> Canvas:
    """Мягкое световое пятно для источников света и зоны видимости."""
    size = 256
    c = Canvas(size, size)
    center = size / 2.0
    for y in range(size):
        for x in range(size):
            distance = math.hypot(x + 0.5 - center, y + 0.5 - center) / center
            if distance >= 1.0:
                continue
            # Плавное затухание: cos даёт мягкий край без резкого кольца.
            alpha = (math.cos(distance * math.pi) + 1.0) / 2.0
            c.blend(x, y, P["white"], alpha)
    return c


UI_ELEMENTS = {
    "slot": ui_slot,
    "slot_active": ui_slot_active,
    "panel": ui_panel,
    "vignette": ui_vignette,
    "light_falloff": ui_light_falloff,
}


def build() -> dict[str, bytes]:
    out: dict[str, bytes] = {}
    for name, factory in ITEM_ICONS.items():
        out[f"items/{name}.png"] = factory().to_png()
    for name, factory in SURFACES.items():
        out[f"surfaces/{name}.png"] = factory().to_png()
    for name, factory in UI_ELEMENTS.items():
        out[f"ui/{name}.png"] = factory().to_png()
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="проверить актуальность без записи")
    arguments = parser.parse_args()

    assets = build()
    stale: list[str] = []
    for name, data in sorted(assets.items()):
        path = ASSETS / name
        if arguments.check:
            if not path.is_file() or path.read_bytes() != data:
                stale.append(name)
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.is_file() or path.read_bytes() != data:
            path.write_bytes(data)
            print(f"generated {path.relative_to(ROOT)}")

    if arguments.check:
        if stale:
            print("Ассеты устарели: " + ", ".join(stale), file=sys.stderr)
            print("Запустите: python3 scripts/generate_assets.py", file=sys.stderr)
            return 1
        print(f"Ассеты актуальны ({len(assets)} файлов)")
        return 0

    print(f"Готово: {len(assets)} ассетов в {ASSETS.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
