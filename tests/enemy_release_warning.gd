extends SceneTree


const BEAR_SCENE := preload("res://enemies/bear.tscn")
const ELK_SCENE := preload("res://enemies/elk.tscn")
const GUARD_SCENE := preload("res://enemies/guard.tscn")
const VALDEMAR_SCENE := preload("res://enemies/valdemar.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const RELEASE_WARNING_DURATION := 0.7

const ENEMY_EXAMPLES := [
	{
		"name": "Bear",
		"scene": BEAR_SCENE,
		"detector_offset": Vector2(-152.0, 42.5),
		"release_player": NodePath("Earthquake/AnimationPlayer"),
	},
	{
		"name": "Elk",
		"scene": ELK_SCENE,
		"detector_offset": Vector2(-172.0, 0.0),
		"release_player": NodePath("SkillDetect/Thunder/AnimationPlayer"),
	},
	{
		"name": "Guard",
		"scene": GUARD_SCENE,
		"detector_offset": Vector2(-92.5, 9.0),
		"release_player": NodePath("SkillDetect/SwordGleam/AnimationPlayer"),
	},
]

var fixture: HeadlessGameplayFixture
var harness: EnemySceneHarness


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	fixture.set_project_setting("physics/2d/default_gravity", 0.0)
	var world := fixture.add_node(Node2D.new()) as Node2D
	fixture.set_current_scene(world)
	harness = EnemyHarness.new(fixture, world)

	await test_other_enemies_warn_before_releasing()
	await test_valdemar_warns_before_sword_gleam()
	await test_valdemar_warning_keeps_gravity()
	await test_valdemar_warns_before_black_water()

	fixture.complete(false)
	await fixture.process_frames(2)
	fixture.complete()


func test_other_enemies_warn_before_releasing() -> void:
	var start_x := 1000.0
	for example in ENEMY_EXAMPLES:
		var start_position := Vector2(start_x, 0.0)
		var enemy := harness.instantiate_enemy(
			example.scene,
			start_position,
			{"idle_duration": 10.0, "patrol_range": 1000.0}
		)
		var detector := harness.add_body(start_position + example.detector_offset)
		var warning := enemy.get_node_or_null("WarnMark") as Node2D
		var release_player := enemy.get_node(
			example.release_player
		) as AnimationPlayer
		var cooldown := enemy.get_node("SkillDetect/Cooldown") as Timer

		await fixture.physics_frames(3)
		fixture.expect(
			warning != null and warning.visible,
			"%s visibly starts its Enemy Release Warning" % example.name
		)
		fixture.expect(
			not _is_casting(release_player) and cooldown.is_stopped(),
			"%s does not release or start cooldown during its warning" % example.name
		)

		var health_before_warning: int = enemy.call("get_current_health")
		detector.queue_free()
		var weapon := harness.add_weapon(enemy.global_position)
		await fixture.physics_frames(2)
		weapon.queue_free()
		fixture.expect(
			enemy.call("get_current_health") == health_before_warning,
			"%s warning rejects weapon damage after Player departure" % example.name
		)

		await fixture.wait_seconds(RELEASE_WARNING_DURATION - 0.15)
		fixture.expect(
			warning != null
			and warning.visible
			and enemy.global_position.is_equal_approx(start_position)
			and not _is_casting(release_player)
			and cooldown.is_stopped(),
			"%s remains stationary and harmless for the full warning" % example.name
		)

		await fixture.wait_seconds(0.15)
		await fixture.physics_frames(2)
		fixture.expect(
			warning != null
			and not warning.visible
			and _is_casting(release_player)
			and not cooldown.is_stopped(),
			(
				(
					"%s releases and starts cooldown only after its warning; "
					+ "warning=%s casting=%s cooldown_stopped=%s"
				)
				% [
					example.name,
					warning.visible if warning != null else null,
					_is_casting(release_player),
					cooldown.is_stopped(),
				]
			)
		)

		enemy.queue_free()
		await fixture.process_frames(1)
		start_x += 1000.0


func test_valdemar_warns_before_sword_gleam() -> void:
	var start_position := Vector2(9000.0, 0.0)
	var valdemar := harness.instantiate_enemy(
		VALDEMAR_SCENE,
		start_position
	)
	valdemar.connect(&"awakening_requested", valdemar.begin_awakening)
	var player := harness.add_body(start_position + Vector2(-162.0, 0.0))
	var warning := valdemar.get_node_or_null("WarnMark") as Node2D
	var sword_player := valdemar.get_node(
		"SwordGleam/AnimationPlayer"
	) as AnimationPlayer
	var sword_cooldown := valdemar.get_node("SwordGleamCooldown") as Timer

	await fixture.physics_frames(3)
	await fixture.wait_seconds(0.95)
	await fixture.physics_frames(2)
	fixture.expect(
		warning != null
		and warning.visible
		and not _is_casting(sword_player)
		and sword_cooldown.is_stopped()
		and valdemar.global_position.is_equal_approx(start_position),
		"Aligned Valdemar starts a stationary warning before Sword Gleam"
	)

	var health_before_warning: int = valdemar.call("get_current_health")
	player.global_position = start_position + Vector2(900.0, 0.0)
	var weapon := harness.add_weapon(valdemar.global_position)
	await fixture.physics_frames(2)
	weapon.queue_free()
	fixture.expect(
		valdemar.call("get_current_health") == health_before_warning,
		"Valdemar warning rejects weapon damage after Player departure"
	)

	await fixture.wait_seconds(RELEASE_WARNING_DURATION - 0.15)
	fixture.expect(
		warning != null
		and warning.visible
		and not _is_casting(sword_player)
		and sword_cooldown.is_stopped(),
		"Valdemar Sword Gleam stays harmless for its full warning"
	)

	await fixture.wait_seconds(0.15)
	await fixture.physics_frames(2)
	fixture.expect(
		warning != null
		and not warning.visible
		and _is_casting(sword_player)
		and not sword_cooldown.is_stopped(),
		"Valdemar Sword Gleam and cooldown start only after its warning"
	)

	valdemar.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func test_valdemar_warns_before_black_water() -> void:
	var start_position := Vector2(11000.0, 0.0)
	var valdemar := harness.instantiate_enemy(
		VALDEMAR_SCENE,
		start_position
	)
	valdemar.connect(&"awakening_requested", valdemar.begin_awakening)
	var black_water_requests := [0]
	valdemar.connect(
		&"black_water_requested",
		func() -> void: black_water_requests[0] += 1
	)
	var player := harness.add_body(start_position + Vector2(300.0, 0.0))
	var warning := valdemar.get_node_or_null("WarnMark") as Node2D
	var sword_cooldown := valdemar.get_node("SwordGleamCooldown") as Timer
	var black_water_cooldown := valdemar.get_node("BlackWaterCooldown") as Timer

	await fixture.physics_frames(3)
	await fixture.wait_seconds(0.95)
	sword_cooldown.start(10.0)
	black_water_cooldown.start(0.01)
	black_water_cooldown.wait_time = 16.0
	await fixture.wait_seconds(0.05)
	await fixture.physics_frames(2)
	fixture.expect(
		warning != null
		and warning.visible
		and black_water_requests[0] == 0
		and black_water_cooldown.is_stopped(),
		"Due Black Water starts a warning without requesting its field or cooldown"
	)

	await fixture.wait_seconds(RELEASE_WARNING_DURATION - 0.1)
	fixture.expect(
		warning != null
		and warning.visible
		and black_water_requests[0] == 0
		and black_water_cooldown.is_stopped(),
		"Valdemar Black Water remains unreleased through its full warning"
	)

	await fixture.wait_seconds(0.15)
	await fixture.physics_frames(2)
	fixture.expect(
		warning != null
		and not warning.visible
		and black_water_requests[0] == 1
		and not black_water_cooldown.is_stopped(),
		(
			(
				"Valdemar requests Black Water and restarts its cycle after the warning; "
				+ "warning=%s requests=%s cooldown_stopped=%s"
			)
			% [
				warning.visible if warning != null else null,
				black_water_requests[0],
				black_water_cooldown.is_stopped(),
			]
		)
	)

	valdemar.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func test_valdemar_warning_keeps_gravity() -> void:
	var start_position := Vector2(10000.0, 0.0)
	var gravity_area := Area2D.new()
	gravity_area.position = start_position
	gravity_area.gravity_space_override = Area2D.SPACE_OVERRIDE_REPLACE
	gravity_area.gravity = 600.0
	gravity_area.collision_layer = 0
	gravity_area.collision_mask = EnemyHarness.ENEMY_COLLISION_LAYER
	var gravity_collision := CollisionShape2D.new()
	var gravity_shape := RectangleShape2D.new()
	gravity_shape.size = Vector2(1000.0, 1000.0)
	gravity_collision.shape = gravity_shape
	gravity_area.add_child(gravity_collision)
	fixture.add_node(gravity_area, harness.world)
	var valdemar := harness.instantiate_enemy(
		VALDEMAR_SCENE,
		start_position
	)
	valdemar.connect(&"awakening_requested", valdemar.begin_awakening)
	var player := harness.add_body(start_position + Vector2(-162.0, 0.0))
	var warning := valdemar.get_node("WarnMark") as Node2D

	for _frame in 70:
		await fixture.physics_frames(1)
		if warning.visible:
			break
	var warning_start_position := valdemar.global_position
	var warning_start_velocity_y := valdemar.velocity.y
	await fixture.wait_seconds(0.25)
	fixture.expect(
		warning.visible
		and is_equal_approx(
			valdemar.global_position.x,
			warning_start_position.x
		)
		and valdemar.global_position.y > warning_start_position.y
		and valdemar.velocity.y > warning_start_velocity_y,
		(
			"Airborne Valdemar stops horizontally but keeps falling during warning "
			+ "(warning=%s, start=%s, current=%s, start_velocity_y=%s, velocity=%s)"
		) % [
			warning.visible,
			warning_start_position,
			valdemar.global_position,
			warning_start_velocity_y,
			valdemar.velocity,
		]
	)

	valdemar.queue_free()
	player.queue_free()
	gravity_area.queue_free()
	await fixture.process_frames(1)


func _is_casting(animation_player: AnimationPlayer) -> bool:
	return (
		animation_player.is_playing()
		and animation_player.current_animation == &"cast"
	)
