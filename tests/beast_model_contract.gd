extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const MODELS := [
	{
		"scene": "res://levels/level_01.tscn",
		"node": "Enemies/WolfKing/BeastVisual/WhiteTigerModel",
		"texture": "white_tiger.png",
		"scale": 0.65,
		"ground": 6.0,
	},
	{
		"scene": "res://levels/level_02.tscn",
		"node": "Enemies/BearKing/BeastVisual/VermilionBirdModel",
		"texture": "vermilion_bird.png",
		"scale": 0.68,
		"ground": -18.0,
	},
	{
		"scene": "res://levels/level_03.tscn",
		"node": "Enemies/ElkKing/BeastVisual/BlackTortoiseModel",
		"texture": "black_tortoise.png",
		"scale": 0.7,
		"ground": -2.0,
	},
	{
		"scene": "res://levels/level_04.tscn",
		"node": "Enemies/Valdemar/BeastVisual/AzureDragonModel",
		"texture": "azure_dragon.png",
		"scale": 0.9,
		"ground": 0.0,
	},
]

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	for spec in MODELS:
		var level := (load(spec["scene"]) as PackedScene).instantiate()
		var model := level.get_node_or_null(spec["node"]) as Sprite2D
		fixture.expect(model != null, "%s contains its themed boss model" % spec["scene"])
		if model != null:
			fixture.expect(
				model.texture.resource_path.ends_with(spec["texture"]),
				"%s uses %s" % [spec["scene"], spec["texture"]]
			)
			fixture.expect(
				model.get("attack_frame_paths").size() == 8,
				"%s has eight attack animation frames" % spec["scene"]
			)
			fixture.expect(
				model.get("move_frame_paths").size() == 8,
				"%s has eight movement animation frames" % spec["scene"]
			)
			fixture.expect(
				is_equal_approx(model.scale.x, float(spec["scale"])),
				"%s model scale matches its body collision" % spec["scene"]
			)
			fixture.expect(
				is_equal_approx(
					float(model.get("ground_offset_y")),
					float(spec["ground"])
				),
				"%s model is aligned to the ground" % spec["scene"]
			)
		level.free()

	var vermilion_level := (
		load("res://levels/level_02.tscn") as PackedScene
	).instantiate()
	var vermilion_cooldown := vermilion_level.get_node(
		"Enemies/BearKing/SkillDetect/Cooldown"
	) as Timer
	fixture.expect(
		is_equal_approx(vermilion_cooldown.wait_time, 2.0),
		"Vermilion Bird uses the increased attack frequency"
	)
	vermilion_level.free()

	var wolf_king := (
		load("res://enemies/wolf_king.tscn") as PackedScene
	).instantiate()
	fixture.add_node(wolf_king)
	await fixture.process_frames(1)
	var animated_model := wolf_king.get_node(
		"BeastVisual/WhiteTigerModel"
	) as Sprite2D
	var idle_texture := animated_model.texture
	wolf_king.set("state", 5)
	await fixture.wait_seconds(0.2)
	fixture.expect(
		animated_model.texture != idle_texture,
		"White Tiger plays generated attack frames during its warning"
	)
	wolf_king.set("state", 0)
	await fixture.process_frames(3)
	fixture.expect(
		animated_model.texture == idle_texture,
		"White Tiger returns to its idle model after the attack state"
	)
	wolf_king.set("state", 1)
	await fixture.wait_seconds(0.15)
	fixture.expect(
		"white_tiger_move/frames" in animated_model.texture.resource_path,
		"White Tiger plays generated movement frames while running"
	)

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()
