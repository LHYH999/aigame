extends SceneTree


const BEAR_KING_SCENE := preload("res://enemies/bear_king.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const SKILL_ANIMATION := &"skill"
const EARTHQUAKE_CAST_ANIMATION := &"cast"
const EXPECTED_HEALTH := 30
const EARTHQUAKE_OFFSET := Vector2(-228.0, 72.0)
const RELEASE_WARNING_DURATION := 0.7

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

	await test_earthquake_damage_and_cooldown()
	await test_damage_faces_attacker_without_interrupting_earthquake()

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func test_earthquake_damage_and_cooldown() -> void:
	var bear_king_position := Vector2(3500.0, 0.0)
	var bear_king := harness.instantiate_enemy(
		BEAR_KING_SCENE,
		bear_king_position,
		{"idle_duration": 10.0}
	)
	var hurt_event_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		bear_king_position + EARTHQUAKE_OFFSET,
		func() -> void: hurt_event_count[0] += 1
	)

	await fixture.physics_frames(3)
	await fixture.wait_seconds(0.05)
	await fixture.wait_seconds(RELEASE_WARNING_DURATION)
	fixture.expect(
		harness.is_playing(bear_king, SKILL_ANIMATION),
		"Gameplay detection starts Vermilion Bird's fireball skill"
	)
	fixture.expect(
		not harness.is_playing(bear_king, EARTHQUAKE_CAST_ANIMATION),
		"Vermilion Bird does not start the inherited earthquake presentation"
	)
	var skill_start_x := bear_king.global_position.x
	# Observe after the impact frame and before the one-second skill completes.
	await fixture.wait_seconds(0.8)
	await fixture.physics_frames(1)
	fixture.expect(hurt_event_count[0] == 1, "Vermilion Bird fireball deals one point of damage once")
	await fixture.wait_seconds(0.3)
	fixture.expect(
		not harness.is_playing(bear_king, SKILL_ANIMATION),
		"Vermilion Bird fireball skill completes once"
	)
	fixture.expect(
		is_equal_approx(bear_king.global_position.x, skill_start_x),
		"Vermilion Bird remains stationed while releasing the fireball"
	)

	await harness.reenter_skill_detection(player, bear_king_position + EARTHQUAKE_OFFSET)
	fixture.expect(
		not harness.is_playing(bear_king, SKILL_ANIMATION),
		"Vermilion Bird cannot release another fireball during cooldown"
	)
	var skill_cooldown := bear_king.get_node("SkillDetect/Cooldown") as Timer
	fixture.expect(
		is_equal_approx(skill_cooldown.wait_time, 2.0),
		"Vermilion Bird uses its current two-second fireball cooldown"
	)
	await fixture.wait_seconds(maxf(skill_cooldown.time_left - 0.25, 0.1))
	await harness.reenter_skill_detection(player, bear_king_position + EARTHQUAKE_OFFSET)
	fixture.expect(
		not harness.is_playing(bear_king, SKILL_ANIMATION),
		"Vermilion Bird preserves its full two-second fireball cooldown"
	)
	await fixture.wait_seconds(0.35)
	await harness.reenter_skill_detection(player, bear_king_position + EARTHQUAKE_OFFSET)
	await fixture.wait_seconds(RELEASE_WARNING_DURATION)
	fixture.expect(
		harness.is_playing(bear_king, SKILL_ANIMATION),
		"Vermilion Bird can release a fireball after cooldown"
	)
	bear_king.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func test_damage_faces_attacker_without_interrupting_earthquake() -> void:
	var bear_king_position := Vector2(5500.0, 0.0)
	var bear_king := harness.instantiate_enemy(
		BEAR_KING_SCENE,
		bear_king_position,
		{"idle_duration": 10.0}
	)
	var hurt_event_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		bear_king_position + EARTHQUAKE_OFFSET,
		func() -> void: hurt_event_count[0] += 1
	)
	await fixture.physics_frames(3)
	await fixture.wait_seconds(0.05)
	await fixture.wait_seconds(RELEASE_WARNING_DURATION)
	fixture.expect(
		harness.is_playing(bear_king, SKILL_ANIMATION),
		"Vermilion Bird is vulnerable while releasing the fireball"
	)

	await harness.deliver_hit(bear_king, Vector2(-50.0, 0.0))
	fixture.expect(
		bear_king.get_current_health() == EXPECTED_HEALTH - 1,
		"Weapon contact damages a vulnerable BearKing "
		+ "(health=%s state=%s air=%s immune=%s hurt_disabled=%s)"
		% [
			bear_king.get_current_health(),
			bear_king.get("state"),
			bear_king.call("is_air_attacking"),
			bear_king.call("is_hurt_immune"),
			(bear_king.get_node(
				"HurtBox/CollisionShape2D"
			) as CollisionShape2D).disabled,
		]
	)
	fixture.expect(
		harness.is_playing(bear_king, SKILL_ANIMATION),
		"Accepted damage keeps Vermilion Bird in its fireball skill"
	)
	fixture.expect(
		not harness.enemy_sprite_is_flipped(bear_king),
		"BearKing faces an attacker on its left"
	)
	fixture.expect(
		is_equal_approx(bear_king.global_position.x, bear_king_position.x),
		"Vermilion Bird fireball skill ignores hurt knockback"
	)
	fixture.expect(
		not harness.is_playing(bear_king, EARTHQUAKE_CAST_ANIMATION),
		"Accepted damage does not start the inherited earthquake presentation"
	)

	await fixture.wait_seconds(0.45)
	await harness.deliver_hit(bear_king, Vector2(50.0, 0.0))
	fixture.expect(
		bear_king.get_current_health() == EXPECTED_HEALTH - 2,
		"Later weapon contact delivers damage after recovery"
	)
	fixture.expect(
		harness.enemy_sprite_is_flipped(bear_king),
		"BearKing faces an attacker on its right"
	)
	await fixture.wait_seconds(0.3)
	fixture.expect(hurt_event_count[0] == 1, "Damaged Vermilion Bird fireball still reaches impact")
	bear_king.queue_free()
	player.queue_free()
	await fixture.process_frames(1)
