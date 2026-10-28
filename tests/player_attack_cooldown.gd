extends SceneTree


const PLAYER_SCENE := preload("res://player/player.tscn")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	fixture.set_project_setting("physics/2d/default_gravity", 0.0)

	await test_player_attack_cooldown_configuration()
	await test_cooldown_attack_presses_release_one_pending_player_attack()
	await test_hurt_attack_press_waits_for_hurt_and_cooldown()
	await test_ready_attack_press_during_hurt_releases_after_hurt()
	await test_control_lock_discards_pending_and_locked_attack_presses()
	await test_held_attack_does_not_repeat_without_a_new_press()
	await test_pending_player_attack_survives_subsequent_hurt()
	await test_pending_player_attack_uses_release_facing()
	await test_player_defeat_prevents_pending_player_attack()

	fixture.complete(false)
	await fixture.process_frames(3)
	await fixture.physics_frames(3)
	fixture.complete()


func test_player_attack_cooldown_configuration() -> void:
	var player := await prepare_player_for_input_test()
	if player == null:
		return

	var attack_cooldown := player.get_node("AttackCooldown") as Timer
	fixture.expect(
		is_equal_approx(attack_cooldown.wait_time, 0.8),
		"Player Attack Cooldown lasts eight tenths of a second"
	)
	fixture.expect(
		player.get_node_or_null("AttackRejectionFeedback") == null,
		"Player has no obsolete attack-rejection feedback"
	)
	player.queue_free()
	await fixture.process_frames(1)


func test_cooldown_attack_presses_release_one_pending_player_attack() -> void:
	var player := await prepare_player_for_input_test()
	if player == null:
		return

	var attack_start_count := observe_attack_starts(player)
	await press_attack()
	await press_attack()
	await press_attack()
	await fixture.physics_frames(50)
	fixture.expect(
		attack_start_count[0] == 2,
		"Cooldown attack presses release one Pending Player Attack"
	)
	await fixture.physics_frames(50)
	fixture.expect(
		attack_start_count[0] == 2,
		"Multiple cooldown attack presses do not queue repeated attacks"
	)
	player.queue_free()
	await fixture.process_frames(1)


func test_hurt_attack_press_waits_for_hurt_and_cooldown() -> void:
	var player := await prepare_player_for_input_test()
	if player == null:
		return

	var attack_start_count := observe_attack_starts(player)
	await press_attack()
	player.take_damage(1, Vector2.RIGHT)
	await fixture.physics_frames(2)
	await press_attack()
	await fixture.physics_frames(40)
	fixture.expect(
		attack_start_count[0] == 1,
		"Pending Player Attack does not interrupt Player Hurt"
	)
	await fixture.physics_frames(20)
	fixture.expect(
		attack_start_count[0] == 2,
		"Player Hurt attack press releases after hurt and cooldown finish"
	)
	player.queue_free()
	await fixture.process_frames(1)


func test_ready_attack_press_during_hurt_releases_after_hurt() -> void:
	var player := await prepare_player_for_input_test()
	if player == null:
		return

	var attack_start_count := observe_attack_starts(player)
	player.take_damage(1, Vector2.RIGHT)
	await fixture.physics_frames(2)
	await press_attack()
	await fixture.physics_frames(40)
	fixture.expect(
		attack_start_count[0] == 0,
		"Ready attack press does not interrupt Player Hurt"
	)
	await fixture.physics_frames(20)
	fixture.expect(
		attack_start_count[0] == 1,
		"Ready attack press during Player Hurt releases when hurt finishes"
	)
	player.queue_free()
	await fixture.process_frames(1)


func test_control_lock_discards_pending_and_locked_attack_presses() -> void:
	var player := await prepare_player_for_input_test()
	if player == null:
		return

	var attack_start_count := observe_attack_starts(player)
	await press_attack()
	await press_attack()
	player.set_controls_enabled(false)
	await press_attack()
	await fixture.physics_frames(50)
	player.set_controls_enabled(true)
	await fixture.physics_frames(3)
	fixture.expect(
		attack_start_count[0] == 1,
		"Player control lock discards pending and locked attack presses"
	)
	await press_attack()
	fixture.expect(
		attack_start_count[0] == 2,
		"Player accepts a new attack after control returns"
	)
	player.queue_free()
	await fixture.process_frames(1)


func test_held_attack_does_not_repeat_without_a_new_press() -> void:
	var player := await prepare_player_for_input_test()
	if player == null:
		return

	var attack_start_count := observe_attack_starts(player)
	Input.action_press(&"attack")
	await fixture.physics_frames(55)
	fixture.expect(
		attack_start_count[0] == 1,
		"Held attack does not repeat without a new press"
	)
	Input.action_release(&"attack")
	player.queue_free()
	await fixture.process_frames(1)


func test_pending_player_attack_survives_subsequent_hurt() -> void:
	var player := await prepare_player_for_input_test()
	if player == null:
		return

	var attack_start_count := observe_attack_starts(player)
	await press_attack()
	await press_attack()
	player.take_damage(1, Vector2.RIGHT)
	await fixture.physics_frames(60)
	fixture.expect(
		attack_start_count[0] == 2,
		"Pending Player Attack releases after subsequent Player Hurt"
	)
	player.queue_free()
	await fixture.process_frames(1)


func test_pending_player_attack_uses_release_facing() -> void:
	var player := await prepare_player_for_input_test()
	if player == null:
		return

	var attack_start_count := observe_attack_starts(player)
	Input.action_press(&"right")
	await fixture.physics_frames(2)
	await press_attack()
	await press_attack()
	Input.action_release(&"right")
	Input.action_press(&"left")
	await fixture.physics_frames(50)
	var visual_root := player.get_node("VisualRoot") as Node2D
	fixture.expect(
		attack_start_count[0] == 2 and visual_root.scale.x < 0.0,
		"Pending Player Attack uses the Player facing when it begins"
	)
	Input.action_release(&"left")
	player.queue_free()
	await fixture.process_frames(1)


func test_player_defeat_prevents_pending_player_attack() -> void:
	var player := await prepare_player_for_input_test()
	if player == null:
		return

	var attack_start_count := observe_attack_starts(player)
	await press_attack()
	await press_attack()
	player.take_damage(player.get_current_health(), Vector2.RIGHT)
	await fixture.physics_frames(55)
	fixture.expect(
		attack_start_count[0] == 1,
		"Player Defeat prevents Pending Player Attack"
	)
	player.queue_free()
	await fixture.process_frames(1)


func prepare_player_for_input_test() -> CharacterBody2D:
	var player := fixture.instantiate_scene(PLAYER_SCENE) as CharacterBody2D
	fixture.expect(player != null, "Player loads through its production input seam")
	if player == null:
		return null

	fixture.set_current_scene(player)
	await fixture.process_frames(1)
	Input.action_release(&"attack")
	await fixture.physics_frames(2)
	return player


func observe_attack_starts(player: CharacterBody2D) -> Array[int]:
	var attack_start_count: Array[int] = [0]
	var animation_tree := player.get_node("AnimationTree") as AnimationTree
	animation_tree.animation_started.connect(
		func(animation_name: StringName) -> void:
			if animation_name == &"attack":
				attack_start_count[0] += 1
	)
	return attack_start_count


func press_attack() -> void:
	Input.action_press(&"attack")
	await fixture.physics_frames(2)
	Input.action_release(&"attack")
	await fixture.physics_frames(1)
