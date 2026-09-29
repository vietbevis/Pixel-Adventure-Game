# Tích hợp Gemini AI vào Pixel Adventure (2D) và Temple Run Pro Max (3D)

Ngày: 2026-09-29 · Trạng thái: chờ duyệt

> Spec này dùng chung cho cả hai repo (`Pixel-Adventure/` và `temple-run-pro-max/`); mỗi repo giữ một bản giống hệt.

## 1. Mục tiêu và phạm vi

**Mục đích:** demo cho bài tập lớn — cho thấy hai game dùng Gemini API để tạo nội dung động, chạy trên máy tính và điện thoại Android của tác giả. Không phát hành công khai.

**Tiêu chí thành công**
- Cả 7 tính năng dưới đây chạy được với một Gemini API key thật.
- Không có key / tắt AI / mất mạng / hết quota / quá thời gian → game chạy **y hệt như hiện tại**, không treo, không lỗi đỏ, không phải chờ.
- API key không bao giờ nằm trong git.
- Không có request mạng nào chặn gameplay (không `await` mạng giữa lúc đang chạy/đánh boss).

**Tính năng**

| Game | Tính năng | Đợt |
|---|---|---|
| Cả hai | Client `Gemini` dùng chung + công tắc AI trong Cài đặt | 1 |
| 3D | Bình luận viên cuối lượt | 1 |
| 2D | NPC trò chuyện AI | 1 |
| 3D | Huấn luyện viên AI (màn Thống kê) | 2 |
| 3D | Truyền thuyết vùng cảnh | 2 |
| 2D | Lời thoại boss động | 2 |
| 3D | Nhiệm vụ do AI tạo | 3 |
| 2D | Gợi ý khi kẹt | 3 |

**Ngoài phạm vi:** proxy server, streaming, hình ảnh/giọng nói, function calling, cho người chơi tự nhập key.

## 2. Nguyên tắc chung

1. **AI là lớp phủ, không phải phụ thuộc.** Mỗi tính năng có nội dung dự phòng tĩnh. Khi `Gemini.enabled == false` thì tính năng hoặc dùng dự phòng, hoặc ẩn hẳn UI của AI.
2. **AI không quyết định luật chơi.** Mọi output có cấu trúc (nhiệm vụ, món đồ gợi ý) phải được game kiểm tra lại với dữ liệu thật (`Catalog`, ...) và kẹp giá trị trước khi dùng.
3. **Gọi trước, dùng sau.** Nội dung cần trong lúc chơi (lời boss, truyền thuyết vùng, gợi ý) được **prefetch** ở thời điểm yên tĩnh (menu, intro boss, lần chết thứ 2) và cache lại.
4. **Output ngắn, có giới hạn.** `maxOutputTokens` nhỏ, cắt độ dài phía client, lọc markdown.

## 3. Client dùng chung: autoload `Gemini`

**Vị trí:** `addons/gemini/gemini.gd` — cùng một file, copy nguyên vào cả hai project, đăng ký autoload tên `Gemini`. Không phụ thuộc gì vào code của game.

### 3.1 API công khai

```gdscript
signal enabled_changed(enabled: bool)

var enabled: bool          # có key VÀ người chơi bật AI (read-only từ ngoài)
var model: String          # đọc từ config, mặc định "gemini-2.5-flash-lite"

## Trả về "" nếu thất bại (không key, timeout, lỗi HTTP, bị chặn an toàn...).
func generate_text(prompt: String, opts := {}) -> String

## Structured output: gửi responseSchema, trả về Dictionary/Array đã parse,
## hoặc null nếu thất bại / JSON sai.
func generate_json(prompt: String, schema: Dictionary, opts := {}) -> Variant

## Hội thoại nhiều lượt. history = [{"role": "user"|"model", "text": String}, ...]
func chat(history: Array, opts := {}) -> String

func set_user_enabled(on: bool) -> void   # công tắc trong Cài đặt
func has_key() -> bool
```

