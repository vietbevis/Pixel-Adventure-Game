# Nội dung đã nghỉ (retired)

Các object ở đây KHÔNG còn được màn nào dùng, giữ lại để tham khảo / tái dùng sau.
Không xoá để lịch sử thiết kế còn nguyên, nhưng đừng đặt vào level mới trừ khi đã
cân nhắc lại.

| Folder | Thay bằng | Ghi chú |
|---|---|---|
| `walker/` | `objects/enemies/pig/` (Pig) | Quái đi bộ Kenney — lệch phong cách pack. |
| `chaser_spike/` | `objects/enemies/pig/pig_ambusher.tscn` (Pig GUARD) | FSM đuổi + leash — ý tưởng đã đưa vào EnemyBase. |
| `spike_head/` | (như trên) | Chỉ còn `chaser_spike` tham chiếu. |
| `moving_platform/` | `objects/traps/falling_platform/` | Bệ di chuyển one-way — các màn dùng falling_platform thay thế. |

Hazard vẫn dùng (KHÔNG nghỉ): `spikes`, `saw`, `orbit_saw`, `flyer`, `falling_spike`,
`spiked_ball`, `cannon`, `fire_trap`, `arrow_shooter`, `fan`, `trampoline`.
