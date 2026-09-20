# PLAN — Bổ sung theo yêu cầu đồ án

> **Trạng thái:** spec đã chốt (20/09/2026), đang triển khai trực tiếp trên `main`.
> **Quan hệ với `ROADMAP.md`:** ROADMAP là tài liệu mở rộng metroidvania (P0–P11), viết từ tháng 8
> và **đã lạc hậu so với code** (nhiều phần ghi "chưa có" thực ra đã làm xong). File PLAN.md này là
> tài liệu kế hoạch **hiện hành**, chỉ bám theo 4 yêu cầu của đồ án. Khi hai file mâu thuẫn, tin file này.

---

## 1. Rà soát hiện trạng so với yêu cầu

Audit trực tiếp `game/` tại commit `580b6eb`.

| # | Yêu cầu | Hiện trạng | Kết luận |
|---|---|---|---|
| 1a | Game over: **thông báo / hiệu ứng hình ảnh** | `ui/end_screen/` hiện "GAME OVER", nền xám `Gray.png`, panel tween fade + pop | ✅ Có |
| 1b | Game over: **hiệu ứng âm thanh** | `AudioManager.SFX_PATHS` chỉ có `jump/attack/hurt/enemy_die/pickup`. `end_screen.gd` không gọi audio. Nhạc world vẫn chạy đè qua màn kết thúc | ❌ **Thiếu** |
| 1c | Game over: **≥3 nút điều hướng** | Lúc thua chỉ hiện **2 nút** (Retry, Hub) vì `NextButton.visible = won and …` | ❌ **Thiếu** |
| 1d | Hiệu ứng **"trên màn hình chơi game"** | Chết → chờ 0.6s → cắt thẳng sang scene `end_screen`. Trong màn chơi không có báo hiệu nào | ❌ **Thiếu** |
| 2a | **≥3 cấp độ/bản đồ khác nhau** | 6 màn (`level_1..6`) + 2 boss arena + hub, chia 3 world: Rừng / Lâu Đài / Hầm Ngục. Mỗi world có tileset, parallax, nhạc nền, bộ enemy và cơ chế riêng (dash-gate, secret alcove, cannon, bomber) | ✅ **Vượt yêu cầu** |
| 2b | **Lưu trạng thái sau mỗi màn** | `SaveManager` → `user://save_data.json`: `completed_levels`, `high_scores`, `best_times`, `unlocked_abilities`, `defeated_bosses`, `collected_secrets`, `max_hp_bonus`, `achievements`, `settings`, `last_level` | ✅ Có |
| 3a | Win: **mục tiêu cụ thể** | Trên thực tế có (cờ đích mỗi màn; hạ Warden ở `boss_dungeon` = kết game) nhưng **game không nêu mục tiêu ở bất kỳ đâu** | ⚠️ **Chưa truyền đạt** |
| 3b | Win: **thông báo / hiệu ứng hình ảnh** | "YOU WIN!", confetti, panel vàng `DialogPanelWin`, báo Best Time mới | ✅ Có |
| 3c | Win: **hiệu ứng âm thanh** | Không có (cùng lý do 1b) | ❌ **Thiếu** |
| 3d | Thắng **cả game** (khác thắng 1 màn) | Hạ Warden cũng ra `end_screen` y hệt thắng màn thường, chỉ khác có Toast thành tựu `the_crown` | ⚠️ **Chưa phân biệt** |
| 4 | **≥3 NPC có hành vi thông minh** | Hub có đúng 3 NPC (`Advisor` / `Villager` / `Deserter`) nhưng **hoàn toàn tĩnh**: chỉ quay mặt về phía player + đọc 1–3 dòng thoại cứng. AI thật (FSM) chỉ nằm ở **enemy/boss**, không phải NPC | ⚠️ **Chưa đạt theo nghĩa "NPC"** |

