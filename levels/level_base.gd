extends "res://levels/campaign_level.gd"


const STORY_SCENE := preload("res://ui/story.tscn")
const ENVIRONMENT_COLLISION_MASK := 1

@export_node_path("Node") var _campaign_completion_source_path: NodePath
@export_file("*.json") var _campaign_victory_story_path := ""
@export var campaign_mask_id: StringName

@onready var player = $Player
@onready var hud = $HUD
@onready var story: CanvasLayer = get_node_or_null("Story") as CanvasLayer
@onready var announcer: CanvasLayer = get_node_or_null("Announcer") as CanvasLayer
@onready var player_camera: Camera2D = $Player/Camera2D

var story_camera: Camera2D = null
var _opening_story_checkpoint_pending := false
var _boss_checkpoint_emitted := false


func _enter_tree() -> void:
	var act_announcer := get_node_or_null("Announcer")
	if act_announcer != null:
		act_announcer.set("announcement_text", _get_act_announcement_text())


func _get_act_announcement_text() -> String:
	return ""


func prepare_for_campaign(play_opening_story: bool) -> void:
	var level_player := get_node("Player")
	level_player.restore_full_health()
	_opening_story_checkpoint_pending = play_opening_story
	if play_opening_story:
		var background := get_node_or_null("Background")
		if background != null:
			background.call("set_music_autostart_enabled", false)
		return

	var opening_story := get_node_or_null("Story")
	if opening_story != null:
		remove_child(opening_story)
		opening_story.queue_free()

	var act_announcer := get_node_or_null("Announcer")
	if act_announcer != null:
		remove_child(act_announcer)
		act_announcer.queue_free()


func is_campaign_story_phase_active() -> bool:
	return story != null and announcer == null


func is_campaign_act_announcement_active() -> bool:
	return announcer != null


func get_campaign_act_announcement_text() -> String:
	var announcer := get_node_or_null("Announcer")
	if announcer == null:
		return ""
	return _get_act_announcement_text()


func is_campaign_control_available() -> bool:
	return is_inside_tree() and not get_tree().paused and player.controls_enabled


func is_campaign_hud_visible() -> bool:
	return is_inside_tree() and hud.visible


func is_campaign_health_full() -> bool:
	var maximum_health: int = player.get_maximum_health()
	return (
		player.get_current_health() == maximum_health
		and hud.is_presenting_health(maximum_health, maximum_health)
	)


func get_campaign_camera_role() -> StringName:
	if story_camera != null and story_camera.is_current():
		return CAMERA_OPENING_STORY
	if player_camera.is_current():
		return CAMERA_PLAYER
	return CAMERA_NONE


func has_campaign_music() -> bool:
	return get_node_or_null("Background") != null


func is_campaign_music_playing() -> bool:
	var background := get_node_or_null("Background")
	return background != null and bool(background.call("is_music_playing"))


func has_campaign_music_started() -> bool:
	var background := get_node_or_null("Background")
	return background != null and bool(background.call("has_music_started"))


func get_campaign_music_playback_position() -> float:
	var background := get_node_or_null("Background")
	if background == null:
		return 0.0
	return float(background.call("get_music_playback_position"))


func set_campaign_controls_enabled(enabled: bool) -> void:
	player.set_controls_enabled(enabled)


func start_campaign_victory_story() -> bool:
	if story != null or _campaign_victory_story_path.is_empty():
		return false

	set_campaign_controls_enabled(false)
	story = STORY_SCENE.instantiate() as CanvasLayer
	story.name = "VictoryStory"
	story.set("story_path", _campaign_victory_story_path)
	story.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	story.connect("story_finished", _on_victory_story_finished, CONNECT_ONE_SHOT)
	add_child(story)
	get_tree().paused = true
	return true


func suspend_from_campaign() -> void:
	var background := get_node_or_null("Background")
	if background != null:
		background.call("stop_music")


func restore_to_campaign() -> void:
	var background := get_node_or_null("Background")
	if background != null:
		background.call("start_music")


