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

> **Status:** ✅ DONE — verified cả 5 màn. `EnemyBase` (CharacterBody2D + FSM + `FloorCheck`), `EnemyStats`, `pig.tscn`/`pig_ambusher.tscn` (Kings and Pigs pig xanh). Thay 18 quái trong 5 màn (spike_head/walker→pig, chaser→pig_ambusher; gỡ override chaser cũ). Flyer + traps giữ nguyên.
> Bug fix lúc test: player animation kẹt khi trúng đòn lúc đang chém (`_end_attack` cho mọi đường cắt ngang); pig `sprite_faces_right` (sprite Kings and Pigs quay trái).
> Nợ (→ P7): đoạn leo shaft L2 (cột chaser dọc) + vài chỗ L5 vốn thiết kế cho quái gắn tường — grounded pig chỉ đứng bệ, cần redesign khi repurpose màn thành world. Folder `walker/spike_head/chaser_spike` giữ lại (bỏ tham chiếu), xoá sau.

**Goal:** `EnemyBase` (`CharacterBody2D`) + FSM tái sử dụng; thay walker/spike_head/chaser_spike/flyer bằng hệ **Pig** (Kings and Pigs). Knockback vị trí thật.
**Why:** Gỡ copy-paste patrol khỏi 6 script; cho quái "phản ứng" (tiền đề của boss); art nhất quán với hero King + boss King Pig.
**Dependencies:** Phase 2 (HealthComponent/Hurtbox/Hitbox/EnemyHitReaction + collision layers).

**Asset (Pillow pipeline như P1.5):** import `Kings and Pigs/Sprites/03-Pig/*` (34×28: idle 11 / run 6 / jump 1 / fall 1 / ground 1 / hit 2 / **attack 4** / dead 3) → `objects/enemies/pig/sprites/` + `pig_frames.tres`.

**Kiến trúc:**
- `objects/enemies/enemy_base.gd` (`class_name EnemyBase extends CharacterBody2D`, group `"enemy"`):
  - `@export var stats: EnemyStats` (resource); `@export var gravity := 900.0` (0 = bay)
  - FSM `enum State { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }` — `match` trong `_physics_process`, mở rộng pattern `chaser_spike.gd` đã có
  - patrol giữa 2 điểm / tự quay đầu ở mép platform + tường; phát hiện player qua khoảng cách tới group `"player"` (hoặc `DetectionArea` con)
  - dùng lại: `HealthComponent`, `Hurtbox`, `Hitbox` (đòn của quái), `EnemyHitReaction` (đã có)
  - `hurtbox.hurt` → state HURT: bật velocity ra xa nguồn ~0.15s (× `stats.knockback_resist`), khoá AI trong lúc đó
  - anim: idle/run/hit/attack/dead theo `sprite.animation`
- `components/enemy_stats.gd` (`class_name EnemyStats extends Resource`): `max_hp`, `move_speed`, `chase_speed`, `damage`, `detect_range`, `leash_range`, `attack_range`, `attack_cooldown`, `knockback_resist`
- Collision: body layer `enemy`(4)/mask `world`(1); Hitbox layer `enemy_hitbox`(64); Hurtbox layer `enemy_hurtbox`(16)/mask `player_hitbox`(32)

**Enemy roster mới:**
| Loại | Scene | Thay cho | Hành vi |
|---|---|---|---|
| Pig (lính) | `objects/enemies/pig/pig.tscn` | walker, spike_head | patrol → phát hiện → chase → attack cận chiến |
| Pig phục kích | `pig_ambusher.tscn` (kế thừa) | chaser_spike | đứng yên gác → lao ra khi player lại gần → về chỗ |
| Flyer | giữ art Kenney, rebase EnemyBase (`gravity=0`) | flyer | bay tuần tra, vật cản trên không, **không** attack |