**Tóm lại:** yêu cầu 2 đã xong hoàn toàn và không cần đụng tới. Cần bổ sung cho yêu cầu 1, 3, 4.

---

## 2. Phạm vi bổ sung

Sáu hạng mục (T1–T6), làm tuần tự trên `main`.

| Mã | Hạng mục | Phục vụ yêu cầu |
|---|---|---|
| T1 | 3 sting âm thanh win / lose / thắng cả game | 1b, 3c |
| T2 | Hiệu ứng kết quả **ngay trong màn chơi** (`ResultFlash`) | 1a, 1d, 3b |
| T3 | Màn Game Over 4 nút + màn hình **Tiến trình** mới | 1c |
| T4 | Mục tiêu win rõ ràng + màn kết game riêng | 3a, 3d |
| T5 | AI cho 3 NPC ở hub | 4 |
| T6 | Tài liệu hoá AI enemy/boss (bằng chứng bổ sung) | 4 |

**Không làm** (ngoài phạm vi đồ án): thêm màn mới, sửa level design, đổi combat, shop/inventory,
đa ngôn ngữ, build APK.

---

## 3. T1 — Sting âm thanh

**Vấn đề:** máy dev không có `ffmpeg`/`oggenc`/`sox`, cũng không có `soundfile` trong Python →
không tạo được `.ogg` như 5 SFX sẵn có. Godot 4 import `.wav` native nên dùng `.wav`.

**Tạo mới** (script sinh bằng Python `wave` + `numpy`, đặt trong scratchpad, không commit script):

| File | Nội dung | Độ dài |
|---|---|---|
| `game/audio/sfx/game_over.wav` | Hợp âm rải đi xuống, âm thứ, có vibrato tắt dần | ~1.3s |
| `game/audio/sfx/victory.wav` | Fanfare đi lên 4 nốt trưởng + hợp âm kết | ~1.4s |
| `game/audio/sfx/final_victory.wav` | Fanfare dài hơn, 2 tầng, kết bằng hợp âm ngân | ~2.6s |

Dạng sóng: square/triangle nhẹ + envelope ADSR đơn giản cho hợp chất liệu chiptune 8-bit của game.

**Sửa `game/core/audio_manager.gd`:**
- Thêm 3 khoá trên vào `SFX_PATHS`.
- Thêm `play_sting(name: String)`: `stop_music()` rồi `play_sfx(name, 0.0)` — `pitch_var = 0.0` vì
  sting giai điệu không được lệch cao độ như SFX lặp lại.

**Sửa `game/ui/main_menu/main_menu.gd`:** gọi `AudioManager.play_music("")` trong `_ready`.
Cần thiết vì từ nay nhạc bị dừng ở thời điểm win/lose → không thêm dòng này thì menu sẽ im lặng.

> **Import:** đã chạy `Godot --headless --path game --import` nên 3 file `.wav.import` được sinh và
> commit kèm; không cần mở editor để nghe được sting. `edit/loop_mode=0` → sting phát đúng một lần.
> (Lần chạy import đầu tiên bị crash giữa chừng ở `victory.wav`; chạy lại lần hai thì xong sạch.)

---

## 4. T2 — Hiệu ứng kết quả trong màn chơi (`ResultFlash`)

Đề yêu cầu thông báo/hiệu ứng **trên màn hình chơi game**, không phải chỉ ở scene kết thúc riêng.

**Scene mới `game/ui/result_flash/result_flash.tscn` + `result_flash.gd`:**
- `CanvasLayer` (layer 60) chứa `ColorRect` phủ toàn màn (alpha 0) + `Label` lớn.
- API công khai: `show_result(kind: String)` với `kind ∈ {"lose", "win", "final"}`.
- Biểu hiện:
  - `lose` — màn tối dần sang đỏ thẫm, chữ **"GỤC NGÃ"** phóng to rồi co lại, rung nhẹ.
  - `win` — chớp trắng ngắn, chữ **"HOÀN THÀNH!"** bật lên theo `TRANS_BACK`, sắc vàng.
  - `final` — như `win` nhưng chữ **"VƯƠNG MIỆN TRỞ VỀ"**, giữ lâu hơn.
