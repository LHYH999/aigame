extends SceneTree


const ELK_KING_SCENE := preload("res://enemies/elk_king.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

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

	await verify_death_cancels_the_ordered_barrage()

	fixture.set_current_scene(null)
	world.free()
	await fixture.process_frames(1)
	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func verify_death_cancels_the_ordered_barrage() -> void:
	var boss_position := Vector2(5000.0, 0.0)
	var boss := harness.instantiate_enemy(
		ELK_KING_SCENE,
		boss_position,
		{"idle_duration": 10.0}
	)
	(
		boss.get_node("SkillDetect/EarthquakeSkill/Cooldown") as Timer
	).start(99.0)
	var player := harness.instantiate_passive_player(
		boss_position + Vector2(-172.0, 0.0),
		func() -> void:
			pass
	)
	var waves: Array = []
	boss.connect(
		&"thunder_wave_spawned",
		func(x_positions: Array) -> void:
			waves.append(x_positions)
	)

	await fixture.physics_frames(3)
	await fixture.wait_seconds(0.9)
	fixture.expect(
		not waves.is_empty() and not (boss.get("_spawned_thunders") as Array).is_empty(),
		"Black Tortoise keeps ordered thunder beams active during its skill"
	)

	boss.call("die")
	await fixture.process_frames(1)
	var wave_count_at_death := waves.size()
	var beams: Array = boss.get("_spawned_thunders")
	var all_beams_cancelled := not beams.is_empty()
	for beam in beams:
		all_beams_cancelled = (
			all_beams_cancelled
			and is_instance_valid(beam)
			and not bool(beam.get("is_cast_active"))
		)
	fixture.expect(
		int(boss.get("state")) == 3
		and not bool(boss.get("_thunder_cast_active"))
		and all_beams_cancelled,
		"Black Tortoise death cancels beam damage while committed presentations finish"
	)

	await fixture.wait_seconds(0.5)
	fixture.expect(
		waves.size() == wave_count_at_death,
		"Black Tortoise death prevents future thunder waves"
	)

	boss.queue_free()
	player.queue_free()
	await fixture.process_frames(2)
