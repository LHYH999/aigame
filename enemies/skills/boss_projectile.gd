class_name BossProjectile
extends Area2D


const KIND_FIRE_FEATHER := &"fire_feather"
const KIND_PURPLE_ORB := &"purple_orb"
const KIND_FIREBALL := &"fireball"
const FIRE_FEATHER_TEXTURE := preload(
	"res://assets/enemies/skills/air_projectiles/fire_feather.png"
)
const PURPLE_ORB_TEXTURE := preload(
	"res://assets/enemies/skills/air_projectiles/purple_orb.png"
)

var _velocity := Vector2.ZERO
var _damage := 1
var _lifetime_left := 4.0
var _visual_kind: StringName = KIND_FIRE_FEATHER
var _color := Color.WHITE
var _hit := false
var _particles: CPUParticles2D

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_particles = CPUParticles2D.new()
	_particles.amount = 18
	_particles.lifetime = 0.38
	_particles.one_shot = false
	_particles.local_coords = false
	_particles.direction = Vector2.LEFT
	_particles.spread = 24.0
	_particles.gravity = Vector2.ZERO
	_particles.initial_velocity_min = 35.0
	_particles.initial_velocity_max = 90.0
	_particles.scale_amount_min = 1.0
	_particles.scale_amount_max = 2.4
	add_child(_particles)


func setup(
	direction: Vector2,
	speed: float,
	visual_kind: StringName,
	color: Color,
	damage := 1,
	size_scale := 1.0
) -> void:
	var normalized_direction := direction.normalized()
	if normalized_direction.is_zero_approx():
		normalized_direction = Vector2.LEFT
	_velocity = normalized_direction * speed
	_visual_kind = visual_kind
	_color = color
	_damage = damage
	var uses_orb_texture := (
		visual_kind == KIND_PURPLE_ORB
		or visual_kind == KIND_FIREBALL
	)
	_sprite.texture = PURPLE_ORB_TEXTURE if uses_orb_texture else FIRE_FEATHER_TEXTURE
	_sprite.modulate = color if visual_kind == KIND_FIREBALL else Color.WHITE
	_sprite.scale = Vector2.ONE * size_scale
	var rectangle := _collision_shape.shape.duplicate() as RectangleShape2D
	rectangle.size = (
		Vector2(26.0, 26.0)
		if uses_orb_texture
		else Vector2(26.0, 12.0)
	) * size_scale
	_collision_shape.shape = rectangle
	rotation = normalized_direction.angle()
	if _particles != null:
		_particles.color = Color(color.r, color.g, color.b, 0.72)
		_particles.scale_amount_min = 1.0 * size_scale
		_particles.scale_amount_max = 2.4 * size_scale


func _physics_process(delta: float) -> void:
	position += _velocity * delta
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _hit:
		return
	var actor := body as DamageableActor
	if actor == null:
		return

	_hit = true
	actor.take_damage(_damage, _velocity)
	queue_free()