- Dựng bằng tween trong code (giống `level_base._show_title_card`), không dùng `AnimationPlayer`.
- `process_mode = ALWAYS` để không bị treo nếu cây scene đang pause.

**Sửa `game/player/player.gd`:**
- Thêm `const RESULT_FLASH := preload(...)` và hàm `_flash_result(kind: String)` — instance flash vào
  `get_tree().current_scene`, gọi `AudioManager.play_sting(...)`.
- `_on_health_died()` nhánh không-checkpoint: gọi `_flash_result("lose")`, nâng chờ `0.6s → 1.4s`
  rồi mới `SceneTransition.goto(end_screen)`.
- `win()`: xác định `final` khi `GameManager.current_level_id == "boss_dungeon"`; gọi
  `_flash_result("win"/"final")`, chờ `1.2s` (`final`: `2.0s`) rồi mới chuyển màn.

**Vì sao đặt ở `player.gd` chứ không nghe `Events.player_died`:** `player_died` cũng phát khi hồi sinh
tại checkpoint (`_on_health_died` phát signal *trước* khi rẽ nhánh), nên listener bên ngoài không phân
biệt được "chết thật" với "mất mạng rồi bung lại". Chỗ duy nhất biết chắc là nhánh trong `player.gd`.
Player vốn đã gọi thẳng `SceneTransition` và `AudioManager` nên cách này không phá vỡ quy ước sẵn có.

**AudioManager pool là autoload** → sting vẫn ngân tiếp qua lúc đổi scene, không bị cắt.

---

## 5. T3 — Màn Game Over 4 nút + màn hình Tiến trình

### 5.1 `end_screen.tscn` / `.gd`

Bỏ `ButtonsBox` (`HBoxContainer`), thay bằng:

```
VBoxContainer
├── NextButton          (full width, chỉ hiện khi thắng & world còn màn kế)
└── ButtonsGrid (GridContainer, columns = 2)
    ├── RetryButton     "Chơi lại"    → chơi lại màn hiện tại
    ├── HubButton       "Về Làng"     → res://levels/hub/hub.tscn
    ├── HomeButton      "Trang chủ"   → res://ui/main_menu/main_menu.tscn
    └── ProgressButton  "Tiến trình"  → res://ui/progress_screen/progress_screen.tscn
```

→ **luôn có 4 nút** kể cả khi thua, mỗi nút dẫn sang một màn riêng biệt. Lưới 2 cột tránh
hàng nút bị tràn ở tỉ lệ dọc / mobile.

`HomeButton` xoá checkpoint (`GameManager.has_checkpoint = false`) trước khi chuyển, giống `HubButton`.

### 5.2 Màn hình mới `game/ui/progress_screen/`

Hiện chưa có UI nào cho thành tựu — màn này vừa lấp lỗ hổng đó vừa là đích đến thật cho nút thứ 4.

Nội dung (dựng trong code từ `SaveManager` + `WorldData` + `Achievements`, giống cách
`level_select` dựng nút):

1. **Dòng mục tiêu** (đầu trang, nổi bật): mục tiêu cuối
   (`"MỤC TIÊU: Đoạt lại Vương Miện — hạ Cai Ngục ở Hầm Ngục Cổ."`) + dòng
   `"BƯỚC KẾ TIẾP: …"` lấy từ `Progression.next_objective()` để trùng khít với điều NPC Cố vấn nói.
   Đổi thành dòng chúc mừng khi `SaveManager.is_boss_defeated("dungeon_boss")`.
2. **Tiến trình thế giới** — lặp `WorldData.WORLDS`: tên world (🔒 nếu chưa mở), rồi từng màn với
   ✓ / 🔒, `Best <điểm>`, `⏱ <thời gian>`.
