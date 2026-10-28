extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const LEVEL_04_SCENE := preload("res://levels/level_04.tscn")

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	fixture.set_project_setting("physics/2d/default_gravity", 0.0)

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
		model.get("pounce_frame_paths").size() == 16,
		"Qinglong exposes sixteen generated counter-pounce frames"
	)

	player.set_physics_process(false)
	player.global_position = valdemar.global_position + Vector2(-1.0, -5000.0)
	valdemar.call("_on_awakening_boundary_body_entered", player)
	await fixture.wait_seconds(1.0)
	await fixture.physics_frames(2)

	(valdemar.get_node("SwordGleamCooldown") as Timer).start(9999.0)
	(valdemar.get_node("BlackWaterCooldown") as Timer).start(9999.0)
	(valdemar.get_node("AirAttackCooldown") as Timer).start(9999.0)
	var shield := player.get_node("VisualRoot/ShieldSkill/Shield") as CanvasItem
	shield.hide()
	player.global_position = valdemar.global_position + Vector2(240.0, 0.0)

	valdemar.take_damage(1, Vector2.LEFT)
	await fixture.wait_seconds(0.45)
	valdemar.take_damage(1, Vector2.LEFT)
	await fixture.wait_seconds(0.45)
	fixture.expect(
		int(valdemar.call("get_consecutive_player_hits")) == 2
		and not bool(valdemar.call("is_pouncing")),
		"Qinglong does not pounce before the third consecutive player hit"
	)

	var player_health_before := int(player.call("get_current_health"))
	var ground_position := valdemar.global_position
	valdemar.take_damage(1, Vector2.LEFT)
	await fixture.wait_seconds(0.50)
	await fixture.process_frames(1)
	fixture.expect(
		int(valdemar.call("get_consecutive_player_hits")) == 0
		and bool(valdemar.call("is_pouncing"))
		and "azure_dragon_pounce/frames" in model.texture.resource_path,
		"The third consecutive hit starts the generated pounce animation"
	)

	var health_during_pounce := int(valdemar.call("get_current_health"))
	valdemar.take_damage(1, Vector2.LEFT)
	await fixture.process_frames(1)
	fixture.expect(
		int(valdemar.call("get_current_health")) == health_during_pounce,
		"Qinglong is protected from interrupting damage during the committed pounce"
	)

	await fixture.wait_seconds(1.50)
	fixture.expect(
		int(player.call("get_current_health")) == player_health_before - 1,
		"Qinglong's dive deals one damage on impact"
	)

	await fixture.wait_seconds(1.0)
	await fixture.physics_frames(2)
	var body_collision := valdemar.get_node("CollisionShape2D") as CollisionShape2D
	var hurt_box_collision := valdemar.get_node(
		"HurtBox/CollisionShape2D"
	) as CollisionShape2D
	fixture.expect(
		not bool(valdemar.call("is_pouncing"))
		and absf(valdemar.global_position.y - ground_position.y) < 2.0
		and absf(valdemar.global_position.x - ground_position.x) < 200.0
		and not body_collision.disabled
		and not hurt_box_collision.disabled
		and int(valdemar.get("_dark_action")) == 0,
		"Qinglong lands, restores collision, and resumes pursuit after the pounce"
	)

	fixture.set_current_scene(null)
	level.free()
	await fixture.process_frames(1)
	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()
