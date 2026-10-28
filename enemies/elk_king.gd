extends "res://enemies/elk.gd"


signal died
signal death_presentation_finished
signal attack_presentation_started
signal thunder_wave_spawned(x_positions: Array)

const ELK_KING_MAX_HEALTH := 90
const EARTHQUAKE_CAST_ANIMATION := &"cast"
const THUNDER_BARRAGE_DURATION := 6.0
const THUNDER_BARRAGE_INTERVAL := 0.6
const THUNDER_BEAMS_PER_WAVE := 3
const THUNDER_POST_BARRAGE_COOLDOWN := 10.0
const THUNDER_SCREEN_EDGE_MARGIN := 100.0
const ThunderScene := preload("res://enemies/skills/thunder.tscn")

@onready var _health_bar: TextureProgressBar = $HealthBar/TextureProgressBar
@onready var _earthquake: Area2D = $SkillDetect/EarthquakeSkill/Earthquake
@onready var _earthquake_animation_player: AnimationPlayer = (
	$SkillDetect/EarthquakeSkill/Earthquake/AnimationPlayer
)
@onready var _earthquake_cooldown_timer: Timer = $SkillDetect/EarthquakeSkill/Cooldown
@onready var _earthquake_cast_offset_x := absf(_earthquake.position.x)

var _thunder_cast_active := false
var _earthquake_cast_active := false
var _earthquake_presentation_active := false
var _death_presentation_started := false
var _death_presentation_finished := false
var _warning_commits_thunder := false
var _warning_commits_earthquake := false
var _skill_sequence_generation := 0
var _spawned_thunders: Array[Area2D] = []


func _ready() -> void:
	super._ready()
	animation_tree.animation_finished.connect(_on_animation_finished)
	_earthquake_cooldown_timer.timeout.connect(_try_start_skill)


func _get_max_health() -> int:
	return ELK_KING_MAX_HEALTH


func _update_health_presentation(current_health: int, maximum_health: int) -> void:
	_health_bar.max_value = maximum_health
	_health_bar.value = current_health


func _prepare_death_presentation() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	died.emit()


func _starts_death_presentation_automatically() -> bool:
	return false


func request_death_presentation() -> void:
	if state != DEAD or _death_presentation_started:
		return

	_death_presentation_started = true
	_start_death_presentation()


func _on_animation_finished(animation_name: StringName) -> void:
	if (
		animation_name != DEAD_ANIMATION
		or not _death_presentation_started
		or _death_presentation_finished
	):
		return

	_death_presentation_finished = true
	death_presentation_finished.emit()


func _stop_species_skill_presentation() -> void:
	_skill_sequence_generation += 1
	_thunder_cast_active = false
	_earthquake_cast_active = false
	if state == DEAD:
		_cancel_spawned_thunder_damage()
	super._stop_species_skill_presentation()


func die() -> void:
	if state == DEAD:
		return

	change_state(DEAD)
	move_direction = -1.0
	face_move_direction()
	_prepare_death_presentation()


func _play_skill_presentations() -> void:
	if state == SKILL:
		animation_state.start(SKILL_ANIMATION)
		attack_presentation_started.emit()


func _try_start_skill() -> void:
	if (
		state == DEAD
		or state == HURT
		or state == WARN
		or state == SKILL
		or is_hurt_immune()
		or not skill_detect.has_overlapping_bodies()
	):
		return

	var thunder_ready := skill_cooldown_timer.is_stopped()
	var earthquake_ready := _earthquake_cooldown_timer.is_stopped()
	if not thunder_ready and not earthquake_ready:
		return

	skill_return_state = state
	_warning_commits_earthquake = earthquake_ready
	_warning_commits_thunder = not earthquake_ready and thunder_ready
	change_state(WARN)
	await get_tree().create_timer(RELEASE_WARNING_DURATION).timeout
	if state != WARN:
		_warning_commits_thunder = false
		_warning_commits_earthquake = false
		return

	var start_earthquake := _warning_commits_earthquake
	var start_thunder := _warning_commits_thunder
	_warning_commits_thunder = false
	_warning_commits_earthquake = false
	change_state(SKILL)
	if start_earthquake:
		await _start_earthquake_cast()
	elif start_thunder:
		await _start_thunder_cast()
	if state == SKILL:
		finish_skill()


