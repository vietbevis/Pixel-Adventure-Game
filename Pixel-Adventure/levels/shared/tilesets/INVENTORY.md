# Tilesets & nền — danh mục

Mọi tileset và nền đều **sinh bằng code** trong `res://tools/level_builder/` — đừng sửa tay
file `.tres`/`.tscn` sinh ra, sửa script dựng rồi chạy lại.

## Tileset địa hình (16px, tự ghép) — `levels/shared/tilesets/`

| File | Nguồn | World |
|---|---|---|
| `forest_auto.png/.tres` | Pixel Adventure 1 `Terrain (16x16).png` — khối cỏ/đất; ván một chiều từ khối gỗ | Rừng + Làng |
| `castle_auto.png/.tres` | `castle_terrain_32.png` (Kings and Pigs, 32px) cắt mini-tile 8px — giữ nét, không thu nhỏ | Lâu Đài |
| `dungeon_auto.png/.tres` | Pixel Adventure 1 khung đá xám; tường nền từ `dungeon_wall_16.png` (Dungeon_pack) | Hầm Ngục |

Bố cục atlas (xem `tile_forge.gd`): hàng 0–3 = ô đặc (cột = mask 4 hướng, hàng = parity),
hàng 4 = ván một chiều, hàng 5 = tường nền không va chạm.

## Nền parallax — `shared/backgrounds/` (dựng bằng `build_backgrounds.gd`)

| Scene | Nguồn (CC0) | Dùng ở |
|---|---|---|
| `meadow_parallax.tscn` | "Parallax background forest pixel art" — MatiasVme | Rừng 1, Làng |
| `deep_forest_parallax.tscn` | "Forest Background" — ansimuz | Rừng 2 |
| `night_town_parallax.tscn` | "Gothicvania Patreon's Collection" (Night Town) — ansimuz | Lâu Đài 1 |
| `castle_hall_parallax.tscn` | "Gothicvania Patreon's Collection" (Gothic Castle, ghép mảnh) — ansimuz | Lâu Đài 2, phòng Vua Heo |
| `dark_castle_parallax.tscn` | "Gothicvania Patreon's Collection" (Old Dark Castle) — ansimuz | Hầm Ngục, phòng Cai Ngục |

`shared/backgrounds/menu/*.png` là tranh toàn cảnh ghép từ các lớp trên, dùng làm nền menu.
