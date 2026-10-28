extends Node2D


const LEVEL_00_SCENE := preload("res://levels/level_00.tscn")
const LEVEL_01_SCENE := preload("res://levels/level_01.tscn")
const LEVEL_02_SCENE := preload("res://levels/level_02.tscn")
const LEVEL_03_SCENE := preload("res://levels/level_03.tscn")
const LEVEL_04_SCENE := preload("res://levels/level_04.tscn")
const CAMPAIGN_PROLOGUE_SCENE := preload("res://ui/prologue.tscn")
const CAMPAIGN_EPILOGUE_SCENE := preload("res://ui/end.tscn")
const PRODUCER_SCENE := preload("res://ui/producer.tscn")
const CampaignSaveModule := preload("res://save/campaign_save.gd")
const RESULT_DEAD := "DEAD"
const CAMPAIGN_PHASE_TITLE := &"title"
const CAMPAIGN_PHASE_PROLOGUE := &"prologue"
const CAMPAIGN_PHASE_GUIDE := &"guide"
const CAMPAIGN_PHASE_LEVEL := &"level"
const CAMPAIGN_PHASE_EPILOGUE := &"epilogue"
const CAMPAIGN_PHASE_PRODUCER := &"producer"

@export var persistence_enabled := true
@export var save_path := "user://campaign_autosave.json"

var _active_level: CampaignLevel = null
var _suspended_level: CampaignLevel = null
var _campaign_prologue: CanvasLayer = null
var _campaign_epilogue: CanvasLayer = null
var _producer_page: CanvasLayer = null
var _victory_story_active := false
var _level_completion_handled := false
var _active_level_scene: PackedScene = null
var _unlocked_mask_ids: Array[StringName] = []
var _equipped_mask_id: StringName = &""
var _current_campaign_id: StringName = &""
var _current_checkpoint_id: StringName = &""

@onready var _title: Control = $Title
@onready var _guide: Control = $Guide
@onready var _game_result_popup := $GameResultPopup
@onready var _pause_menu = $PauseMenu


func _ready() -> void:
	if (
		DisplayServer.get_name() == "headless"
		and save_path == CampaignSaveModule.DEFAULT_SAVE_PATH
	):
		persistence_enabled = false
	_game_result_popup.hide_result()
	_title.connect("start_requested", _on_title_start_requested)
	_title.connect("continue_requested", _on_title_continue_requested)
	_game_result_popup.retry_requested.connect(_on_retry_pressed)
	_game_result_popup.quit_requested.connect(_on_quit_pressed)
	_pause_menu.retry_requested.connect(_on_pause_retry_requested)
	_pause_menu.title_requested.connect(_on_pause_title_requested)
	_pause_menu.quit_requested.connect(_on_quit_pressed)
	_refresh_continue_button()


func _input(event: InputEvent) -> void:
	if is_instance_valid(_campaign_prologue):
		if not _is_campaign_page_continuation(event):
			return

		get_viewport().set_input_as_handled()
		_campaign_prologue.queue_free()
		_campaign_prologue = null
		_guide.visible = true
		return

	if is_instance_valid(_campaign_epilogue):
		if not _is_campaign_page_continuation(event):
			return

		get_viewport().set_input_as_handled()
		_campaign_epilogue.queue_free()
		_campaign_epilogue = null
		_producer_page = PRODUCER_SCENE.instantiate() as CanvasLayer
		add_child(_producer_page)
		return

	if not _guide.visible:
		return
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if not event.is_pressed() or event.is_echo():
		return

	get_viewport().set_input_as_handled()
	_guide.visible = false
	start_level_01()


func _is_campaign_page_continuation(event: InputEvent) -> bool:
	if not (
		event is InputEventKey
		or event is InputEventMouseButton
		or event is InputEventJoypadButton
		or event is InputEventScreenTouch
	):
		return false
	return event.is_pressed() and not event.is_echo()


func get_campaign_phase() -> StringName:
	if _active_level != null:
		return CAMPAIGN_PHASE_LEVEL
	if is_instance_valid(_campaign_prologue):
		return CAMPAIGN_PHASE_PROLOGUE
	if is_instance_valid(_campaign_epilogue):
		return CAMPAIGN_PHASE_EPILOGUE
	if is_instance_valid(_producer_page):
		return CAMPAIGN_PHASE_PRODUCER
	if is_instance_valid(_title) and _title.visible:
		return CAMPAIGN_PHASE_TITLE
	if _guide.visible:
		return CAMPAIGN_PHASE_GUIDE
	return CAMPAIGN_PHASE_TITLE


func get_active_campaign_level() -> CampaignLevel:
	return _active_level


func is_campaign_result_visible() -> bool:
	return _game_result_popup.is_result_visible()


func can_open_pause_menu() -> bool:
	return (
		is_instance_valid(_active_level)
		and not _game_result_popup.is_result_visible()
		and not _victory_story_active
		and not _active_level.is_campaign_story_phase_active()
		and not _active_level.is_campaign_act_announcement_active()
		and _active_level.is_campaign_control_available()
	)


