# Tilesets & backgrounds — P9 inventory

Nguồn: 3 pack tải về repo root + Kings and Pigs + Dungeon_pack (đều CC0 / ansimuz royalty-free).
Style: foreground tileset theo world; Gothicvania CHỈ dùng cho nền parallax (ở xa, không lộ tông).

## Foreground tilesets — `game/levels/shared/tilesets/`

| File | Kích thước | Ô | Dùng cho | `.tres` |
|---|---|---|---|---|
| `castle_terrain_32.png` | 608×416 | 32×32 (lưới 19×13) | W2 Lâu Đài — đất/tường | `castle_tileset.tres` |
| `castle_decorations_32.png` | 224×192 | 32×32 (lưới 7×6) | W2 — biểu ngữ, cửa sổ, xích (đặt làm Sprite2D, KHÔNG vào tileset) | — |
| `dungeon_tileset_16.png` | 96×96 | 16×16 (lưới 6×6) | W3 Hầm Ngục — đất/nền chính | `dungeon_tileset.tres` |
| `dungeon_wall_16.png` | 16×16 | 16×16 (1 ô) | W3 — khối tường đặc | (thêm source trong editor) |
| `dungeon_column_16.png` | 128×80 | 16×16 (lưới 8×5) | W3 — cột đá (Sprite2D hoặc source phụ) | (thêm source trong editor) |
| `res://levels/level_1/terrain_tileset.tres` (đã có) | — | 16×16 | W1 Rừng — giữ nguyên | — |

**Cần làm trong Godot editor** (không tạo được bằng code):
1. Mở `castle_tileset.tres` / `dungeon_tileset.tres` → TileSet panel → "Create tiles automatically" cho atlas source.
2. Với mỗi ô đất: vẽ **collision polygon** (Physics Layer 0) — thường ô đặc = hình vuông full, ô dốc/mép = polygon riêng.
3. Gán **Terrain peering bits** (terrain_set_0 "Ground") cho các ô viền để vẽ nhanh bằng terrain brush.
4. `dungeon_wall_16.png` + `dungeon_column_16.png`: Add Atlas Source mới trong cùng `.tres` nếu muốn vẽ chúng qua TileMap; nếu không thì đặt làm Sprite2D lẻ.

## Nền parallax — `game/shared/backgrounds/`

### `sunnyland/` → W1 Rừng  (`forest_parallax.tscn`)
| File | Kích thước | Lớp | motion_scale gợi ý |
|---|---|---|---|
| `forest_back.png` | 384×240 | trời + đồi xa | 0.15 |
| `forest_middle.png` | 176×368 | hàng cây | 0.40 |

### `coldcorridors/` → W2 Lâu Đài  (`castle_parallax.tscn`)
| File | Kích thước | Lớp | motion_scale |
|---|---|---|---|
| `back.png` | 32×224 | tường sâu nhất | 0.10 |
| `far.png` | 32×224 | tường xa | 0.20 |
| `middle.png` | 80×224 | cột/vòm giữa | 0.40 |
| `near.png` | 224×224 | cột gần | 0.65 |
| `foreground.png` | 224×224 | tiền cảnh (phủ trước player nhẹ) | 1.15 |
| `torch-sheet.png` | 128×32 | đuốc động — ~8 frame 16×32 (hoặc 4×32×32), tune trong SpriteFrames panel | — |

### `cemetery/` → W3 Hầm Ngục  (`dungeon_parallax.tscn`)
| File | Kích thước | Lớp | motion_scale | Ghi chú |
|---|---|---|---|---|
| `background.png` | 384×224 | hầm mộ nền | 0.10 | tô tối `modulate ≈ (0.4,0.4,0.5)` |
| `mountains.png` | 192×179 | khối đá xa | 0.25 | tô tối |
| `graveyard.png` | 384×123 | bóng bia mộ dưới | 0.55 | dựng ngược làm trần hang / hoặc bỏ |

## Trang trí lẻ (Sprite2D) — sẽ copy ở P9-1b
- W1: Sunny Land `Props/{tree,pine,bush,rock-1,rock-2,shrooms,sign,small-platform}.png`
- W2: `castle_decorations_32.png` cắt ra + Cold Corridors torch
- W3: `Dungeon_pack/{Metal Torch,candles,Chest_01,Pot,DecorsS,wood_bridge_&_ladder,Gates}.png` + Cemetery `objects.png` (tượng, bia)
