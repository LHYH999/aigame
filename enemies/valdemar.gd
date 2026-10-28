extends "res://combat/damageable_actor.gd"


signal health_changed(current_health: int, maximum_health: int)
signal awakening_requested
signal defeat_started
signal enrage_started
@warning_ignore("unused_signal")
signal black_water_requested
@warning_ignore("unused_signal")
signal died

const MAXIMUM_HEALTH := 110
const PLAYER_COLLISION_LAYER := 1 << 1
const TRANSFORMATION_ANIMATION := &"transformation"
const ATTACK_ANIMATION := &"attack"
const DEAD_ANIMATION := &"dead"
const HURT_ANIMATION := &"hurt"
const IDLE_ANIMATION := &"idle"
const RUN_ANIMATION := &"run"
const SKILL_ANIMATION := &"skill"
const SWORD_GLEAM_CAST_ANIMATION := &"cast"
const RELEASE_WARNING_DURATION := 0.7
const BODY_PURSUIT_VERTICAL_DISTANCE := 10.0
const ENRAGED_SCALE := 1.2
const ENRAGED_SWORD_TINT := Color(0.82, 0.42, 1.0, 1.0)
const FIRST_PHASE_SWORD_GLEAM_COOLDOWN := 2.0
const ENRAGED_SWORD_GLEAM_COOLDOWN := 1.5
const SWORD_GLEAM_ALIGNMENT_TOLERANCE := 64.0
const SWORD_GLEAM_PLATFORM_MIN_ELEVATION := 48.0
const SWORD_GLEAM_PLATFORM_REACH := 280.0
const SWORD_GLEAM_MIN_HEIGHT := -280.0
const SWORD_GLEAM_MAX_HEIGHT := 80.0
const AIR_ATTACK_COOLDOWN := 12.0
const AIR_ATTACK_TRIGGER_DISTANCE := 1800.0
const AIR_ASCENT_DURATION := 0.75
const AIR_CAST_WARNING_DURATION := 0.6
const AIR_DESCENT_DURATION := 0.75
const AIR_RECOVERY_DURATION := 1.2
const AIR_PROJECTILE_SPEED := 600.0
const AIR_PROJECTILE_DAMAGE := 1
const POUNCE_HIT_THRESHOLD := 3
const POUNCE_WARNING_DURATION := 0.55
const POUNCE_ASCENT_DURATION := 0.38
const POUNCE_HOLD_DURATION := 0.12
const POUNCE_DIVE_DURATION := 0.30
const POUNCE_IMPACT_HOLD_DURATION := 0.12
const POUNCE_RECOVERY_DURATION := 0.65
const POUNCE_ASCENT_HEIGHT := 280.0
const POUNCE_MAX_HORIZONTAL_DISTANCE := 640.0
const POUNCE_IMPACT_REACH := 150.0
const POUNCE_DAMAGE := 1
const ENRAGED_ACTION_SWORD := &"sword"
const ENRAGED_ACTION_BLACK_WATER := &"black_water"
const ENRAGED_ACTION_AIR := &"air"
const ENRAGED_ATTACK_PATTERN := [
	ENRAGED_ACTION_SWORD,
	ENRAGED_ACTION_SWORD,
	ENRAGED_ACTION_BLACK_WATER,
	ENRAGED_ACTION_SWORD,
	ENRAGED_ACTION_SWORD,
	ENRAGED_ACTION_AIR,
]
const DamageAndHealthModule := preload("res://combat/damage_and_health.gd")
const ENRAGED_SWORD_SHADER := preload(
	"res://enemies/skills/sword_gleam_enraged.gdshader"
)
const BossProjectileScene := preload("res://enemies/skills/boss_projectile.tscn")

enum Phase { NORMAL_FORM, PRE_AWAKENING, AWAKENING, DARK_MODE, DEFEATED }
enum DarkAction {
	PURSUIT,
	SWORD_GLEAM_WARNING,
	SWORD_GLEAM,
	HURT,
	BLACK_WATER_WARNING,
	BLACK_WATER_CAST,
	AIR_ATTACK,
	POUNCE_WARNING,
	POUNCE_ATTACK,
}

@export var awakening_distance := 800.0
@export var pursuit_speed := 165.0