func connect_level_events() -> void:
	_active_level.campaign_outcome_reached.connect(
		_on_campaign_outcome_reached.bind(_active_level)
	)
	_active_level.mask_awarded.connect(_on_mask_awarded)
	_active_level.checkpoint_reached.connect(
		_on_checkpoint_reached.bind(_active_level)
	)


func set_level_controls_enabled(enabled: bool) -> void:
	if _active_level == null:
		return

	_active_level.set_campaign_controls_enabled(enabled)


func show_result(result_text: String) -> void:
	if _game_result_popup.is_result_visible():
		return

	set_level_controls_enabled(false)
	_game_result_popup.show_result(result_text)


func start_level(
	scene: PackedScene,
	play_opening_story: bool,
	play_pre_awakening_story := true
) -> void:
	replace_campaign_session(
		scene,
		play_opening_story,
		play_pre_awakening_story
	)


func replace_campaign_session(
	scene: PackedScene,
	play_opening_story: bool,
	play_pre_awakening_story := true
) -> void:
	get_tree().paused = false
	if is_instance_valid(_title):
		_title.visible = false
	if is_instance_valid(_campaign_prologue):
		_campaign_prologue.queue_free()
		_campaign_prologue = null
	_guide.visible = false
	_victory_story_active = false
	_current_checkpoint_id = CampaignLevel.CHECKPOINT_LEVEL_START

	if _suspended_level != null:
		var old_suspended_level := _suspended_level
		_suspended_level = null
		old_suspended_level.queue_free()

	var next_level := scene.instantiate() as CampaignLevel
	if scene == LEVEL_04_SCENE:
		next_level.call(
			"set_pre_awakening_story_enabled",
			play_pre_awakening_story
		)
	next_level.prepare_for_campaign(play_opening_story)
	replace_level(scene, next_level)
	if scene == LEVEL_01_SCENE and play_opening_story:
		_active_level.campaign_story_phase_finished.connect(
			_on_level_01_story_phase_finished.bind(_active_level),
			CONNECT_ONE_SHOT
		)


func replace_level(scene: PackedScene, next_level: CampaignLevel) -> void:
	_game_result_popup.hide_result()

	if _active_level != null:
		var old_level := _active_level
		_active_level = null
		remove_child(old_level)
		old_level.queue_free()

	_active_level_scene = scene
	_active_level = next_level
	_current_campaign_id = next_level.get_campaign_id()
	_level_completion_handled = false

	add_child(_active_level)
	move_child(_active_level, 0)
	connect_level_events()
	_apply_active_mask_progress()


func start_level_01(play_intro: bool = true) -> void:
	replace_campaign_session(LEVEL_01_SCENE, play_intro)


func start_level_02(play_intro: bool = true) -> void:
	start_level(LEVEL_02_SCENE, play_intro)


func start_level_03() -> void:
	start_level(LEVEL_03_SCENE, true)


func start_level_04(play_intro: bool = true) -> void:
	start_level(LEVEL_04_SCENE, play_intro)


func play_level_00() -> void:
	if _active_level == null or _active_level.get_campaign_id() != &"level_01":
		return
	if _suspended_level != null:
		return

	_suspended_level = _active_level
	_suspended_level.suspend_from_campaign()
	remove_child(_suspended_level)

	_active_level = LEVEL_00_SCENE.instantiate() as CampaignLevel
	_active_level.name = "Level00"
	_active_level.prepare_for_campaign(true)
	_active_level.campaign_story_phase_finished.connect(
		_on_level_00_story_finished.bind(_active_level),
		CONNECT_ONE_SHOT
	)
	add_child(_active_level)
	move_child(_active_level, 0)


func _on_title_start_requested() -> void:
	_unlocked_mask_ids.clear()
	_equipped_mask_id = &""
	_current_campaign_id = &""
	_current_checkpoint_id = &""
	if persistence_enabled:
		CampaignSaveModule.clear(save_path)
	_title.visible = false
	_title.queue_free()
	_campaign_prologue = CAMPAIGN_PROLOGUE_SCENE.instantiate() as CanvasLayer
	add_child(_campaign_prologue)


func _on_title_continue_requested() -> void:
	continue_campaign()


func continue_campaign() -> bool:
	var data: Dictionary = CampaignSaveModule.load_game(save_path)
	if data.is_empty():
		_refresh_continue_button()
		return false
	var scene := _get_campaign_scene(StringName(data["campaign_id"]))
	if scene == null:
		return false

	_unlocked_mask_ids = CampaignSaveModule.get_mask_ids(data)
	_equipped_mask_id = StringName(data.get("equipped_mask", ""))
	_current_campaign_id = StringName(data["campaign_id"])
	var checkpoint_id := StringName(data["checkpoint"])
	_current_checkpoint_id = checkpoint_id
	if is_instance_valid(_title):
		_title.visible = false
		_title.queue_free()
	start_level(scene, false, true)
	_current_checkpoint_id = checkpoint_id
	if checkpoint_id == CampaignLevel.CHECKPOINT_BOSS:
		await _active_level.restore_boss_checkpoint()
	return true


func has_save_game() -> bool:
	return persistence_enabled and CampaignSaveModule.has_valid_save(save_path)


