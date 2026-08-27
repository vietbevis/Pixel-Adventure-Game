# Contributing

Hướng dẫn ngắn gọn để mọi người trong nhóm làm việc trên dự án theo cùng một chuẩn.

## Nguyên tắc cấu trúc thư mục

Xem phần "Cấu trúc thư mục" trong [README.md](README.md). Nguyên tắc cốt lõi: **tổ chức theo tính năng, không theo loại file**. Trước khi tạo file mới, tự hỏi "tính năng này thuộc thư mục nào trong `player/`, `levels/`, `objects/`, `ui/`, `core/`?" thay vì "file này là script hay scene?".

## Quy ước đặt tên

- Thư mục và file: `snake_case` (vd: `enemy_spike_head.gd`, `main_menu.tscn`).
- Tên node trong scene: `PascalCase` (vd: `AnimatedSprite2D`, `CollisionShape2D`).
- Hằng số: `SCREAMING_SNAKE_CASE`. Biến/hàm: `snake_case`.
- Class toàn cục (`class_name`): `PascalCase`, đặt trong `core/` nếu dùng xuyên suốt dự án.

## Script GDScript

- Luôn khai báo kiểu dữ liệu tường minh khi có thể (`var speed: float`, `-> void`) — dễ đọc và Godot báo lỗi sớm hơn.
- Comment chỉ nên giải thích **tại sao**, không giải thích **cái gì** (code đã tự nói lên điều đó). Ví dụ tốt: comment trong `player/player.gd` giải thích lý do cần khoá input sau wall-jump.
- Không hard-code đường dẫn `res://` rải rác nhiều nơi nếu asset đó có khả năng cần đổi tên/di chuyển sau này — cân nhắc gom vào một chỗ như `core/characters.gd` đang làm với sprite nhân vật.

## Scene (.tscn)

- Mỗi object/màn UI có scene gốc trong thư mục riêng của nó (xem cấu trúc trong README).
- Khi một object có nhiều biến thể chỉ khác texture/animation, **không tạo scene riêng cho từng biến thể** — chỉ 1 scene gốc (vd: `fruit.tscn`), mỗi biến thể là 1 file `SpriteFrames` (`.tres`) riêng trong `sprites/`. Nơi cần biến thể cụ thể (level, object khác...) thì instance thẳng scene gốc, rồi set property export (vd: `variant_frames` trên `fruit.gd`) ngay trên **node instance đó** trong Inspector — xem `levels/level_1/level_1.tscn`, các node `Apple1`, `Banana1`... **Không** override property của node con nằm sâu bên trong instance (vd: `AnimatedSprite2D` bên trong) — kiểu override đó không ổn định, Godot editor có thể tự dọn mất khi lưu lại scene.
- Asset (sprite, font...) chỉ dùng bởi một tính năng → để trong `sprites/` của tính năng đó. Asset dùng chung ≥ 2 nơi → `shared/` (toàn cục) hoặc `ui/shared/` (chỉ dùng chung giữa các màn UI).

## Animation (AnimatedSprite2D)

**Luôn bake `SpriteFrames` bằng Godot editor (SpriteFrames panel), không dựng bằng code lúc chạy.** Nếu `AnimatedSprite2D` không có `Sprite Frames` được set sẵn trong scene, Godot sẽ báo "Node Configuration Warning" và người mở scene không xem được animation thật trong editor.

Cách làm chuẩn trong dự án này — mỗi bộ animation là **một file `.tres` riêng** (không nhúng thẳng vào `.tscn`), để mở bằng SpriteFrames panel sửa trực tiếp và tái sử dụng được:

