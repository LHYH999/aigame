extends Sprite2D

@export var run_frame_paths: PackedStringArray
@export var jump_frame_paths: PackedStringArray
@export var attack_frame_paths: PackedStringArray
@export var dodge_frame_paths: PackedStringArray
@export var run_frame_rate := 12.0
@export var jump_frame_rate := 16.0
@export var attack_frame_rate := 24.0
@export var dodge_frame_rate := 53.0

var _player: CharacterBody2D
var _source: Sprite2D
var _run_frames: Array[Texture2D] = []
var _jump_frames: Array[Texture2D] = []
var _attack_frames: Array[Texture2D] = []
var _dodge_frames: Array[Texture2D] = []
var _idle_texture: Texture2D
var _active_sequence := ""
var _frame_index := 0
var _frame_elapsed := 0.0
var _elapsed := 0.0


func _ready() -> void:
	_player = get_parent().get_parent() as CharacterBody2D
	_source = get_parent().get_node_or_null("Sprite2D") as Sprite2D
	if _source != null:
		_source.modulate.a = 0.0
	var weapon_sprite := get_parent().get_node_or_null(
		"WeaponMount/Sprite2D"
	) as Sprite2D
	if weapon_sprite != null:
		weapon_sprite.modulate.a = 0.0
	_idle_texture = load("res://assets/player/redesign_v2/base/yan_idle_256.png")
	_run_frames = _load_frames(run_frame_paths)
	_jump_frames = _load_frames(jump_frame_paths)
	_attack_frames = _load_frames(attack_frame_paths)
	_dodge_frames = _load_frames(dodge_frame_paths)
	z_index = 1


func _process(delta: float) -> void:
	if _player == null or _source == null:
		return
	_elapsed += delta
	flip_h = _source.flip_h
	visible = _source.visible

	var state: int = int(_player.get("state"))
	var base_position := _source.position + Vector2(0.0, -5.0)
	match state:
		0:
			_reset_sequence()
			texture = _idle_texture
			position = base_position + Vector2(0.0, -sin(_elapsed * 2.0) * 1.0)
			rotation = 0.0
		1:
			_play_sequence("run", _run_frames, true, run_frame_rate, delta)
			position = base_position
			rotation = 0.0
		2:
			_play_sequence("jump", _jump_frames, false, jump_frame_rate, delta)
			position = base_position
			rotation = 0.0
		3:
			_reset_sequence()
			texture = _idle_texture
			position = base_position
			var visual_root := _player.get("visual_root") as Node2D
			rotation = 0.12 * signf(visual_root.scale.x)
		4:
			_reset_sequence()
		5:
			_play_sequence("attack", _attack_frames, false, attack_frame_rate, delta)
			position = base_position
			rotation = 0.0
		6:
			_play_sequence(
				"dodge",
				_dodge_frames,
				false,
				dodge_frame_rate,
				delta
			)
			position = base_position
			rotation = 0.0


func _load_frames(paths: PackedStringArray) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for path in paths:
		frames.append(load(path) as Texture2D)
	return frames


func _play_sequence(
	sequence_name: String,
	frames: Array[Texture2D],
	loop: bool,
	rate: float,
	delta: float
) -> void:
	if frames.is_empty():
		texture = _idle_texture
		return
	if _active_sequence != sequence_name:
		_active_sequence = sequence_name
		_frame_index = 0
		_frame_elapsed = 0.0
	else:
		_frame_elapsed += delta
		while _frame_elapsed >= 1.0 / rate:
			_frame_elapsed -= 1.0 / rate
			if loop:
				_frame_index = (_frame_index + 1) % frames.size()
			else:
				_frame_index = mini(_frame_index + 1, frames.size() - 1)
	texture = frames[_frame_index]


func _reset_sequence() -> void:
	_active_sequence = ""
	_frame_index = 0
	_frame_elapsed = 0.0
