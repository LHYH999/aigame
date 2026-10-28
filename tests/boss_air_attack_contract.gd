extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const PLAYER_SCENE := preload("res://player/player.tscn")
const LEVEL_02_SCENE := preload("res://levels/level_02.tscn")
const LEVEL_04_SCENE := preload("res://levels/level_04.tscn")
const PROJECTILE_SCENE := preload("res://enemies/skills/boss_projectile.tscn")

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	fixture.set_project_setting("physics/2d/default_gravity", 0.0)

	await test_projectile_damage()
	await test_vermilion_air_attack()
	await test_qinglong_enraged_attack_pattern()
	await test_qinglong_platform_sword_attack()
	await test_qinglong_first_phase_air_attack()
	await test_qinglong_air_attack()

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func test_projectile_damage() -> void:
	var player := fixture.instantiate_scene(PLAYER_SCENE) as DamageableActor
	fixture.set_current_scene(player)
	await fixture.process_frames(1)
	player.set_physics_process(false)
	player.global_position = Vector2.ZERO
	var health_before := int(player.call("get_current_health"))

	var projectile := PROJECTILE_SCENE.instantiate() as BossProjectile
	fixture.add_node(projectile)
	projectile.global_position = Vector2(-60.0, 0.0)
	projectile.setup(
		Vector2.RIGHT,
		180.0,
		BossProjectile.KIND_FIRE_FEATHER,
		Color("#ff6a24")
	)
	var projectile_sprite := projectile.get_node("Sprite2D") as Sprite2D
	fixture.expect(
		projectile_sprite.texture.resource_path.ends_with("fire_feather.png"),
		"Generated fire-feather projectile uses its transparent pixel texture"
	)
	await fixture.wait_seconds(0.5)
	fixture.expect(
		player.call("get_current_health") == health_before - 1,
		"Boss projectile deals one damage through the Player body"
	)

	fixture.set_current_scene(null)
	player.free()
	await fixture.process_frames(1)


func test_vermilion_air_attack() -> void:
	var level := fixture.instantiate_scene(LEVEL_02_SCENE) as CampaignLevel
	level.call("prepare_for_campaign", false)
	fixture.set_current_scene(level)
	await fixture.process_frames(2)
	fixture.set_paused(false)

	var player := level.get_node("Player") as DamageableActor
	var bear_king := level.get_node("Enemies/BearKing") as DamageableActor
	var model := bear_king.get_node(
		"BeastVisual/VermilionBirdModel"
	) as Sprite2D
	fixture.expect(
		model.get("air_attack_frame_paths").size() == 8,
		"Vermilion Bird owns eight generated air-attack frames"
	)
	player.set_physics_process(false)
	player.set_damage_immune(true)
	player.global_position = bear_king.global_position + Vector2(-500.0, 0.0)
	(bear_king.get_node("SkillDetect/Cooldown") as Timer).start(9999.0)
	var ground_y := bear_king.global_position.y
	var full_health := int(bear_king.call("get_current_health"))

	bear_king.call("_start_air_attack")
	await fixture.wait_seconds(0.85)
	fixture.expect(
		full_health == int(bear_king.call("get_maximum_health"))
		and bool(bear_king.call("is_air_attacking"))
		and bear_king.global_position.y < ground_y - 100.0,
		"Vermilion Bird can enter its air attack without a second-phase health gate"
	)

	await fixture.wait_seconds(0.15)
	fixture.expect(
		bool(bear_king.call("is_air_casting"))
		and "vermilion_bird_air_attack/frames" in model.texture.resource_path,
		"Vermilion Bird plays the generated air-cast frames "
		+ "(casting=%s texture=%s)"
		% [bear_king.call("is_air_casting"), model.texture.resource_path]
	)
	await fixture.wait_seconds(0.35)
	fixture.expect(
		get_nodes_in_group(&"enemy_projectiles").size() == 3,
		"Vermilion Bird air attack releases a three-feather fan "
		+ "(projectiles=%s)" % get_nodes_in_group(&"enemy_projectiles").size()
	)

	await fixture.wait_seconds(3.0)
	fixture.expect(
		not bool(bear_king.call("is_air_attacking"))
		and is_equal_approx(bear_king.global_position.y, ground_y)
		and not (bear_king.get_node(
			"HurtBox/CollisionShape2D"
		) as CollisionShape2D).disabled,
		"Vermilion Bird returns to combat collision after its air attack"
	)

	fixture.set_current_scene(null)
	level.free()
	await fixture.process_frames(1)


