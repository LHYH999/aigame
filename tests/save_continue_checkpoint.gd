extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const LEVEL_02_SCENE := preload("res://levels/level_02.tscn")
const MAIN_SCENE := preload("res://main.tscn")
const SaveSystem := preload("res://save/campaign_save.gd")
const SAVE_PATH := "res://.tmp/campaign_continue_contract.json"

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	SaveSystem.clear(SAVE_PATH)

	await verify_boss_door_emits_checkpoint()
	await verify_continue_restores_boss_checkpoint()
	await verify_new_game_clears_previous_save()

	SaveSystem.clear(SAVE_PATH)
	fixture.complete(false)
	await fixture.process_frames(2)
	fixture.complete()


func verify_boss_door_emits_checkpoint() -> void:
	var level := fixture.instantiate_scene(LEVEL_02_SCENE) as CampaignLevel
	level.call("prepare_for_campaign", false)
	fixture.set_current_scene(level)
	await fixture.process_frames(2)

	var player := level.get_node("Player") as CharacterBody2D
	var boss_door := level.get_node("BossDoor") as Area2D
	var checkpoints: Array[StringName] = []
	level.checkpoint_reached.connect(
		func(checkpoint_id: StringName) -> void:
			checkpoints.append(checkpoint_id)
	)
	player.set_physics_process(false)
	player.global_position = boss_door.global_position + Vector2(-100.0, 0.0)
	await fixture.physics_frames(2)
	boss_door.call("_on_body_entered", player)
	player.global_position = boss_door.global_position + Vector2(100.0, 0.0)
	boss_door.call("_on_body_exited", player)
	await fixture.process_frames(2)
	fixture.expect(
		checkpoints == [CampaignLevel.CHECKPOINT_BOSS],
		"Crossing a Boss Door emits exactly one Boss checkpoint"
	)

	fixture.set_current_scene(null)
	level.queue_free()
	await fixture.process_frames(1)


func verify_continue_restores_boss_checkpoint() -> void:
	var masks: Array[StringName] = [&"white_tiger", &"vermilion_bird"]
	var data := SaveSystem.create_data(
		&"level_02",
		SaveSystem.CHECKPOINT_BOSS,
		masks,
		&"vermilion_bird"
	)
	fixture.expect(
		SaveSystem.save_game(data, SAVE_PATH) == OK,
		"Continue test save is written"
	)

	var main := MAIN_SCENE.instantiate()
	main.set("save_path", SAVE_PATH)
	main.set("persistence_enabled", true)
	fixture.add_node(main)
	fixture.set_current_scene(main)
	await fixture.process_frames(2)

	var title := main.get_node("Title")
	var continue_button := title.get_node("VBoxContainer/Continue") as Button
	var title_label := title.get_node("Label") as Label
	var start_button := title.get_node("VBoxContainer/Start") as Button
	fixture.expect(
		continue_button.visible and not continue_button.disabled,
		"Title exposes Continue when a valid campaign save exists"
	)
	fixture.expect(
		title_label.get_global_rect().end.y
		<= start_button.get_global_rect().position.y - 12.0,
		"Title remains clear of the complete menu stack when Continue is visible"
	)
	fixture.expect(
		title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and is_equal_approx(
			title_label.get_global_rect().get_center().x,
			main.get_viewport_rect().size.x * 0.5
		),
		"Title text remains horizontally centered across the viewport"
	)
	continue_button.emit_signal("pressed")
	for _frame in 20:
		if main.call("get_active_campaign_level") != null:
			break
		await fixture.process_frames(1)
	await fixture.wait_seconds(0.2)

	var level := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		level != null and level.get_campaign_id() == &"level_02",
		"Continue restores the saved campaign Level"
	)
	if level == null:
		return

	var player := level.get_node("Player") as CharacterBody2D
	var boss_door := level.get_node("BossDoor") as Area2D
	fixture.expect(
		player.has_mask(&"white_tiger")
		and player.has_mask(&"vermilion_bird")
		and player.get_mask_controller().primary_mask_id == &"vermilion_bird",
		"Continue restores unlocked masks and the equipped mask"
	)
	fixture.expect(
		main.call("get_current_checkpoint_id") == CampaignLevel.CHECKPOINT_BOSS
		and boss_door.get("is_locked")
		and player.global_position.x > boss_door.global_position.x,
		"Continue restores the Player beyond the locked Boss checkpoint door"
	)

	await main.call("retry_campaign")
	await fixture.wait_seconds(0.2)
	var retried_level := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		retried_level != null
		and retried_level != level
		and retried_level.get_campaign_id() == &"level_02",
		"Defeat retry recreates the saved campaign Level at its Boss checkpoint"
	)
	if retried_level != null:
		var retried_player := retried_level.get_node("Player") as CharacterBody2D
		var retried_door := retried_level.get_node("BossDoor") as Area2D
		fixture.expect(
			retried_door.get("is_locked")
			and retried_player.global_position.x > retried_door.global_position.x,
			"Defeat retry restores the Player beyond the locked Boss Door"
		)

	fixture.set_current_scene(null)
	main.queue_free()
	await fixture.process_frames(2)


func verify_new_game_clears_previous_save() -> void:
	fixture.expect(
		SaveSystem.has_valid_save(SAVE_PATH),
		"Boss checkpoint save remains available before starting a new campaign"
	)
	var main := MAIN_SCENE.instantiate()
	main.set("save_path", SAVE_PATH)
	main.set("persistence_enabled", true)
	fixture.add_node(main)
	fixture.set_current_scene(main)
	await fixture.process_frames(2)

	var title := main.get_node("Title")
	title.emit_signal("start_requested")
	await fixture.process_frames(2)
	fixture.expect(
		not SaveSystem.has_valid_save(SAVE_PATH)
		and main.call("get_campaign_phase") == &"prologue",
		"Starting a new campaign clears the previous autosave"
	)

	fixture.set_current_scene(null)
	main.queue_free()
	await fixture.process_frames(2)