`opts` (tuỳ chọn): `system` (system instruction), `temperature` (mặc định 0.9), `max_tokens` (mặc định 200), `timeout` (mặc định 8 s), `cache_key` (String — nếu có, lưu/trả kết quả từ cache), `persist` (bool — cache ghi ra đĩa).

Mọi hàm là coroutine: người gọi dùng `await Gemini.generate_text(...)`. Khi `enabled == false` các hàm trả về ngay (`""` / `null`) mà không tạo request.

### 3.2 Đọc API key và cấu hình

Thứ tự ưu tiên (lấy nguồn đầu tiên có key):
1. Biến môi trường `GEMINI_API_KEY` — tiện khi chạy trên máy tính.
2. `user://gemini.cfg` — file ConfigFile trong thư mục dữ liệu của game.
3. `res://gemini.local.cfg` — file nằm trong project, **được thêm vào `.gitignore`**, dùng để đóng gói key vào APK khi demo trên điện thoại.

Định dạng file:
```ini
[gemini]
api_key="AIza..."
model="gemini-2.5-flash-lite"
```

Repo có file mẫu `gemini.example.cfg` (không chứa key) để hướng dẫn. Ghi chú trong README: key trong APK có thể bị trích xuất — chỉ chấp nhận được vì đây là bản demo cá nhân; nên tạo key riêng cho demo và giới hạn quota trong Google AI Studio.

Công tắc người chơi (`set_user_enabled`) được lưu vào `user://gemini_prefs.cfg` bởi chính client — không đụng vào save của từng game.

### 3.3 Request

- `POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`
- Header `x-goog-api-key: <key>` (không đặt key trên URL để không lọt vào log).
- Body: `contents`, `systemInstruction`, `generationConfig {temperature, maxOutputTokens, responseMimeType?, responseSchema?}`.
- Mỗi request một node `HTTPRequest` con, `timeout` = `opts.timeout`, `queue_free` sau khi xong.
- Đọc kết quả từ `candidates[0].content.parts[*].text` (nối các part lại).

### 3.4 Bảo vệ và xử lý lỗi

| Tình huống | Xử lý |
|---|---|
| Không có key / người chơi tắt | `enabled = false`, trả về ngay |
| Timeout, lỗi mạng (`result != RESULT_SUCCESS`) | trả `""`/`null`, `push_warning` 1 dòng |
| HTTP 429 (hết quota) | trả thất bại + **cooldown 60 s**: mọi lời gọi trong 60 s trả thất bại ngay |
| HTTP 400/403 (key sai, model sai) | trả thất bại + tắt AI đến hết phiên, `push_warning` rõ nguyên nhân |
| HTTP 5xx | trả thất bại (không retry — người gọi đã có dự phòng) |
| Không có `candidates` / `finishReason` = SAFETY | trả thất bại |
| `generate_json` parse lỗi hoặc sai kiểu | trả `null` |
| Quá 2 request đồng thời | request thứ 3 trả thất bại ngay |

Không bao giờ in key ra log. Làm sạch text trả về: bỏ `*`, `#`, backtick, gộp khoảng trắng, `strip_edges()`.

### 3.5 Cache

Dictionary trong bộ nhớ theo `cache_key`. Nếu `persist = true` thì ghi thêm vào `user://gemini_cache.json` (dùng cho truyền thuyết vùng). Mỗi mục có `saved_at` (unix time); hàm `cache_age(key)` để tính năng tự quyết định khi nào làm mới.

### 3.6 Kiểm thử được

Client có biến `transport: Callable` (mặc định gửi HTTP thật). Test gán một Callable giả trả về `{code, body}` để chạy mọi nhánh lỗi mà không cần mạng.

## 4. Công tắc AI trong Cài đặt (cả hai game)

Thêm một dòng bật/tắt "Tính năng AI (Gemini)" vào màn Cài đặt, dùng component có sẵn (`toggle_row` ở 3D, `IconToggle` ở 2D). Nếu `Gemini.has_key() == false` thì dòng hiện mờ kèm chú thích "Chưa có API key". Công tắc này cho phép demo trực tiếp chế độ dự phòng.

