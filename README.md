# Pixel Adventure

Platformer 2D làm bằng [Godot Engine 4.7](https://godotengine.org/). Người chơi chọn nhân vật, vượt chướng ngại vật (gai, cưa, quái tuần tra), thu thập trái cây, qua checkpoint và về đích.

## Yêu cầu

- Godot Engine **4.7.x** (bản Standard, không cần .NET/C#).

## Chạy dự án

1. Mở Godot, chọn **Import**, trỏ tới file `game/project.godot`.
2. Nhấn **F5** (hoặc nút Play) để chạy từ `ui/main_menu/main_menu.tscn`.

## Cấu trúc thư mục

Toàn bộ dự án Godot nằm trong `game/`. Bên trong đó, code/scene/asset được tổ chức **theo tính năng (feature-based)**: mỗi tính năng là một thư mục chứa gần như mọi thứ nó cần (`.tscn`, `.gd`, sprite riêng) thay vì tách riêng `assets/`, `scenes/`, `scripts/` như trước. Mục tiêu: mở một thư mục là thấy đủ để hiểu/sửa tính năng đó, không phải nhảy qua lại giữa nhiều cây thư mục song song.

```
game/
├── project.godot          # cấu hình project, autoload, input map
├── icon.svg                # icon của game
├── core/                   # autoload singletons + logic/data dùng toàn cục
│   ├── game_manager.gd     # autoload "GameManager": điểm, tim, checkpoint, nhân vật đã chọn
│   ├── scene_transition.gd # autoload "SceneTransition": chuyển scene có hiệu ứng
│   └── characters.gd       # class CharacterData: danh sách nhân vật chơi được + đường dẫn sprite/frames
│
├── player/                 # nhân vật người chơi
│   ├── player.tscn / player.gd
│   └── sprites/            # 4 bộ sprite nhân vật (Mask Dude, Ninja Frog, Pink Man, Virtual Guy)
│
├── levels/
│   └── level_1/             # mỗi màn chơi 1 thư mục riêng
│       ├── level_1.tscn / level_1.gd
│       └── terrain_tileset.tres, terrain/   # tileset + sprite địa hình riêng của level này
│
├── objects/                 # các "vật thể" gameplay tái sử dụng được, mỗi cái 1 thư mục
│   ├── fruit/                # fruit.tscn (1 scene duy nhất) + sprites/<loại>_frames.tres cho từng loại quả
│   ├── checkpoint/
│   ├── goal_flag/
│   ├── start_marker/         # cột mốc điểm xuất phát, đặt trong Interactables của level
│   └── enemies/
│       ├── saw/
│       ├── spikes/
│       └── spike_head/
│
├── ui/                       # toàn bộ màn hình UI, mỗi màn hình 1 thư mục
│   ├── main_menu/, pause_menu/, settings_menu/, character_select/, end_screen/, hud/
│   ├── components/icon_toggle/   # component UI tái sử dụng (nút bật/tắt kiểu checkbox)
│   ├── theme/                    # ui_theme.tres (theme toàn cục) + panel/font riêng cho theme
│   └── shared/                   # icon/nút/control dùng chung bởi ≥ 2 màn hình UI (buttons, controls, text)
│
└── shared/
    └── backgrounds/           # ảnh nền dùng chung giữa menu và level
```

### Quy ước khi thêm mới

- **Thêm object gameplay mới** (bẫy, vật phẩm, quái...): tạo thư mục trong `objects/`, đặt `.tscn` + `.gd` + `sprites/` của riêng nó vào đó — kể cả những thứ nhỏ như 1 sprite cắm mốc, không viết node rời trực tiếp trong scene level (xem `objects/start_marker/`).
- **Thêm màn UI mới**: tạo thư mục trong `ui/`, cùng tên với scene. Nếu dùng chung asset với màn khác → để trong `ui/shared/`; nếu chỉ màn đó dùng → để trong `sprites/` ngay trong thư mục của màn.
- **Thêm level mới**: tạo `levels/level_2/` (v.v.), giữ nguyên cấu trúc như `level_1/`.
- Asset chỉ nên nằm ở `shared/` hoặc `ui/shared/` khi thực sự được ≥ 2 tính năng dùng chung — kiểm tra bằng cách grep đường dẫn asset đó trong `*.tscn`/`*.gd` trước khi coi là "dùng chung".
- Autoload (singleton toàn cục) mới → đặt trong `core/`, rồi khai báo trong `project.godot` (mục `[autoload]`).
- Trong scene tree của mỗi level, gom node theo nhóm chức năng thay vì để lẻ tẻ ở gốc: `Interactables` (StartMarker, GoalFlag, Checkpoint...), `Enemies` (Saw, Spikes, EnemySpikeHead...), `Fruits`.

### Animation

`AnimatedSprite2D` trong dự án luôn dùng `SpriteFrames` đã bake sẵn (file `.tres` riêng, sửa được bằng SpriteFrames panel của Godot) — không dựng frame bằng code lúc chạy. Xem quy ước chi tiết trong [CONTRIBUTING.md](CONTRIBUTING.md#animation-animatedsprite2d).

## Điều khiển

| Hành động | Phím |
|---|---|
| Di chuyển | A/D hoặc ←/→ |
| Nhảy (double jump) | Space / W / ↑ |
| Tạm dừng | Esc |

## Đóng góp

Xem [CONTRIBUTING.md](CONTRIBUTING.md) trước khi thêm tính năng mới.