**Files:** `objects/enemies/pig/*` (mới), `objects/enemies/enemy_base.gd`+`.tscn`, `components/enemy_stats.gd`, `objects/enemies/flyer/*` (rebase), xoá `walker/`, `spike_head/`, `chaser_spike/` (giữ folder sprite cũ hay xoá — hỏi), 5 `level_N.tscn` (thay instance quái + chỉnh vị trí: Pig là body đứng trên đất, quái Area2D cũ thả nổi).
**Implementation order:** (1) `EnemyStats` + `EnemyBase` FSM skeleton (chỉ IDLE/PATROL) → (2) bake pig_frames → (3) `pig.tscn`, test patrol 1 màn → (4) CHASE + ATTACK + HURT + knockback → (5) `pig_ambusher` → (6) rebase flyer → (7) thay quái trong 5 màn, test từng màn.
**Acceptance Criteria:** Pig patrol/chase/attack (gây 1 damage)/nảy lùi khi trúng/chết pop qua cùng 1 base; đứng đúng trên terrain + moving_platform; rơi khỏi mép platform thì quay đầu (không rớt); chỉnh `EnemyStats` trong Inspector đổi hành vi ngay.
**Testing:** Mỗi loại trong mỗi màn; nhiều Pig cùng chase; Pig + moving_platform; Pig đứng mép vực; player nhảy qua đầu Pig; chém Pig từ trên/dưới.
**Risks:** Area2D→CharacterBody2D làm lệch vị trí/va chạm trong 5 màn cũ. Mitigation: thay + test từng màn; ghi lại chỗ level cần chỉnh (→ P7/P8).
**Complexity:** **High**

---

### Phase 4 — Boss (King Pig)

> **Chia P4a (boss chơi được, 1 pattern) → P4b (charge + jump_slam + phases + gate).**
> **P4a ✅** — verified (King Pig ném bom, 10 hp, arena, health bar).
> **P4b ✅** — verified. `boss_base.gd`: mỗi pattern = sub-machine `_pattern_step`/`_step_timer`. `charge` (phase 2, có `FloorProbe` chống lao xuống hố), `jump_slam` + `SlamHitbox` shockwave (phase 3), pool theo phase, roar + i-frame khi đổi phase, safety net rơi→spawn. `objects/boss_gate/` (cửa Kings-and-Pigs). User đã lấp hố arena + L5 trong editor.
> **Phase 4 HOÀN THÀNH.** `BossBase` **KHÔNG kế thừa EnemyBase** (FSM khác hẳn — INTRO/THINK/ATTACK/RECOVER/HURT/DEAD, timer/step driven, không coroutine). `objects/bomb/` (Area2D bay cung, chỉ vụ nổ gây damage). `king_pig.tscn` hp 10, pattern `bomb_toss`, `BodyHitbox` contact damage. `ui/boss_health_bar/`. `levels/boss_forest/` (`boss_arena.gd extends LevelBase`, thắng khi boss chết). `LevelData` +`boss_forest` (khoá sau L5). Test nhanh: **F6 (Run Current Scene)** trên `boss_forest.tscn`.

**Goal:** 1 boss hoàn chỉnh: `BossBase`, 2-3 attack pattern, 2 phase theo máu, boss arena khoá cửa, health bar, `Events.boss_defeated`.
**Why:** Điểm nhấn cuối world; trigger unlock ability (loop: Boss → Reward).
**Dependencies:** Phase 3.

**Asset:** `Kings and Pigs/Sprites/02-King Pig/*` (38×28, full moveset) → `objects/bosses/king_pig/sprites/` + `king_pig_frames.tres`. `Kings and Pigs/Sprites/09-Bomb/*` (Off/On 52×56/Boom) → `objects/bomb/`.

**Kiến trúc:**
- `objects/enemies/boss_base.gd` (`class_name BossBase extends EnemyBase`): thêm `PhaseController` (con Node) + mảng attack pattern. Máu lớn (~12-16). Không patrol — luôn hướng về player.
- `PhaseController`: máu ≤66% → phase 2 (nhanh hơn, thêm pattern), ≤33% → phase 3. Emit `Events.boss_phase_changed(n)`.
- Attack pattern (mỗi cái 1 method, dùng state + timer KHÔNG coroutine dài để pause/chết không vỡ):
  1. **Charge** — telegraph (khựng + nháy) → lao ngang arena, Hitbox bật
  2. **Bomb toss** — spawn `Bomb` (arc theo trọng lực → fuse ~1.2s → nổ → Hitbox `enemy_hitbox` ngắn → anim Boom → free)
  3. **Jump slam** (phase 2+) — nhảy → tiếp đất → shockwave 2 bên