var _phase := Phase.NORMAL_FORM
var _dark_action := DarkAction.PURSUIT
var _health := DamageAndHealthModule.new(MAXIMUM_HEALTH)
var _player: Node2D
var _enraged := false
var _black_water_pending := false
var _enraged_attack_index := 0
var _has_locked_sword_target := false
var _locked_sword_target_x := 0.0
var _locked_sword_facing := 0.0
var _base_scale := Vector2.ONE
var _sword_gleam_base_particle_color := Color.WHITE
var _air_attack_active := false
var _air_attack_invulnerable := false
var _air_casting := false
var _air_attack_projectile_count := 4
var _air_attack_volley_count := 2
var _air_ground_position := Vector2.ZERO
var _air_tween: Tween
var _consecutive_player_hits := 0
var _pounce_pending := false
var _pounce_active := false
var _pounce_invulnerable := false
var _pounce_ground_position := Vector2.ZERO
var _pounce_tween: Tween

@onready var _normal: Sprite2D = $Normal
@onready var _dark_mode: Sprite2D = $DarkMode
@onready var _dying: Sprite2D = $Dying
@onready var _warning_mark: Node2D = $WarnMark
@onready var _body_collision: CollisionShape2D = $CollisionShape2D
@onready var _health_bar_root: Node2D = $HealthBar
@onready var _health_bar: TextureProgressBar = $HealthBar/TextureProgressBar
@onready var _hurt_box_collision: CollisionShape2D = $HurtBox/CollisionShape2D
@onready var _awakening_boundary: Area2D = $AwakeningBoundary
@onready var _awakening_shape: CollisionShape2D = $AwakeningBoundary/CollisionShape2D
@onready var _sword_gleam: Area2D = $SwordGleam
@onready var _sword_gleam_collision: CollisionShape2D = $SwordGleam/CollisionShape2D
@onready var _sword_gleam_animation_player: AnimationPlayer = $SwordGleam/AnimationPlayer
@onready var _sword_gleam_sprite: Sprite2D = $SwordGleam/Sprite2D
@onready var _sword_gleam_particles: CPUParticles2D = $SwordGleam/CPUParticles2D
@onready var _sword_gleam_offset_x := absf(_sword_gleam.position.x)
@onready var _sword_gleam_scale_x := absf(_sword_gleam.scale.x)
@onready var _sword_gleam_offset_y := _sword_gleam.position.y
@onready var _sword_gleam_cooldown: Timer = $SwordGleamCooldown
@onready var _black_water_cooldown: Timer = $BlackWaterCooldown
@onready var _air_attack_cooldown: Timer = $AirAttackCooldown
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _animation_tree: AnimationTree = $AnimationTree
@onready var _animation_state: AnimationNodeStateMachinePlayback = _animation_tree.get(
	"parameters/playback"
)


func _init() -> void:
	_health.health_changed.connect(_on_health_changed)


func _ready() -> void:
	var boundary_shape := _awakening_shape.shape as RectangleShape2D
	boundary_shape.size.x = awakening_distance * 2.0
	_base_scale = scale
	_sword_gleam_base_particle_color = _sword_gleam_particles.color
	_set_cooldown_duration(
		_sword_gleam_cooldown,
		FIRST_PHASE_SWORD_GLEAM_COOLDOWN
	)
	_normal.show()
	_dark_mode.hide()
	_warning_mark.hide()
	_health_bar_root.hide()
	_update_health_presentation(
		_health.get_current_health(),
		_health.get_maximum_health()
	)
	_hurt_box_collision.disabled = true
	_sword_gleam_cooldown.stop()
	_black_water_cooldown.stop()
	velocity = Vector2.ZERO
	set_physics_process(false)
	_animation_tree.active = false
	_awakening_boundary.body_entered.connect(_on_awakening_boundary_body_entered)
	_black_water_cooldown.timeout.connect(_on_black_water_cooldown_timeout)
	_air_attack_cooldown.timeout.connect(_on_air_attack_cooldown_timeout)


func get_current_health() -> int:
	return _health.get_current_health()


func get_maximum_health() -> int:
	return _health.get_maximum_health()


func is_hurt_immune() -> bool:
	return _health.is_hurt_immune()


func is_health_depleted() -> bool:
	return _health.is_depleted()


func is_enraged() -> bool:
	return _enraged


func is_air_attacking() -> bool:
	return _air_attack_active and _air_attack_invulnerable


func is_air_casting() -> bool:
	return _air_casting


func is_pouncing() -> bool:
	return _pounce_active


func get_consecutive_player_hits() -> int:
	return _consecutive_player_hits


func get_enraged_attack_pattern() -> Array[StringName]:
	var pattern: Array[StringName] = []
	for action in ENRAGED_ATTACK_PATTERN:
		pattern.append(action)
	return pattern


func apply_debug_health_override(health: int) -> bool:
	return _health.apply_debug_health_override(health)


func restore_full_health() -> void:
	_health.restore_full_health()