func _ready() -> void:
	hud.present_health(player.get_current_health(), player.get_maximum_health())
	player.health_changed.connect(hud.present_health)
	player.mask_state_changed.connect(hud.present_mask)
	player.connect("died", _on_campaign_defeated)

	var completion_source := get_node_or_null(_campaign_completion_source_path)
	if completion_source != null:
		completion_source.connect("died", _on_campaign_completed)

	if story != null:
		story_camera = Camera2D.new()
		story_camera.name = "StoryCamera"
		story_camera.position = Vector2.ZERO
		story_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
		story_camera.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		add_child(story_camera)
		story_camera.make_current()
		story_camera.force_update_scroll()

		hud.visible = false
		story.process_mode = (
			Node.PROCESS_MODE_DISABLED
			if announcer != null
			else Node.PROCESS_MODE_WHEN_PAUSED
		)
		story.set_process_input(announcer == null)
		story.connect("story_finished", _on_story_finished)
		if announcer != null:
			announcer.connect(
				"announcement_finished",
				_on_act_announcement_finished,
				CONNECT_ONE_SHOT
			)
		get_tree().paused = true

	var boss_door := get_node_or_null("BossDoor")
	if boss_door != null and boss_door.has_signal("crossed"):
		boss_door.connect("crossed", _on_boss_door_crossed)


func _exit_tree() -> void:
	if story != null:
		get_tree().paused = false


func _on_story_finished() -> void:
	var finished_story := story
	var finished_camera := story_camera
	story = null
	story_camera = null

	player_camera.make_current()
	player_camera.reset_smoothing()
	player_camera.force_update_scroll()
	finished_camera.queue_free()

	hud.visible = true
	get_tree().paused = false
	finished_story.queue_free()
	if _opening_story_checkpoint_pending:
		_opening_story_checkpoint_pending = false
		checkpoint_reached.emit(CHECKPOINT_LEVEL_START)
	campaign_story_phase_finished.emit()


func _on_act_announcement_finished() -> void:
	var finished_announcer := announcer
	announcer = null

	story.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	story.set_process_input(true)
	var background := get_node_or_null("Background")
	if background != null:
		background.call("start_music")
	finished_announcer.queue_free()


func _on_victory_story_finished() -> void:
	var finished_story := story
	story = null

	get_tree().paused = false
	finished_story.queue_free()
	campaign_story_phase_finished.emit()


func _on_campaign_defeated() -> void:
	campaign_outcome_reached.emit(OUTCOME_DEFEAT)


func _on_campaign_completed() -> void:
	if not campaign_mask_id.is_empty():
		player.unlock_mask(campaign_mask_id)
		mask_awarded.emit(campaign_mask_id)
	campaign_outcome_reached.emit(OUTCOME_COMPLETION)


func apply_campaign_masks(
	mask_ids: Array[StringName],
	equipped_mask_id: StringName
) -> void:
	player.apply_mask_progress(mask_ids, equipped_mask_id)


func restore_boss_checkpoint() -> void:
	var boss_door := get_node_or_null("BossDoor") as Area2D
	if boss_door == null:
		return

	var target_x := boss_door.global_position.x + 96.0
	var target_y := boss_door.global_position.y + 100.0
	var query := PhysicsRayQueryParameters2D.create(
		Vector2(target_x, boss_door.global_position.y - 240.0),
		Vector2(target_x, boss_door.global_position.y + 900.0),
		ENVIRONMENT_COLLISION_MASK
	)
	query.exclude = [player.get_rid()]
	var floor_hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not floor_hit.is_empty():
		var player_shape := player.get_node("CollisionShape2D") as CollisionShape2D
		var shape_half_height := player_shape.shape.get_rect().size.y * 0.5
		target_y = (
			float(floor_hit["position"].y)
			- shape_half_height
			- player_shape.position.y
		)

	player.global_position = Vector2(target_x, target_y)
	player.velocity = Vector2.ZERO
	player_camera.reset_smoothing()
	_boss_checkpoint_emitted = true
	await boss_door.call("lock_door", player)


func _on_boss_door_crossed(body: Node2D) -> void:
	if body != player or _boss_checkpoint_emitted:
		return
	_boss_checkpoint_emitted = true
	checkpoint_reached.emit(CHECKPOINT_BOSS)


func get_campaign_equipped_mask_id() -> StringName:
	return player.mask_controller.primary_mask_id