- `objects/bomb/bomb.gd`+`.tscn` — projectile tái dùng (boss giờ, "Bomb Pig" enemy sau).
- `levels/boss_forest/boss_forest.tscn` — arena nhỏ (dùng `LevelBase`), camera khoá, `BossGate` đóng khi vào / mở khi `boss_defeated`.
- `ui/boss_health_bar/` — CanvasLayer, nghe `Events.boss_health_changed`.
- Thắng: `Events.boss_defeated.emit("forest_boss")` (save wiring ở P6).
**Files:** `objects/bosses/*`, `objects/bomb/*`, `levels/boss_forest/*`, `ui/boss_health_bar/*`, `core/events` (dùng `boss_*`).
**Implementation order:** (1) `Bomb` projectile → (2) `BossBase` + Charge + health bar → (3) Bomb toss → (4) `PhaseController` + Jump slam → (5) arena + BossGate → (6) death sequence + `boss_defeated`.
**Acceptance Criteria:** Đánh boss qua 2-3 phase, boss đổi pattern theo máu, thắng → cửa mở + event; thua → checkpoint/end_screen như thường; pause giữa fight OK; Bomb nổ đúng chỗ.
**Testing:** Thắng / thua / pause mọi lúc / chết boss đúng frame đổi phase / thoát arena giữa chừng (không được) / nhiều Bomb cùng lúc.
**Risks:** Pattern dùng `await` dài vỡ khi pause/chết → dùng state+timer, `PhaseController` reset on death. Bomb kẹt trong tường.
**Complexity:** **High**

---

### Phase 5 — Ability System & Dash

> **Status:** ✅ DONE — verified. `SaveManager` +`unlocked_abilities` + API; `core/progression.gd` autoload (boss→reward, `forest_boss`→`dash`); `player/abilities/ability_system.gd` (`is_unlocked` + `dev_unlock_all`); Dash trong `player.gd` (flat velocity + skip gravity + return khi `is_dashing`, cooldown 0.5s, huỷ khi trúng đòn); `objects/fx/dust.tscn` (CPUParticles2D); `ui/toast/` autoload; nút Dash trong touch controls. Double/wall jump giữ inline. (Bug fix lúc test: `_start_dash` gọi `_end_attack` — cái này clear luôn `is_dashing` — phải gọi TRƯỚC khi bật cờ.)

**Goal:** `AbilitySystem` (Node con của Player) + **Dash** là ability đầu tiên, unlock bởi `Events.boss_defeated`, persist. **Double/wall jump giữ inline trong `player.gd`** (không refactor — chúng hoạt động tốt, không phải unlockable trong scope; King/Captain có sẵn từ đầu).
**Why:** Trục metroidvania — "Unlock Ability" trong gameplay loop; Dash mở dash-gate ở P8.
**Dependencies:** Phase 4 (trigger unlock; Dash dev-unlock sớm để test độc lập).

**Kiến trúc:**
- `player/abilities/ability_system.gd` (Node): giữ danh sách ability con; expose `is_unlocked(id)` (query `SaveManager`).
- `player/abilities/dash.gd` (Node con): đọc action `dash` (L/Shift — có từ P0); nếu unlocked + hết cooldown + không dead/attacking → set `player.velocity.x = DASH_SPEED * player.facing` trong `DASH_DURATION` (~0.18s), bỏ qua trọng lực trong lúc đó, cooldown ~0.5s, i-frame ngắn tuỳ chọn, particle khói (Free Smoke Fx), anim (dùng "jump" + có thể nghiêng). Huỷ khi trúng đòn/chết.
- `player.gd`: expose vừa đủ cho dash (`facing` đã có; thêm 1 flag `is_dashing` để `_physics_process` nhường điều khiển velocity.x + skip gravity). Movement khác không đụng.
- `SaveManager`: thêm `unlocked_abilities: Array` + `is_ability_unlocked(id)` / `unlock_ability(id)` (persist qua `settings`/dict riêng — chốt ở P6, P5 làm bản tối giản).
- `AbilityData` (`class_name AbilityData extends Resource`): `id`, `display_name`, `icon`, `description` — cho toast + màn abilities sau. P5 có thể dùng dict tạm.
- Wire: `Events.boss_defeated` → `SaveManager.unlock_ability("dash")` + `Events.ability_unlocked.emit("dash")` → toast UI (label mờ dần).
- Dev flag: unlock-all để test khi chưa có boss.
**Files:** `player/abilities/*` (mới), `player/player.gd` (thêm `is_dashing` hook), `player/player.tscn` (thêm `AbilitySystem` + `Dash` node), `core/save_manager.gd`, `core/ability_data.gd`, `ui/toast/` (mới, tối giản).
**Implementation order:** (1) `AbilitySystem` + `Dash` (dev-unlock) → (2) tune dash feel (speed/duration/cooldown) → (3) particle + anim → (4) `SaveManager.unlock_ability` + persist → (5) `Events.boss_defeated` → unlock + toast → (6) touch_controls: thêm nút Dash.
**Acceptance Criteria:** Chưa unlock → bấm dash không có gì; unlock → dash hoạt động, giữ sau tắt/mở game; dash qua vực rộng hơn 1 nhảy thường; double/wall jump y hệt; touch có nút Dash.
**Testing:** Dash đất/không/vào tường/qua vực/dash+attack; spam dash (cooldown); dash rồi chết; save/load giữ unlock; nút Dash trên touch.
**Risks:** Dash + `move_and_slide` xuyên tường mỏng ở tốc độ cao → giới hạn DASH_SPEED hoặc nhiều bước collision. Dash lúc đang hit-stop.
**Complexity:** **Medium**