3. **Sức mạnh** — `get_unlocked_abilities()`, tên hiển thị tiếng Việt.
4. **Boss đã hạ** — `defeated_bosses`.
5. **Mảnh Vương Ấn** — `collected_secrets` đếm trên 3, cộng `max_hp_bonus`.
6. **Thành tựu** — 6 mốc trong `Achievements.ACHIEVEMENTS`, mở thì sáng, khoá thì xám + 🔒.
7. Nút **Quay lại**.

Bố cục `ScrollContainer > VBoxContainer` vì nội dung dài hơn một màn hình.

**Điều hướng quay lại:** thêm `var progress_return_scene: String` vào `GameManager` (runtime state,
đúng ranh giới GameManager/SaveManager). Bên gọi set trước khi `goto`; mặc định là main menu.

**Lối vào thứ hai:** thêm nút "Tiến trình" vào `main_menu` để màn này không chỉ tới được sau khi thua.

---

## 6. T4 — Mục tiêu win + kết game riêng

**Mục tiêu thắng game** được nêu ở 3 chỗ để người chơi không thể bỏ lỡ:
1. Dòng đầu màn hình **Tiến trình** (T3).
2. NPC **Cố vấn** ở hub nói mục tiêu kế tiếp, cập nhật theo tiến độ (T5).
3. Hiệu ứng `final` khi thật sự thắng (T2).

**`end_screen.gd`** phân biệt kết game:
```gdscript
var is_final := won and GameManager.current_level_id == "boss_dungeon"
```
- Tiêu đề `"VƯƠNG MIỆN TRỞ VỀ!"` thay cho `"YOU WIN!"`.
- Thêm khối tổng kết: số màn đã hoàn thành / tổng, số mảnh Vương Ấn, số thành tựu, tổng số tim tối đa.
- `NextButton` ẩn sẵn (`next_in_world("boss_dungeon") == ""`) — không cần sửa.

Điều kiện thắng game giữ nguyên, chỉ được **truyền đạt** rõ hơn: hạ Cai Ngục (Warden) ở `boss_dungeon`.

---

## 7. T5 — AI cho 3 NPC ở hub

`objects/npc/npc.gd` hiện là Area2D tĩnh. Nâng thành một FSM nhỏ, hand-rolled, theo đúng pattern
`EnemyBase` (không cài plugin state machine — xem ROADMAP mục 13.9).

### 7.1 Khung chung (`npc.gd`)

```gdscript
enum Behavior { STATIONARY, WANDER, SKITTISH }
enum State { IDLE, WANDER, NOTICE, TALK, FLEE, RETURN }
```

- Di chuyển bằng `position.x` (sàn hub phẳng, NPC là `Area2D` không cần vật lý), phát `run`/`idle`,
  `flip_h` theo hướng, tôn trọng `sprite_faces_right` sẵn có.
- Nhận biết player qua khoảng cách mỗi `_process` (chỉ 3 NPC → không cần Area detection riêng).
- Mọi state đều nhường cho `Dialogue.is_open` (state `TALK`, đứng im, quay mặt về player).
- Export thêm: `behavior`, `wander_range`, `walk_speed`, `notice_radius`, `follow_distance`,
  `flee_radius`, `calm_time`, `dynamic_line`.
- `enum DynamicLine { NONE, NEXT_OBJECTIVE, MOOD, WORLD_TIP }` — chọn **một** dòng thoại tính động
  nối vào cuối `line_1..3` (giữ nguyên cơ chế `report_abilities` đang dùng).

### 7.2 Ba hành vi khác biệt

**1. Cố vấn — `STATIONARY` + `NEXT_OBJECTIVE` (lập kế hoạch theo tiến độ).**
Không đi lại (đứng bên bàn đồ). Tính **mục tiêu kế tiếp** từ save và:
- nói đúng mục tiêu đó khi trò chuyện;
- lúc rảnh, cứ ~3.5s lại **quay mặt về portal của world đang là mục tiêu** — chỉ đường không lời.
  Tìm portal bằng cách quét node anh em có property `world_id` (portal không thuộc group nào).