func begin_awakening() -> void:
	if _phase != Phase.PRE_AWAKENING:
		return

	_phase = Phase.AWAKENING
	_animation_tree.active = true
	_animation_state.start(TRANSFORMATION_ANIMATION)
	await get_tree().create_timer(
		_animation_player.get_animation(TRANSFORMATION_ANIMATION).length
	).timeout
	if _phase == Phase.AWAKENING:
		_enter_dark_mode()


func begin_enraged_phase() -> void:
	if _enraged or _phase != Phase.DARK_MODE:
		return

	_enraged = true
	_health.restore_full_health()
	_set_enraged_presentation(true)
	_set_cooldown_duration(
		_sword_gleam_cooldown,
		ENRAGED_SWORD_GLEAM_COOLDOWN
	)
	_halve_cooldown(_black_water_cooldown)
	_enraged_attack_index = 0
	_dark_action = DarkAction.PURSUIT
	_black_water_pending = false
	_sword_gleam_cooldown.stop()
	_black_water_cooldown.stop()
	_air_attack_cooldown.stop()
	enrage_started.emit()


func end_enraged_phase() -> void:
	_cancel_air_attack()
	_cancel_pounce_attack()
	_air_attack_cooldown.stop()
	if not _enraged:
		return

	_enraged = false
	_set_enraged_presentation(false)


func _set_enraged_presentation(enabled: bool) -> void:
	scale = _base_scale * (ENRAGED_SCALE if enabled else 1.0)
	if enabled:
		var enraged_material := ShaderMaterial.new()
		enraged_material.shader = ENRAGED_SWORD_SHADER
		_sword_gleam_sprite.material = enraged_material
		_sword_gleam_particles.color = ENRAGED_SWORD_TINT
	else:
		_sword_gleam_sprite.material = null
		_sword_gleam_particles.color = _sword_gleam_base_particle_color


func _halve_cooldown(timer: Timer) -> void:
	var remaining := timer.time_left
	timer.wait_time *= 0.5
	if remaining > 0.0:
		timer.start()


func _set_cooldown_duration(timer: Timer, duration: float) -> void:
	var remaining := timer.time_left
	timer.wait_time = duration
	if remaining > 0.0:
		timer.start()


func take_damage(amount: int, _knockback_direction: Vector2) -> void:
	if _phase != Phase.DARK_MODE:
		return
	if _air_attack_invulnerable or _pounce_invulnerable:
		return
	if _dark_action == DarkAction.BLACK_WATER_CAST:
		return

	if (
		amount > 0
		and amount >= _health.get_current_health()
		and _health.is_hurt_immune()
	):
		_health.end_hurt_immunity()
	if not _health.accept_damage(amount):
		return
	if _health.is_depleted():
		_begin_defeat()
		return

	_register_player_hit()
	if _dark_action == DarkAction.PURSUIT:
		_clear_locked_sword_target()
		_dark_action = DarkAction.HURT
		velocity = Vector2.ZERO
		_animation_state.start(HURT_ANIMATION)

	await get_tree().create_timer(
		_animation_player.get_animation(HURT_ANIMATION).length
	).timeout
	_health.end_hurt_immunity()
	if _phase == Phase.DARK_MODE and _dark_action == DarkAction.HURT:
		_finish_dark_action()


func take_damage_over_time(amount: int) -> void:
	if (
		_phase != Phase.DARK_MODE
		or _air_attack_invulnerable
		or _pounce_invulnerable
		or _dark_action == DarkAction.BLACK_WATER_CAST
	):
		return
	if not _health.accept_periodic_damage(amount):
		return
	if _health.is_depleted():
		_begin_defeat()


func _on_hurt_box_area_entered(area: Area2D) -> void:
	if not area.is_in_group("weapons"):
		return
	if (
		_dark_action == DarkAction.SWORD_GLEAM_WARNING
		or _dark_action == DarkAction.BLACK_WATER_WARNING
		or _dark_action == DarkAction.POUNCE_WARNING
	):
		return

	take_damage(
		int(area.get_meta(&"attack_damage", 1)),
		global_position - area.global_position
	)


func _on_awakening_boundary_body_entered(body: Node2D) -> void:
	var collision_body := body as CollisionObject2D
	if (
		_phase != Phase.NORMAL_FORM
		or collision_body == null
		or collision_body.collision_layer & PLAYER_COLLISION_LAYER == 0
	):
		return

	_phase = Phase.PRE_AWAKENING
	_player = body
	_awakening_boundary.set_deferred("monitoring", false)
	awakening_requested.emit()


