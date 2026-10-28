extends Area2D


const CAST_ANIMATION := &"cast"
const ENRAGED_SCALE := 1.2

@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _player: DamageableActor = $"../Player"
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

var _base_sprite_scale := Vector2.ONE
var _base_collision_scale := Vector2.ONE


func _ready() -> void:
	_base_sprite_scale = _sprite.scale
	_base_collision_scale = _collision_shape.scale


func set_enraged(enabled: bool) -> void:
	var scale_multiplier := ENRAGED_SCALE if enabled else 1.0
	_sprite.scale = _base_sprite_scale * scale_multiplier
	_collision_shape.scale = _base_collision_scale * scale_multiplier


func cast() -> void:
	_animation_player.stop()
	_animation_player.play(CAST_ANIMATION)


func _physics_process(_delta: float) -> void:
	if (
		_animation_player.current_animation != CAST_ANIMATION
		or not _animation_player.is_playing()
	):
		return

	for body in get_overlapping_bodies():
		if body != _player:
			continue

		_player.take_damage(1, _player.global_position - global_position)
		return
