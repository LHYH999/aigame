extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const PLAYER_SCENE := preload("res://player/player.tscn")
const GUARD_SCENE := preload("res://enemies/guard.tscn")


var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	var player := fixture.instantiate_scene(PLAYER_SCENE)
	fixture.set_current_scene(player)
	await fixture.process_frames(1)
	player.set_physics_process(false)
	var mask_ids: Array[StringName] = [&"white_tiger"]
	player.apply_mask_progress(mask_ids, &"white_tiger")
	player.change_state(player.ATTACK)
	await fixture.physics_frames(2)

	var weapon_area := player.get_node(
		"VisualRoot/AttackFan"
	) as Area2D
	var guard := GUARD_SCENE.instantiate() as CharacterBody2D
	guard.position = Vector2(1000.0, 0.0)
	fixture.add_node(guard)
	guard.set_physics_process(false)
	await fixture.process_frames(1)
	guard.call("apply_debug_health_override", 100)
	var health_before := int(guard.call("get_current_health"))
	guard.call("_on_hurt_box_area_entered", weapon_area)
	await fixture.process_frames(1)

	fixture.expect(
		int(guard.call("get_current_health")) == health_before - 16,
		"White Tiger weapon contact deals sixteen damage through enemy hurt boxes "
		+ "(before=%d after=%d state=%d weapon=%s)"
		% [
			health_before,
			int(guard.call("get_current_health")),
			int(guard.get("state")),
			weapon_area.is_in_group(&"weapons"),
		]
	)

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()