func _enter_dark_mode() -> void:
	_phase = Phase.DARK_MODE
	_animation_state.start(IDLE_ANIMATION)
	_animation_tree.advance(0.0)
	_normal.hide()
	_dark_mode.show()
	_update_health_presentation(
		_health.get_current_health(),
		_health.get_maximum_health()
	)
	_health_bar_root.show()
	_hurt_box_collision.disabled = false
	_black_water_cooldown.start()
	_air_attack_cooldown.start(4.0)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _dark_action == DarkAction.PURSUIT:
		if _pounce_pending:
			_start_pounce_attack()
			return
		if _black_water_pending:
			_start_black_water_cast()
		elif (
			not _black_water_cooldown.is_stopped()
			and _black_water_cooldown.time_left <= delta
		):
			velocity = Vector2.ZERO
		else:
			if not is_on_floor():
				velocity += get_gravity() * delta
			_update_sword_pursuit(delta)
	elif (
		_dark_action == DarkAction.SWORD_GLEAM_WARNING
		or _dark_action == DarkAction.BLACK_WATER_WARNING
	):
		velocity.x = 0.0
		if not is_on_floor():
			velocity += get_gravity() * delta
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func _update_sword_pursuit(delta: float) -> void:
	if not is_instance_valid(_player):
		_clear_locked_sword_target()
		velocity.x = 0.0
		_play_movement_animation(IDLE_ANIMATION)
		return

	var maximum_step := pursuit_speed * delta
	if (
		absf(_player.global_position.y - global_position.y)
		< BODY_PURSUIT_VERTICAL_DISTANCE
	):
		_clear_locked_sword_target()
		var body_distance := _player.global_position.x - global_position.x
		var movement_direction := signf(body_distance)
		var turned_before_movement := (
			not is_zero_approx(movement_direction)
			and movement_direction != signf(_sword_gleam.position.x)
		)
		_set_facing(movement_direction)
		var movement_step := movement_direction * minf(
			absf(body_distance),
			maximum_step
		)
		if _try_start_sword_gleam(
			movement_step,
			not turned_before_movement
		):
			return
		if is_zero_approx(body_distance):
			velocity.x = 0.0
			_play_movement_animation(IDLE_ANIMATION)
			return
		velocity.x = movement_direction * pursuit_speed
		_play_movement_animation(RUN_ANIMATION)
		return

	var target_x: float
	var turned_before_movement := false
	if _has_locked_sword_target:
		target_x = _locked_sword_target_x
	else:
		var initial_facing := signf(_sword_gleam.position.x)
		target_x = _player.global_position.x - _sword_gleam.position.x
		var initial_direction := signf(target_x - global_position.x)
		if (
			not is_zero_approx(initial_direction)
			and initial_direction != initial_facing
		):
			_has_locked_sword_target = true
			_locked_sword_target_x = target_x
			_locked_sword_facing = initial_facing
			turned_before_movement = true
			_set_facing(initial_direction)

	var distance_to_target := target_x - global_position.x
	if absf(distance_to_target) <= maximum_step:
		global_position.x = target_x
		velocity.x = 0.0
		if _has_locked_sword_target:
			_set_facing(_locked_sword_facing)
			_clear_locked_sword_target()
		if _try_start_sword_gleam(0.0):
			return
		_play_movement_animation(IDLE_ANIMATION)
		return

	var movement_direction := signf(distance_to_target)
	_set_facing(movement_direction)
	var movement_step := movement_direction * maximum_step
	if _try_start_sword_gleam(
		movement_step,
		not turned_before_movement
	):
		return
	velocity.x = movement_direction * pursuit_speed
	_play_movement_animation(RUN_ANIMATION)


func _face_player() -> void:
	var direction := signf(_player.global_position.x - global_position.x)
	_set_facing(direction)


func _set_facing(direction: float) -> void:
	if is_zero_approx(direction):
		return
	_dark_mode.flip_h = direction > 0.0
	_sword_gleam.position.x = _sword_gleam_offset_x * direction
	_sword_gleam.scale.x = -_sword_gleam_scale_x * direction


