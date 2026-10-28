extends SceneTree


const LEVEL_04_SCENE := preload("res://levels/level_04.tscn")
const RAGE_STORY_PATH := "res://levels/level_04_rage_story.json"
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	var level := fixture.instantiate_scene(LEVEL_04_SCENE) as CampaignLevel
	level.call("set_pre_awakening_story_enabled", false)
	fixture.set_current_scene(level)
	await fixture.process_frames(2)
	fixture.set_paused(false)
	level.call("prepare_for_campaign", false)
	await fixture.process_frames(1)

	var player := level.get_node("Player") as DamageableActor
	var valdemar := level.get_node("Enemies/Valdemar") as DamageableActor
	valdemar.call("_on_awakening_boundary_body_entered", player)
	await fixture.wait_seconds(1.0)
	await fixture.physics_frames(2)

	var enrage_count := [0]
	valdemar.connect(
		&"enrage_started",
		func() -> void: enrage_count[0] += 1
	)
	var rage_nodes = JSON.parse_string(FileAccess.get_file_as_string(RAGE_STORY_PATH))
	var rage_nodes_use_dragon := rage_nodes is Array
	if rage_nodes_use_dragon:
		for node in rage_nodes:
			if not node is Dictionary:
				rage_nodes_use_dragon = false
				break
			var right_portrait := str(node.get("right", ""))
			if (
				not right_portrait.is_empty()
				and not right_portrait.ends_with(
					"azure_dragon/frames/frame_000.png"
				)
			):
				rage_nodes_use_dragon = false
				break
	fixture.expect(
		rage_nodes_use_dragon,
		"Qinglong rage dialogue uses the dragon portrait instead of the legacy king"
	)
	valdemar.call("apply_debug_health_override", 56)
	valdemar.call("take_damage", 2, Vector2.ZERO)
	await fixture.process_frames(1)

	var rage_story := level.get_node_or_null("RageStory") as CanvasLayer
	fixture.expect(rage_story != null, "Qinglong half health opens the rage story")
	fixture.expect(
		rage_story != null
		and rage_story.get("story_path") == RAGE_STORY_PATH
		and paused,
		"Qinglong rage story pauses combat with its dedicated dialogue"
	)
	fixture.expect(
		not bool(valdemar.call("is_enraged")),
		"Qinglong stays in the normal phase until the rage story finishes"
	)

	rage_story.emit_signal(&"story_finished")
	await fixture.process_frames(2)
	var sword_cooldown := valdemar.get_node("SwordGleamCooldown") as Timer
	var black_water_cooldown := valdemar.get_node("BlackWaterCooldown") as Timer
	var black_water := level.get_node("BlackWater") as Area2D
	var black_water_sprite := black_water.get_node("Sprite2D") as Sprite2D
	var black_water_collision := black_water.get_node(
		"CollisionShape2D"
	) as CollisionShape2D
	var sword_gleam := valdemar.get_node("SwordGleam") as Area2D
	var sword_sprite := sword_gleam.get_node("Sprite2D") as Sprite2D
	var sword_particles := sword_gleam.get_node("CPUParticles2D") as CPUParticles2D
	var body_collision := valdemar.get_node("CollisionShape2D") as CollisionShape2D
	var hurt_box_collision := valdemar.get_node(
		"HurtBox/CollisionShape2D"
	) as CollisionShape2D
	var dragon_model := valdemar.get_node(
		"BeastVisual/AzureDragonModel"
	) as Sprite2D
	fixture.expect(
		not paused
		and bool(valdemar.call("is_enraged"))
		and enrage_count[0] == 1,
		"Completing the rage story resumes combat and triggers Qinglong enrage once"
	)
	fixture.expect(
		valdemar.call("get_current_health") == 110
		and valdemar.scale.is_equal_approx(Vector2(1.2, 1.2))
		and dragon_model.global_scale.is_equal_approx(Vector2(1.08, 1.08))
		and body_collision.global_scale.is_equal_approx(Vector2(1.2, 1.2))
		and hurt_box_collision.global_scale.is_equal_approx(Vector2(1.2, 1.2)),
		"Qinglong enrage restores full health and enlarges its model and collisions"
	)
	fixture.expect(
		is_equal_approx(sword_cooldown.wait_time, 1.5)
		and is_equal_approx(black_water_cooldown.wait_time, 8.0),
		"Qinglong enrage doubles the frequency of both attack timers "
		+ "(sword=%.3f black_water=%.3f)"
		% [sword_cooldown.wait_time, black_water_cooldown.wait_time]
	)
	var legacy_dark_mode := valdemar.get_node("DarkMode") as Sprite2D
	fixture.expect(
		dragon_model.modulate.b > dragon_model.modulate.r
		and is_zero_approx(legacy_dark_mode.modulate.a),
		"Qinglong uses the purple dragon model without the legacy model showing"
	)
	fixture.expect(
		sword_sprite.material is ShaderMaterial
		and sword_sprite.material.get("shader") != null
		and sword_particles.color.b > sword_particles.color.g,
		"Qinglong enrage turns Sword Gleam purple while keeping its particles purple"
	)
	fixture.expect(
		is_equal_approx(absf(sword_gleam.scale.x), 6.0)
		and is_equal_approx(absf(sword_gleam.global_scale.x), 7.2)
		and is_equal_approx(absf(sword_gleam.global_scale.y), 7.2),
		"Qinglong Sword Gleam uses its six-unit base with the 1.2 phase scale"
	)
	fixture.expect(
		black_water_sprite.scale.is_equal_approx(Vector2(36.0, 6.0))
		and black_water_collision.scale.is_equal_approx(Vector2(1.2, 1.2)),
		"Qinglong enrage enlarges Black Water Field's visual and collision range"
	)
	fixture.expect(
		black_water_sprite.modulate.is_equal_approx(Color.WHITE),
		"Qinglong enrage preserves the Black Water spray's original black color"
	)

	valdemar.emit_signal(&"health_changed", 40, 110)
	await fixture.process_frames(1)
	fixture.expect(
		level.get_node_or_null("RageStory") == null and enrage_count[0] == 1,
		"Qinglong rage story and enrage trigger only once"
	)
	valdemar.call("apply_debug_health_override", 1)
	valdemar.call("take_damage", 1, Vector2.ZERO)
	await fixture.process_frames(2)
	fixture.expect(
		not bool(valdemar.call("is_enraged"))
		and valdemar.scale.is_equal_approx(Vector2.ONE)
		and sword_sprite.material == null
		and sword_particles.color.is_equal_approx(
			Color(0.6117647, 0.8352941, 0.5176471, 1.0)
		)
		and black_water_sprite.scale.is_equal_approx(Vector2(30.0, 5.0))
		and black_water_collision.scale.is_equal_approx(Vector2.ONE)
		and not dragon_model.modulate.is_equal_approx(
			Color(0.58, 0.22, 0.82, 1.0)
		),
		"Qinglong enrage presentation clears when combat ends"
	)

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()
