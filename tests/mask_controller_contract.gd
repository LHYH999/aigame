extends SceneTree


const PLAYER_SCENE := preload("res://player/player.tscn")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	var player := fixture.instantiate_scene(PLAYER_SCENE)
	fixture.set_current_scene(player)
	await fixture.process_frames(1)

	var controller = player.get_node("MaskController")
	fixture.expect(controller != null, "Player owns a MaskController")
	if controller == null:
		fixture.complete()
		return
	var redesigned_model := player.get_node_or_null(
		"VisualRoot/RedesignedModel"
	) as Sprite2D
	fixture.expect(
		redesigned_model != null
		and redesigned_model.texture.resource_path.ends_with("yan_idle_256.png"),
		"Gameplay Player uses the redesigned Yan model"
	)
	fixture.expect(
		redesigned_model != null
		and redesigned_model.scale.is_equal_approx(Vector2(0.48, 0.48)),
		"Redesigned Player model matches the 102-pixel collision height"
	)
	if redesigned_model != null:
		player.set_physics_process(false)
		player.change_state(player.RUN)
		await fixture.wait_seconds(0.15)
		fixture.expect(
			"animations/run/frames" in redesigned_model.texture.resource_path,
			"Run state uses the generated movement frames"
		)
		player.change_state(player.JUMP)
		await fixture.wait_seconds(0.15)
		fixture.expect(
			"animations/jump/frames" in redesigned_model.texture.resource_path,
			"Jump state uses the generated jump frames"
		)
		player.change_state(player.ATTACK)
		await fixture.wait_seconds(0.15)
		fixture.expect(
			"animations/attack/frames" in redesigned_model.texture.resource_path,
			"Attack state uses the generated attack frames (path=%s state=%s)"
			% [redesigned_model.texture.resource_path, player.get("state")]
		)
		player.change_state(player.IDLE)
		await fixture.wait_seconds(0.1)
		player.set_physics_process(true)

	fixture.expect(controller.unlocked_mask_ids.is_empty(), "Player starts without masks")
	fixture.expect(
		controller.get_display_name() == "未获得面具",
		"MaskController exposes the empty state"
	)
	var weapon_area := player.get_node(
		"VisualRoot/AttackFan"
	) as Area2D
	var weapon_shape := player.get_node(
		"VisualRoot/AttackFan/CollisionShape2D"
	) as CollisionShape2D
	player.change_state(player.ATTACK)
	fixture.expect(
		is_equal_approx(weapon_shape.scale.x, 1.5)
		and int(weapon_area.get_meta(&"attack_damage", 0)) == 8,
		"Unmasked attacks use the 1.5x base range and base damage"
	)
	var initial_attack_arcs: Array[Line2D] = []
	for child in player.get_children():
		var line := child as Line2D
		if line != null and line.z_index >= 19:
			initial_attack_arcs.append(line)
	var initial_reach := float(player.call("_get_weapon_reach"))
	var initial_effect_matches := initial_attack_arcs.size() == 2
	for arc in initial_attack_arcs:
		initial_effect_matches = (
			initial_effect_matches
			and is_equal_approx(arc.points[6].length(), initial_reach)
		)
	fixture.expect(
		initial_effect_matches,
		"Unmasked attacks create an effect matching their actual attack reach"
	)
	player.change_state(player.IDLE)
	await fixture.wait_seconds(0.25)

	fixture.expect(player.call("unlock_mask", &"white_tiger"), "White Tiger mask unlocks once")
	fixture.expect(
		not player.call("unlock_mask", &"white_tiger"),
		"White Tiger mask cannot unlock twice"
	)
	fixture.expect(controller.charge == 60, "New mask starts with checkpoint charge")
	fixture.expect(
		controller.get_display_name() == "白虎面具",
		"White Tiger mask presents its display name"
	)

	controller.add_charge(100)
	fixture.expect(
		controller.charge == controller.MAX_CHARGE,
		"Mask charge clamps at its maximum"
	)
	fixture.expect(
		controller.try_activate().is_empty(),
		"White Tiger mask has no Q active skill"
	)
	player.change_state(player.ATTACK)
	var attack_fan := weapon_shape.shape as ConvexPolygonShape2D
	var fan_extends_forward := attack_fan.points.size() == 12
	for point in attack_fan.points:
		fan_extends_forward = fan_extends_forward and point.x >= 0.0
	fixture.expect(
		fan_extends_forward
		and attack_fan.points[1].y < 0.0
		and attack_fan.points[-1].y > 0.0,
		"Player attack collision is a forward-only convex fan"
	)
	fixture.expect(
		is_equal_approx(weapon_shape.scale.x, 3.0),
		"White Tiger range multiplies the 1.5x base reach by 2.0"
	)
	fixture.expect(
		int(weapon_area.get_meta(&"attack_damage", 1)) == 16,
		"White Tiger damage multiplies the base damage by two"
	)
	var weapon_reach := float(player.call("_get_weapon_reach"))
	var attack_arcs: Array[Line2D] = []
	for child in player.get_children():
		var line := child as Line2D
		if line != null and line.z_index >= 19:
			attack_arcs.append(line)
	var arcs_match := attack_arcs.size() == 2
	for arc in attack_arcs:
		arcs_match = (
			arcs_match
			and is_equal_approx(arc.points[6].length(), weapon_reach)
		)
	fixture.expect(
		arcs_match,
		"White Tiger attack effects match the actual weapon reach"
	)
	player.change_state(player.IDLE)

	controller.unlock_mask(&"vermilion_bird")
	fixture.expect(
		controller.cycle_primary() == &"vermilion_bird",
		"Cycle selects the next unlocked beast mask"
	)
	player.change_state(player.ATTACK)
	fixture.expect(
		is_equal_approx(weapon_shape.scale.x, 1.5)
		and int(weapon_area.get_meta(&"attack_damage", 1)) == 8,
		"Non-White-Tiger attacks keep the 1.5x base range and base damage"
	)
	player.change_state(player.IDLE)
	var restored_mask_ids: Array[StringName] = [&"white_tiger", &"black_tortoise"]
	player.apply_mask_progress(restored_mask_ids, &"black_tortoise")
	fixture.expect(
		controller.primary_mask_id == &"black_tortoise",
		"Campaign progress restores the equipped mask"
	)
	fixture.expect(
		controller.unlocked_mask_ids == [&"white_tiger", &"black_tortoise"],
		"Campaign progress restores unlocked masks in order"
	)
	var health_before_block: int = player.get_current_health()
	player.take_damage(1, Vector2.RIGHT)
	fixture.expect(
		player.get_current_health() == health_before_block,
		"Black Tortoise blocks one otherwise applicable hit"
	)
	fixture.expect(
		is_equal_approx(controller.get_black_tortoise_block_cooldown(), 10.0),
		"Black Tortoise automatic block starts its ten-second cooldown"
	)

	player.take_damage(1, Vector2.RIGHT)
	var health_after_hit: int = player.get_current_health()
	fixture.expect(
		health_after_hit == health_before_block - 1,
		"Damage passes after the automatic block is spent (health=%d block=%s)"
		% [health_after_hit, controller.get_black_tortoise_block_cooldown()]
	)
	player.call("_try_activate_mask")
	fixture.expect(
		player.get_current_health() == health_before_block,
		"Black Tortoise Q heals one health"
	)
	fixture.expect(
		is_equal_approx(controller.get_cooldown_left(), 15.0),
		"Black Tortoise Q starts its fifteen-second cooldown"
	)

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()
