class_name EnemyStats
extends Resource
## Thông số AI + di chuyển của 1 loại quái. Gán vào `EnemyBase.stats` (1 file .tres
## mỗi loại). Máu để riêng trên `HealthComponent` của scene — component tự quản.

## Tốc độ tuần tra (px/giây). `EnemyBase.patrol_speed > 0` sẽ ghi đè giá trị này
## (giữ tương thích với override cũ trong các level scene).
@export var move_speed: float = 34.0
## Tốc độ khi đuổi theo player.
@export var chase_speed: float = 62.0
## Sát thương đòn đánh (gán vào Hitbox của quái lúc _ready).
@export var damage: int = 1

## Bán kính (px) phát hiện player để chuyển sang CHASE.
@export var detect_range: float = 110.0
## Đuổi xa quá khoảng này (px, tính từ điểm gác) thì bỏ cuộc.
@export var leash_range: float = 220.0

## Khoảng cách (px) tới player để vào ATTACK.
@export var attack_range: float = 24.0
## Nghỉ giữa 2 đòn (giây).
@export var attack_cooldown: float = 1.3

## Vận tốc bị hất khi trúng đòn (px/giây) + thời gian khoá AI trong lúc đó.
@export var knockback_speed: float = 150.0
@export var knockback_time: float = 0.18
