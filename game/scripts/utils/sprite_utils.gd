class_name SpriteUtils
extends RefCounted

## Slices a horizontal sprite-sheet strip into an animation and adds it to sprite_frames.
static func add_animation_from_strip(
	sprite_frames: SpriteFrames,
	anim_name: String,
	texture: Texture2D,
	frame_size: Vector2i,
	fps: float = 10.0,
	do_loop: bool = true
) -> void:
	if sprite_frames.has_animation(anim_name):
		sprite_frames.remove_animation(anim_name)
	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_speed(anim_name, fps)
	sprite_frames.set_animation_loop(anim_name, do_loop)

	@warning_ignore("integer_division")
	var frame_count: int = texture.get_width() / frame_size.x
	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * frame_size.x, 0, frame_size.x, frame_size.y)
		sprite_frames.add_frame(anim_name, atlas)