## 5. Temple Run Pro Max (3D)

Prompt luôn yêu cầu trả lời bằng ngôn ngữ hiện tại (`Loc`: Tiếng Việt / English) và nêu phong cách hiện tại (Cổ điển / Hiện đại) để giọng văn khớp bối cảnh.

### 5.1 Bình luận viên cuối lượt (đợt 1)

- **File:** `scripts/ai/run_commentary.gd` (lớp tĩnh `RunCommentary`) + thêm khung "Bình luận" vào màn Kết quả.
- **Khi nào:** `results_screen.build()` hiện khung với chữ "…" rồi gọi `await RunCommentary.fetch(summary)`.
- **Dữ liệu gửi:** quãng đường, điểm, xu, ngọc, nguyên nhân kết thúc (`fall`/`caught`), số lần trúng đòn, số lần hồi sinh, kỷ lục trước đó, có phá kỷ lục không, vùng cảnh xa nhất đã tới, nhân vật đang dùng.
- **Output:** `generate_text`, tối đa 2 câu, ~160 ký tự: một câu nhận xét + một lời khuyên.
- **Dự phòng:** chọn ngẫu nhiên từ bộ câu tĩnh theo nguyên nhân kết thúc và việc có phá kỷ lục không (khoảng 4 câu/nhóm, 2 ngôn ngữ, đặt trong `Catalog`). Nếu AI tắt, khung vẫn hiện với câu dự phòng.
- Nếu người chơi rời màn Kết quả trước khi có kết quả thì bỏ qua kết quả (kiểm tra `is_instance_valid`).

### 5.2 Huấn luyện viên AI (đợt 2)

- **File:** `scripts/ai/coach.gd` + nút "Lời khuyên từ HLV" trên màn Thống kê.
- **Dữ liệu gửi:** chỉ số tổng hợp từ `Profile` (số lượt, bị bắt vs rơi vực, quãng đường trung bình/kỷ lục, nhảy/trượt/rẽ trung bình mỗi lượt, số lần hồi sinh), cấp hiện tại của các nâng cấp, số xu, danh sách `id` + tên + giá của nâng cấp/đồ trong shop.
- **Output:** `generate_json` với schema `{advice: string, recommend_id: string}`.
- **Kiểm tra:** `recommend_id` phải tồn tại trong Catalog và chưa max cấp; sai → bỏ phần gợi ý, chỉ giữ `advice`.
- **Dự phòng (luật cứng):** rơi vực > bị bắt → khuyên chú ý ngã rẽ; ngược lại → khuyên trượt/nhảy sớm hơn; gợi ý nâng cấp rẻ nhất chưa max mà người chơi mua được.
- **Cache:** theo `cache_key = "coach_%d" % runs` — chưa chơi thêm lượt thì không gọi lại.

### 5.3 Truyền thuyết vùng cảnh (đợt 2)

- **File:** `scripts/ai/biome_lore.gd`.
- **Prefetch:** khi vào menu, nếu cache của (phong cách, ngôn ngữ) cũ hơn 24 h hoặc chưa có → một lời gọi `generate_json` trả về `{biomes: [{index, lines: [string, string, string]}]}` cho tất cả vùng của phong cách hiện tại. `persist = true`.
- **Trong lượt chạy:** `main.gd` đang hiện banner "Đang vào\n<tên vùng>" khi `biome_changed`; thêm một dòng truyền thuyết lấy ngẫu nhiên từ cache. **Không có request mạng nào trong lượt chạy.**
- **Kiểm tra:** mỗi câu ≤ 90 ký tự, `index` hợp lệ; câu sai thì bỏ.
- **Dự phòng:** không có cache → banner giữ nguyên như hiện tại.

### 5.4 Nhiệm vụ do AI tạo (đợt 3)