---

### Phase 6 — Progression & Save Expansion

> **Status:** 🔨 Code xong — chờ verify. Bỏ `GameManager.hearts` mirror (HUD nghe `Events.player_health_changed`; `GameManager` giờ thuần runtime, không còn `MAX_HEARTS`); `SaveManager` +`defeated_bosses` + `last_level` + API; `progression.gd` mark boss; `objects/ability_gate/` (StaticBody, mở khi unlock ability); nút **Continue** ở main menu (→ thẳng màn gần nhất).
> **`WorldData` hoãn sang P7** (consumer là hub).

> **Cập nhật:** `SaveManager` đã có `settings` dict + `get/set_setting` (từ P2.5). P5 đã thêm bản tối giản `unlocked_abilities`/`is_ability_unlocked`. P6 chính thức hoá: thêm `progress` dict (`defeated_bosses[]`, `collected_secrets[]`, `furthest_world`), và **bỏ `GameManager.hearts` mirror** — nguồn thật là `HealthComponent`, HUD chuyển sang nghe `Events.player_health_changed`. `GameManager` = thuần runtime.

**Goal:** `SaveManager.progress` (bosses/secrets/world) + `WorldData` + `AbilityGate` + "Continue". Dọn Runtime vs Persistent.
**Why:** Nền cho hub + backtrack; gameplay không chạm file, chỉ query API.
**Dependencies:** Phase 5.
**Features:** load thiếu key thì default (tương thích ngược); `WorldData.WORLDS[]` (id, name, level ids[], boss id); `objects/ability_gate/` (`Area2D` chặn đường, mở nếu `SaveManager.is_ability_unlocked(id)` — mở vĩnh viễn sau lần đầu); `SaveManager.get_continue_point()` → world/level gần nhất; nút **Continue** ở `main_menu`.
**Architecture Changes:** `GameManager.hearts` bị gỡ; `hud.gd` nghe `Events.player_health_changed`. `GameManager.start_new_run` tách `start_level(id)` / `enter_hub()`.
**Files affected:** `core/save_manager.gd`, `core/game_manager.gd`, `ui/hud/hud.gd`, `core/world_data.gd` (mới), `objects/ability_gate/*` (mới), `ui/main_menu` (+Continue), `ui/level_select` (đọc WorldData).
**Implementation order:** (1) mở rộng save schema + migration an toàn → (2) `WorldData` → (3) `AbilityGate` → (4) `get_continue_point` + nút Continue ở main menu.
**Acceptance Criteria:** Save cũ vẫn load; unlock ability/boss persist; dash-gate mở đúng theo trạng thái; Continue vào đúng world.
**Testing:** Xóa save → chạy mới; save cũ format → không crash; unlock rồi tắt game → vẫn còn; gate khóa/mở.
**Risks:** Migration save. Mitigation: mọi `get(key, default)`, không giả định key tồn tại.
**Complexity:** **Medium**

---

### Phase 7 — Hub & World Flow  *(FINALIZED)*