Cây quyết định đặt ở **`Progression.next_objective()`** chứ không nhúng trong `npc.gd`, để màn
Tiến trình (T3) và NPC không tự suy luận tiến độ theo hai kiểu khác nhau:

| Điều kiện | World | Mục tiêu |
|---|---|---|
| `level_2` chưa hoàn thành | `forest` | Băng qua Rừng Ranh Giới. Di vật Lướt nằm ở cuối rừng, và Cổng Lâu Đài chỉ mở khi vượt hết khu Rừng. |
| `forest_boss` chưa hạ | `castle` | Vào Lâu Đài Thất Thủ, hạ Vua Heo. Hạ được hắn thì đường xuống Hầm Ngục Cổ mới lộ ra. |
| `dungeon_boss` chưa hạ | `dungeon` | Xuống Hầm Ngục Cổ, hạ Cai Ngục — Vương Miện đang nằm trong tay hắn. |
| Đã hạ `dungeon_boss` | `` | Vương Miện đã trở về. Ngài lại là Vua, thưa Đức Vua. |

> **Đính chính so với bản nháp:** Dash **không** đến từ boss. `Progression.BOSS_REWARDS` rỗng —
> Dash nhặt ở `objects/ability_relic/` đặt cuối `level_2`. Hạ Vua Heo chỉ `mark_boss_defeated`
> để mở world Hầm Ngục. Chuỗi mục tiêu ở trên đã theo đúng luồng thật.

**2. Dân làng — `WANDER` + bám theo + `MOOD` (tuần tra, tò mò, tâm trạng theo tiến độ).**
- Đi tuần qua lại trong `wander_range`, dừng nghỉ ngẫu nhiên 1–2s (làm việc vặt).
- Player vào `notice_radius` → dừng, quay mặt, hiện bong bóng; player ở lại → **đi theo** giữ
  `follow_distance`, player rời xa → `RETURN` về quãng tuần tra.
- **Tâm trạng** 3 bậc theo số world đã mở / boss đã hạ: `sợ hãi → hy vọng → ăn mừng`. Ảnh hưởng
  `walk_speed`, `modulate`, và dòng `MOOD` khi nói chuyện.

**3. Heo đào ngũ — `SKITTISH` + `WORLD_TIP` (nhát gan, phải tạo lòng tin).**
- Player lại gần **mà đang chạy nhanh / tấn công / lướt** (`abs(velocity.x) > 60`, `is_attacking`,
  `is_dashing`) → `FLEE` chạy về `flee_anchor`, hiện bong bóng hoảng, **không cho nói chuyện**.
- Chỉ khi player **đứng yên** trong `flee_radius` đủ `calm_time` (~1.2s) thì mới bình tĩnh lại,
  quay về chỗ cũ và mở thoại — "đổi thông tin lấy lòng tin".
- `WORLD_TIP`: mách về loại quái ở **world mục tiêu kế tiếp** (cannon ở Lâu Đài, bomber ở Hầm Ngục…).

### 7.3 Cập nhật `levels/hub/hub.tscn`

Set property trên từng instance NPC (đúng quy ước: chỉ override property trên node instance gốc,
không đụng node con lồng sâu):
- `Advisor` (x=120): `behavior = STATIONARY`, `dynamic_line = NEXT_OBJECTIVE`, giữ `report_abilities`.
  Bỏ `line_2`/`line_3` cũ vì chúng hardcode đúng thông tin mà dòng động giờ tự tính.
- `Villager` (x=300): `behavior = WANDER`, `wander_range = 60`, `walk_speed = 24`,
  `dynamic_line = MOOD`. Sprite là King frames (có `idle` + `run`) nên đi được.
