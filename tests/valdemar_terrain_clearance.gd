extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const PLAYER_SCENE := preload("res://player/player.tscn")
const VALDEMAR_SCENE := preload("res://enemies/valdemar.tscn")

const FLOOR_TOP := 77.0
const WALL_CENTER_X := -200.0
const WALL_WIDTH := 40.0
const WALL_HEIGHT := 400.0

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	_add_floor()
	_add_wall()

	var player := fixture.instantiate_scene(PLAYER_SCENE) as DamageableActor
	var valdemar := fixture.instantiate_scene(VALDEMAR_SCENE) as DamageableActor
	fixture.set_current_scene(valdemar)
	await fixture.process_frames(2)

	player.set_physics_process(false)
	player.global_position = Vector2(-500.0, 0.0)
	valdemar.call("_on_awakening_boundary_body_entered", player)
	valdemar.call("begin_awakening")
	await fixture.wait_seconds(1.0)
	await fixture.physics_frames(2)

	player.collision_layer = 0
	player.collision_mask = 0
	(valdemar.get_node("SwordGleamCooldown") as Timer).start(9999.0)
	(valdemar.get_node("BlackWaterCooldown") as Timer).stop()

	var observed_airborne := false
	var passed_wall := false
	for _frame in 240:
		await fixture.physics_frames(1)
		observed_airborne = observed_airborne or not valdemar.is_on_floor()
		if valdemar.global_position.x < WALL_CENTER_X - WALL_WIDTH * 0.5 - 50.0:
			passed_wall = true
			break

	fixture.expect(
		not observed_airborne and passed_wall,
		"Qinglong ignores TileMap-style walls while its dedicated floor keeps it grounded "
		+ "(airborne=%s passed=%s position=%s)"
		% [observed_airborne, passed_wall, valdemar.global_position]
	)

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func _add_floor() -> void:
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(1600.0, 80.0)
	floor_body.collision_layer = 8
	floor_body.collision_mask = 0
	floor_shape.shape = rectangle
	floor_shape.position = Vector2(0.0, FLOOR_TOP + rectangle.size.y * 0.5)
	floor_body.add_child(floor_shape)
	fixture.add_node(floor_body)


func _add_wall() -> void:
	var wall_body := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(WALL_WIDTH, WALL_HEIGHT)
	wall_shape.shape = rectangle
	wall_shape.position = Vector2(
		WALL_CENTER_X,
		FLOOR_TOP - WALL_HEIGHT * 0.5
	)
	wall_body.add_child(wall_shape)
	fixture.add_node(wall_body)