> **Status (7a — Hub & chain flow):** ✅ DONE — verified in editor, commit `dded2ac` trên branch `feat/phase-0-foundation`. `core/world_data.gd` (`WorldData.WORLDS`: forest = level_1-3 + boss_forest / mở sẵn; cave = level_4-5 / cần `forest_boss`); `levels/hub/hub.tscn` + `hub.gd` (extends `LevelBase`, phòng đi bộ, không enemy/flag). `objects/portal/` (Area2D layer interactable, `interact` → `WorldData.first_level(world_id)`, xám + 🔒 nếu world khoá, tự refresh khi `Events.boss_defeated`). `objects/hub_sign/` (biển → `target_scene`, đang trỏ Levels menu). Flow "chain trong world" (Option A do user chọn): `end_screen` +nút **Next Level** (chỉ hiện khi `won and WorldData.next_in_world(id) != ""`) → vào thẳng màn kế; nút cũ đổi "Levels" → **Hub**. `character_select` / `level_select` back → hub. `main_menu` **Continue** → hub (khôi phục `SaveManager` setting `character`); `character_select` lưu `character`. `GameManager.current_world` (portal set). Touch controls +nút **interact** (icon "E"). 
> **7a — nợ đã dọn** (commit sau 7b): `LevelData.LEVELS` xếp lại theo world order (level_1-3 → boss_forest → level_4-5) nên chuỗi `is_level_unlocked` khớp world; `level_select` nhóm theo `WorldData.WORLDS` + tiêu đề world; gỡ `get_next_id()` chết. King door_in anim đã gắn ở 7b.
> **Status (7b — NPC & dialogue):** ✅ DONE — verified in editor, commit `8d8de2d` trên branch `feat/phase-0-foundation`. Autoload `Dialogue` (`ui/dialogue/`, CanvasLayer, panel chữ đáy màn hình, `interact`/`jump` qua dòng, `is_open` giữ thêm 1 frame sau khi đóng để không double-trigger, không modal). `objects/npc/` (Area2D layer interactable, `interact` → `Dialogue.open`, `line_1..3` + `report_abilities` dựng động từ `SaveManager.unlocked_abilities`, dùng lại `pig_frames.tres`, bong bóng "Hello" Kings and Pigs `npc/sprites/bubble_frames.tres`, quay mặt về phía player). 1 NPC "Cố vấn" trong hub (x=150). Portal +`play_enter_door()` trên `player.gd` (chơi `door_in` nếu nhân vật có anim → chờ đúng thời lượng rồi mới `SceneTransition.goto`; Captain fade thẳng); portal + hub_sign gate trên `Dialogue.is_open`.

> **Cập nhật:** Flow = `main_menu → character_select (chọn hero) → hub → portal → level`. Giữ `character_select` (quyết định P1.5). King có anim **door_in/door_out** (P1.5) → dùng cho portal; Captain chưa có → fade. Dialogue dùng bong bóng "Dialogue Boxes" của Kings and Pigs (20 sprite In/Out: Hello, Hi, ?, !!!, No... ) + panel text đơn giản.

**Goal:** Hub đi bộ được (portal vào world, ≥1 NPC thoại tĩnh, bảng ability đã unlock). Repurpose 5 màn → World 1 Forest (level 1-3) + World 2 Cave (level 4-5) + boss.
**Why:** "Hub/Village" — trung tâm vòng lặp explore.
**Dependencies:** Phase 6.
**Features:** `levels/hub/hub.tscn` (dùng `LevelBase` + player); `objects/portal/` (`Area2D` + action `interact` → `SceneTransition.goto`, khoá theo `WorldData` unlock chain); `objects/npc/` (`Area2D` + `interact` → bong bóng + 1-3 dòng); return-to-hub sau khi thắng level/boss.
**Architecture Changes:** `hub` là entry chính; `level_select` → giữ làm "fast travel" trong hub hoặc bỏ. `GameManager`: `start_level(id)` / `enter_hub()`.
**Files affected:** `levels/hub/*` (mới), `objects/portal/*`, `objects/npc/*`, `ui/dialogue/*` (mới, tối giản), `core/game_manager.gd`, `core/world_data.gd`, `ui/character_select` (→ hub thay vì level_select).
**Implementation order:** (1) hub scene + player + camera → (2) Portal → 1 world → (3) restructure LevelData thành world → (4) NPC + dialogue tối giản → (5) return-to-hub sau khi thắng level/boss.
**Acceptance Criteria:** Đi từ hub → world 1 → thắng → về hub; portal world 2 khóa tới khi qua world 1; NPC nói được.
**Testing:** Mọi portal; vào/ra hub nhiều lần; pause trong hub; save ở hub → Continue về hub.
**Risks:** Flow scene rối (nhiều entry point). Mitigation: vẽ sơ đồ flow trước khi code.
**Complexity:** **Medium-High**