- `Deserter` (x=510): `behavior = SKITTISH`, `flee_radius = 72`, `calm_time = 1.2`,
  `walk_speed = 22`, `dynamic_line = WORLD_TIP`. Bỏ `line_3` cũ (mách nước giờ là dòng động).

**Giới hạn không gian.** Portal ở x = 220 / 400 / 590, vùng `interact` rộng 40px. Dây xích của NPC
là `wander_range + leash_extra` (mặc định 40) quanh vị trí đặt trong scene:
Villager 240–360 (không chạm portal nào), Deserter 470–550 (chừa portal Hầm Ngục ở 570–610).
Sàn hub trải -40…1080 nên không NPC nào rơi ra ngoài.

---

## 8. T6 — Tài liệu hoá AI enemy/boss

Bằng chứng bổ sung cho yêu cầu "hành vi thông minh", phòng trường hợp "NPC" được hiểu theo nghĩa rộng
là mọi nhân vật do máy điều khiển:

| Nhân vật | Hành vi |
|---|---|
| **Pig** (`EnemyBase`, `behavior = PATROL`) | FSM `PATROL/IDLE/CHASE/ATTACK/RETURN/HURT`. Đi tuần giữa 2 mốc, `FloorCheck` RayCast quay đầu ở mép vực để không rơi, phát hiện player trong `detect_range` thì đuổi, vào tầm thì `ATTACK` (bật `Hitbox` đúng frame animation), mất dấu thì quay về tuyến tuần tra. |
| **Pig phục kích** (`behavior = GUARD`) | Đứng gác, lao ra khi player lại gần, vượt `leash_range` thì bỏ cuộc và `RETURN` về chỗ gác. |
| **Pig ném bom** (`pig_bomber.gd`) | Đánh tầm xa: giữ khoảng cách, ném bom theo quỹ đạo vòng cung, thời gian bay tính theo khoảng cách tới player. |
| **Cannon** (`cannon.gd`) | Tháp phòng thủ tĩnh, bắn theo chu kỳ khi player ở đúng hướng/tầm. |
| **Vua Heo** (`BossBase`, hp 10) | FSM riêng `INTRO/THINK/ATTACK/RECOVER/HURT/DEAD`, **3 phase theo % máu** (≤66%, ≤33%), mở khoá dần pattern: `bomb_toss` → `+charge` (telegraph rồi lao, choáng dài khi đâm tường) → `+jump_slam` (sóng xung kích khi tiếp đất). Chọn pattern theo phase + khoảng cách. |
| **Cai Ngục / Warden** (hp 14) | Cùng FSM, máu và nhịp tấn công cao hơn — boss cuối. |

Không sửa code ở T6, chỉ ghi nhận.

---

## 9. Thứ tự thực hiện & cách kiểm chứng

```
T1 audio  →  T2 flash  →  T3 nút + progress screen  →  T4 ending  →  T5 NPC AI  →  T6 doc
```
T1 phải xong trước T2 vì flash gọi sting.

**Đã kiểm được bằng máy:** Godot 4.7.2 nằm ở `/Applications/Godot.app/Contents/MacOS/Godot`.
Đã nạp thành công `main_menu`, `level_1`, `hub`, `end_screen`, `progress_screen` — **không lỗi biên
dịch, không lỗi runtime**, chỉ còn 2 warning có sẵn từ trước (`levels.gd:32` chia số nguyên,
`audio_manager.gd:71` tham số `name` che property của `Node`).

