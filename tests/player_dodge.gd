extends SceneTree


const PLAYER_SCENE := preload("res://player/player.tscn")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	fixture.set_project_setting("physics/2d/default_gravity", 0.0)

	var dodge_events := InputMap.action_get_events(&"dodge")
	var shift_is_bound := false
	for event in dodge_events:
		if event is InputEventKey and event.physical_keycode == KEY_SHIFT:
			shift_is_bound = true
	fixture.expect(shift_is_bound, "Shift is bound to the dodge action")

	var player := fixture.instantiate_scene(PLAYER_SCENE) as CharacterBody2D
	fixture.set_current_scene(player)
	await fixture.process_frames(1)
	var dodge_started_count := [0]
	player.connect(
		&"dodge_started",
		func() -> void:
			dodge_started_count[0] += 1
	)
	var dodge_cooldown := player.get_node("DodgeCooldown") as Timer
	var model := player.get_node("VisualRoot/RedesignedModel") as Sprite2D
	fixture.expect(
		is_equal_approx(dodge_cooldown.wait_time, 0.3),
		"Player Dodge has a 0.3-second cooldown"
	)

	var health_before := int(player.call("get_current_health"))
	var start_x := player.global_position.x
	Input.action_press(&"right")
	Input.action_press(&"dodge")
	await fixture.physics_frames(3)
	Input.action_release(&"dodge")
	fixture.expect(
		dodge_started_count[0] == 1
		and bool(player.call("is_dodging"))
		and player.global_position.x > start_x,
		"Dodge starts immediately in the current movement direction "
		+ "(starts=%s dodging=%s state=%s x=%.2f start=%.2f cooldown=%.2f)"
		% [
			dodge_started_count[0],
			player.call("is_dodging"),
			player.get("state"),
			player.global_position.x,
			start_x,
			dodge_cooldown.time_left,
		]
	)
	fixture.expect(
		is_equal_approx(player.velocity.x, 940.0),
		"Player Dodge uses the 940 dash speed"
	)
	var observed_dodge_frame := false
	for _frame in 4:
		await fixture.process_frames(1)
		if "animations/dodge/frames" in model.texture.resource_path:
			observed_dodge_frame = true
	fixture.expect(
		observed_dodge_frame,
		"Player Dodge plays the dedicated generated dodge animation"
	)
	fixture.expect(
		not dodge_cooldown.is_stopped()
		and get_nodes_in_group(&"dodge_afterimages").size() > 0,
		"Dodge starts its cooldown and creates an afterimage"
	)

	await fixture.wait_seconds(0.20)
	fixture.expect(
		not bool(player.call("is_dodging")),
		"Dodge state ends when the dash motion completes"
	)
	var action_after_dash: int = int(dodge_started_count[0])
	Input.action_press(&"dodge")
	await fixture.physics_frames(2)
	Input.action_release(&"dodge")
	fixture.expect(
		dodge_started_count[0] == action_after_dash,
		"Dodge cannot restart before its 0.3-second cooldown finishes"
	)

	await fixture.wait_seconds(dodge_cooldown.time_left + 0.05)
	Input.action_press(&"dodge")
	await fixture.physics_frames(2)
	Input.action_release(&"dodge")
	fixture.expect(
		dodge_started_count[0] == action_after_dash + 1,
		"Dodge becomes available again after its 0.3-second cooldown"
	)
	player.call("take_damage", 1, Vector2.LEFT)
	fixture.expect(
		int(player.call("get_current_health")) == health_before - 1
		and not bool(player.call("is_dodging")),
		"Dodge provides movement only and accepted damage interrupts it"
	)

	Input.action_release(&"right")
	await fixture.wait_seconds(0.3)
	fixture.set_current_scene(null)
	player.queue_free()
	await fixture.process_frames(2)
	fixture.complete(false)
	await fixture.process_frames(2)
	fixture.complete()