- **File:** `scripts/ai/mission_designer.gd` + sửa nhỏ trong `Profile`.
- **Prefetch:** khi vào menu, nếu hàng đợi `Profile.data.ai_missions` còn ít hơn 3 → gọi `generate_json`, schema `{missions: [{template_id, target, text_en, text_vi}]}`, kèm danh sách template trong `Catalog.MISSIONS` (id, loại, mô tả, các mốc target), cấp nhiệm vụ, kỷ lục và trung bình của người chơi.
- **Kiểm tra từng nhiệm vụ:** `template_id` có trong `Catalog.MISSIONS`; `target` kẹp trong `[targets[0], targets[-1]]` và làm tròn về số "đẹp" (bội của 5/10/50 theo độ lớn); text không rỗng, ≤ 60 ký tự, có chứa con số target — sai thì dùng tên template gốc.
- **Dùng:** `_new_mission()` vẫn đồng bộ như cũ; lấy nhiệm vụ đầu hàng đợi nếu template chưa trùng với nhiệm vụ đang hoạt động, không thì random như cũ. Nhiệm vụ AI có thêm khoá `"text": [en, vi]`; `mission_text()` dùng `text` nếu có. Mọi chỗ đọc dùng `.get()` để save cũ vẫn chạy.
- **Dự phòng:** hàng đợi rỗng → hành vi y như hiện tại.

## 6. Pixel Adventure (2D)

Prompt tiếng Việt; bối cảnh lấy từ `Progression.next_objective()`, `SaveManager` (ability đã mở, boss đã hạ), `CharacterData` (nhân vật đang chơi).

### 6.1 NPC trò chuyện AI (đợt 1)

- **File mới:** `ui/ai_chat/ai_chat.tscn` + `ai_chat.gd` (CanvasLayer, `process_mode = ALWAYS`).
- **Sửa `npc.gd`:** thêm `@export_multiline var ai_persona: String` (tính cách + vai trò NPC, viết tay cho 3 NPC ở hub). Khi bấm `interact`:
  - `Gemini.enabled` và `ai_persona` khác rỗng → mở `AiChat` thay cho `Dialogue`.
  - Ngược lại → `Dialogue.open(...)` như hiện tại (không đổi hành vi).
- **Giao diện AiChat:** chân dung/tên NPC, khung câu trả lời, 3 nút câu hỏi gợi ý ("Tôi nên đi đâu tiếp?", "Kể về vùng đất này", "Có bí mật gì không?") để chơi bằng cảm ứng, một ô `LineEdit` (≤ 120 ký tự) + nút Gửi, nút Tạm biệt. Câu chào đầu tiên là `line_1` tĩnh của NPC (hiện ngay, không chờ mạng).
- **Trong lúc chat:** `get_tree().paused = true` để phím gõ không điều khiển nhân vật; đóng thì bỏ pause và đặt cooldown giống `Dialogue.REOPEN_COOLDOWN_MS` để phím đóng không mở lại hộp thoại. `Dialogue.is_open` phải tính cả `AiChat` đang mở để portal/biển báo không kích hoạt trùng.
- **Gọi AI:** `Gemini.chat(history, {system: persona + bối cảnh + luật})`, giữ 6 lượt gần nhất. System instruction: luôn nhập vai, trả lời ≤ 2 câu, không bịa phần thưởng/cơ chế không có, từ chối nhẹ nhàng các câu hỏi ngoài thế giới game.
- **Lỗi giữa chừng:** hiện câu tĩnh kiểu "…(NPC gãi đầu) Ta không nhớ ra." và vẫn cho hỏi tiếp.

### 6.2 Lời thoại boss động (đợt 2)

- **File mới:** `core/boss_voice.gd` (autoload `BossVoice`) + `ui/boss_taunt/boss_taunt.tscn` (label hiện dưới thanh máu boss, mờ dần sau 3 s).
- **Prefetch một lần mỗi trận:** khi `Events.boss_intro` → `generate_json` schema `{intro, phase_2, player_died, defeated}` (mỗi câu ≤ 70 ký tự) với tên boss, số lần đã thử (lưu mới trong `SaveManager`: `boss_attempts`), nhân vật người chơi, các ability đã có.
- **Hiện:** `boss_intro` → hiện `intro` (hoặc dự phòng nếu request chưa xong sau 1,5 s); `boss_phase_changed` → `phase_2`; `player_died` trong màn boss → `player_died`; `boss_defeated` → `defeated`. Chỉ đọc cache — không chờ mạng giữa trận.
- **Dự phòng:** bộ câu tĩnh cho mỗi boss (`king_pig`, `ghost_warden`) trong `boss_voice.gd`.