func test_qinglong_enraged_attack_pattern() -> void:
	var level := fixture.instantiate_scene(LEVEL_04_SCENE) as CampaignLevel
	level.call("set_pre_awakening_story_enabled", false)
	level.call("set_rage_story_enabled", false)
	fixture.set_current_scene(level)
	await fixture.process_frames(2)
	fixture.set_paused(false)
	level.call("prepare_for_campaign", false)
	await fixture.process_frames(1)

	var player := level.get_node("Player") as DamageableActor
	var valdemar := level.get_node("Enemies/Valdemar") as DamageableActor
	player.set_physics_process(false)
	player.set_damage_immune(true)
	player.global_position = valdemar.global_position + Vector2(-1.0, -5000.0)
	valdemar.call("_on_awakening_boundary_body_entered", player)
	await fixture.wait_seconds(1.0)
	await fixture.physics_frames(2)
	valdemar.call("begin_enraged_phase")

	var expected_pattern: Array[StringName] = [
		&"sword",
		&"sword",
		&"black_water",
		&"sword",
		&"sword",
		&"air",
	]
	var observed_pattern: Array[StringName] = []
	for _step in expected_pattern.size():
		observed_pattern.append(valdemar.call("_get_current_enraged_action"))
		valdemar.call("_advance_enraged_attack")
	fixture.expect(
		observed_pattern == expected_pattern
		and valdemar.call("get_enraged_attack_pattern") == expected_pattern,
		"Qinglong follows sword, sword, Black Water, sword, sword, air"
	)
	valdemar.set("_enraged_attack_index", 2)
	valdemar.set("_dark_action", 2)
	valdemar.call("_finish_dark_action")
	await fixture.wait_seconds(0.5)
	fixture.expect(
		int(valdemar.get("_dark_action")) == 4,
		"Qinglong continues from the second Sword Gleam into Black Water"
	)

	fixture.set_current_scene(null)
	level.free()
	await fixture.process_frames(1)


func test_qinglong_platform_sword_attack() -> void:
	var level := fixture.instantiate_scene(LEVEL_04_SCENE) as CampaignLevel
	level.call("set_pre_awakening_story_enabled", false)
	level.call("set_rage_story_enabled", false)
	fixture.set_current_scene(level)
	await fixture.process_frames(2)
	fixture.set_paused(false)
	level.call("prepare_for_campaign", false)
	await fixture.process_frames(1)

	var player := level.get_node("Player") as DamageableActor
	var valdemar := level.get_node("Enemies/Valdemar") as DamageableActor
	player.set_physics_process(false)
	player.set_damage_immune(true)
	player.global_position = valdemar.global_position + Vector2(-1.0, -5000.0)
	valdemar.call("_on_awakening_boundary_body_entered", player)
	await fixture.wait_seconds(1.0)
	await fixture.physics_frames(2)

	valdemar.call("begin_enraged_phase")
	player.global_position = valdemar.global_position + Vector2(-600.0, -160.0)
	var sword_gleam := valdemar.get_node("SwordGleam") as Area2D
	var sword_animation := sword_gleam.get_node("AnimationPlayer") as AnimationPlayer
	var attack_count := [0]
	sword_animation.animation_started.connect(
		func(animation_name: StringName) -> void:
			if animation_name == &"cast":
				attack_count[0] += 1
	)
	var best_alignment := INF
	for _frame in 600:
		await fixture.physics_frames(1)
		if sword_gleam.visible:
			best_alignment = minf(
				best_alignment,
				absf(sword_gleam.global_position.y - player.global_position.y)
			)
		if attack_count[0] >= 2:
			break
	fixture.expect(
		attack_count[0] >= 2 and best_alignment < 20.0,
		"Qinglong attacks an elevated Player twice and aligns Sword Gleam "
		+ "(attacks=%s alignment=%.2f)" % [attack_count[0], best_alignment]
	)

	fixture.set_current_scene(null)
	level.free()
	await fixture.process_frames(1)


func test_qinglong_first_phase_air_attack() -> void:
	var level := fixture.instantiate_scene(LEVEL_04_SCENE) as CampaignLevel
	level.call("set_pre_awakening_story_enabled", false)
	level.call("set_rage_story_enabled", false)
	fixture.set_current_scene(level)
	await fixture.process_frames(2)
	fixture.set_paused(false)
	level.call("prepare_for_campaign", false)
	await fixture.process_frames(1)

	var player := level.get_node("Player") as DamageableActor
	var valdemar := level.get_node("Enemies/Valdemar") as DamageableActor
	player.set_physics_process(false)
	player.set_damage_immune(true)
	player.global_position = valdemar.global_position + Vector2(-1.0, -5000.0)
	valdemar.call("_on_awakening_boundary_body_entered", player)
	await fixture.wait_seconds(1.0)
	await fixture.physics_frames(2)
	player.global_position = valdemar.global_position + Vector2(-500.0, 0.0)
	valdemar.call("_start_air_attack")
	await fixture.wait_seconds(1.45)
	var first_phase_projectiles := get_nodes_in_group(&"enemy_projectiles").filter(
		func(projectile: Node) -> bool:
			return (
				(projectile.get_node("Sprite2D") as Sprite2D).texture.resource_path
				.ends_with("purple_orb.png")
			)
	)
	fixture.expect(
		first_phase_projectiles.size() == 2
		and int(valdemar.get("_air_attack_volley_count")) == 1,
		"First-phase Qinglong fires two purple orbs in a single volley"
	)

	fixture.set_current_scene(null)
	level.free()
	await fixture.process_frames(1)