func _try_start_sword_gleam(
	movement_step: float,
	allow_stationary_alignment := true
) -> bool:
	if (
		_enraged
		and _get_current_enraged_action() != ENRAGED_ACTION_SWORD
	):
		return false
	if not _sword_gleam_cooldown.is_stopped():
		return false

	var player_is_elevated := (
		absf(_player.global_position.y - global_position.y)
		>= SWORD_GLEAM_PLATFORM_MIN_ELEVATION
	)
	var player_horizontal_distance := (
		_player.global_position.x - global_position.x
	)
	if (
		player_is_elevated
		and absf(player_horizontal_distance) <= SWORD_GLEAM_PLATFORM_REACH
	):
		_set_facing(signf(player_horizontal_distance))
		_align_sword_gleam_to_player()
		_start_sword_gleam()
		return true

	var gleam_distance := (
		_player.global_position.x - _sword_gleam.global_position.x
	)
	if (
		allow_stationary_alignment
		and absf(gleam_distance) <= SWORD_GLEAM_ALIGNMENT_TOLERANCE
	):
		_start_sword_gleam()
		return true
	if (
		not is_zero_approx(movement_step)
		and signf(gleam_distance) == signf(movement_step)
		and absf(gleam_distance) <= absf(movement_step)
	):
		global_position.x += gleam_distance
		velocity.x = 0.0
		_start_sword_gleam()
		return true
	return false


func _clear_locked_sword_target() -> void:
	_has_locked_sword_target = false


func _play_movement_animation(animation_name: StringName) -> void:
	if _animation_state.get_current_node() != animation_name:
		_animation_state.travel(animation_name)


func _start_sword_gleam() -> void:
	_clear_locked_sword_target()
	_start_release_warning(DarkAction.SWORD_GLEAM_WARNING)


func _release_sword_gleam() -> void:
	_dark_action = DarkAction.SWORD_GLEAM
	_sword_gleam_cooldown.start()
	_align_sword_gleam_to_player_height()
	if _enraged:
		_advance_enraged_attack()
	_animation_state.start(ATTACK_ANIMATION)
	_animation_tree.advance(0.0)
	_sword_gleam_animation_player.play(SWORD_GLEAM_CAST_ANIMATION)
	await get_tree().create_timer(
		_animation_player.get_animation(ATTACK_ANIMATION).length
	).timeout
	if _phase == Phase.DARK_MODE and _dark_action == DarkAction.SWORD_GLEAM:
		_finish_dark_action()


func _on_black_water_cooldown_timeout() -> void:
	if _phase != Phase.DARK_MODE:
		return
	if _pounce_pending or _pounce_active:
		_black_water_cooldown.start(0.5)
		return
	if _enraged:
		if (
			_get_current_enraged_action() == ENRAGED_ACTION_BLACK_WATER
			and _dark_action == DarkAction.PURSUIT
		):
			_start_black_water_cast()
		return

	_black_water_pending = true
	if _dark_action == DarkAction.PURSUIT:
		_start_black_water_cast()


func _on_air_attack_cooldown_timeout() -> void:
	if _phase != Phase.DARK_MODE:
		return
	if _pounce_pending or _pounce_active:
		_air_attack_cooldown.start(0.5)
		return
	if not _enraged:
		if _dark_action == DarkAction.PURSUIT:
			_start_air_attack()
		else:
			_air_attack_cooldown.start(0.5)
		return
	if (
		not is_instance_valid(_player)
		or global_position.distance_to(_player.global_position)
		> AIR_ATTACK_TRIGGER_DISTANCE
	):
		_air_attack_cooldown.start(2.0)
		return

	if (
		_get_current_enraged_action() == ENRAGED_ACTION_AIR
		and _dark_action == DarkAction.PURSUIT
	):
		_start_air_attack()


func _start_black_water_cast() -> void:
	_clear_locked_sword_target()
	_black_water_pending = false
	if is_instance_valid(_player):
		_face_player()
	_start_release_warning(DarkAction.BLACK_WATER_WARNING)


func _release_black_water_cast() -> void:
	_dark_action = DarkAction.BLACK_WATER_CAST
	_black_water_cooldown.start()
	if _enraged:
		_advance_enraged_attack()
	_animation_state.start(SKILL_ANIMATION)
	black_water_requested.emit()
	await get_tree().create_timer(
		_animation_player.get_animation(SKILL_ANIMATION).length
	).timeout
	if _phase == Phase.DARK_MODE and _dark_action == DarkAction.BLACK_WATER_CAST:
		_finish_dark_action()


func _start_release_warning(warning_action: int) -> void:
	_dark_action = warning_action
	velocity = Vector2.ZERO
	_animation_tree.active = false
	_warning_mark.show()
	await get_tree().create_timer(RELEASE_WARNING_DURATION).timeout
	if _phase != Phase.DARK_MODE or _dark_action != warning_action:
		return

	_animation_tree.active = true
	_warning_mark.hide()
	if warning_action == DarkAction.SWORD_GLEAM_WARNING:
		_release_sword_gleam()
	else:
		_release_black_water_cast()