---

### Phase 8 — Metroidvania Content  *(FINALIZED)*

> **Status:** ✅ DONE — verified in editor ("phase 8 oke"), commit trên branch `feat/phase-0-foundation`. Nợ → P9: bố trí lại secret khi redesign map (Rừng còn 2 màn, `diamond_forest_3` phải dời khỏi level_3). `SaveManager` +`collected_secrets[]` + `max_hp_bonus` + API (`is_secret_collected`/`collect_secret`/`get_max_hp_bonus`/`add_max_hp_bonus`). `objects/collectible_diamond/` (`@tool` Area2D, `@export secret_id`, persist — tự `queue_free` nếu đã nhặt; nhặt → `SaveManager.collect_secret` + `Events.collectible_collected(id,"diamond")` + tween biến mất). `objects/secret_alcove/` (bệ nổi + `AbilityGate` "dash" chắn ngang giữa). `Progression` +`FOREST_SECRETS` (3 id) + `_on_collectible_collected` → đủ 3 → `add_max_hp_bonus(1)` + `Events.max_hp_increased`. `Events` +`max_hp_increased`. `player.gd` cộng bonus vào `health.max_hp` lúc `_ready` + nghe `max_hp_increased` tăng ngay. `hud.gd` dựng lại HeartsRow theo `maximum` (2→5 tim) + nhãn `◆ n/3`. `Toast` +"Heart Container!". 3 màn Forest: `Secrets/SecretAlcoveN` + `DiamondN` (`diamond_forest_1..3`) — **toạ độ tạm, user căn lại trong editor**.
> **Cập nhật:** collectible = **Diamond** (`Kings and Pigs/12-Live and Coins/Big Diamond`, 18×14). Reward đầu tiên = **heart container** (tăng `HealthComponent.max_hp` vĩnh viễn — `SaveManager.max_hp_bonus`).

**Goal:** 2-3 dash-gate trong World 1 (Forest) mở đường/secret; 1-2 secret room có Diamond; reward backtrack.
**Why:** "Quay lại khu vực cũ" — thứ làm nó là metroidvania.
**Dependencies:** Phase 5 (dash) + Phase 7 (hub để backtrack) + Phase 6 (`AbilityGate`, save).
**Features:** dash-gate (khe rộng / tường nứt) đặt trong Forest levels; secret room sau gate; `objects/collectible_diamond/` (persist qua `SaveManager.collected_secrets` — id duy nhất mỗi viên); HUD đếm; reward heart container.
**Architecture Changes:** Không (dùng `AbilityGate` + pattern `fruit.gd`).
**Files affected:** Forest level `.tscn` (thêm gate + secret room), `objects/collectible_diamond/*` (mới), `ui/hud/*`, `core/save_manager.gd` (`max_hp_bonus`).
**Implementation order:** (1) 1 collectible type + persist → (2) 1 secret room sau dash-gate ở level 1 → (3) nhân rộng 2-3 chỗ → (4) HUD counter + reward.
**Acceptance Criteria:** Trước khi có dash không vào được secret; sau dash quay lại vào được; collectible đếm + persist; thu hết → reward.
**Testing:** Vào secret khi chưa/đã có dash; nhặt collectible rồi tắt game; nhặt 2 lần (không tăng đôi).
**Risks:** Sửa 5 tscn màn cũ (đang share script) — cẩn thận camera limit / bố cục.
**Complexity:** **Medium**

---

### Phase 9 — Level & World Redesign  🔨 ĐANG LÀM