func test_qinglong_air_attack() -> void:
	var level := fixture.instantiate_scene(LEVEL_04_SCENE) as CampaignLevel
	level.call("set_pre_awakening_story_enabled", false)
	level.call("set_rage_story_enabled", false)
	fixture.set_current_scene(level)
	await fixture.process_frames(2)
	fixture.set_paused(false)
	level.call("prepare_for_campaign", false)
	await fixture.process_frames(1)

	var player := level.get_node("Player") as DamageableActor
	var valdemar := level.get_node("Enemies/Valdemar") as DamageableActor
	var model := valdemar.get_node(
		"BeastVisual/AzureDragonModel"
	) as Sprite2D
	fixture.expect(
		model.get("air_attack_frame_paths").size() == 8,
		"Qinglong owns eight generated air-attack frames"
	)
	player.set_physics_process(false)
	player.set_damage_immune(true)
	player.global_position = valdemar.global_position + Vector2(-1.0, -5000.0)
	valdemar.call("_on_awakening_boundary_body_entered", player)
	await fixture.wait_seconds(1.0)
	await fixture.physics_frames(2)
	player.global_position = valdemar.global_position + Vector2(-500.0, 0.0)
	valdemar.call("begin_enraged_phase")
	var ground_y := valdemar.global_position.y
	valdemar.call("_start_air_attack")

	await fixture.wait_seconds(0.9)
	fixture.expect(
		bool(valdemar.call("is_air_attacking"))
		and valdemar.global_position.y < ground_y - 240.0,
		"Qinglong enters its airborne second-phase attack at the raised height"
	)
	await fixture.wait_seconds(0.3)
	fixture.expect(
		bool(valdemar.call("is_air_casting"))
		and "azure_dragon_air_attack/frames" in model.texture.resource_path,
		"Qinglong plays the generated purple-phase air-cast frames"
	)
	await fixture.wait_seconds(0.25)
	var purple_projectiles := get_nodes_in_group(&"enemy_projectiles").filter(
		func(projectile: Node) -> bool:
			return (
				(projectile.get_node("Sprite2D") as Sprite2D).texture.resource_path
				.ends_with("purple_orb.png")
			)
	)
	fixture.expect(
		purple_projectiles.size() == 4,
		"Qinglong air attack releases four generated purple-orb projectiles per volley"
	)
	if purple_projectiles.size() == 4:
		var purple_projectile := purple_projectiles[0] as BossProjectile
		var purple_sprite := purple_projectile.get_node("Sprite2D") as Sprite2D
		var purple_collision := purple_projectile.get_node(
			"CollisionShape2D"
		) as CollisionShape2D
		var velocity: Vector2 = purple_projectile.get("_velocity")
		fixture.expect(
			purple_sprite.scale.is_equal_approx(Vector2(2.5, 2.5))
			and (purple_collision.shape as RectangleShape2D).size.is_equal_approx(
				Vector2(65.0, 65.0)
			)
			and is_equal_approx(velocity.length(), 600.0),
			"Qinglong projectile uses slightly reduced size and 600 speed"
		)
	var first_volley_ids: Array[int] = []
	for projectile in purple_projectiles:
		first_volley_ids.append(projectile.get_instance_id())
	await fixture.wait_seconds(0.85)
	var second_volley_projectiles := get_nodes_in_group(
		&"enemy_projectiles"
	).filter(
		func(projectile: Node) -> bool:
			return (
				not first_volley_ids.has(projectile.get_instance_id())
				and
				(projectile.get_node("Sprite2D") as Sprite2D).texture.resource_path
				.ends_with("purple_orb.png")
			)
	)
	fixture.expect(
		second_volley_projectiles.size() == 4,
		"Qinglong fires four new purple orbs after the 0.8-second volley interval"
	)
	var air_attack_timer := valdemar.get_node(
		"AirAttackCooldown"
	) as Timer
	fixture.expect(
		is_equal_approx(air_attack_timer.wait_time, 12.0),
		"Qinglong purple lightning breath uses a twelve-second cooldown"
	)

	await fixture.wait_seconds(4.0)
	var hurt_box_collision := valdemar.get_node(
		"HurtBox/CollisionShape2D"
	) as CollisionShape2D
	fixture.expect(
		not bool(valdemar.call("is_air_attacking"))
		and valdemar.global_position.y <= ground_y + 1.0
		and valdemar.global_position.y > ground_y - 30.0
		and not hurt_box_collision.disabled,
		"Qinglong lands, restores collision, and resumes the ground phase "
		+ "(y=%.2f ground=%.2f hurt_disabled=%s active=%s action=%s)"
		% [
			valdemar.global_position.y,
			ground_y,
			hurt_box_collision.disabled,
			valdemar.call("is_air_attacking"),
			valdemar.get("_dark_action"),
		]
	)

	fixture.set_current_scene(null)
	level.free()
	await fixture.process_frames(1)