### 6.3 Gợi ý khi kẹt (đợt 3)

- **File mới:** `core/stuck_helper.gd` (autoload `StuckHelper`) + `core/level_notes.gd` (mô tả tay 1–2 câu về chướng ngại/quái của từng màn, dùng làm ngữ cảnh cho prompt và làm dự phòng).
- **Theo dõi:** đếm `Events.player_died` theo `level_started`; reset khi `level_completed` hoặc đổi màn.
- **Lần chết thứ 2:** prefetch gợi ý (`generate_text`, ≤ 2 câu) với ghi chú màn, số lần chết, nhân vật, ability, vị trí checkpoint gần nhất (có hay không).
- **Lần chết thứ 3 (rồi mỗi 3 lần):** sau khi hồi sinh, `Dialogue.open([gợi ý], "Cố vấn")`. Chưa có kết quả AI → dùng ghi chú tĩnh của màn.
- Không kích hoạt ở hub.

## 7. Android

- `export_presets.cfg`: bật `permissions/internet=true`; thêm `gemini.local.cfg` vào `include_filter` để file key được đóng gói.
- Pixel Adventure chưa có `export_presets.cfg` — tạo khi export lần đầu, áp dụng cùng 2 thiết lập.
- Bàn phím ảo: `LineEdit` trong AiChat dùng `virtual_keyboard_enabled` mặc định; kiểm tra khung chat không bị bàn phím che (đặt khung ở nửa trên màn hình).

## 8. Kiểm thử

**Tự động (headless, không cần mạng):** `tests/test_gemini.gd` chạy bằng `Godot --headless --script`, dùng `transport` giả để kiểm:
- không key → `enabled == false`, trả về ngay, không gọi transport;
- 200 hợp lệ → parse đúng text và JSON;
- 429 → thất bại + cooldown; 403 → tắt đến hết phiên; timeout → thất bại;
- JSON hỏng → `null`; text được làm sạch markdown;
- hàm kiểm tra nhiệm vụ AI (template sai, target vượt ngưỡng, text rỗng) và gợi ý nâng cấp (id không tồn tại).

Cùng file test được copy vào cả hai project.

**Thủ công (demo checklist) cho mỗi tính năng:** (1) có key → thấy nội dung AI; (2) tắt AI trong Cài đặt → thấy dự phòng; (3) tắt Wi-Fi → thấy dự phòng, không treo; (4) key sai → một cảnh báo trong log, game vẫn chạy. Pixel Adventure: thêm kiểm tra vào `_dev_playtest.tscn` cho luồng NPC khi AI tắt (không hồi quy).

## 9. File thay đổi (tóm tắt)

**Cả hai:** `addons/gemini/gemini.gd` (mới), `tests/test_gemini.gd` (mới), `gemini.example.cfg` (mới), `.gitignore` (+`gemini.local.cfg`), `project.godot` (autoload), màn Cài đặt (công tắc), README (hướng dẫn key).

**3D:** `scripts/ai/{run_commentary,coach,biome_lore,mission_designer}.gd` (mới); `results_screen`, `stats_screen`, `main.gd`, `profile.gd`, `catalog.gd` (câu dự phòng), `export_presets.cfg`.

**2D:** `ui/ai_chat/*`, `ui/boss_taunt/*`, `core/{boss_voice,stuck_helper,level_notes}.gd` (mới); `objects/npc/npc.gd`, hub scene (persona cho 3 NPC), `ui/dialogue/dialogue.gd` (`is_open` tính cả AiChat), `core/save_manager.gd` (`boss_attempts`), `project.godot`.