- 1 object có nhiều biến thể chỉ khác hình (trái cây...): chỉ 1 scene gốc (`fruit.tscn`, bake sẵn 1 bộ mặc định để không có warning), mỗi biến thể là 1 file `<ten>_frames.tres` riêng trong `sprites/` của object đó (vd: `objects/fruit/sprites/apple_frames.tres`). Script của object export 1 biến `SpriteFrames` (vd: `variant_frames` trong `fruit.gd`) **với `set()` riêng** (không chỉ áp dụng trong `_ready()`) và đánh dấu `@tool` ở đầu file — để khi gán biến thể trong Inspector, hình đổi ngay trong editor (không cần bấm Play mới thấy đúng). Nơi cần biến thể cụ thể thì set biến này ngay trên node instance — xem `levels/level_1/level_1.tscn`.
- 1 scene cần đổi bộ animation lúc chạy (nhân vật chọn được...): mỗi lựa chọn có file `.tres` riêng (vd: `player/sprites/Mask Dude/mask_dude_frames.tres`), scene bake sẵn 1 bộ mặc định để không bao giờ có warning, code chỉ `load()` rồi gán `sprite.sprite_frames = ...` khi cần đổi — **không** tự dựng `AtlasTexture` bằng vòng lặp trong script. Xem `player/player.tscn` + `player/player.gd` (`_apply_sprite_frames`).

## Collision layers (2D physics)

Đặt tên trong `project.godot [layer_names]`. Dùng ĐÚNG layer cho từng loại node — sai layer là bug khó tìm.

| Bit | Tên | Node ở layer này | `collision_mask` nên trỏ tới |
|---|---|---|---|
| 1 | `world` | terrain TileMapLayer, `moving_platform`, bệ tĩnh | — |
| 2 | `player` | `Player` (CharacterBody2D) | `world` |
| 3 | `enemy` | Enemy body (CharacterBody2D, từ Phase 3) | `world` |
| 4 | `player_hurtbox` | `Hurtbox` con của Player | `enemy_hitbox` |
| 5 | `enemy_hurtbox` | `Hurtbox` con của Enemy | `player_hitbox` |
| 6 | `player_hitbox` | `Hitbox` đòn đánh của Player | — (bị động) |
| 7 | `enemy_hitbox` | `Hitbox` đòn đánh của Enemy + bẫy (gai/cưa) | — (bị động) |
| 8 | `interactable` | checkpoint, goal_flag, fruit, portal, npc | — |

Giá trị số của mask = tổng `1 << (bit-1)`: `world`=1, `player`=2, `player_hurtbox`=8, `player_hitbox`=32, `enemy_hitbox`=64.

## Component tái sử dụng (`components/`)

Pattern: 1 nhiệm vụ = 1 `Node`/`Area2D` con, gắn vào scene, nối qua `@export` (không hard-code trong code).

- **`HealthComponent`** (Node) — máu + i-frame. Thuần logic, không biết Events/UI. Owner nghe signal (`died`, `health_changed`, `invincibility_started`...) và tự forward lên `Events` nếu cần.
- **`Hitbox`** (Area2D) — vùng GÂY sát thương. Bị động (`monitoring=false`), chỉ chứa `damage`/`knockback`. `enable()`/`disable()` trong khung hình tấn công.
- **`Hurtbox`** (Area2D) — vùng NHẬN sát thương. Chủ động: dò `Hitbox` chồng lên → gọi `health_component.damage()`. Gán `health_component` trong Inspector.

## Trước khi mở PR / commit

- Mở project trong Godot editor ít nhất một lần sau khi đổi cấu trúc thư mục, để editor quét lại và tự sửa các cảnh báo (nếu có) — sau đó lưu lại các scene bị đánh dấu "cần lưu lại".
- Không commit thư mục `.godot/` (đã có trong `.gitignore` — đây là cache do editor tự sinh, mỗi máy tự tạo lại).
- Kiểm tra `git status` trước khi `git add` để tránh commit nhầm file rác (`.DS_Store`, file tạm...).

## Thêm một object gameplay mới (ví dụ)

1. Tạo `objects/ten_object/`.
2. Thêm `ten_object.tscn` + `ten_object.gd` trong đó.
3. Nếu có sprite riêng, thêm `objects/ten_object/sprites/`.
4. Instance scene vào level cần dùng (`levels/level_x/level_x.tscn`).

## Thêm một màn hình UI mới (ví dụ)

1. Tạo `ui/ten_man_hinh/`.
2. Thêm `ten_man_hinh.tscn` + `ten_man_hinh.gd`.
3. Icon/nút dùng chung với màn khác → lấy từ `ui/shared/`; asset riêng → `ui/theme/` hoặc thư mục riêng của màn đó.