func _finish_dark_action() -> void:
	_restore_sword_gleam_offset()
	if _pounce_pending:
		_start_pounce_attack()
		return
	if _enraged:
		_continue_enraged_attack_pattern()
		return
	if _black_water_pending:
		_start_black_water_cast()
	else:
		_dark_action = DarkAction.PURSUIT
		_animation_state.start(IDLE_ANIMATION)


func _get_current_enraged_action() -> StringName:
	return ENRAGED_ATTACK_PATTERN[_enraged_attack_index]


func _align_sword_gleam_to_player_height() -> void:
	if not is_instance_valid(_player):
		return
	_sword_gleam.position.y = clampf(
		to_local(_player.global_position).y,
		SWORD_GLEAM_MIN_HEIGHT,
		SWORD_GLEAM_MAX_HEIGHT
	)


func _align_sword_gleam_to_player() -> void:
	if not is_instance_valid(_player):
		return
	var local_player_position := to_local(_player.global_position)
	_sword_gleam.position.x = local_player_position.x
	_sword_gleam.position.y = clampf(
		local_player_position.y,
		SWORD_GLEAM_MIN_HEIGHT,
		SWORD_GLEAM_MAX_HEIGHT
	)


func _restore_sword_gleam_offset() -> void:
	var facing := 1.0 if _dark_mode.flip_h else -1.0
	_sword_gleam.position.x = _sword_gleam_offset_x * facing
	_sword_gleam.position.y = _sword_gleam_offset_y


func _advance_enraged_attack() -> void:
	_enraged_attack_index = (
		_enraged_attack_index + 1
	) % ENRAGED_ATTACK_PATTERN.size()


func _continue_enraged_attack_pattern() -> void:
	var expected_index := _enraged_attack_index
	var next_action := _get_current_enraged_action()
	_dark_action = DarkAction.PURSUIT
	_animation_state.start(IDLE_ANIMATION)
	if next_action == ENRAGED_ACTION_SWORD:
		return

	await get_tree().create_timer(0.35).timeout
	if (
		not _enraged
		or _phase != Phase.DARK_MODE
		or _enraged_attack_index != expected_index
		or _dark_action != DarkAction.PURSUIT
	):
		return

	if next_action == ENRAGED_ACTION_BLACK_WATER:
		_black_water_cooldown.stop()
		_start_black_water_cast()
	elif next_action == ENRAGED_ACTION_AIR:
		_air_attack_cooldown.stop()
		_start_air_attack()


func _start_air_attack() -> void:
	if _air_attack_active or _phase != Phase.DARK_MODE:
		return

	_air_attack_active = true
	_air_attack_invulnerable = true
	_air_attack_projectile_count = 4 if _enraged else 2
	_air_attack_volley_count = 2 if _enraged else 1
	_air_ground_position = global_position
	_dark_action = DarkAction.AIR_ATTACK
	_clear_locked_sword_target()
	velocity = Vector2.ZERO
	_warning_mark.hide()
	_sword_gleam_cooldown.stop()
	_black_water_cooldown.stop()
	_body_collision.set_deferred("disabled", true)
	_hurt_box_collision.set_deferred("disabled", true)
	_animation_state.start(RUN_ANIMATION)
	if _enraged:
		_advance_enraged_attack()
	_air_attack_cooldown.start(AIR_ATTACK_COOLDOWN)

	var horizontal_offset := 0.0
	if is_instance_valid(_player):
		horizontal_offset = clampf(
			_player.global_position.x - global_position.x,
			-200.0,
			200.0
		)
		_set_facing(signf(horizontal_offset))
	_air_tween = create_tween()
	_air_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_air_tween.tween_property(
		self,
		"global_position",
		_air_ground_position + Vector2(horizontal_offset, -280.0),
		AIR_ASCENT_DURATION
	)
	await _air_tween.finished
	if not _can_finish_air_attack():
		return

	_warning_mark.show()
	_air_casting = true
	await get_tree().create_timer(AIR_CAST_WARNING_DURATION).timeout
	if not _can_finish_air_attack():
		return

	_fire_air_projectile_volley()
	if _air_attack_volley_count > 1:
		await get_tree().create_timer(0.8).timeout
		if not _can_finish_air_attack():
			return
		_fire_air_projectile_volley()
	_air_casting = false
	_warning_mark.hide()
	await get_tree().create_timer(0.4).timeout
	if not _can_finish_air_attack():
		return

	_air_tween = create_tween()
	_air_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_air_tween.tween_property(
		self,
		"global_position",
		_air_ground_position,
		AIR_DESCENT_DURATION
	)
	await _air_tween.finished
	if not _can_finish_air_attack():
		return

	_air_attack_invulnerable = false
	_body_collision.set_deferred("disabled", false)
	_hurt_box_collision.set_deferred("disabled", false)
	await get_tree().create_timer(AIR_RECOVERY_DURATION).timeout
	if not _air_attack_active or _phase != Phase.DARK_MODE:
		return

	_air_attack_active = false
	if _dark_action == DarkAction.AIR_ATTACK:
		_dark_action = DarkAction.PURSUIT
		_animation_state.start(IDLE_ANIMATION)
	_sword_gleam_cooldown.start()
	_black_water_cooldown.start()


