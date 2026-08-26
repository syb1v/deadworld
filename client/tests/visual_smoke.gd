extends SceneTree

## Визуальный smoke-тест мира.
##
## Рендерит мир, атмосферу и сущности в offscreen-виewport и сохраняет PNG.
## Нужен, чтобы проверять визуал численно (контраст, палитра, освещение),
## а не «на глаз»: регрессия отрисовки иначе замечается только вручную.
##
##     godot --path client --script res://tests/visual_smoke.gd -- --out=/tmp/shot.png

const WorldMapScript = preload("res://scripts/world/WorldMap.gd")
const AtmosphereScript = preload("res://scripts/world/Atmosphere.gd")
const PlayerScript = preload("res://scripts/entities/Player.gd")
const ZombieScript = preload("res://scripts/entities/Zombie.gd")
const WorldItemScript = preload("res://scripts/entities/WorldItem.gd")
const ContainerScript = preload("res://scripts/entities/Container.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := "/tmp/opencode/deadworld_visual.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var world := Node2D.new()
	viewport.add_child(world)

	var map := Node2D.new()
	map.set_script(WorldMapScript)
	world.add_child(map)

	# Игрок в центре зоны сбора — типичная стартовая позиция.
	var player := Node2D.new()
	player.set_script(PlayerScript)
	world.add_child(player)
	player.position = Vector2(640, 380)
	player.setup(true)
	player.set_authoritative_position(Vector2(640, 380))
	player.set_authoritative_state({"health": 78, "state": "idle", "vx": 0.0, "vy": 0.0})

	var zombie := Node2D.new()
	zombie.set_script(ZombieScript)
	world.add_child(zombie)
	zombie.apply_snapshot({"id": "zombie:1", "x": 745, "y": 420, "hp": 60, "state": "chase"})

	var item := Node2D.new()
	item.set_script(WorldItemScript)
	world.add_child(item)
	item.setup({"id": "item:1", "definitionId": "pistol", "x": 570, "y": 430, "quantity": 1})

	var box := Node2D.new()
	box.set_script(ContainerScript)
	world.add_child(box)
	box.setup({"id": "container:1", "x": 700, "y": 330, "version": 1, "items": [{"id": "a"}]})

	var atmosphere := Node2D.new()
	atmosphere.set_script(AtmosphereScript)
	world.add_child(atmosphere)
	atmosphere.set_player(player)

	var camera := Camera2D.new()
	camera.set_script(preload("res://scripts/world/GameCamera.gd"))
	world.add_child(camera)
	camera.make_current()
	camera.set_target(player)

	# Даём кадрам стабилизироваться: камера и атмосфера считают позицию
	# в _process, поэтому первый кадр ещё не репрезентативен.
	for frame in range(6):
		await process_frame

	var image := viewport.get_texture().get_image()
	image.save_png(output)
	print("visual smoke saved: ", output)
	quit()