**Chưa kiểm được:** mọi thứ cần input thật (chết, thắng, nói chuyện với NPC, bấm nút). Checklist
playtest trong editor:
- [ ] Chết sạch tim khi **chưa** chạm checkpoint → thấy chữ "GỤC NGÃ" + nghe sting + sau đó mới sang Game Over.
- [ ] Chết khi **đã** chạm checkpoint → **không** có flash, bung lại tại checkpoint như cũ.
- [ ] Chạm cờ đích → chữ "HOÀN THÀNH!" + fanfare trong màn chơi.
- [ ] Màn Game Over hiện đủ **4 nút**; bấm từng nút đi đúng màn; "Tiến trình" quay lại được.
- [ ] Màn Tiến trình hiện đúng số liệu save (so với `user://save_data.json`).
- [ ] Hạ Warden ở `boss_dungeon` → flash `final` + tiêu đề "VƯƠNG MIỆN TRỞ VỀ!" + khối tổng kết.
- [ ] Vào hub: Dân làng đi tuần và bám theo player; Heo đào ngũ bỏ chạy khi lao tới, chịu nói khi đứng yên;
      Cố vấn nói đúng mục tiêu kế tiếp theo tiến độ save.
- [ ] NPC không đi xuyên portal / trôi khỏi sàn hub.
- [ ] Xoá `user://save_data.json` rồi chơi lại từ đầu → mục tiêu của Cố vấn về lại bước 1.
- [ ] Chạm cờ đích rồi **cố tình lao vào bẫy** trong lúc hiệu ứng thắng đang chạy → vẫn ra "YOU WIN!",
      không bị lật thành Game Over (xem mục 10, lỗi hồi quy do độ trễ mới).

---

## 10. Đã triển khai (20/09/2026, trên `main`)

Toàn bộ T1–T6 đã code xong. Khác biệt so với spec nháp ở trên, đã sửa ngay trong tài liệu:

1. **Chuỗi mục tiêu chuyển vào `Progression.next_objective()`** thay vì nhúng trong `npc.gd`.
   NPC Cố vấn và màn Tiến trình cùng đọc một nguồn → không thể nói hai điều khác nhau.
2. **Đính chính luồng Dash** — nhặt ở di vật cuối `level_2`, không phải phần thưởng boss (mục 7.2).
3. **Thêm cờ `GameManager.result_recorded`.** Từ `end_screen` sang màn Tiến trình rồi bấm "Quay lại"
   sẽ chạy `end_screen._ready()` lần nữa; không có cờ này thì `SaveManager.record_result` ghi hai lần
   và `Events.level_completed` bắn lại (Toast thành tựu hiện lại).
4. **Sửa lỗi hồi quy do chính T2 gây ra:** `win()` giờ chờ 1.2–2.0s cho hiệu ứng chạy, mà `Hurtbox`
   của player vẫn sống trong khoảng đó — một lưỡi cưa chạm vào là trừ máu tới 0, phát `died`, và lật
   kết quả vừa thắng thành "lose". `win()` nay tắt `hurtbox.monitoring` ngay khi bắt đầu chờ.
   (Hurtbox là bên chủ động dò Hitbox nên tắt `monitoring` ở đây đúng chiều, không dính gotcha
   "`monitoring=false` chặn cả việc bị area khác dò" ghi ở ROADMAP mục 11.2.)
5. **`leash_extra` thành `@export`** thay vì hằng số 48 cứng, để chỉnh được dây xích từng NPC cho
   khỏi lấn vào vùng `interact` của portal bên cạnh.

**File mới:** `game/ui/result_flash/`, `game/ui/progress_screen/`,
`game/audio/sfx/{game_over,victory,final_victory}.wav`.
**File sửa:** `core/{audio_manager,game_manager,progression}.gd`, `player/player.gd`,
`objects/npc/npc.gd`, `levels/hub/hub.tscn`, `ui/end_screen/*`, `ui/main_menu/*`.

---

## 11. Bổ sung 20/09/2026 — UI âm lượng + Việt hoá toàn bộ

Ngoài phạm vi 4 yêu cầu đồ án, làm theo yêu cầu trực tiếp. Vẫn trên `main`.

### 11.1 Thanh âm lượng

