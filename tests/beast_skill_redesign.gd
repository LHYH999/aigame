extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const EnemySceneHarness := preload("res://tests/enemy_scene_harness.gd")
const BEAR_KING_SCENE := preload("res://enemies/bear_king.tscn")
const ELK_KING_SCENE := preload("res://enemies/elk_king.tscn")
const RELEASE_WARNING_DURATION := 0.7

var fixture: HeadlessGameplayFixture
var world: Node2D
var harness: EnemySceneHarness


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	fixture.set_project_setting("physics/2d/default_gravity", 0.0)
	world = fixture.add_node(Node2D.new()) as Node2D
	fixture.set_current_scene(world)
	harness = EnemySceneHarness.new(fixture, world)

	await test_vermilion_fireball()
	await test_black_tortoise_independent_skills()

	fixture.set_current_scene(null)
	world.free()
	await fixture.process_frames(1)
	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func test_vermilion_fireball() -> void:
	var boss_position := Vector2(3000.0, 0.0)
	var boss := harness.instantiate_enemy(
		BEAR_KING_SCENE,
		boss_position,
		{"idle_duration": 10.0}
	)
	var player := harness.instantiate_passive_player(
		boss_position + Vector2(-152.0, 42.5),
		func() -> void:
			pass
	)
	var player_health_before := int(player.call("get_current_health"))

	await fixture.physics_frames(3)
	await fixture.wait_seconds(0.05)
	player.global_position = boss_position + Vector2(-600.0, 0.0)
	await fixture.wait_seconds(RELEASE_WARNING_DURATION + 0.05)
	fixture.expect(
		not harness.is_playing(boss, &"cast"),
		"Vermilion Bird no longer starts the inherited earthquake presentation"
	)
	var projectiles := get_nodes_in_group(&"enemy_projectiles")
	fixture.expect(
		projectiles.size() == 1,
		"Vermilion Bird releases one fireball instead of an earthquake"
	)
	if projectiles.size() == 1:
		var projectile := projectiles[0] as BossProjectile
		var sprite := projectile.get_node("Sprite2D") as Sprite2D
		var velocity: Vector2 = projectile.get("_velocity")
		fixture.expect(
			sprite.texture.resource_path.ends_with("purple_orb.png")
			and sprite.modulate.r > 0.9
			and sprite.modulate.g < 0.4
			and sprite.scale.is_equal_approx(Vector2(2.16, 2.16))
			and is_equal_approx(velocity.length(), 570.0)
			and velocity.dot(player.global_position - projectile.global_position) > 0.0,
			"Vermilion fireball uses the larger 570-speed red thunder-orb projectile"
		)
	await fixture.wait_seconds(1.2)
	fixture.expect(
		int(player.call("get_current_health")) == player_health_before - 1,
		"Vermilion Bird fireball deals one damage on contact"
	)

	boss.queue_free()
	player.queue_free()
	await fixture.process_frames(2)


