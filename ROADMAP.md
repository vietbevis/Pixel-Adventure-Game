# GAME EXPANSION ROADMAP

> Tài liệu này là kết quả Phase 0 (Audit + Architecture). Nó KHÔNG phải task list —
> chỉ code khi bạn xác nhận từng Phase. Xem mục 14 (Next Step).
> Nguồn: audit trực tiếp codebase `game/` tại commit `2e6d232`.

---

## 1. Current Project Audit

### 1.1 Tổng quan kỹ thuật

| Hạng mục | Hiện trạng |
|---|---|
| Engine | Godot 4.7, build Standard (không C#), preset **Mobile**, renderer `mobile` |
| Project root | `game/` (repo root chỉ chứa docs + asset thô) |
| Main scene | `res://ui/main_menu/main_menu.tscn` |
| Stretch | `canvas_items` / `aspect = expand` (đã sẵn sàng cho nhiều tỉ lệ màn hình) |
| Autoload | `GameManager`, `SceneTransition`, `SaveManager` |
| Class toàn cục (`class_name`) | `LevelData`, `CharacterData` |
| Số dòng code | ~640 dòng GDScript, 27 file `.gd`, ~25 scene |
| Test tự động | Không có. Chỉ verify trong editor (F5) |

### 1.2 Từng hệ thống

**Folder structure** — Feature-based, rất sạch. Mỗi feature = 1 folder chứa `.tscn` + `.gd` + `sprites/`. `core/` cho autoload + data class. `shared/` chỉ dùng khi ≥2 feature tham chiếu. Đây là điểm mạnh nhất của project — GIỮ NGUYÊN.

**Player** (`player/player.gd`, 164 dòng) — `CharacterBody2D`, group `"player"`. Một script monolith làm 5 việc: gravity/di chuyển, jump + double jump + wall slide + wall jump (có input-lock chống leo tường vô hạn), máu (`hit()` trừ tim), chết/hồi sinh (`_respawn_at_checkpoint`, chuyển `end_screen`), animation (`_update_animation` bằng chuỗi `play("...")` kèm guard). Đọc thẳng `GameManager.hearts`. Camera là node con của Player (`zoom 2x`, smoothing).

**Enemy** (`objects/enemies/`, 8 loại) — **Tất cả đều là `Area2D`**, không phải body vật lý, không va chạm với terrain. Mỗi loại 1 script độc lập, **không có base class chung**. Hành vi duy nhất: chạm player → `body.hit()`. Không có máu, không nhận sát thương, không có khái niệm "đánh chết quái".
- Traps thuần: `spikes` (tĩnh), `saw` (đung đưa sin), `orbit_saw` (quay quanh tâm), `falling_spike` (FSM 3 trạng thái: HANGING/FALLING/RESETTING).
- "Quái" di chuyển: `spike_head`, `spikes`-patrol, `walker` (patrol move_toward), `flyer` (patrol + bob sin), `chaser_spike` (**FSM IDLE/CHASING/RETURNING + leash** — đây là mầm mống AI duy nhất trong project).
- Logic patrol (`_start`/`_end`/`_moving_forward` + `move_toward`) bị **copy-paste ở ~5 file**.

**Level** (`levels/level_1..5`) — Cả 5 scene **dùng chung 1 script** `level_1.gd`. Script này gánh: set spawn từ `$Interactables/StartMarker` (`_enter_tree`, chạy trước `_ready` của con), refill tim, **đẩy camera limit vào node Camera2D của Player** (coupling ngược), phát hiện rơi khỏi map (`fall_death_y`), sở hữu pause menu. Quy ước cây scene: `Interactables` / `Enemies` / `Fruits`. HUD được instance trong từng level scene.

**UI** (`ui/`) — Các `Control` scene phẳng, nối signal trong `_ready`, điều hướng qua `SceneTransition.goto("res://...")` với **path hardcode**. Có `ui_theme.tres`, component tái sử dụng `IconToggle`. Flow: `main_menu → character_select → level_select → level → end_screen`.

**Save** (`save_manager.gd`) — JSON tại `user://save_data.json`, 3 dict: `completed_levels`, `high_scores`, `best_times`. `is_level_unlocked()` = chuỗi tuyến tính (màn N cần thắng N-1). `record_result()` gọi từ `end_screen`. **SaveManager là nơi DUY NHẤT làm file IO** — đây là điểm tốt, giữ nguyên nguyên tắc này.

**Data / Resource** — `LevelData.LEVELS` (mảng const dict: id/name/scene) là single source of truth cho thứ tự màn. `CharacterData.NAMES` + helper path. `fruit.gd` dùng pattern **`@tool` + `@export var variant_frames: SpriteFrames` có setter** để 1 base scene + 1 `.tres` mỗi biến thể — đây là pattern chuẩn để nhân bản object trong project. Chưa có `Resource` custom nào cho stats.

**Signal / Event system** — **Không có `signal` nào được định nghĩa trong toàn bộ codebase.** Mọi liên lạc là gọi trực tiếp (`body.hit()`, `GameManager.score += 1`) hoặc polling (`hud.gd` đọc `GameManager` mỗi frame trong `_process`). Duck typing qua `has_method("hit")` / `has_method("win")`.

**Input** — 4 action: `move_left`, `move_right`, `jump`, `pause`. Không có `move_down`, `attack`, `dash`, `interact`. Player gọi thẳng `Input.is_action_*`. **Không có lớp abstraction input.**

**Audio** — **Hoàn toàn không có.** Không `AudioStreamPlayer`, không audio bus, không SFX/nhạc. Slider volume trong settings bị `editable = false` (placeholder). Fullscreen toggle không được lưu.

**Camera** — Nằm trên Player. Không có per-room, không shake. Limit đẩy từ level script (brittle).

**Animation** — `SpriteFrames` `.tres` bake sẵn, `AnimatedSprite2D`, gọi `play("string")` với guard thủ công. Fragile nhưng chấp nhận được ở scale hiện tại.

**Mobile** — Preset Mobile + stretch expand đã cấu hình, NHƯNG **không có on-screen control nào** → game hiện tại **không chơi được trên điện thoại**.

### 1.3 Asset đã có sẵn tại repo root (chưa import, dùng được, không tốn tiền)

| Pack | Nội dung hữu ích cho expansion |
|---|---|
| **Kings and Pigs** | King Human (hero có anim **chém kiếm** — dùng cho combat), Pig / King Pig (**boss**), Bomb, Cannon, **Dialogue Boxes**, coins. Rất hợp metroidvania. |
| **Free Smoke Fx Pixel 2** | Particle khói cho dash / tiếp đất / hit-stop |
| **Dungeon_pack** | Tileset + props cho world Cave/Temple (cửa, đòn bẩy, rương, đuốc) |
| `adve/` | Pixel Adventure gốc (backup) |

---

## 2. Current Architecture

```
Autoloads (sống xuyên scene)
├── GameManager      → RUNTIME state: selected_character, current_level_id,
│                       score, hearts, respawn_position/has_checkpoint,
│                       last_result, _elapsed (playtime)
├── SceneTransition  → goto(path): unpause → fade → change_scene → fade. LUÔN dùng cái này.
└── SaveManager      → PERSISTENT state → user://save_data.json (nơi duy nhất làm file IO)

Data classes (class_name, không autoload)
├── LevelData        → LEVELS[] (id/name/scene) + get_index/get_next_id/format_time
└── CharacterData    → NAMES[] + path helper tới SpriteFrames

Scene flow
main_menu → character_select → level_select → level_N.tscn → end_screen
                                    │              │
                                    │              ├── HUD (instance trong level)
                                    │              ├── pause_menu (instance khi bấm pause)
                                    │              └── Player (+ Camera2D con)
                                    └── đọc SaveManager.is_level_unlocked()

Gameplay object contract (duck typing, không có interface)
├── hazard/enemy (Area2D)  → body.hit()      khi body ∈ group "player"
├── goal_flag (Area2D)     → body.win()
├── checkpoint (Area2D)    → GameManager.set_checkpoint(pos)
└── fruit (Area2D)         → GameManager.score += 1
```

**Đánh giá:** Với một platformer tuyến tính 5 màn, architecture này **tốt và cân đối** — đơn giản, dễ đọc, không over-engineer. Vấn đề chỉ xuất hiện khi mở rộng sang combat / ability / metroidvania: những trục đó cần **component tái sử dụng** và **event loose-coupling** mà hiện chưa có.

---

## 3. Missing Systems

| Nhóm | Thiếu |
|---|---|
| Player | Health component tách rời, Hurtbox/Hitbox, attack, dash, ability system, input abstraction |
| Combat | Sát thương 2 chiều, knockback, hit-stop, i-frame có cấu trúc, chết-của-quái |
| Enemy | Base class, state machine tái sử dụng, stats resource, detection component, loot |
| Boss | Toàn bộ (boss base, phase, attack pattern, arena, health bar) |
| Progression | Ability unlock, ability-gated door, currency/collectible ngoài fruit, world/area data |
| Metroidvania | Hub/village, world map, backtrack, secret area, quay lại mở đường cũ |
| NPC / Story | NPC, dialogue (dù pack có sẵn Dialogue Boxes) |
| Save | unlocked_abilities, defeated_bosses, collected_secrets, current_world, settings persistence |
| Mobile | Touch controls, virtual joystick, on-screen buttons, UI scaling pass |
| Audio | Bus, SFX, nhạc, volume settings |
| Event | Event bus / signal hub |
| Polish | Camera shake, hit-stop, particle, achievements, challenge mode |

---

## 4. Technical Debt

Xếp theo mức độ chặn expansion (cao → thấp):

| # | Nợ kỹ thuật | Ảnh hưởng | Đề xuất migration NHỎ NHẤT |
|---|---|---|---|
| D1 | **`player.gd` monolith** — movement + health + death + animation trong 1 file, đọc thẳng `GameManager.hearts` | Chặn dash/combat/ability | Tách thành node con: `HealthComponent`, giữ movement trong `player.gd`, `AnimationController` nhỏ. KHÔNG viết FSM framework. |
| D2 | **Enemy không có base class**, logic patrol copy-paste 5 chỗ, đều là `Area2D` (không nhận damage) | Chặn combat + AI + boss | Tạo `EnemyBase` (`CharacterBody2D`) + 1 helper `patrol/chase`. Giữ traps thuần (`spikes`/`saw`) là `Area2D` — **đừng migrate trap thành enemy**. |
| D3 | **Không có event bus** — HUD polling, gameplay gọi thẳng save/UI | Combat feedback, achievements, quest sẽ phải hardcode phụ thuộc | Thêm 1 autoload `Events` (chỉ chứa `signal`). Trade-off: thêm 1 lớp gián tiếp, đổi lại gỡ hard-dep giữa gameplay ↔ UI/Save. Đáng làm. |
| D4 | **Không có input abstraction** — `player.gd` gọi `Input.is_action_*` trực tiếp | Chặn mobile + rebinding | Thêm action mới vào InputMap + 1 wrapper mỏng `PlayerInput` (đọc axis/nút). Touch dùng `TouchScreenButton.action` map vào cùng action → tích hợp gần như miễn phí. |
| D5 | **`level_1.gd` gánh 5 việc + đẩy camera limit vào Camera2D của Player** | Hub/boss arena cần LevelBase rõ ràng hơn | Đổi tên/format thành `level_base.gd` có `class_name LevelBase`, giữ nguyên hành vi; cân nhắc chuyển camera limit sang `CameraController` con của Level (sau). |
| D6 | **Scene path hardcode trong UI** | Hub + world map cần điều hướng data-driven | Mở rộng `LevelData` thành registry có `world`/`area`; UI đọc từ đó. |
| D7 | `GameManager.start_new_run()` chỉ hợp với "chơi 1 màn từ Level Select" | Progression theo world/hub | Tách rõ Runtime vs Persistent (mục 10), thêm `SaveManager.get_continue_point()`. |
| D8 | Settings không persist, không audio bus | Polish | Phase 10. |
| D9 | `git status`: `level_2.tscn` đang sửa dở, chưa commit | Nhiễu khi bắt đầu | **Commit/clean trước khi bắt đầu Phase 1.** |

---

## 5. Recommended Architecture

Nguyên tắc: **Simple → Modular → Reusable → Maintainable.** Không ECS, không plugin, không FSM framework. Component = `Node` con có 1 nhiệm vụ. Data tinh chỉnh = `Resource` (`.tres`) với `@export`.

### 5.1 Player

```
Player (CharacterBody2D, group "player")
├── HealthComponent (Node)        # hp, max_hp, damage(amount, source), heal(), i-frame
│                                 # signal died, health_changed  ← DÙNG CHUNG với Enemy
├── Hurtbox (Area2D)              # nhận đòn → gọi HealthComponent.damage()
├── Hitbox (Area2D, disabled)    # bật trong frame tấn công → gây damage cho Hurtbox địch
├── MovementController (trong player.gd)  # gravity, walk, jump (giữ code hiện tại)
├── AbilitySystem (Node)          # dict ability đã unlock (query từ SaveManager)
│   └── mỗi ability = 1 script nhỏ hook vào MovementController:
│       DoubleJump, WallJump (refactor từ code hiện có), Dash, (Glide/GroundSlam = sau)
├── AnimationController (Node)    # map trạng thái → tên animation (gỡ chuỗi play() khỏi player.gd)
└── Camera2D                      # giữ nguyên
```

Ability = **cắm/rút được**: unlock = set 1 flag; ability tự đăng ký input handler của mình. Thêm Dash KHÔNG cần sửa logic jump.

### 5.2 Enemy

```
EnemyBase (CharacterBody2D, group "enemy")
├── HealthComponent (Node)        # CÙNG script với Player
├── Hurtbox (Area2D)              # nhận đòn từ Hitbox của Player
├── Hitbox (Area2D)               # chạm player → damage (thay cho body.hit() hiện tại)
├── AI (Node)                     # state machine hand-rolled:
│                                 # idle → patrol → chase → attack → hurt → dead
│                                 # (mở rộng từ pattern chaser_spike.gd đã có)
├── stats: EnemyStats (Resource)  # @export .tres: max_hp, move_speed, damage,
│                                 #   detect_range, leash_range, attack_cooldown
└── DropTable (Node, optional P2) # rơi coin/heal khi chết

Traps (spikes, saw, orbit_saw, falling_spike) → GIỮ NGUYÊN Area2D, KHÔNG migrate.
Chúng là hazard môi trường, không phải "enemy". Chỉ đổi `body.hit()` → dùng
HealthComponent qua Hurtbox để thống nhất đường sát thương.
```

### 5.3 Boss

```
BossBase (extends EnemyBase hoặc riêng, group "boss")
├── HealthComponent + Hurtbox     # tái dùng
├── PhaseController (Node)        # đổi pattern theo % máu (vd 100→60→30)
├── AttackPattern[] (mỗi pattern = 1 script/coroutine: charge, projectile, slam)
└── BossArena (scene)             # khoá lối vào khi bắt đầu, mở khi thắng
UI: boss_health_bar.tscn (nghe Events.boss_health_changed)
```

### 5.4 Data-driven (vừa đủ, không hơn)

| Loại data | Cơ chế | Ví dụ |
|---|---|---|
| Cấu trúc (thứ tự, unlock chain) | `const` array trong class `class_name` | `LevelData`, `WorldData` (mới) |
| Stats tinh chỉnh | `Resource` `.tres` + `@export` | `EnemyStats`, `PlayerStats`, `BossStats` |
| Ability metadata | `Resource` `.tres` | `AbilityData` (id, tên, icon, `unlock_key`) |
| Biến thể chỉ khác sprite | 1 base scene + `@export SpriteFrames` (pattern `fruit.gd` đã có) | enemy skins, collectible types |

**KHÔNG** làm: quest resource graph, item database, dialogue tree resource. Chưa cần.

### 5.5 Event bus

```
Events (autoload, chỉ chứa signal — không logic)
  signal player_damaged(amount)
  signal player_died
  signal enemy_died(enemy, position)
  signal collectible_collected(id, kind)
  signal ability_unlocked(id)
  signal boss_defeated(boss_id)
  signal checkpoint_activated(position)
```
HUD, SaveManager, achievements, quest… **nghe** Events thay vì bị gọi trực tiếp. Gameplay chỉ `emit`, không biết ai nghe.

### 5.6 Input layer

```
InputMap actions:  move_left/right/up/down, jump, attack, dash, interact, pause
        │
PlayerInput (wrapper mỏng — autoload hoặc node con Player)
   move_axis: float,  jump_just_pressed: bool,  attack_pressed: bool, ...
        │
Gameplay (Player, AbilitySystem) đọc PlayerInput, KHÔNG đọc Input trực tiếp

Nguồn vào: Keyboard / Gamepad (qua InputMap) + TouchScreenButton.action (map vào cùng action)
→ mobile "miễn phí" khi PlayerInput đã tồn tại.
```

### 5.7 Những gì GIỮ NGUYÊN (architecture hiện tại đã đúng)

- Feature-based folder layout.
- `SceneTransition.goto()` là cổng đổi scene duy nhất.
- `SaveManager` là nơi duy nhất làm file IO; gameplay query qua API, không đọc file.
- `LevelData` / `CharacterData` kiểu static data class.
- Pattern `@tool` + `@export variant` của `fruit.gd`.
- Pre-baked `SpriteFrames`, không build atlas trong code.
- Group `"player"` + duck typing (chấp nhận được; base class sẽ làm nó typed dần).

---

## 6. Feature Dependency Graph

```
                    ┌─────────────────────────────────────────┐
                    │  P1: HealthComponent + Hurtbox/Hitbox     │  ← NỀN MÓNG
                    │      (dùng chung Player + Enemy)          │
                    └───────────────┬─────────────────────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              ▼                     ▼                     ▼
   ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
   │ P2: Combat        │   │ Event bus (P0)    │   │ Input layer (P0)  │
   │ (player attack)   │   │ (song song)      │   │ (song song)       │
   └────────┬─────────┘   └──────────────────┘   └────────┬─────────┘
            ▼                                              │
   ┌──────────────────┐                                    │
   │ P3: Enemy AI base │                                    │
   │ (patrol/chase/atk)│                                    │
   └────────┬─────────┘                                    │
            ▼                                               │
   ┌──────────────────┐                                     │
   │ P4: Boss          │                                     │
   └────────┬─────────┘                                     │
            ▼                                               │
   ┌──────────────────┐     ┌──────────────────┐            │
   │ P5: Ability System│────▶│ P6: Progression   │           │
   │ + Dash            │     │ + Save expansion  │           │
   └────────┬─────────┘     └────────┬─────────┘            │
            │                        ▼                        │
            │               ┌──────────────────┐             │
            │               │ P7: Hub + World   │             │
            │               │     flow          │             │
            │               └────────┬─────────┘             │
            ▼                        ▼                         │
   ┌─────────────────────────────────────────┐               │
   │ P8: Metroidvania content                 │               │
   │ (dash-gate mở đường cũ, secret area)     │               │
   └─────────────────────────────────────────┘               │
                                                              ▼
                                            ┌──────────────────────────┐
                                            │ P9: Mobile controls       │
                                            │ (cần input layer + các    │
                                            │  action attack/dash tồn tại)│
                                            └──────────────────────────┘

   P10: Audio + Polish        → phụ thuộc lỏng, làm sau cùng
   P11: Achievements/Challenge → cần Event bus + Save; optional
```

Chuỗi bắt buộc theo thứ tự:
```
Health/Hitbox → Combat → Enemy AI → Boss → Ability unlock → Progression/Save → Hub → Metroidvania gating
Checkpoint (đã có) → Save expansion → World progression / Continue
Input layer → Mobile controls
```

---

## 7. Development Phases

> ### ⚠️ ROADMAP REVISION — 2026-08-27 (sau khi hoàn thành P0, P1)
>
> Hai quyết định định hướng từ chủ dự án làm thay đổi thứ tự & nội dung các phase sau:
>
> **A. Thay hệ nhân vật — GIỮ màn chọn nhân vật, mở rộng roster.** 4 nhân vật Pixel Adventure
> (Ninja Frog...) **không có animation tấn công** → không dùng được cho combat. Không xoá màn
> chọn nhân vật; thay bằng roster mới gồm các nhân vật **có đủ moveset + attack**, cùng phong
> cách pixel Pixel Frog (CC0), tải thêm từ itch.io:
> - **King Human** — pack "Kings and Pigs" (ĐÃ CÓ). idle/run/jump/fall/land/hit/**attack(3f)**/dead/**door in-out**. Kiếm, cận chiến.
> - **Captain Clown Nose** — pack "Treasure Hunters" (CẦN TẢI). Kiếm, cận chiến combo. (pack có thể có thêm 1-2 nhân vật dùng được — kiểm sau khi tải.)
> - **Pirate (Bomber)** — pack "Pirate Bomb" (CẦN TẢI). Ném bom, tầm xa.
> Cả 3 pack đều **CC0** (không cần credit), cùng tác giả Pixel Frog → style khớp.
> 4 nhân vật froggy cũ: rút khỏi roster (giữ file, có thể làm skin unlock sau).
> Thiếu double_jump/wall_jump anim ở nhân vật mới → dùng "jump" + VFX (2 skill này là ability
> unlock, không cần anim riêng). Kéo theo: Pig/King Pig thành hệ enemy/boss mới (P3/P4);
> "Live and Coins" (Kings and Pigs) có sẵn heart HUD + diamond collectible + number font.
>
> **B. Mobile là ưu tiên, kéo lên sớm.** Game target Android → cần touch controls để playtest
> trên máy thật ngay sau khi có combat, không đợi tới cuối.
>
> **Thứ tự phase mới từ đây:**
> ```
> P1.5 Hero Migration (King Human)  ← MỚI, chèn trước Combat
>   ↓
> P2  Combat (dùng anim attack thật của King + enemy damage pipeline)
>   ↓
> P2.5 Input Abstraction + Mobile Touch Controls  ← kéo từ P9 lên
>   ↓
> P3  Enemy AI Base + migrate quái sang hệ Pig
>   ↓
> P4 Boss (King Pig) → P5 Dash → P6 Save → P7 Hub (dùng door anim) →
> P8 Metroidvania → P10 Audio/Polish → P11 optional
> ```
> P9 cũ (Mobile) phần lớn gộp vào P2.5; phần còn lại (perf, test đa tỉ lệ) về P10.
> Spec chi tiết P1.5 và P2.5 ở bên dưới; các phase khác giữ nguyên nội dung, chỉ đổi số/thứ tự.

### Phase 0 — Audit & Foundation Skeleton

> **Status:** ✅ DONE — verified in editor (cả 5 màn chạy OK), commit `cfad66b` trên branch `feat/phase-0-foundation`.
> Đã làm: revert `level_2.tscn`; tạo `core/events.gd` + đăng ký autoload; thêm 5 action
> (`move_up/move_down/attack/dash/interact`); rename `level_1/level_1.gd` → `levels/level_base.gd`
> (`class_name LevelBase`) + sửa 5 tscn; cập nhật CLAUDE.md.

**Goal:** Chốt kiến trúc (tài liệu này) + dựng bộ khung an toàn, không đổi gameplay: `Events` autoload, action input mới, dọn git, đổi `level_1.gd` → `level_base.gd`.
**Why:** Mọi Phase sau cắm vào `Events` và input layer. Dựng khung rỗng trước để các Phase sau không phải refactor chéo.
**Dependencies:** Không.
**Features:** `Events` autoload (chỉ signal, chưa ai emit); thêm InputMap action `move_up/move_down/attack/dash/interact`; `class_name LevelBase` cho `level_1.gd` (giữ nguyên logic); commit `level_2.tscn`.
**Architecture Changes:** Thêm 1 autoload. Không đổi gì đang chạy.
**Files affected:** `project.godot` (autoload + input), `core/events.gd` (mới), `levels/level_1/level_1.gd` → rename script file thành `level_base.gd` + `class_name`, cập nhật 5 `level_N.tscn` (đường dẫn script).
**Implementation order:** (1) commit/clean git → (2) `events.gd` + đăng ký autoload → (3) thêm action vào InputMap → (4) rename level script + `class_name` + sửa 5 tscn → (5) mở editor rescan, F5 test 5 màn.
**Acceptance Criteria:** 5 màn chạy y hệt trước; `Events` truy cập được từ console; action mới hiện trong Project Settings; `git status` sạch.
**Testing:** F5 từng màn: đi/nhảy/wall-jump/checkpoint/goal/rơi hố/pause — không regression.
**Risks:** Đổi path script trong `.tscn` sai → màn không load. Mitigation: sửa từng file, test ngay.
**Complexity:** **Low**

---

### Phase 1 — Player Refactor & Shared Health/Damage Component

> **Status:** ✅ DONE — verified in editor, commit `dafc723` trên branch `feat/phase-0-foundation`.
> Đã làm: `components/{health_component,hitbox,hurtbox}.gd`; `[layer_names]` (8 layer) + doc CONTRIBUTING;
> player.gd/tscn dùng `HealthComponent` (hành vi giữ nguyên); walker/flyer/spike_head có HealthComponent+Hurtbox;
> `checkpoint.gd` emit `Events.checkpoint_activated`.
> Hoãn sang P2 (đã thống nhất): AnimationController, migrate collision layer cho node cũ, HUD nghe Events.
> Bonus fix: chặn leo tường vô hạn thật sự (`last_wall_jump_dir` — không wall-jump lại cùng 1 mặt tường tới khi chạm đất/tường đối diện).

**Goal:** Tách `player.gd` thành component; tạo `HealthComponent` + `Hurtbox` + `Hitbox` dùng chung; gắn `HealthComponent` cho enemy (chưa cần combat, chỉ "damageable-ready"). Hành vi player KHÔNG đổi.
**Why:** D1 + D2. Đây là **critical path** — combat, ability, boss, mobile đều cắm vào contract này. Làm sai ở đây = sửa toàn bộ về sau.
**Dependencies:** Phase 0 (Events).
**Features:**
- `HealthComponent` (Node): `max_hp`, `hp`, `damage(amount, source)`, `heal()`, i-frame timer; emit `died`, `health_changed`; forward lên `Events`.
- `Hurtbox` (Area2D) / `Hitbox` (Area2D): cặp component chuẩn, collision layer riêng (player_hurt / enemy_hurt / player_hit / enemy_hit).
- Player: chuyển máu từ `GameManager.hearts` → `HealthComponent` (GameManager giữ `hearts` như mirror để HUD/checkpoint cũ vẫn chạy trong lúc chuyển tiếp).
- `AnimationController` nhỏ: gỡ chuỗi `play()` khỏi `_physics_process`.
- Enemy: gắn `HealthComponent` + `Hurtbox` vào `walker`/`flyer`/`chaser_spike`/`spike_head` (chưa cho chết — chỉ nhận). `body.hit()` giữ nguyên tạm.
**Architecture Changes:** Player từ 1 script → 1 script + 3 node con. Collision layer đặt tên (hiện chưa dùng layer nào).
**Files affected:** `player/player.gd` + `player.tscn`; `core/game_manager.gd` (hearts ↔ HealthComponent); `components/health_component.gd`, `components/hurtbox.gd`, `components/hitbox.gd` (mới, đặt ở `game/components/` hoặc `game/shared/components/`); `ui/hud/hud.gd` (đọc HealthComponent qua Events thay vì poll — hoặc giữ poll tạm); các enemy `.tscn`/`.gd`.
**Implementation order:** (1) 3 component + layer đặt tên → (2) gắn Hurtbox/Health vào Player, giữ `hit()` cũ gọi vào `HealthComponent.damage(1)` → (3) test player mất tim/chết/checkpoint y như cũ → (4) `AnimationController` → (5) gắn Health/Hurtbox vào 4 enemy di chuyển → (6) HUD nghe `Events.health_changed`.
**Acceptance Criteria:** Player mất tim, i-frame nhấp nháy, chết, hồi sinh tại checkpoint, rơi hố — **giống hệt** bản hiện tại. HUD hiển thị đúng. Enemy có `HealthComponent` (kiểm tra bằng debug print).
**Testing:** Regression full 5 màn. Đâm gai liên tục (i-frame), rơi hố nhiều lần, chết không checkpoint → end_screen, chết có checkpoint → hồi sinh.
**Risks:** `hearts` bị lệch giữa GameManager và HealthComponent. Mitigation: 1 chiều duy nhất (HealthComponent là nguồn, GameManager mirror). Await/timer trong `hit()` dễ vỡ khi tách — test kỹ.
**Complexity:** **High**

---

### Phase 1.5 — Multi-Hero Migration  🆕

> **Status:** ✅ DONE — verified in editor (chân sát đất, flip OK, 2 nhân vật chơi được). Commit trên branch `feat/phase-0-foundation`.
> Roster: **King + Captain** (Pixel Frog CC0). Task A montage strip vào `player/sprites/{King,Captain}/`;
> Task B sinh `king_frames.tres` / `captain_frames.tres` (double_jump/wall_jump alias jump); Task C:
> `CharacterData` roster mới + `get_offset/portrait`, `game_manager.selected_character="King"`,
> `player.gd` set `sprite.offset`, `player.tscn` (king_frames, collision 22×36, camera zoom 1.7,
> sprite offset), `character_select` sinh nút từ `NAMES`. 4 froggy giữ folder, rút khỏi NAMES.
> Bomb Guy: để sau P2. Canh chỉnh collision/offset/zoom/movement: làm trong editor (Task D).

**Goal:** Thay roster 4 froggy (không có attack) bằng roster **3 nhân vật có đủ moveset + attack**, cùng style Pixel Frog CC0. **Giữ màn chọn nhân vật.** Player di chuyển/nhảy/wall-jump/mất máu/chết y như hiện tại, chỉ khác sprite + kích thước + roster.
**Why:** Quyết định A. Combat (P2) cần anim attack thật. Tách riêng để verify nhân vật mới đi/nhảy đúng trong 5 màn cũ trước khi chồng combat lên.
**Dependencies:** Phase 1. **Chặn: cần user tải 2 pack** (`Treasure Hunters.zip`, `Pirate Bomb.zip` từ pixelfrog-assets.itch.io) về repo root.
**Roster đề xuất (chốt sau khi inventory file thực tế):**
| # | Nhân vật | Pack | Kiểu combat | Frame size |
|---|---|---|---|---|
| 1 | King Human | Kings and Pigs (có) | Kiếm, cận chiến | 78×58 |
| 2 | Captain Clown Nose | Treasure Hunters (tải) | Kiếm, cận chiến combo | ~cần kiểm |
| 3 | Pirate (Bomber) | Pirate Bomb (tải) | Ném bom, tầm xa | ~cần kiểm |

(Treasure Hunters có thể có thêm Bald Pirate / Cucumber dùng được → tối đa 4-5 nhân vật.)
**Features:**
- Import sprite 3 nhân vật vào `game/player/sprites/<Tên>/`.
- Mỗi nhân vật 1 `<ten>_frames.tres` (SpriteFrames bake editor): idle/run/jump/fall/hit/**attack**/dead (+ land/door nếu có). double_jump/wall_jump → alias sang "jump".
- **Chuẩn hoá kích thước**: các nhân vật khác frame size → thống nhất `CollisionShape2D` chung trên `player.tscn` (~24×40), canh `AnimatedSprite2D.offset` từng bộ frame cho khớp chân.
- `CharacterData` (`core/characters.gd`): `NAMES` = roster mới; `get_frames_path()` giữ nguyên cơ chế. Thêm metadata mỗi nhân vật nếu cần (attack range, sau này).
- `character_select.tscn/.gd`: cập nhật 3-4 nút + preview sprite mới. Giữ nguyên luồng `main_menu → character_select → level_select`.
- `player.gd`: `_apply_sprite_frames()` **giữ nguyên** (load theo `GameManager.selected_character`). `_update_animation` giữ nguyên (nhờ alias anim). Có thể thêm state "attack" ở P2.
- Retune `SPEED`/`JUMP_VELOCITY`/`GRAVITY` nếu cần cho nhân vật to hơn — canh editor, giữ tỉ lệ jump-height/gap.
- 4 froggy cũ: xoá khỏi `NAMES`, **giữ folder sprite** (skin unlock tương lai).
- (Có thể để P10) HUD heart → `Big Heart (18x14)` của pack Kings and Pigs.
**Architecture Changes:** Không. `CharacterData.NAMES` đổi nội dung; player.tscn dùng 1 collision chung, offset per-frameset.
**Files affected:** `game/player/sprites/<3 nhân vật>/` (mới), `player/player.tscn` (+ có thể `player.gd` retune), `core/characters.gd`, `ui/character_select/character_select.tscn` + `.gd`, repo root (2 zip user tải + giải nén).
**Implementation order:** (0) user tải 2 pack → (1) inventory file, chốt roster + frame layout → (2) import sprite, bake 3 `.tres` (tôi tạo region, user chỉnh speed/loop editor) → (3) `CharacterData.NAMES` + player.tscn collision chung + offset → (4) F5 test từng nhân vật ở vài màn → (5) retune movement nếu cần → (6) `character_select` UI mới → (7) full regression 5 màn × mỗi nhân vật (spot check).
**Acceptance Criteria:** Chọn được mỗi nhân vật ở màn chọn; mỗi nhân vật đi/chạy/nhảy/double jump/wall jump (không leo vô hạn)/mất tim/i-frame/chết/respawn/goal ở các màn, không kẹt địa hình, camera hợp lý. Không lỗi đỏ.
**Testing:** Mỗi nhân vật: 1 lượt xuyên màn 1 + spot check màn 5 (khe hẹp, wall-jump). Flow menu đầy đủ. Preview ở character_select đúng sprite.
**Risks:**
| Risk | Mitigation |
|---|---|
| Nhân vật to hơn kẹt địa hình 5 màn (thiết kế cho 32px) | Collision chung nhỏ gọn ~24×40; test từng màn; ghi chỗ cần sửa (làm ở P7/P8) |
| 3 pack frame size khác nhau → canh offset lệch | 1 collision chung, chỉnh `AnimatedSprite2D.offset` per-frameset trong editor |
| `_frames.tres` viết tay sai region | Tôi tính region cẩn thận; user verify + set speed/loop trong SpriteFrames panel |
| Bomber (tầm xa) khác hẳn 2 nhân vật kiếm → P2 combat phức tạp | P1.5 chỉ lo di chuyển/anim; nếu Bomber làm P2 phức tạp → tạm cho attack đơn giản, hoàn thiện sau |
| License | Cả 3 pack Pixel Frog đều CC0 — an toàn thương mại, không cần credit |
**Complexity:** **Medium-High**

---

### Phase 2 — Combat (Player Attack)

> **Điều chỉnh (revision):** mỗi nhân vật roster mới có anim **attack** thật → dùng nó + AnimatedSprite `frame_changed` để bật/tắt Hitbox theo frame (thay slash placeholder). Nhân vật Bomber: attack = spawn projectile bom (có thể làm bản đơn giản trước). Gộp luôn migrate collision layer + gỡ `body.hit()` (hoãn từ P1). Knockback vị trí cho enemy vẫn hoãn → P3. Hit-stop tối giản: làm ở P2.
>
> **Phase 2a (pipeline migration):** ✅ DONE — verified. `hurtbox.gd` nhận Area2D thường + tự tìm `HealthComponent` anh em nếu export null; migrate collision layer (player→2/1, enemy+trap→layer 64 mask 0, checkpoint/goal/fruit→8/2, moving_platform→1/0, falling_spike DetectZone→mask 2); gỡ `body_entered→body.hit()` khỏi 6 script quái/bẫy; xoá `spikes.gd`; `player.gd` connect `hurtbox.hurt`→`_on_hurt`. (Bug: `monitoring=false` trên Area2D quái chặn cả việc bị detect → đã bỏ.)
> **Phase 2b (combat feel):** ✅ DONE — verified. `hitbox.gd` chủ động (`monitoring`, mask `enemy_hurtbox`, signal `hit_landed`); `player.gd` attack (phím J → `_start_attack` → đặt Hitbox theo `facing`, bật/tắt theo `frame_changed`/`animation_finished`) + hit-stop `Engine.time_scale`; `CharacterData` thêm `attack_reach`/`attack_damage`; `enemy_hit_reaction.gd` (flash + death pop + `Events.enemy_died`) gắn vào walker/flyer/spike_head; `scene_transition` reset `time_scale`.
>
> **Phase 2 (2a + 2b) HOÀN THÀNH.**

**Goal:** Player chém được; enemy nhận sát thương, hurt/knockback, chết; contact damage enemy→player chuyển qua Hitbox.
**Why:** Vòng lặp "Fight" trong gameplay loop. Không có combat thì metroidvania vô nghĩa.
**Dependencies:** Phase 1.
**Features:** attack input + animation (dùng anim kiếm của **King Human** trong pack Kings and Pigs, hoặc hiệu ứng slash tạm); `Hitbox` player bật/tắt theo frame anim (`AnimationPlayer` call method track, KHÔNG hardcode timer); enemy `HealthComponent.died` → anim chết + `queue_free` + `Events.enemy_died`; knockback 2 chiều; hit-stop nhẹ (freeze frame ~0.05s); combo 2-3 đòn (optional).
**Architecture Changes:** Không (cắm vào component P1).
**Files affected:** `player.tscn`/`player.gd` (attack state), `components/hitbox.gd`, enemy base/scripts (`died` handler), `objects/enemies/*` chuyển `body.hit()` → Hitbox contact; có thể thêm `player/sprites` cho anim attack.
**Implementation order:** (1) attack input + anim + Hitbox toggle → (2) enemy chết khi hết máu → (3) knockback → (4) enemy Hitbox contact thay `body.hit()` → (5) hit-stop + particle (khói pack).
**Acceptance Criteria:** Chém 2-3 phát chết `walker`; enemy đẩy lùi khi trúng; player vẫn mất tim khi chạm enemy; traps vẫn hoạt động qua đường Hurtbox.
**Testing:** Chém từng loại enemy; chém hụt; bị đánh trong lúc chém; chém gần mép vực (không văng ra map).
**Risks:** Hitbox/Hurtbox layer sai → chém trúng chính mình hoặc không trúng ai. Frame timing anim attack lệch.
**Complexity:** **Medium**

---

### Phase 3 — Enemy AI Base + Pig Migration

> **Điều chỉnh (revision):** gộp việc thay hệ quái sang **Pig family** ("Kings and Pigs": Pig 34×28, Pig Throwing Box, Pig Throwing Bomb, Pig With a Match — đều có full moveset idle/run/jump/fall/hit/attack/dead). Quái Kenney trừu tượng (walker/flyer) + spike_head bị thay bằng Pig khi lên `EnemyBase`. Knockback vị trí thật làm ở đây (enemy đã là CharacterBody2D). Traps (spikes/saw) giữ nguyên.

**Goal:** `EnemyBase` (`CharacterBody2D`) + state machine tái sử dụng (idle/patrol/chase/attack/hurt/dead), `EnemyStats` resource; hệ quái mới dựa trên sprite Pig; knockback thật.
**Why:** D2. Gỡ copy-paste patrol, cho enemy "phản ứng" (điều kiện tiên quyết của boss).
**Dependencies:** Phase 2.
**Features:** `EnemyBase` (`CharacterBody2D`, gravity cho enemy mặt đất, fly cho `flyer`); FSM hand-rolled (mở rộng pattern `chaser_spike`); `EnemyStats.tres` mỗi loại; `DetectionArea` component; attack telegraph đơn giản.
**Architecture Changes:** Enemy: `Area2D` → `CharacterBody2D` (cho loại di chuyển). Cần thêm collision với terrain layer.
**Files affected:** `objects/enemies/enemy_base.gd` + `.tscn` (mới); `components/enemy_stats.gd`; refactor 4 enemy folder; các `level_N.tscn` (enemy instance có thể cần chỉnh vị trí do đổi từ Area2D sang body).
**Implementation order:** (1) `EnemyBase` + FSM skeleton + `EnemyStats` → (2) migrate `walker` (đơn giản nhất) → (3) `chaser_spike` (đã có FSM) → (4) `flyer` (biến thể fly) → (5) `spike_head` → (6) attack state (lao vào / nhảy).
**Acceptance Criteria:** 4 enemy patrol/chase/attack/hurt/die qua cùng 1 base; đứng trên terrain đúng (không lọt); `EnemyStats` chỉnh trong Inspector đổi hành vi.
**Testing:** Mỗi enemy trong mỗi màn có nó; enemy rơi khỏi mép platform; nhiều enemy cùng chase; enemy + moving_platform.
**Risks:** Đổi Area2D→CharacterBody2D làm lệch vị trí/va chạm trong 5 màn cũ → regression level design. Mitigation: migrate + test từng màn.
**Complexity:** **High**

---

### Phase 4 — Boss

**Goal:** 1 boss hoàn chỉnh: `BossBase`, 2-3 attack pattern, 2 phase theo máu, boss arena, health bar UI, `Events.boss_defeated`.
**Why:** Điểm nhấn cuối mỗi world; trigger unlock ability (gameplay loop: Boss → Reward).
**Dependencies:** Phase 3.
**Features:** dùng **King Pig** (Kings and Pigs pack); pattern: charge, ném bom (pack có Bomb + anim "Pig Throwing a Bomb"), slam; `PhaseController`; `BossArena` khoá cửa vào; `boss_health_bar.tscn`; nhạc boss (placeholder tới P10).
**Architecture Changes:** Không (mở rộng EnemyBase).
**Files affected:** `objects/bosses/king_pig/` (mới), `levels/boss_forest/` (arena scene), `ui/boss_health_bar/`, `core/events.gd` (dùng `boss_defeated`), `SaveManager` (`defeated_bosses` — hoặc để P6).
**Implementation order:** (1) BossBase + 1 pattern + health bar → (2) pattern 2,3 → (3) PhaseController → (4) arena khoá/mở cửa → (5) death sequence + `boss_defeated`.
**Acceptance Criteria:** Đánh boss qua 2 phase, boss đổi pattern, thắng → cửa mở + event bắn; thua → về checkpoint/end_screen như thường.
**Testing:** Thắng, thua, thoát arena giữa chừng (không được), pause giữa fight, chết boss đúng lúc đổi phase.
**Risks:** Attack pattern dùng nhiều `await`/coroutine dễ vỡ khi pause/chết. State cleanup.
**Complexity:** **High**

---

### Phase 5 — Ability System & Dash

**Goal:** `AbilitySystem` component; `AbilityData` resource; Dash là ability đầu tiên; refactor double-jump + wall-jump thành ability module để nhất quán; wire `boss_defeated` → unlock.
**Why:** Trục metroidvania. "Unlock Ability" trong gameplay loop.
**Dependencies:** Phase 1 (component player), Phase 4 (trigger unlock — nhưng dash có thể dev-unlock sớm để test).
**Features:** `AbilitySystem` giữ dict `{ability_id: bool}` query từ `SaveManager`; mỗi ability = script nhỏ (`can_activate`, `activate`, hook input); Dash (dài cố định, cooldown, i-frame ngắn tùy chọn, particle khói); double-jump/wall-jump chuyển thành module (giữ hằng số hiện tại).
**Architecture Changes:** Movement trong `player.gd` expose hook cho ability (velocity override có kiểm soát).
**Files affected:** `player/abilities/` (mới: `ability_system.gd`, `dash.gd`, `double_jump.gd`, `wall_jump.gd`), `player.gd` (bỏ inline double/wall jump), `components/ability_data.gd`, `SaveManager` (`is_ability_unlocked`).
**Implementation order:** (1) `AbilitySystem` + `AbilityData` + dev-unlock all → (2) Dash → (3) migrate double-jump → (4) migrate wall-jump → (5) `SaveManager.is_ability_unlocked` + `boss_defeated` → unlock Dash → (6) `Events.ability_unlocked` + toast UI.
**Acceptance Criteria:** Chưa thắng boss → không dash được; thắng → dash hoạt động, còn sau khi tắt/mở game (persist); double/wall jump y như cũ.
**Testing:** Dash trên đất/trên không/vào tường/qua vực; dash + attack; wall-jump vẫn không leo vô hạn; save/load giữ unlock.
**Risks:** Refactor wall-jump (code tinh vi chống leo tường) dễ gây regression. Mitigation: giữ nguyên hằng số + logic, chỉ đổi chỗ chứa.
**Complexity:** **Medium-High**

---

### Phase 6 — Progression & Save Expansion

**Goal:** Mở rộng `SaveManager`: `unlocked_abilities`, `defeated_bosses`, `collected_secrets`, `current_world`, `coins` (nếu dùng). `WorldData`. Dash-gate / ability-gated door. Hỗ trợ "Continue".
**Why:** Tách rõ Runtime vs Persistent; nền cho hub + backtrack.
**Dependencies:** Phase 5.
**Features:** JSON mới (giữ tương thích ngược — load thiếu key thì default); `WorldData.WORLDS[]` (id, name, levels[], boss); `AbilityGate` object (Area2D chặn, mở nếu `is_ability_unlocked`); `SaveManager.get_continue_point()`.
**Architecture Changes:** `GameManager` (Runtime) vs `SaveManager` (Persistent) — chốt ranh giới (mục 10). Gameplay query API, không chạm file.
**Files affected:** `core/save_manager.gd`, `core/game_manager.gd`, `core/world_data.gd` (mới), `objects/ability_gate/` (mới), `ui/level_select` (đọc WorldData).
**Implementation order:** (1) mở rộng save schema + migration an toàn → (2) `WorldData` → (3) `AbilityGate` → (4) `get_continue_point` + nút Continue ở main menu.
**Acceptance Criteria:** Save cũ vẫn load; unlock ability/boss persist; dash-gate mở đúng theo trạng thái; Continue vào đúng world.
**Testing:** Xóa save → chạy mới; save cũ format → không crash; unlock rồi tắt game → vẫn còn; gate khóa/mở.
**Risks:** Migration save. Mitigation: mọi `get(key, default)`, không giả định key tồn tại.
**Complexity:** **Medium**

---

### Phase 7 — Hub & World Flow

**Goal:** Hub scene (village) đi bộ được, có portal vào world, ≥1 NPC (thoại tĩnh), bảng ability đã unlock. Restructure flow: `character_select → hub → world → level`. Repurpose 5 màn hiện có thành World 1 (Forest ×3) + World 2 (Cave ×2).
**Why:** "Hub/Village" trong định hướng. Trung tâm của vòng lặp explore.
**Dependencies:** Phase 6.
**Features:** `hub.tscn` (reuse `LevelBase` + player), `Portal` object (`Area2D` + `interact` → `SceneTransition.goto`), `NPC` (Area2D + `interact` → hộp thoại 1-2 dòng dùng **Dialogue Boxes** pack), map lại `LevelData`/`WorldData` cho 2 world + boss.
**Architecture Changes:** `level_select` giữ lại như "fast travel" hoặc bỏ; hub là entry chính. `GameManager.start_new_run` → tách `start_level(id)` khỏi `enter_hub()`.
**Files affected:** `levels/hub/` (mới), `objects/portal/`, `objects/npc/`, `ui/dialogue/` (mới, tối giản), `core/game_manager.gd`, `ui/level_select` hoặc thay bằng hub.
**Implementation order:** (1) hub scene + player + camera → (2) Portal → 1 world → (3) restructure LevelData thành world → (4) NPC + dialogue tối giản → (5) return-to-hub sau khi thắng level/boss.
**Acceptance Criteria:** Đi từ hub → world 1 → thắng → về hub; portal world 2 khóa tới khi qua world 1; NPC nói được.
**Testing:** Mọi portal; vào/ra hub nhiều lần; pause trong hub; save ở hub → Continue về hub.
**Risks:** Flow scene rối (nhiều entry point). Mitigation: vẽ sơ đồ flow trước khi code.
**Complexity:** **Medium-High**

---

### Phase 8 — Metroidvania Content

**Goal:** Đặt dash-gate trong màn cũ để mở đường/secret area mới; 1-2 secret area có collectible; phần thưởng backtrack.
**Why:** "Quay lại khu vực cũ" — thứ khiến nó là metroidvania chứ không phải platformer có hub.
**Dependencies:** Phase 5 (dash) + Phase 7 (hub để backtrack).
**Features:** 2-3 vị trí dash-gate (vd khe rộng, tường nứt) trong World 1; 1-2 secret room + collectible mới (dùng coin/gem pack); HUD đếm collectible; reward = coin / heart container / cosmetic.
**Architecture Changes:** Không (dùng `AbilityGate` P6 + collectible theo pattern `fruit.gd`).
**Files affected:** `levels/level_1..3` (thêm gate + secret room vào tscn), `objects/collectible_secret/` (mới), `ui/hud`.
**Implementation order:** (1) 1 collectible type + persist → (2) 1 secret room sau dash-gate ở level 1 → (3) nhân rộng 2-3 chỗ → (4) HUD counter + reward.
**Acceptance Criteria:** Trước khi có dash không vào được secret; sau dash quay lại vào được; collectible đếm + persist; thu hết → reward.
**Testing:** Vào secret khi chưa/đã có dash; nhặt collectible rồi tắt game; nhặt 2 lần (không tăng đôi).
**Risks:** Sửa 5 tscn màn cũ (đang share script) — cẩn thận camera limit / bố cục.
**Complexity:** **Medium**

---

### Phase 2.5 — Input Abstraction + Mobile Touch Controls  🆕 (kéo từ P9 lên)

> Nội dung như "Phase 9" cũ bên dưới, nhưng làm ngay sau Combat để playtest Android sớm.

**Goal:** `PlayerInput` wrapper; on-screen touch controls (virtual joystick/dpad + Jump + Attack + Pause; ô Dash để trống, nối ở P5); tự hiện trên touch device + toggle trong settings; pass UI scaling / safe-area; export APK thử.
**Why:** Quyết định B — game target Android, cần chơi được trên máy thật ngay khi có combat.
**Dependencies:** Phase 2 (action `attack` đã final; `jump`/`move_*` có từ P0).
**Features:** `core/player_input.gd` (đọc InputMap → property: `move_axis`, `jump_pressed`, `attack_pressed`...); `player.gd` chuyển `Input.is_action_*` → `PlayerInput.*`; `ui/touch_controls/` (CanvasLayer, `TouchScreenButton.action` map vào cùng InputMap action → keyboard/gamepad không đổi); auto-show theo `DisplayServer.is_touchscreen_available()`; `Input.emulate_touch_from_mouse` để test trên PC; settings toggle + persist; kiểm 16:9 / 18:9 / 20:9 + notch.
**Architecture Changes:** `player.gd` đọc `PlayerInput` thay vì `Input` trực tiếp. Abilities (P5) theo cùng pattern.
**Files affected:** `core/player_input.gd` (mới), `player/player.gd`, `ui/touch_controls/*` (mới), `ui/settings_menu/*`, `SaveManager` (settings), `project.godot` (đăng ký `PlayerInput` autoload nếu chọn hướng đó).
**Implementation order:** (1) `PlayerInput` + chuyển player sang dùng nó (regression) → (2) `TouchControls` scene (joystick + Jump + Attack + Pause) → (3) auto-show + emulate-from-mouse → (4) settings toggle + persist → (5) UI scaling/safe-area pass → (6) export APK, test máy thật.
**Acceptance Criteria:** Chơi hết 1 màn chỉ bằng touch (di chuyển + nhảy + chém đồng thời OK); keyboard/gamepad giữ nguyên; nút không che vùng chơi; APK chạy được trên Android.
**Testing:** APK máy thật/emulator; đa điểm chạm; xoay ngang; pause bằng nút touch; toggle tắt touch trên desktop.
**Risks:** Nút overlap vùng chơi; joystick analog + `move_and_slide`; perf mobile renderer; input lag.
**Complexity:** **Medium**

---

### Phase 9 — Input Abstraction & Mobile Controls

> **Đã kéo lên thành Phase 2.5** (xem trên). Phần còn lại ở đây (tối ưu perf mobile, test đa thiết bị/tỉ lệ sâu, gamepad polish) gộp vào **P10**.

**Goal:** `PlayerInput` wrapper hoàn chỉnh; on-screen controls (joystick/dpad + jump + attack + dash + interact + pause); tự hiện trên touch device + toggle trong settings; pass UI scaling / safe area.
**Why:** Game target Android. Đây là MVP, không phải optional.
**Dependencies:** Phase 5 (dash + attack action đã final).
**Features:** `PlayerInput` (đọc InputMap → property), gameplay chuyển sang đọc wrapper; `TouchControls` CanvasLayer với `TouchScreenButton.action` map vào cùng action; `Input.emulate_touch_from_mouse` để test trên PC; settings toggle "Touch controls" + lưu; kiểm tra aspect 16:9 / 18:9 / 20:9, notch safe area.
**Architecture Changes:** `player.gd` + abilities: `Input.is_action_*` → `PlayerInput.*`. (Nếu làm D4 sớm ở P0 thì đây chỉ là hoàn thiện.)
**Files affected:** `core/player_input.gd` (mới), `player.gd`, `player/abilities/*`, `ui/touch_controls/` (mới), `ui/settings_menu`, `SaveManager` (settings).
**Implementation order:** (1) `PlayerInput` + chuyển player/abilities sang dùng nó (regression test) → (2) `TouchControls` scene → (3) auto-show theo `DisplayServer.is_touchscreen_available()` → (4) settings toggle + persist → (5) test tỉ lệ màn hình + export Android thử.
**Acceptance Criteria:** Chơi hết 1 world chỉ bằng touch; keyboard/gamepad vẫn nguyên; nút không che gameplay; xoay ngang OK.
**Testing:** Export APK chạy máy thật/emulator; đa điểm chạm (di chuyển + nhảy + chém đồng thời); pause bằng nút touch.
**Risks:** Touch button overlap vùng chơi; `move_and_slide` + input analog joystick; performance mobile renderer.
**Complexity:** **Medium**

---

### Phase 10 — Audio & Polish

**Goal:** Audio bus (Master/Music/SFX) + SFX + nhạc + volume persist + fullscreen persist; camera shake; hit-stop; particle (khói); polish transition.
**Why:** Ưu tiên #6 (Polish). Chất lượng demo/present.
**Dependencies:** Lỏng — làm sau cùng.
**Features:** `AudioManager` autoload (play SFX theo tên, đổi nhạc theo world, nghe `Events`); bus layout `.tres`; SFX: jump, land, hit, hurt, collect, death, dash, boss; nhạc mỗi world + boss + hub; `settings_menu` bật lại volume slider (đang `editable=false`); `CameraShake` component; particle từ **Free Smoke Fx Pixel 2**.
**Architecture Changes:** Thêm 1 autoload `AudioManager`; audio phản ứng qua `Events` (không cần gameplay gọi trực tiếp).
**Files affected:** `core/audio_manager.gd`, `audio/` (buses + import), `ui/settings_menu.gd` (volume + persist), `SaveManager` (settings), `player/camera` (shake).
**Implementation order:** (1) bus + AudioManager + 1 SFX → (2) nối `Events` → SFX → (3) nhạc theo world → (4) volume/fullscreen persist → (5) shake + hit-stop + particle.
**Acceptance Criteria:** Mọi hành động chính có SFX; nhạc đổi theo khu; chỉnh volume + tắt/mở game vẫn giữ; không tụt FPS trên mobile.
**Testing:** Mute/unmute; nhiều SFX cùng lúc; chuyển scene khi nhạc đang phát.
**Risks:** Thiếu asset audio (pack không có nhạc) → cần nguồn CC0 ngoài (đánh giá license). Spam SFX.
**Complexity:** **Medium**

---

### Phase 11 — Optional Replayability

**Goal:** Achievements; challenge/time-attack mode.
**Why:** Tăng giá trị chơi lại. Optional — bỏ được nếu thiếu thời gian.
**Dependencies:** Event bus (P0) + Save (P6).
**Features:** `AchievementData` resource + `AchievementManager` (nghe `Events`, set flag, toast); challenge mode = màn có timer target + leaderboard local (best_times đã có sẵn hạ tầng).
**Architecture Changes:** Không.
**Files affected:** `core/achievement_manager.gd`, `data/achievements/`, `ui/achievements/`, `ui/challenge_select/`.
**Implementation order:** (1) AchievementManager + 3 achievement → (2) toast UI → (3) màn achievements → (4) challenge mode (nếu còn thời gian).
**Acceptance Criteria:** Đạt điều kiện → unlock + persist + toast; challenge mode chấm giờ.
**Testing:** Trigger từng achievement; đã unlock không trigger lại.
**Risks:** Scope creep. Giữ ≤ 8 achievement.
**Complexity:** **Low-Medium**

---

## 8. MVP Scope

> Mục tiêu MVP: **"platformer có hub + combat + 1 ability mở đường + 2 world + boss + chơi được trên Android"** — một vòng lặp gameplay hoàn chỉnh, demo được.

| Trong MVP | Phase |
|---|---|
| Foundation skeleton (Events, input actions) | P0 |
| Player component refactor + HealthComponent/Hurtbox/Hitbox | P1 |
| Melee combat (player chém, enemy chết, knockback) | P2 |
| Enemy AI base — 3-4 enemy (patrol + chase + attack + die) | P3 |
| 1 boss (King Pig), 2 phase, arena | P4 |
| Ability system + **Dash**, unlock bởi boss, persist | P5 |
| Save expansion (abilities, boss, world, continue) | P6 |
| Hub tối giản (đi bộ được, portal, 1 NPC), 2 world từ 5 màn cũ | P7 |
| **1 dash-gate mở đường/secret cũ** (chứng minh vòng metroidvania) | P8 (rút gọn) |
| Touch controls + input abstraction | P9 |
| SFX cơ bản + nhạc + volume/fullscreen persist | P10 (rút gọn) |

## 9. P1 / P2 / P3 Scope (post-MVP)

**Version 1.1 (nên có):**
- Hub village đi bộ đầy đủ + 2-3 NPC + dialogue nhiều dòng
- Ability thứ 2 (Glide **hoặc** Ground Slam — chọn 1)
- 2-3 secret area + collectible counter + reward (heart container)
- World map screen riêng
- World 2 boss
- Camera shake + hit-stop + particle polish đầy đủ

**Version 1.2 (nâng cao):**
- World 3 (Temple) + Final Boss
- Achievements (P11)
- Challenge / time-attack mode (P11)
- Thêm enemy types (Cannon, Pig throwing box)
- Coin economy + upgrade nhẹ (heal, +damage)

**Nice-to-have (bỏ được):**
- Dialogue có portrait / branching
- Ability riêng theo từng nhân vật
- Parallax background nhiều lớp, weather
- Controller rumble, gamepad UI navigation polish
- Localization (hiện Việt hardcode)

---

## 10. Priority Matrix

| Feature | Impact | Complexity | Priority | Dependency |
|---|---|---|---|---|
| Events autoload | High | Low | **P0** | — |
| Input actions (attack/dash/up/down) | High | Low | **P0** | — |
| HealthComponent + Hurtbox/Hitbox | Very High | High | **P0** | Events |
| Player component refactor | High | High | **P0** | Health component |
| Melee combat | Very High | Medium | **P0** | P1 |
| Enemy AI base + FSM | High | High | **P0** | Combat |
| Dash ability | Very High | Medium | **P0** | Player refactor |
| Ability system (khung) | High | Medium | **P0** | Player refactor |
| 1 Boss | High | High | **P0** | Enemy AI |
| Save expansion (Runtime/Persistent) | High | Medium | **P0** | Ability + Boss |
| Ability-gated door / dash-gate | High | Low | **P0** | Dash + Save |
| Hub (tối giản) | High | Medium | **P0** | Save |
| Touch controls + input abstraction | Very High (Android) | Medium | **P0** | Dash/attack final |
| Reuse 5 màn → 2 world | High | Low | **P0** | WorldData |
| SFX + nhạc + volume persist | Medium | Medium | **P1** | Events |
| NPC + dialogue tối giản | Medium | Low | **P1** | Hub |
| Secret area + collectible | Medium | Medium | **P1** | Dash-gate + Hub |
| Ability #2 (glide/slam) | Medium | Medium | **P1** | Ability system |
| World map screen | Medium | Low | **P1** | WorldData |
| World 2 boss | Medium | High | **P1** | Boss base |
| Camera shake / hit-stop | Medium | Low | **P1** | Combat |
| Hub village đi bộ đầy đủ | Medium | Medium | **P2** | Hub tối giản |
| Coin economy + upgrade | Low-Medium | Medium | **P2** | Save + collectible |
| World 3 + Final Boss | Medium | High | **P2** | 2 world hoạt động |
| Achievements | Low-Medium | Low | **P2** | Events + Save |
| Challenge / time-attack | Low | Medium | **P3** | best_times (đã có) |
| Quest system | Low | High | **P3** | — (KHÔNG làm, xem mục 13) |
| Dialogue branching / portrait | Low | Medium | **P3** | Dialogue |
| Inventory / item system | Low | High | **P3** | — (KHÔNG làm) |
| Per-character unique ability | Low | Medium | **P3** | Ability system |

---

## 11. Critical Path

Các quyết định/feature mà **làm sai sẽ kéo theo refactor toàn hệ thống**:

1. **HealthComponent + Hurtbox/Hitbox contract (P1)** — Player, mọi Enemy, Boss, traps, ability i-frame, HUD, achievements đều cắm vào đây. Đặt sai collision layer / sai signal shape = sửa mọi thứ. **Dành thời gian thiết kế cặp component này nhiều nhất.**
2. **Collision layer naming (P1)** — hiện project không dùng layer nào. Chốt bảng layer (world / player_body / player_hurt / player_hit / enemy_body / enemy_hurt / enemy_hit / interactable / gate) NGAY ở P1 và ghi vào CONTRIBUTING.
3. **Runtime vs Persistent boundary (P6, nhưng nghĩ từ P1)** — `GameManager` = runtime, `SaveManager` = persistent, gameplay query qua API. Nếu để gameplay đọc file save trực tiếp → không test được, không migrate được.
4. **AbilitySystem hook vào MovementController (P5)** — nếu ability sửa thẳng `player.gd` thay vì qua hook, thêm ability thứ 3-4 sẽ phá jump/dash. Interface `activate()/can_activate()` phải sạch từ Dash.
5. **Event bus shape (P0)** — đổi signature signal về sau = sửa mọi listener. Định nghĩa đủ signal ngay từ đầu (thừa còn hơn thiếu).
6. **Enemy Area2D → CharacterBody2D (P3)** — chạm tới level design 5 màn cũ. Migrate + test từng màn, đừng làm hàng loạt.

---

## 12. Recommended Final Scope

**Một game demo-được, vòng lặp hoàn chỉnh, ~2 world:**

```
Hub (village, đi bộ, 1-2 NPC, portal)
 ├── World 1 — Forest   : 3 level (repurpose level_1,2,3) + Boss (King Pig)
 │                         → thắng boss: unlock DASH
 ├── World 2 — Cave     : 2 level (repurpose level_4,5) + Boss
 │                         → thắng boss: unlock ability #2 (v1.1)
 └── Backtrack: 1-3 dash-gate ở Forest → secret area + collectible
```

- **Combat:** melee 1 vũ khí, 4 enemy types + 2 boss
- **Ability:** Dash (MVP) + 1 nữa (v1.1). Double/wall jump đã có → chuyển thành module.
- **Progression:** boss → ability → mở đường cũ → secret → world tiếp theo
- **Save:** completed_levels, high_scores, best_times (đã có) + unlocked_abilities + defeated_bosses + collected_secrets + current_world + settings
- **Mobile:** touch controls đầy đủ, chơi được trên Android
- **Audio:** SFX + nhạc 3 track (hub/forest/cave) + boss
- **KHÔNG có:** quest, inventory, economy lớn, World 3 (để v1.2), dialogue phức tạp

Ước lượng: **P0–P10 = scope chính**. P11 + v1.1/v1.2 làm nếu còn thời gian.

---

## 13. Things NOT to Build Yet

**Tuyệt đối chưa động tới ở thời điểm này:**

1. **Quest system** — objective tracking, quest chain, quest log. Một dòng thoại NPC "đánh bại vua heo ở khu rừng" là đủ. Quest thực sự = P3/v1.2.
2. **Inventory / item system** — không có gameplay cho nó. Ability là "item" duy nhất bạn cần.
3. **Economy / shop / upgrade tree** — có thể thêm coin đếm cho vui, nhưng KHÔNG làm shop/upgrade UI cho tới khi vòng lặp core chạy.
4. **Nhiều ability cùng lúc (glide + slam + grapple + …)** — chỉ Dash cho MVP, tối đa +1 cho v1.1. Mỗi ability = 1 gate type + 2-3 placement.
5. **Seamless room streaming / no-loading-zone world** — ngoài scope. Mỗi area load riêng qua `SceneTransition` là chấp nhận được.
6. **World 3 / Final Boss** — cho tới khi World 1 + 2 chạy trọn vẹn end-to-end.
7. **Achievements** — cho tới khi core loop xong (cần Events + Save ổn định trước).
8. **Dialogue có nhánh / portrait / cutscene** — hộp thoại 1-3 dòng tĩnh là đủ.
9. **FSM framework / state machine plugin** — hand-roll cái máy nhỏ (pattern `chaser_spike.gd` đã cho thấy cách). Không cài plugin.
10. **ECS, DI container, event-sourcing, bất kỳ plugin bên thứ 3** — mục 14 PLAN.md.
11. **Enemy loot drop / XP / leveling** — enemy chết là đủ. Coin drop = v1.2.
12. **Localization / đa ngôn ngữ** — giữ Việt hardcode.
13. **Controller rumble, cloud save, Steam/GooglePlay integration.**
14. **Per-character unique ability** — 4 nhân vật hiện chỉ khác skin; giữ vậy.
15. **Procedural generation** bất cứ thứ gì.

**Refactor KHÔNG nên làm:**
- Đừng viết lại `SceneTransition` / `SaveManager` — chúng đúng rồi, chỉ mở rộng.
- Đừng migrate traps (`spikes`/`saw`/`orbit_saw`/`falling_spike`) thành `EnemyBase` — chúng là hazard, không phải enemy.
- Đừng bỏ duck typing `has_method()` ngay — để base class làm nó typed dần.
- Đừng đổi feature-based folder layout.

---

## 14. Next Step

**KHÔNG code.**

Roadmap đã sẵn sàng. Thứ tự phát triển đề xuất:

```
P0 (Foundation) → P1 (Player/Health) → P2 (Combat) → P3 (Enemy AI)
→ P4 (Boss) → P5 (Ability + Dash) → P6 (Save/Progression) → P7 (Hub)
→ P8 (Metroidvania gating) → P9 (Mobile) → P10 (Audio/Polish) → P11 (optional)
```

**Bạn muốn bắt đầu Phase 0 không?**

Khi bạn xác nhận một Phase, tôi sẽ: re-inspect file liên quan → implementation plan chi tiết → chia task nhỏ → liệt kê file tạo/sửa → xác định test → chờ bạn duyệt → mới code. Sau mỗi task: check compile/runtime/regression, cập nhật progress, không tự chuyển Phase.
