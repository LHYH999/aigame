extends "res://levels/level_base.gd"


const PRE_AWAKENING_STORY_PATH := "res://levels/level_04_a_story.json"
const RAGE_STORY_PATH := "res://levels/level_04_rage_story.json"
const TERMINAL_OUTCOME_NONE := &"none"
const TERMINAL_OUTCOME_PLAYER_DEFEAT := &"player_defeat"
const TERMINAL_OUTCOME_VALDEMAR_DEFEAT := &"valdemar_defeat"
const ACT_ANNOUNCEMENT_TEXT := "第四幕\n东木青龙"

@onready var valdemar = $Enemies/Valdemar
@onready var _black_water = $BlackWater

var _play_pre_awakening_story := true
var _rage_story_enabled := true
var _rage_story_started := false
var _terminal_outcome := TERMINAL_OUTCOME_NONE
var _level_completion_reached := false


func _get_act_announcement_text() -> String:
	return ACT_ANNOUNCEMENT_TEXT


func set_pre_awakening_story_enabled(enabled: bool) -> void:
	_play_pre_awakening_story = enabled


func set_rage_story_enabled(enabled: bool) -> void:
	_rage_story_enabled = enabled


func get_terminal_outcome() -> StringName:
	return _terminal_outcome


func set_campaign_controls_enabled(enabled: bool) -> void:
	super.set_campaign_controls_enabled(
		enabled and _terminal_outcome != TERMINAL_OUTCOME_VALDEMAR_DEFEAT
	)


func _ready() -> void:
	super._ready()
	valdemar.awakening_requested.connect(_on_valdemar_awakening_requested)
	valdemar.defeat_started.connect(_on_valdemar_defeat_started)
	valdemar.health_changed.connect(_on_valdemar_health_changed)
	valdemar.enrage_started.connect(_on_valdemar_enrage_started)


func _on_campaign_defeated() -> void:
	if _terminal_outcome != TERMINAL_OUTCOME_NONE:
		return

	_terminal_outcome = TERMINAL_OUTCOME_PLAYER_DEFEAT
	valdemar.call("end_enraged_phase")
	_black_water.call("set_enraged", false)
	super._on_campaign_defeated()


func _on_campaign_completed() -> void:
	if (
		_terminal_outcome != TERMINAL_OUTCOME_VALDEMAR_DEFEAT
		or _level_completion_reached
	):
		return
	_level_completion_reached = true
	super._on_campaign_completed()


func _on_valdemar_defeat_started() -> void:
	if _terminal_outcome != TERMINAL_OUTCOME_NONE:
		return
	if player.is_health_depleted():
		_on_campaign_defeated()
		return

	_terminal_outcome = TERMINAL_OUTCOME_VALDEMAR_DEFEAT
	_black_water.call("set_enraged", false)
	hud.visible = false
	set_campaign_controls_enabled(false)
	player.set_damage_immune(true)


func _on_valdemar_awakening_requested() -> void:
	if not _play_pre_awakening_story:
		valdemar.begin_awakening()
		return

	set_campaign_controls_enabled(false)
	hud.visible = false
	story = STORY_SCENE.instantiate() as CanvasLayer
	story.name = "PreAwakeningStory"
	story.set("story_path", PRE_AWAKENING_STORY_PATH)
	story.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	story.connect("story_finished", _on_pre_awakening_story_finished, CONNECT_ONE_SHOT)
	add_child(story)
	get_tree().paused = true


func _on_pre_awakening_story_finished() -> void:
	var finished_story := story
	story = null

	hud.visible = true
	get_tree().paused = false
	set_campaign_controls_enabled(true)
	finished_story.queue_free()
	campaign_story_phase_finished.emit()
	valdemar.begin_awakening()


func _on_valdemar_health_changed(current_health: int, maximum_health: int) -> void:
	if (
		not _rage_story_enabled
		or _rage_story_started
		or current_health <= 0
		or current_health * 2 >= maximum_health
		or _terminal_outcome != TERMINAL_OUTCOME_NONE
	):
		return

	_rage_story_started = true
	set_campaign_controls_enabled(false)
	hud.visible = false
	story = STORY_SCENE.instantiate() as CanvasLayer
	story.name = "RageStory"
	story.set("story_path", RAGE_STORY_PATH)
	story.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	story.connect("story_finished", _on_rage_story_finished, CONNECT_ONE_SHOT)
	add_child(story)
	get_tree().paused = true


func _on_valdemar_enrage_started() -> void:
	_black_water.call("set_enraged", true)


func _on_rage_story_finished() -> void:
	var finished_story := story
	story = null

	hud.visible = true
	get_tree().paused = false
	set_campaign_controls_enabled(true)
	finished_story.queue_free()
	campaign_story_phase_finished.emit()
	valdemar.begin_enraged_phase()