`HSlider` cũ hỏng thật chứ không chỉ xấu — chụp màn hình bằng Godot mới thấy:
texture nguồn chỉ 55×15px nhưng `texture_margin_left/right = 14` chừa lõi 27px để giãn ra 140px
→ thanh rách có mối nối; núm kéo dạt hẳn khỏi rãnh; `grabber_area` là `StyleBoxEmpty` nên
không có phần tô đầy → không nhìn ra đang ở mức nào; và không có số.

Thay bằng **thanh 10 ô + nút −/+**:
- Ô dựng trong code (giống `hud.gd` dựng icon tim) để số ô luôn khớp `VOLUME_STEPS`.
- Bấm/kéo thẳng trên dãy ô nhảy tới bậc đó; `size_flags_vertical = SHRINK_CENTER` giữ ô vuông
  thay vì bị `HBoxContainer` kéo cao bằng hàng nút.
- Nhãn `80%`, đổi thành `Tắt` ở mức 0; nút − / + tự khoá ở hai đầu.
- `AudioManager` tách `apply_master_volume()` (chỉ áp lên bus) khỏi `set_master_volume()`
  (áp + lưu) — `SaveManager.set_setting` gọi `save_data()` mỗi lần nên kéo rê mà lưu từng bậc
  là ghi file liên tục. `_ready` của AudioManager cũng chuyển sang `apply_` (giá trị vừa đọc
  từ save, ghi lại là thừa).

### 11.2 Việt hoá

Toàn bộ chữ hiển thị cho người chơi đã sang tiếng Việt: 34 chuỗi trong 12 `.tscn` + các chuỗi
định dạng trong `end_screen.gd`, `hud.gd`, `settings_menu.gd`, `npc.gd`, `hub_sign.gd`.
Không dựng lớp i18n — viết thẳng tiếng Việt (xem CLAUDE.md, mục Conventions).

Định danh giữ tiếng Anh: `CharacterData.NAMES` vẫn là `["King", "Captain"]` vì nó dùng để tra
thư mục sprite và lưu vào save; chỉ trường `display` đổi thành "Nhà Vua" / "Thuyền Trưởng".

Hai chỗ không nhất quán được thống nhất luôn:
- Boss cuối từng mang hai tên: `LevelData` + thẻ tiêu đề gọi "Người Gác Hầm", còn các dòng mục
  tiêu mới gọi "Cai Ngục". Chốt **"Cai Ngục"** (ngắn, vừa thanh máu).
- `boss_health_bar.tscn` hardcode "KING PIG" và không code nào đổi → trận boss cuối vẫn hiện tên
  Vua Heo. Thêm `Events.boss_intro(boss_id, display_name)`, `BossBase` phát khi vào trận
  (**deferred** — trong cả hai scene arena node boss đứng trước `BossHealthBar` nên phát ngay
  thì thanh máu chưa connect, bỏ lỡ cả tên lẫn máu ban đầu).

### 11.3 Kiểm chứng

Dựng harness `game/_dev_shot.tscn` (**gitignored, không commit**) — nạp một scene, chờ 40 frame
cho tween chạy xong, lưu PNG rồi thoát:

```
/Applications/Godot.app/Contents/MacOS/Godot --path game res://_dev_shot.tscn -- <res://scene.tscn> <out.png>
```

Đã nạp và chụp 12 scene (5 màn UI + progress + hud + hub + level_1 + 2 boss arena):
**không lỗi biên dịch, không lỗi runtime**, bố cục không vỡ dù chữ Việt dài hơn tiếng Anh.
Thanh máu boss cuối xác nhận hiện "CAI NGỤC".

> **Bẫy công cụ:** `sips -c H W` cắt ảnh **từ tâm**, không phải từ góc trái — `--cropOffset` là
> độ lệch so với tâm. Cắt nhầm từng làm tôi tưởng HUD không hiển thị; probe in `get_global_rect()`
> cho thấy HUD hoàn toàn bình thường. Xem ảnh đầy đủ trước khi kết luận.