func _can_finish_air_attack() -> bool:
	return (
		_air_attack_active
		and _phase == Phase.DARK_MODE
		and _dark_action == DarkAction.AIR_ATTACK
	)


func _fire_air_projectile_volley() -> void:
	if not is_instance_valid(_player):
		return

	var spawn_position := global_position + Vector2(
		signf(_sword_gleam.position.x) * 42.0,
		-24.0
	)
	var direction := (_player.global_position - spawn_position).normalized()
	for projectile_index in _air_attack_projectile_count:
		var angle_offset := lerpf(
			-0.24,
			0.24,
			float(projectile_index) / float(
				maxi(_air_attack_projectile_count - 1, 1)
			)
		)
		var projectile := BossProjectileScene.instantiate() as BossProjectile
		get_parent().add_child(projectile)
		projectile.global_position = spawn_position
		projectile.setup(
			direction.rotated(angle_offset),
			AIR_PROJECTILE_SPEED,
			BossProjectile.KIND_PURPLE_ORB,
			Color("#b36cff"),
			AIR_PROJECTILE_DAMAGE,
			2.5
		)


func _register_player_hit() -> void:
	_consecutive_player_hits += 1
	if _consecutive_player_hits < POUNCE_HIT_THRESHOLD:
		return

	_consecutive_player_hits = 0
	_pounce_pending = true


func _start_pounce_attack() -> void:
	_pounce_pending = false
	if (
		_pounce_active
		or _phase != Phase.DARK_MODE
		or not is_instance_valid(_player)
	):
		return

	_pounce_active = true
	_pounce_invulnerable = true
	_pounce_ground_position = global_position
	_dark_action = DarkAction.POUNCE_WARNING
	_clear_locked_sword_target()
	velocity = Vector2.ZERO
	_warning_mark.show()
	_sword_gleam_cooldown.stop()
	_black_water_cooldown.stop()
	_air_attack_cooldown.stop()
	_body_collision.set_deferred("disabled", true)
	_hurt_box_collision.set_deferred("disabled", true)
	_animation_tree.active = true
	_animation_state.start(IDLE_ANIMATION)
	_air_attack_active = false
	_air_attack_invulnerable = false
	_air_casting = false

	await get_tree().create_timer(POUNCE_WARNING_DURATION).timeout
	if not _can_finish_pounce_attack():
		return

	_warning_mark.hide()
	_dark_action = DarkAction.POUNCE_ATTACK
	_face_player()
	await _tween_pounce_position(
		_pounce_ground_position + Vector2(0.0, -POUNCE_ASCENT_HEIGHT),
		POUNCE_ASCENT_DURATION,
		Tween.EASE_OUT
	)
	if not _can_finish_pounce_attack():
		return

	await get_tree().create_timer(POUNCE_HOLD_DURATION).timeout
	if not _can_finish_pounce_attack():
		return

	var target_position := _player.global_position + Vector2(0.0, -20.0)
	target_position.x = clampf(
		target_position.x,
		_pounce_ground_position.x - POUNCE_MAX_HORIZONTAL_DISTANCE,
		_pounce_ground_position.x + POUNCE_MAX_HORIZONTAL_DISTANCE
	)
	_face_player()
	await _tween_pounce_position(
		target_position,
		POUNCE_DIVE_DURATION,
		Tween.EASE_IN
	)
	if not _can_finish_pounce_attack():
		return

	_apply_pounce_impact()
	await get_tree().create_timer(POUNCE_IMPACT_HOLD_DURATION).timeout
	if not _can_finish_pounce_attack():
		return

	await _tween_pounce_position(
		_pounce_ground_position,
		POUNCE_RECOVERY_DURATION,
		Tween.EASE_OUT
	)
	if not _can_finish_pounce_attack():
		return
	_finish_pounce_attack()


func _tween_pounce_position(
	target_position: Vector2,
	duration: float,
	ease_type: Tween.EaseType
) -> void:
	_pounce_tween = create_tween()
	_pounce_tween.set_trans(Tween.TRANS_QUAD).set_ease(ease_type)
	_pounce_tween.tween_property(
		self,
		"global_position",
		target_position,
		duration
	)
	await _pounce_tween.finished