> **Bối cảnh:** 5 màn cũ dùng chung 1 tileset + nền phẳng + 0 trang trí + bố cục
> "rắc hazard" → nhìn giống hệt nhau, cổ điển, thiếu cốt truyện. Dựng lại toàn bộ
> thành **3 world khác biệt + cốt truyện "Vua Trở Về"**.
>
> **Cấu trúc mới (id giữ nguyên, không rename file):**
> - W1 **Rừng Ranh Giới** — `level_1`, `level_2` (mở sẵn). Cuối `level_2` = tiền đồn Heo → nhặt **relic Dash**.
> - W2 **Lâu Đài Thất Thủ** — `level_3`, `level_4`, `boss_forest` (mở khi xong `level_2`). Boss = King Pig (retheme lâu đài). Hạ boss → mở W3.
> - W3 **Hầm Ngục Cổ** — `level_5`, `level_6` (mở khi hạ `forest_boss`). `level_6` = scene mới. Boss cuối để v1.2.
>
> **Asset:** foreground tileset theo world (cỏ Pixel Adventure / Kings-and-Pigs castle 32px / Dungeon_pack) —
> KHÔNG trộn Gothicvania vào mặt đất. Nền parallax: Sunny Land (W1) / Gothicvania Cold Corridors (W2) /
> Gothicvania Cemetery (W3) — 3 pack đã tải về repo root, license ansimuz royalty-free.
> Trap mới (~4, từ `Free/Traps` chưa dùng): trampoline, arrow_shooter, spiked_ball, fire_trap.
>
> **Task:** P9-0 restructure code → P9-1 import asset + 2 tileset `.tres` scaffold + scene nền parallax →
> P9-2 story layer (`story_sign`, title card, NPC hub, thoại world, `ability_relic`, relore Diamond) →
> P9-3 trap mới → P9-4 dựng lại W1 → P9-5 dựng lại W2 + retheme boss → P9-6 dựng lại W3 + `level_6` →
> P9-7 retheme hub + regression + docs. Làm 1 world/lần, mỗi task verify→commit→dừng.
>
> **P9-0 ✅ code xong — chờ verify.** `WorldData.WORLDS` = 3 world + khoá `unlock_level`
> (`is_world_unlocked` cần cả `unlock_boss` lẫn `unlock_level`); `SaveManager.is_level_completed()`;
> `LevelData.LEVELS` xếp lại + `level_6` + tên tiếng Việt; `level_base.gd` +`world_title`/`level_subtitle`
> + thẻ tiêu đề mờ dần (dựng bằng code, CanvasLayer tạm); `levels/level_6/level_6.tscn` (placeholder —
> sàn StaticBody2D + 2 Pig + cờ, có title card để test); `hub.tscn` 3 portal (forest/castle/dungeon);
> `level_1.tscn` +title card. **Chưa đụng địa hình/nội dung màn nào.** Nợ→P9-2: `Progression.BOSS_REWARDS`
> vẫn `forest_boss→dash` (chuyển sang `ability_relic`); thoại Advisor trong hub còn nhắc "hạ trùm".

**Acceptance P9-0:** hub 3 portal (Rừng mở, Lâu Đài + Hầm Ngục khoá 🔒); xong `level_2` → Lâu Đài mở;
hạ King Pig → Hầm Ngục mở; chuỗi Next Level trong world đúng; `level_6` load được (có title card);
Level Select nhóm 3 world; không regression 5 màn cũ.
**Complexity:** **High** (phase to nhất).

---

### Phase 2.5 — Mobile Touch Controls  ✅ DONE (kéo từ P9 lên)

Làm ngay sau Combat để playtest Android sớm. **Không có lớp `PlayerInput` riêng** — `TouchScreenButton.action` → cùng InputMap action, `player.gd` không đổi. Đã làm: nút sinh bằng Pillow (`ui/touch_controls/sprites/`); `ui/touch_controls/touch_controls.tscn`+`.gd` (5 TouchScreenButton tự đặt vị trí theo mép, `pause_pressed` signal); `level_base.gd` instance + connect; `project.godot` `emulate_touch_from_mouse`; `SaveManager` thêm `settings` dict + `get/set_setting`; `settings_menu` toggle Touch (Auto/On/Off) + persist fullscreen; `main_menu` áp lại fullscreen đã lưu. **Verified trên PC. APK chưa build (để sau — hướng dẫn export đã đưa cho user).**

**"Phase 9" cũ (Input abstraction + mobile) đã gộp vào đây.** Phần còn lại (dash button — P5; perf mobile + test đa tỉ lệ sâu + gamepad polish + safe-area chuẩn) → **P10**.

---

### Phase 10 — Audio & Polish  *(FINALIZED)*

> **Cập nhật:** fullscreen persist + volume-setting infra đã có (P2.5). P10 = audio thật + juice + phần mobile còn lại từ "P9".

