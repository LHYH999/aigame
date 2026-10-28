extends SceneTree


const GUARD_SCENE := preload("res://enemies/guard.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")


var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	fixture.set_project_setting("physics/2d/default_gravity", 0.0)
	var world := fixture.add_node(Node2D.new()) as Node2D
	fixture.set_current_scene(world)
	var harness := EnemyHarness.new(fixture, world)
	var guard := harness.instantiate_enemy(GUARD_SCENE, Vector2.ZERO)
	await fixture.process_frames(2)

	var sprite := guard.get_node("Sprite2D") as Sprite2D
	var animation_player := guard.get_node("AnimationPlayer") as AnimationPlayer
	var run_animation := animation_player.get_animation(&"run")
	fixture.expect(
		"res://assets/enemies/guard/redesign/idle/west/" in sprite.texture.resource_path,
		"Level 04 Guard uses the redesigned idle sprite"
	)
	fixture.expect(
		is_equal_approx(run_animation.length, 1.0)
		and run_animation.track_get_key_count(0) == 16,
		"Guard run is a one-second sixteen-frame loop"
	)
	for specification in [
		{"name": &"skill", "directory": "redesign/skill/west"},
		{"name": &"hurt", "directory": "redesign/run/west"},
		{"name": &"dead", "directory": "redesign/run/west"},
	]:
		var animation_name: StringName = specification["name"]
		var animation := animation_player.get_animation(animation_name)
		var first_texture := animation.track_get_key_value(0, 0) as Texture2D
		fixture.expect(
			first_texture != null
			and specification["directory"] in first_texture.resource_path,
			"Guard %s uses the redesigned sprite frames" % animation_name
		)
	fixture.expect(
		animation_player.get_animation(&"skill").track_get_key_count(0) == 8,
		"Guard attack uses its generated eight-frame swing"
	)
	fixture.expect(
		animation_player.get_animation(&"dead").get_track_count() == 5,
		"Guard death combines redesigned frames with a collapse transform"
	)

	guard.set_physics_process(false)
	guard.change_state(1)
	await fixture.process_frames(2)
	fixture.expect(
		"res://assets/enemies/guard/redesign/run/west/" in sprite.texture.resource_path,
		"Guard moving state uses the redesigned run frames"
	)
	fixture.expect(
		sprite.texture.get_size() == Vector2(228.0, 228.0),
		"Redesigned Guard frames match the existing gameplay canvas"
	)
	guard.change_state(4)
	await fixture.wait_seconds(0.2)
	fixture.expect(
		"res://assets/enemies/guard/redesign/skill/west/" in sprite.texture.resource_path
		and sprite.visible,
		"Guard attack state visibly plays the generated attack frames"
	)
	guard.change_state(1)
	await fixture.process_frames(2)
	var animation_state := guard.get_node("AnimationTree").get(
		"parameters/playback"
	) as AnimationNodeStateMachinePlayback
	for hit_index in 2:
		guard.take_damage(1, Vector2.ZERO)
		await fixture.wait_seconds(0.06)
		fixture.expect(
			animation_state.get_current_node() == &"hurt"
			and sprite.modulate.g < 0.8,
			"Guard hit %d starts the redesigned hurt feedback"
			% (hit_index + 1)
		)
		await fixture.wait_seconds(0.35)

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()