func _start_thunder_cast() -> void:
	_thunder_cast_active = true
	skill_cooldown_timer.stop()
	var generation := _skill_sequence_generation
	var wave_count := ceili(
		THUNDER_BARRAGE_DURATION / THUNDER_BARRAGE_INTERVAL
	)
	for _wave_index in wave_count:
		if not _is_skill_sequence_valid(generation):
			return
		_spawn_random_thunder_wave()
		await get_tree().create_timer(THUNDER_BARRAGE_INTERVAL).timeout

	if _is_skill_sequence_valid(generation):
		_thunder_cast_active = false
		skill_cooldown_timer.start(THUNDER_POST_BARRAGE_COOLDOWN)


func _spawn_random_thunder_wave() -> void:
	var positions := _get_non_adjacent_thunder_positions()
	for thunder_x in positions:
		_spawn_thunder_beam(thunder_x)
	thunder_wave_spawned.emit(positions)


func _get_non_adjacent_thunder_positions() -> Array[float]:
	var bounds := _get_thunder_arena_bounds()
	var left: float = bounds.x
	var right: float = bounds.y
	var segment_width := (right - left) / float(THUNDER_BEAMS_PER_WAVE)
	var positions: Array[float] = []
	for segment_index in THUNDER_BEAMS_PER_WAVE:
		var segment_left := left + segment_width * float(segment_index)
		var inset := minf(segment_width * 0.2, 48.0)
		positions.append(
			_rng.randf_range(
				segment_left + inset,
				segment_left + segment_width - inset
			)
		)
	return positions


func _get_thunder_arena_bounds() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	var center_x := global_position.x
	var half_width := 640.0
	if camera != null:
		center_x = camera.get_screen_center_position().x
		half_width = viewport_size.x * 0.5 / maxf(camera.zoom.x, 0.01)
	var usable_half_width := maxf(
		half_width - THUNDER_SCREEN_EDGE_MARGIN,
		360.0
	)
	return Vector2(
		center_x - usable_half_width,
		center_x + usable_half_width
	)


func _spawn_thunder_beam(thunder_x: float) -> void:
	var thunder := ThunderScene.instantiate() as Area2D
	get_parent().add_child(thunder)
	thunder.global_position = Vector2(
		thunder_x,
		_get_thunder_ground_y(thunder_x)
	)
	thunder.scale = _thunder.scale
	var audio := thunder.get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D
	if audio != null:
		audio.volume_db = -80.0
	var animation_player := thunder.get_node("AnimationPlayer") as AnimationPlayer
	animation_player.animation_finished.connect(
		func(animation_name: StringName) -> void:
			if animation_name == THUNDER_CAST_ANIMATION and is_instance_valid(thunder):
				thunder.queue_free()
	)
	thunder.tree_exited.connect(
		func() -> void:
			_spawned_thunders.erase(thunder)
	)
	_spawned_thunders.append(thunder)
	animation_player.stop()
	animation_player.play(THUNDER_CAST_ANIMATION)
	thunder.call("start_cast")


func _start_earthquake_cast() -> void:
	_earthquake_cast_active = true
	_earthquake_presentation_active = true
	_earthquake_cooldown_timer.start()
	var earthquake_x := (
		global_position.x + move_direction * _earthquake_cast_offset_x
	)
	_play_earthquake_cast(earthquake_x)
	var earthquake_length := _earthquake_animation_player.get_animation(
		EARTHQUAKE_CAST_ANIMATION
	).length
	await get_tree().create_timer(earthquake_length).timeout
	_earthquake_cast_active = false
	_earthquake_presentation_active = false
	_update_casting_presentation()


func _play_earthquake_cast(earthquake_x: float) -> void:
	_earthquake.global_position.x = earthquake_x
	_earthquake_animation_player.stop()
	_earthquake_animation_player.play(EARTHQUAKE_CAST_ANIMATION)


func _update_casting_presentation() -> void:
	pass


func _is_skill_sequence_valid(generation: int) -> bool:
	return generation == _skill_sequence_generation and state == SKILL


func _cancel_spawned_thunder_damage() -> void:
	for thunder in _spawned_thunders:
		if not is_instance_valid(thunder):
			continue
		thunder.call("cancel_cast")


func _get_skill_cooldown_timer() -> Timer:
	return $SkillDetect/ThunderSkill/Cooldown


func _get_thunder() -> Area2D:
	return $SkillDetect/ThunderSkill/Thunder
