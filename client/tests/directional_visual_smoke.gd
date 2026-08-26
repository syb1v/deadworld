extends SceneTree

const LayeredCharacter = preload("res://scripts/entities2d/LayeredCharacter.gd")
const DIRECTIONS := [
	Vector2.UP, Vector2(1, -1), Vector2.RIGHT, Vector2(1, 1),
	Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1)
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := "/tmp/opencode/deadworld_directions.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 360)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("111713")
	background.size = Vector2(1280, 360)
	viewport.add_child(background)
	var world := Node2D.new()
	viewport.add_child(world)
	for index in range(DIRECTIONS.size()):
		var actor: Node2D = LayeredCharacter.new()
		actor.asset_id = "survivor"
		world.add_child(actor)
		actor.apply_snapshot(Vector2(90 + index * 155, 255), Vector2.ZERO, DIRECTIONS[index], &"idle")
	for frame in range(12):
		await process_frame
	var texture := viewport.get_texture()
	if texture == null:
		push_error("directional visual smoke did not produce a viewport texture")
		quit(1)
		return
	var image := texture.get_image()
	if image == null:
		push_error("directional visual smoke did not produce an image")
		quit(1)
		return
	image.save_png(output)
	print("directional visual smoke saved: ", output)
	quit()