func _apply_pounce_impact() -> void:
	if (
		not is_instance_valid(_player)
		or bool(_player.call("is_health_depleted"))
		or global_position.distance_to(_player.global_position) > POUNCE_IMPACT_REACH
	):
		return

	var knockback_direction := Vector2(
		signf(_player.global_position.x - global_position.x),
		-0.45
	)
	_player.call("take_damage", POUNCE_DAMAGE, knockback_direction, true)


func _can_finish_pounce_attack() -> bool:
	return (
		_pounce_active
		and _phase == Phase.DARK_MODE
		and (
			_dark_action == DarkAction.POUNCE_WARNING
			or _dark_action == DarkAction.POUNCE_ATTACK
		)
	)


func _finish_pounce_attack() -> void:
	if not _pounce_active:
		return

	global_position = _pounce_ground_position
	_pounce_active = false
	_pounce_invulnerable = false
	_warning_mark.hide()
	_body_collision.set_deferred("disabled", false)
	_hurt_box_collision.set_deferred("disabled", false)
	_dark_action = DarkAction.PURSUIT
	_animation_state.start(IDLE_ANIMATION)
	if _enraged:
		_continue_enraged_attack_pattern()
	else:
		_sword_gleam_cooldown.start()
		_black_water_cooldown.start()
		_air_attack_cooldown.start(AIR_ATTACK_COOLDOWN)


func _cancel_pounce_attack() -> void:
	if _pounce_tween != null and _pounce_tween.is_valid():
		_pounce_tween.kill()
	_pounce_tween = null
	if not _pounce_active:
		return

	_pounce_active = false
	_pounce_invulnerable = false
	_warning_mark.hide()
	global_position = _pounce_ground_position
	if _phase == Phase.DARK_MODE:
		_body_collision.set_deferred("disabled", false)
		_hurt_box_collision.set_deferred("disabled", false)
		_dark_action = DarkAction.PURSUIT
		_animation_state.start(IDLE_ANIMATION)


func _cancel_air_attack() -> void:
	if _air_tween != null and _air_tween.is_valid():
		_air_tween.kill()
	_air_tween = null
	if not _air_attack_active:
		return

	_air_attack_active = false
	_air_attack_invulnerable = false
	_air_casting = false
	_warning_mark.hide()
	global_position = _air_ground_position
	if _phase == Phase.DARK_MODE:
		_body_collision.set_deferred("disabled", false)
		_hurt_box_collision.set_deferred("disabled", false)
		_dark_action = DarkAction.PURSUIT
		_animation_state.start(IDLE_ANIMATION)


func _begin_defeat() -> void:
	if _phase == Phase.DEFEATED:
		return

	_phase = Phase.DEFEATED
	end_enraged_phase()
	_cancel_pounce_attack()
	defeat_started.emit()
	_dark_action = DarkAction.PURSUIT
	_animation_tree.active = true
	_warning_mark.hide()
	_black_water_pending = false
	_clear_locked_sword_target()
	velocity = Vector2.ZERO
	set_physics_process(false)
	remove_from_group("enemies")
	_health_bar_root.hide()
	_sword_gleam_cooldown.stop()
	_black_water_cooldown.stop()
	_sword_gleam.call("cancel_cast")
	_sword_gleam_animation_player.stop()
	_sword_gleam.hide()
	_dying.flip_h = _dark_mode.flip_h

	collision_layer = 0
	collision_mask = 0
	$HurtBox.collision_layer = 0
	$HurtBox.collision_mask = 0
	_sword_gleam.collision_layer = 0
	_sword_gleam.collision_mask = 0
	_awakening_boundary.collision_layer = 0
	_awakening_boundary.collision_mask = 0
	_body_collision.set_deferred("disabled", true)
	_hurt_box_collision.set_deferred("disabled", true)
	_sword_gleam_collision.set_deferred("disabled", true)
	_awakening_boundary.set_deferred("monitoring", false)
	_sword_gleam.set_deferred("monitoring", false)

	_animation_state.start(DEAD_ANIMATION)
	_animation_tree.advance(0.0)
	var finished_animation: StringName = await _animation_tree.animation_finished
	if _phase != Phase.DEFEATED or finished_animation != DEAD_ANIMATION:
		return

	_animation_tree.active = false
	died.emit()


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	_update_health_presentation(current_health, maximum_health)
	health_changed.emit(current_health, maximum_health)


func _update_health_presentation(current_health: int, maximum_health: int) -> void:
	_health_bar.max_value = maximum_health
	_health_bar.value = current_health