func get_current_checkpoint_id() -> StringName:
	return _current_checkpoint_id


func _refresh_continue_button() -> void:
	if is_instance_valid(_title):
		_title.call("set_continue_available", has_save_game())


func _on_checkpoint_reached(
	checkpoint_id: StringName,
	source: CampaignLevel
) -> void:
	if source != _active_level:
		return
	_sync_active_mask_equipment()
	_current_campaign_id = source.get_campaign_id()
	_current_checkpoint_id = checkpoint_id
	if not persistence_enabled:
		return
	var data := CampaignSaveModule.create_data(
		_current_campaign_id,
		_current_checkpoint_id,
		_unlocked_mask_ids,
		_equipped_mask_id
	)
	var save_error: Error = CampaignSaveModule.save_game(data, save_path)
	if save_error != OK:
		push_warning("Campaign checkpoint could not be saved: %s" % save_error)


func _get_campaign_scene(campaign_id: StringName) -> PackedScene:
	match campaign_id:
		&"level_01":
			return LEVEL_01_SCENE
		&"level_02":
			return LEVEL_02_SCENE
		&"level_03":
			return LEVEL_03_SCENE
		&"level_04":
			return LEVEL_04_SCENE
	return null


func _on_level_01_story_phase_finished(source: CampaignLevel) -> void:
	if source != _active_level:
		return
	play_level_00()


func _on_level_00_story_finished(source: CampaignLevel) -> void:
	if source != _active_level:
		return
	if _suspended_level == null:
		return

	var finished_level_00 := _active_level
	_active_level = _suspended_level
	_suspended_level = null

	remove_child(finished_level_00)
	finished_level_00.queue_free()
	add_child(_active_level)
	move_child(_active_level, 0)
	_active_level.restore_to_campaign()


func _on_campaign_outcome_reached(outcome: StringName, source: CampaignLevel) -> void:
	if source != _active_level:
		return

	match outcome:
		CampaignLevel.OUTCOME_DEFEAT:
			if not _victory_story_active:
				show_result(RESULT_DEAD)
		CampaignLevel.OUTCOME_COMPLETION:
			var mask_id: Variant = source.get("campaign_mask_id")
			if mask_id is StringName:
				_on_mask_awarded(mask_id)
			play_level_victory_story(source)


func _on_mask_awarded(mask_id: StringName) -> void:
	if mask_id.is_empty() or _unlocked_mask_ids.has(mask_id):
		return
	_unlocked_mask_ids.append(mask_id)
	if _equipped_mask_id.is_empty():
		_equipped_mask_id = mask_id
	_apply_active_mask_progress()


func _apply_active_mask_progress() -> void:
	if _active_level == null:
		return
	_active_level.apply_campaign_masks(_unlocked_mask_ids, _equipped_mask_id)


func play_level_victory_story(source: CampaignLevel) -> void:
	if _victory_story_active or _level_completion_handled:
		return
	if not source.start_campaign_victory_story():
		return

	_victory_story_active = true
	_level_completion_handled = true
	_game_result_popup.hide_result()
	source.campaign_story_phase_finished.connect(
		_on_level_victory_story_finished.bind(source),
		CONNECT_ONE_SHOT
	)


func _on_level_victory_story_finished(source: CampaignLevel) -> void:
	if source != _active_level:
		return
	_victory_story_active = false
	_sync_active_mask_equipment()

	match source.get_campaign_id():
		&"level_01":
			start_level_02()
		&"level_02":
			start_level_03()
		&"level_03":
			start_level_04()
		&"level_04":
			show_campaign_epilogue()


func show_campaign_epilogue() -> void:
	get_tree().paused = false
	_game_result_popup.hide_result()

	if _active_level != null:
		var finished_level := _active_level
		_active_level = null
		remove_child(finished_level)
		finished_level.queue_free()
	_active_level_scene = null

	_campaign_epilogue = CAMPAIGN_EPILOGUE_SCENE.instantiate() as CanvasLayer
	_campaign_epilogue.name = "CampaignEpiloguePage"
	add_child(_campaign_epilogue)


func retry_campaign() -> void:
	if _active_level_scene == null:
		return

	_sync_active_mask_equipment()
	var restore_boss_checkpoint := (
		_current_checkpoint_id == CampaignLevel.CHECKPOINT_BOSS
	)
	get_tree().paused = false
	start_level(_active_level_scene, false, false)
	_current_checkpoint_id = (
		CampaignLevel.CHECKPOINT_BOSS
		if restore_boss_checkpoint
		else CampaignLevel.CHECKPOINT_LEVEL_START
	)
	if restore_boss_checkpoint:
		await _active_level.restore_boss_checkpoint()


func _on_retry_pressed() -> void:
	retry_campaign()


func _on_pause_retry_requested() -> void:
	retry_campaign()


func _on_pause_title_requested() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _sync_active_mask_equipment() -> void:
	if _active_level == null:
		return
	var equipped_mask_id := _active_level.get_campaign_equipped_mask_id()
	if not equipped_mask_id.is_empty():
		_equipped_mask_id = equipped_mask_id