**Goal:** Audio bus + SFX + nhạc; camera shake; screen-shake/particle juice; safe-area chuẩn; perf pass mobile; gamepad polish.
**Why:** Ưu tiên #6 (Polish) — chất lượng demo/present.
**Dependencies:** Lỏng — làm gần cuối. Cần asset audio CC0 ngoài (pack không có nhạc — đánh giá license trước).
**Features:**
- `core/audio_manager.gd` autoload — nghe `Events` (`player_died`, `enemy_died`, `fruit_collected`, `ability_unlocked`, `boss_*`...) + API `play_sfx(name)` / `play_music(track)`. Bus layout `Master/Music/SFX` (`.tres`). Volume slider trong `settings_menu` bật lại + persist qua `SaveManager.get/set_setting`.
- SFX: jump, land, hit, hurt, collect, dash, enemy_hit, enemy_die, boss. Nhạc: hub / forest / cave / boss.
- `components/camera_shake.gd` — nghe `hit_landed` / `boss` / `player_damaged`.
- Particle từ **Free Smoke Fx Pixel 2** cho dash / land / enemy death.
- Safe-area chuẩn cho touch controls (`DisplayServer.get_display_safe_area`); perf test mobile renderer; gamepad button hints.
**Files affected:** `core/audio_manager.gd` (mới), `audio/*` (mới), `project.godot` (bus + autoload), `ui/settings_menu`, `player/player.tscn` (camera shake), `ui/touch_controls` (safe-area).
**Complexity:** **Medium**

---

### Phase 11 — Optional Replayability  *(FINALIZED — chỉ làm nếu còn thời gian)*

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
2. **Collision layer naming** — ✅ chốt ở P1 (8 layer: world/player/enemy/player_hurtbox/enemy_hurtbox/player_hitbox/enemy_hitbox/interactable), ghi ở CONTRIBUTING. **Gotcha đã gặp:** `monitoring=false` trên Area2D chặn cả việc bị area khác detect — dùng `collision_mask=0` thay vì.
3. **Runtime vs Persistent boundary (P6)** — `GameManager` = runtime, `SaveManager` = persistent, gameplay query qua `get_setting`/`is_*_unlocked` API (đã bắt đầu ở P2.5). `GameManager.hearts` mirror sẽ bị gỡ ở P6.
4. **AbilitySystem hook vào player movement (P5)** — Dash phải nhường/lấy điều khiển `velocity` qua 1 flag (`is_dashing`) rõ ràng, không rải logic dash khắp `_physics_process`. Double/wall jump giữ inline (không đụng).
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

- **Combat:** melee (King búa / Captain kiếm), 2-3 enemy Pig types + 2 boss
- **Ability:** Dash (MVP) + 1 nữa (v1.1). Double/wall jump **giữ inline** trong player.gd (không refactor — không phải unlockable).
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
14. **Per-character unique ability / stats sâu** — King & Captain hiện chỉ khác sprite + `attack_reach`; giữ đơn giản vậy tới khi core loop xong. Bomb Guy (hero thứ 3, tầm xa) cũng để sau P2.
15. **Procedural generation** bất cứ thứ gì.

**Refactor KHÔNG nên làm:**
- Đừng viết lại `SceneTransition` / `SaveManager` — chúng đúng rồi, chỉ mở rộng.
- Đừng migrate traps (`spikes`/`saw`/`orbit_saw`/`falling_spike`) thành `EnemyBase` — chúng là hazard, không phải enemy.
- Đừng bỏ duck typing `has_method()` ngay — để base class làm nó typed dần.
- Đừng đổi feature-based folder layout.

---

## 14. Progress & Next Step

**Đã xong** (branch `feat/phase-0-foundation`, verified từng phase, chưa merge `main`):

```
P0  Foundation ...................... ✅ 0f84012
P1  Player refactor + Health ........ ✅ cf4a750  (+ fix leo tường vô hạn)
P1.5 Multi-hero (King + Captain) .... ✅ 11a9bdb
P2a Damage pipeline migration ....... ✅ a747cf1
P2b Player attack + enemy reactions . ✅ a88272b
P2.5 Mobile touch controls ......... ✅ 05684cf  (APK chưa build)
```

**Còn lại** (spec đã FINALIZED ở trên):

```
P3  Enemy AI base + Pig migration   ← NEXT
→ P4  Boss (King Pig) → P5  AbilitySystem + Dash → P6  Save/Progression
→ P7  Hub + World flow → P8  Metroidvania gating → P10  Audio + Polish
→ P11 Achievements / Challenge (optional)
```

Quy trình mỗi phase: xác nhận → re-inspect → implementation plan chi tiết → chia task → chờ duyệt → code → verify (compile/runtime/regression) → commit → dừng, không tự chuyển phase.

**Bạn muốn bắt đầu Phase 3 không?**