func test_black_tortoise_independent_skills() -> void:
	var boss_position := Vector2(-2000.0, 0.0)
	var boss := harness.instantiate_enemy(
		ELK_KING_SCENE,
		boss_position,
		{"idle_duration": 10.0}
	)
	var earthquake_cooldown := boss.get_node(
		"SkillDetect/EarthquakeSkill/Cooldown"
	) as Timer
	var thunder_cooldown := boss.get_node(
		"SkillDetect/ThunderSkill/Cooldown"
	) as Timer
	earthquake_cooldown.start(99.0)
	var player := harness.instantiate_passive_player(
		boss_position + Vector2(-152.0, 42.5),
		func() -> void:
			pass
	)
	var waves: Array = []
	var wave_times_ms: Array[int] = []
	boss.connect(
		&"thunder_wave_spawned",
		func(x_positions: Array) -> void:
			waves.append(x_positions.duplicate())
			wave_times_ms.append(Time.get_ticks_msec())
	)

	await fixture.physics_frames(3)
	await fixture.wait_seconds(RELEASE_WARNING_DURATION + 0.15)
	fixture.expect(
		waves.size() >= 1 and (waves[0] as Array).size() == 3,
		"Black Tortoise thunder barrage creates three beams per wave"
	)
	if not waves.is_empty():
		var positions: Array = (waves[0] as Array).duplicate()
		positions.sort()
		fixture.expect(
			float(positions[1]) - float(positions[0]) >= 100.0
			and float(positions[2]) - float(positions[1]) >= 100.0,
			"Each thunder wave uses non-adjacent map positions"
		)
	fixture.expect(
		not bool(boss.get("_earthquake_cast_active")),
		"Earthquake waits while the thunder barrage is being released"
	)
	earthquake_cooldown.stop()
	await fixture.wait_seconds(0.30)
	fixture.expect(
		not bool(boss.get("_earthquake_cast_active")),
		"A ready earthquake cannot interrupt an active thunder barrage"
	)

	await fixture.wait_seconds(1.0)
	fixture.expect(
		waves.size() >= 3,
		"Black Tortoise emits thunder waves repeatedly at the 0.6-second interval"
	)
	if wave_times_ms.size() >= 3:
		var first_interval := wave_times_ms[1] - wave_times_ms[0]
		var second_interval := wave_times_ms[2] - wave_times_ms[1]
		fixture.expect(
			first_interval >= 450 and first_interval <= 850
			and second_interval >= 450 and second_interval <= 850,
			"Consecutive thunder waves keep the configured short interval"
		)

	player.global_position = boss_position + Vector2(-1000.0, 0.0)
	await fixture.wait_seconds(5.0)
	fixture.expect(
		waves.size() >= 9,
		"Black Tortoise continues spawning three thunder beams for six seconds"
	)
	fixture.expect(
		not bool(boss.get("_earthquake_cast_active")),
		"Earthquake remains separated from the thunder barrage"
	)

	fixture.expect(
		not bool(boss.get("_earthquake_cast_active")),
		"Earthquake waits outside Black Tortoise's attack range after thunder ends"
	)
	fixture.expect(
		not thunder_cooldown.is_stopped()
		and is_equal_approx(thunder_cooldown.wait_time, 10.0)
		and thunder_cooldown.time_left > 9.3,
		"Black Tortoise starts its ten-second thunder cooldown after the barrage ends"
	)

	await harness.reenter_skill_detection(
		player,
		boss_position + Vector2(-152.0, 42.5)
	)
	var warning := boss.get_node("WarnMark") as Node2D
	fixture.expect(
		warning.visible
		and waves.size() == 10
		and not bool(boss.get("_earthquake_cast_active")),
		"Re-entering attack range starts a new earthquake warning without more thunder waves "
		+ "(warning=%s waves=%s quake=%s state=%s)"
		% [
			warning.visible,
			waves.size(),
			boss.get("_earthquake_cast_active"),
			boss.get("state"),
		]
	)
	await fixture.wait_seconds(RELEASE_WARNING_DURATION + 0.10)
	fixture.expect(
		bool(boss.get("_earthquake_cast_active"))
		or harness.is_playing(boss, &"cast"),
		"Earthquake releases only after its own completed warning"
	)

	var waves_after_earthquake := waves.size()
	await fixture.wait_seconds(maxf(thunder_cooldown.time_left - 0.3, 0.0))
	fixture.expect(
		waves.size() == waves_after_earthquake,
		"Black Tortoise cannot restart thunder before its ten-second post-barrage cooldown"
	)
	await fixture.wait_seconds(RELEASE_WARNING_DURATION + 0.35)
	fixture.expect(
		waves.size() > waves_after_earthquake,
		"Black Tortoise can release thunder again after the post-barrage cooldown"
	)

	boss.queue_free()
	player.queue_free()
	await fixture.process_frames(2)
