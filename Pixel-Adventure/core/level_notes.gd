class_name LevelNotes
extends RefCounted
## Ghi chú tay về chướng ngại / quái của từng màn. StuckHelper gửi cho Gemini làm ngữ cảnh,
## và hiện thẳng làm gợi ý khi AI tắt/lỗi. Thêm màn mới trong LevelData → thêm ghi chú ở đây.

const NOTES := {
	"level_1": "Bìa rừng: gai, cưa, thú nhỏ. Nhảy đôi để qua hố rộng, đạp lên đầu quái để hạ chúng.",
	"level_2": "Leo dọc: bám tường rồi nhảy tường, dùng quạt gió đẩy lên, ván gỗ sẽ rơi nếu đứng lâu. Cuối màn nhặt di vật Lướt rồi lướt qua tường vỡ.",
	"level_3": "Tường thành: qua hào bằng bè, lướt để phá cổng, khối đá nghiền rơi khi đứng ngay dưới — chờ nó nâng lên rồi chạy qua.",
	"level_4": "Hành lang ngai: sóng lửa đuổi theo, bệ di chuyển trên hố gai, phòng đại bác, quả cầu gai lắc — canh nhịp rồi mới nhảy.",
	"boss_forest": "Vua Heo: chỉ vụ nổ của bom gây sát thương; từ giai đoạn 2 hắn lao húc (nhảy lên né, hắn choáng khi đâm tường — lúc đó đánh); giai đoạn 3 nhảy dập tạo sóng xung kích sát đất.",
	"level_5": "Lối xuống hầm: gai rơi từ trần, bộ xương trỗi dậy khi lại gần, hồn ma bay xuyên tường — lúc hồn ma mờ đi thì không đánh được.",
	"level_6": "Hầm vàng: chó săn lao tới khi đứng ngang hàng, cưa chạy trên ray, kim tự tháp lửa, bệ sụp trên vực — đừng đứng lâu trên bệ nứt.",
	"boss_dungeon": "Cai Ngục (bay): lao chéo xuống rồi lơ lửng thấp — đó là lúc đánh; gọi 2 bộ xương; giai đoạn 2 mưa cầu linh hồn có cảnh báo trên sàn; giai đoạn 3 biến mất rồi hiện sau lưng chém.",
}


static func tip(level_id: String) -> String:
	return String(NOTES.get(level_id, ""))
