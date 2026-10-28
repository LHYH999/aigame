extends SceneTree


const PLAYER_04_SCENE := preload("res://player/player_04.tscn")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	await verify_shield_requires_black_tortoise()
	await verify_dragon_roost_cooldown()
	await verify_dragon_roost_cooldown_survives_mask_switching()
	await verify_other_masks_do_not_block()
	await verify_shield_returns_after_cooldown()
	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func verify_shield_requires_black_tortoise() -> void:
	var player := fixture.instantiate_scene(PLAYER_04_SCENE) as DamageableActor
	player.set_physics_process(false)
	await fixture.process_frames(1)
	var shield := player.get_node("VisualRoot/ShieldSkill/Shield") as Area2D
	fixture.expect(not shield.visible, "Player Shield is hidden without a mask")

	var mask_ids: Array[StringName] = [&"black_tortoise"]
	player.apply_mask_progress(mask_ids, &"black_tortoise")
	await fixture.process_frames(1)
	fixture.expect(
		shield.visible
		and (shield.get_node("AnimationPlayer") as AnimationPlayer).current_animation == &"idle",
		"Black Tortoise mask presents the ready shield bubble"
	)

	var maximum_health := int(player.call("get_maximum_health"))
	player.take_damage(1, Vector2.RIGHT)
	fixture.expect(
		player.call("get_current_health") == maximum_health,
		"Black Tortoise mask blocks one damage event"
	)
	fixture.expect(
		is_equal_approx(
			float(player.get_mask_controller().get_black_tortoise_block_cooldown()),
			10.0
		),
		"Black Tortoise automatic block starts its ten-second cooldown"
	)
	player.queue_free()
	await fixture.process_frames(1)


func verify_dragon_roost_cooldown() -> void:
	var player := fixture.instantiate_scene(PLAYER_04_SCENE) as DamageableActor
	player.set_physics_process(false)
	await fixture.process_frames(1)
	var controller = player.get_mask_controller()
	var mask_ids: Array[StringName] = [&"black_tortoise"]
	player.apply_mask_progress(mask_ids, &"black_tortoise")
	fixture.expect(
		controller.try_activate() == &"black_tortoise",
		"Black Tortoise Q activates Dragon Roost"
	)
	fixture.expect(
		is_equal_approx(float(controller.get_cooldown_left()), 15.0),
		"Black Tortoise Q starts its fifteen-second cooldown"
	)
	player.queue_free()
	await fixture.process_frames(1)


func verify_dragon_roost_cooldown_survives_mask_switching() -> void:
	var player := fixture.instantiate_scene(PLAYER_04_SCENE) as DamageableActor
	player.set_physics_process(false)
	await fixture.process_frames(1)
	var controller = player.get_mask_controller()
	var mask_ids: Array[StringName] = [&"black_tortoise", &"white_tiger"]
	player.apply_mask_progress(mask_ids, &"black_tortoise")
	fixture.expect(
		controller.try_activate() == &"black_tortoise",
		"Black Tortoise Q activates before testing mask switching"
	)
	var cooldown_before_switch := float(controller.get_cooldown_left())

	fixture.expect(
		controller.cycle_primary() == &"white_tiger"
		and is_zero_approx(float(controller.get_cooldown_left())),
		"Switching to a non-active mask exposes that mask's independent cooldown"
	)
	await fixture.wait_seconds(0.1)
	fixture.expect(
		controller.cycle_primary() == &"black_tortoise",
		"Cycling masks returns to Black Tortoise"
	)
	fixture.expect(
		float(controller.get_cooldown_left()) > 0.0
		and float(controller.get_cooldown_left()) < cooldown_before_switch - 0.05,
		"Dragon Roost cooldown keeps counting down while another mask is equipped"
	)
	fixture.expect(
		controller.try_activate().is_empty(),
		"Dragon Roost remains unavailable while its persisted cooldown is active"
	)
	player.queue_free()
	await fixture.process_frames(1)


func verify_other_masks_do_not_block() -> void:
	var player := fixture.instantiate_scene(PLAYER_04_SCENE) as DamageableActor
	player.set_physics_process(false)
	await fixture.process_frames(1)
	var shield := player.get_node("VisualRoot/ShieldSkill/Shield") as Area2D
	var mask_ids: Array[StringName] = [&"white_tiger"]
	player.apply_mask_progress(mask_ids, &"white_tiger")
	await fixture.process_frames(1)
	fixture.expect(
		not shield.visible,
		"Non-Black-Tortoise masks do not present a shield bubble"
	)

	var health_before := int(player.call("get_current_health"))
	player.take_damage(1, Vector2.RIGHT)
	fixture.expect(
		player.call("get_current_health") == health_before - 1,
		"Non-Black-Tortoise masks do not automatically block damage"
	)
	player.queue_free()
	await fixture.process_frames(1)


func verify_shield_returns_after_cooldown() -> void:
	var player := fixture.instantiate_scene(PLAYER_04_SCENE) as DamageableActor
	player.set_physics_process(false)
	await fixture.process_frames(1)
	var shield := player.get_node("VisualRoot/ShieldSkill/Shield") as Area2D
	var controller = player.get_mask_controller()
	var mask_ids: Array[StringName] = [&"black_tortoise"]
	player.apply_mask_progress(mask_ids, &"black_tortoise")
	player.take_damage(1, Vector2.RIGHT)
	await fixture.process_frames(1)
	controller.set("_black_tortoise_block_cooldown", 0.1)
	await fixture.wait_seconds(0.15)
	fixture.expect(
		shield.visible
		and (shield.get_node("AnimationPlayer") as AnimationPlayer).current_animation == &"idle",
		"Black Tortoise shield returns after its cooldown completes"
	)
	player.queue_free()
	await fixture.process_frames(1)
