extends Sprite2D

@export var attack_frame_paths: PackedStringArray
@export var move_frame_paths: PackedStringArray
@export var air_attack_frame_paths: PackedStringArray
@export var pounce_frame_paths: PackedStringArray
@export var attack_fps := 8.0
@export var move_fps := 10.0
@export var air_attack_fps := 8.0
@export var pounce_fps := 8.0
@export var ground_offset_y := 0.0

const ENRAGED_TINT := Color(0.58, 0.22, 0.82, 1.0)

var _actor: Node
var _idle_texture: Texture2D
var _attack_textures: Array[Texture2D] = []
var _move_textures: Array[Texture2D] = []
var _air_attack_textures: Array[Texture2D] = []
var _pounce_textures: Array[Texture2D] = []
var _source_sprites: Array[Sprite2D] = []
var _attack_frame := 0
var _attack_elapsed := 0.0
var _move_frame := 0
var _move_elapsed := 0.0
var _air_attack_frame := 0
var _air_attack_elapsed := 0.0
var _pounce_frame := 0
var _pounce_elapsed := 0.0
var _attack_was_active := false
var _move_was_active := false
var _air_attack_was_active := false
var _pounce_was_active := false

func _ready() -> void:
	_actor = get_parent().get_parent()
	z_index = 2
	_idle_texture = texture
	for path in attack_frame_paths:
		_attack_textures.append(load(path) as Texture2D)
	for path in move_frame_paths:
		_move_textures.append(load(path) as Texture2D)
	for path in air_attack_frame_paths:
		_air_attack_textures.append(load(path) as Texture2D)
	for path in pounce_frame_paths:
		_pounce_textures.append(load(path) as Texture2D)
	for child in _actor.get_children():
		if child is Sprite2D and child != self:
			var source := child as Sprite2D
			_source_sprites.append(source)
			source.modulate.a = 0.0


func _process(delta: float) -> void:
	var reference: Sprite2D = null
	var any_source_visible := false
	for source in _source_sprites:
		if source.visible:
			any_source_visible = true
			if reference == null:
				reference = source
		source.modulate = Color(
			source.modulate.r,
			source.modulate.g,
			source.modulate.b,
			0.0
		)

	visible = any_source_visible
	if reference != null:
		flip_h = reference.flip_h
		position = reference.position + Vector2(0.0, ground_offset_y)
		modulate = Color(
			reference.modulate.r,
			reference.modulate.g,
			reference.modulate.b,
			1.0
		)
		if (
			_actor.has_method("is_enraged")
			and bool(_actor.call("is_enraged"))
		):
			modulate = ENRAGED_TINT
		if _actor.has_meta(&"burning"):
			modulate = Color(1.0, 0.58, 0.38, 1.0)

	var pouncing := _is_pouncing()
	var air_attacking := _is_air_casting()
	var attacking := _is_attacking()
	if pouncing and not _pounce_textures.is_empty():
		if not _pounce_was_active:
			_pounce_frame = 0
			_pounce_elapsed = 0.0
		else:
			_pounce_elapsed += delta
			while _pounce_elapsed >= 1.0 / pounce_fps:
				_pounce_elapsed -= 1.0 / pounce_fps
				_pounce_frame = mini(
					_pounce_frame + 1,
					_pounce_textures.size() - 1
				)
		texture = _pounce_textures[_pounce_frame]
		_move_was_active = false
		_attack_was_active = false
		_air_attack_was_active = false
	elif air_attacking and not _air_attack_textures.is_empty():
		if not _air_attack_was_active:
			_air_attack_frame = 0
			_air_attack_elapsed = 0.0
		else:
			_air_attack_elapsed += delta
			while _air_attack_elapsed >= 1.0 / air_attack_fps:
				_air_attack_elapsed -= 1.0 / air_attack_fps
				_air_attack_frame = mini(
					_air_attack_frame + 1,
					_air_attack_textures.size() - 1
				)
		texture = _air_attack_textures[_air_attack_frame]
		_move_was_active = false
		_attack_was_active = false
	elif attacking and not _attack_textures.is_empty():
		if not _attack_was_active:
			_attack_frame = 0
			_attack_elapsed = 0.0
		else:
			_attack_elapsed += delta
			while _attack_elapsed >= 1.0 / attack_fps:
				_attack_elapsed -= 1.0 / attack_fps
				_attack_frame = mini(_attack_frame + 1, _attack_textures.size() - 1)
		texture = _attack_textures[_attack_frame]
		_move_was_active = false
	elif _is_moving() and not _move_textures.is_empty():
		if not _move_was_active:
			_move_frame = 0
			_move_elapsed = 0.0
		else:
			_move_elapsed += delta
			while _move_elapsed >= 1.0 / move_fps:
				_move_elapsed -= 1.0 / move_fps
				_move_frame = (_move_frame + 1) % _move_textures.size()
		texture = _move_textures[_move_frame]
		_move_was_active = true
		_attack_was_active = false
	else:
		texture = _idle_texture
		if not attacking:
			_attack_was_active = false
		if not _is_moving():
			_move_was_active = false
	if attacking:
		_attack_was_active = true
	if air_attacking:
		_air_attack_was_active = true
	else:
		_air_attack_was_active = false
	if pouncing:
		_pounce_was_active = true
	else:
		_pounce_was_active = false


func _is_air_casting() -> bool:
	return (
		_actor.has_method("is_air_casting")
		and bool(_actor.call("is_air_casting"))
	)


func _is_pouncing() -> bool:
	return (
		_actor.has_method("is_pouncing")
		and bool(_actor.call("is_pouncing"))
	)


func _is_attacking() -> bool:
	var shared_state: Variant = _actor.get("state")
	if shared_state is int and int(shared_state) in [4, 5]:
		return true
	var dark_action: Variant = _actor.get("_dark_action")
	return dark_action is int and int(dark_action) in [1, 2, 4, 5]


func _is_moving() -> bool:
	if (
		_actor.has_method("is_air_attacking")
		and bool(_actor.call("is_air_attacking"))
	):
		return true
	var shared_state: Variant = _actor.get("state")
	if shared_state is int and int(shared_state) == 1:
		return true
	var phase: Variant = _actor.get("_phase")
	var dark_action: Variant = _actor.get("_dark_action")
	return (
		phase is int
		and int(phase) == 3
		and dark_action is int
		and int(dark_action) == 0
	)
