extends "res://enemies/bear.gd"


signal died

const BEAR_KING_MAX_HEALTH := 30
const AIR_ATTACK_COOLDOWN := 12.0
const AIR_ATTACK_TRIGGER_DISTANCE := 950.0
const AIR_ASCENT_DURATION := 0.7
const AIR_CAST_WARNING_DURATION := 0.55
const AIR_DESCENT_DURATION := 0.7
const AIR_RECOVERY_DURATION := 1.2
const AIR_PROJECTILE_SPEED := 350.0
const AIR_PROJECTILE_DAMAGE := 1
const FIREBALL_SPEED := 570.0
const FIREBALL_DAMAGE := 1
const FIREBALL_SIZE_SCALE := 2.16
const BossProjectileScene := preload("res://enemies/skills/boss_projectile.tscn")

@onready var health_bar: TextureProgressBar = $HealthBar/TextureProgressBar
@onready var _air_attack_cooldown: Timer = $AirAttackCooldown

var _player: Node2D
var _air_attack_active := false
var _air_casting := false
var _air_return_state := IDLE
var _air_ground_position := Vector2.ZERO
var _air_tween: Tween


func _ready() -> void:
	super._ready()
	_player = _find_player()
	if is_instance_valid(_player) and _player.has_signal(&"died"):
		_player.connect(&"died", _cancel_air_attack)
	_air_attack_cooldown.timeout.connect(_try_start_air_attack)
	_air_attack_cooldown.start()


func _physics_process(delta: float) -> void:
	if _air_attack_active:
		return
	super._physics_process(delta)


func is_air_attacking() -> bool:
	return _air_attack_active


func is_air_casting() -> bool:
	return _air_casting


func _get_max_health() -> int:
	return BEAR_KING_MAX_HEALTH


func _update_health_presentation(current_health: int, maximum_health: int) -> void:
	health_bar.max_value = maximum_health
	health_bar.value = current_health


func _prepare_hurt(knockback_direction: Vector2) -> void:
	if not is_zero_approx(knockback_direction.x):
		move_direction = -signf(knockback_direction.x)
		face_move_direction()


func _prepare_death_presentation() -> void:
	_cancel_air_attack(false)
	process_mode = Node.PROCESS_MODE_ALWAYS
	died.emit()


func _try_start_skill() -> void:
	if _air_attack_active:
		return
	super._try_start_skill()


func _try_start_air_attack() -> void:
	if state == DEAD or _air_attack_active:
		return
	if state == SKILL or state == WARN or _health.is_hurt_immune():
		_air_attack_cooldown.start(1.0)
		return

	if not is_instance_valid(_player):
		_player = _find_player()
	if (
		not is_instance_valid(_player)
		or (
			_player.has_method("is_health_depleted")
			and bool(_player.call("is_health_depleted"))
		)
		or global_position.distance_to(_player.global_position)
		> AIR_ATTACK_TRIGGER_DISTANCE
	):
		_air_attack_cooldown.start(1.0)
		return

	_start_air_attack()


func _play_species_skill_presentation() -> void:
	if state != SKILL:
		return
	_fire_red_fireball()


func _stop_species_skill_presentation() -> void:
	pass


func _fire_red_fireball() -> void:
	if not is_instance_valid(_player):
		_player = _find_player()

	var direction := Vector2(move_direction, 0.0)
	if is_instance_valid(_player):
		direction = (
			_player.global_position
			- (global_position + Vector2(move_direction * 42.0, -34.0))
		).normalized()
	var spawn_position := global_position + Vector2(move_direction * 42.0, -34.0)
	var projectile := BossProjectileScene.instantiate() as BossProjectile
	get_parent().add_child(projectile)
	projectile.global_position = spawn_position
	projectile.setup(
		direction,
		FIREBALL_SPEED,
		BossProjectile.KIND_FIREBALL,
		Color("#ff3b24"),
		FIREBALL_DAMAGE,
		FIREBALL_SIZE_SCALE
	)


func _start_air_attack() -> void:
	if _air_attack_active or state == DEAD:
		return
	if not is_instance_valid(_player):
		_player = _find_player()

	_air_attack_active = true
	_air_attack_cooldown.start(AIR_ATTACK_COOLDOWN)
	_air_return_state = state if state == RUN else IDLE
	_air_ground_position = global_position
	state = RUN
	animation_state.start(RUN_ANIMATION)
	hurt_box_collision_shape.set_deferred("disabled", true)
	body_collision_shape.set_deferred("disabled", true)
	warning_mark.hide()

	move_direction = signf(
		_player.global_position.x - global_position.x
	) if is_instance_valid(_player) else move_direction
	face_move_direction()
	var horizontal_offset := clampf(
		_player.global_position.x - global_position.x,
		-180.0,
		180.0
	) if is_instance_valid(_player) else 0.0
	_air_tween = create_tween()
	_air_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_air_tween.tween_property(
		self,
		"global_position",
		_air_ground_position + Vector2(horizontal_offset, -190.0),
		AIR_ASCENT_DURATION
	)
	await _air_tween.finished
	if not _air_attack_active or state == DEAD:
		return

	state = SKILL
	_air_casting = true
	warning_mark.show()
	await get_tree().create_timer(AIR_CAST_WARNING_DURATION).timeout
	if not _air_attack_active or state == DEAD:
		return

	_fire_feather_fan()
	_air_casting = false
	warning_mark.hide()
	state = RUN
	await get_tree().create_timer(0.35).timeout
	if not _air_attack_active or state == DEAD:
		return

	var landing_position := _air_ground_position
	_air_tween = create_tween()
	_air_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_air_tween.tween_property(
		self,
		"global_position",
		landing_position,
		AIR_DESCENT_DURATION
	)
	await _air_tween.finished
	if not _air_attack_active or state == DEAD:
		return

	state = IDLE
	_restore_after_air_attack()
	await get_tree().create_timer(AIR_RECOVERY_DURATION).timeout
	if not _air_attack_active or state == DEAD:
		return

	_air_attack_active = false
	if state != HURT:
		change_state(_air_return_state)


func _fire_feather_fan() -> void:
	if not is_instance_valid(_player):
		return

	var direction := (
		_player.global_position
		- (global_position + Vector2(move_direction * 30.0, -25.0))
	).normalized()
	var projectile_parent := get_parent()
	for angle_offset in [-0.16, 0.0, 0.16]:
		var projectile := BossProjectileScene.instantiate() as BossProjectile
		projectile_parent.add_child(projectile)
		projectile.global_position = global_position + Vector2(
			move_direction * 30.0,
			-25.0
		)
		projectile.setup(
			direction.rotated(angle_offset),
			AIR_PROJECTILE_SPEED,
			BossProjectile.KIND_FIRE_FEATHER,
			Color("#ff6a24"),
			AIR_PROJECTILE_DAMAGE
		)


func _restore_after_air_attack() -> void:
	body_collision_shape.set_deferred("disabled", false)
	hurt_box_collision_shape.set_deferred("disabled", false)


func _cancel_air_attack(restore_position := true) -> void:
	if _air_tween != null and _air_tween.is_valid():
		_air_tween.kill()
	_air_tween = null
	if not _air_attack_active:
		return

	_air_attack_active = false
	_air_casting = false
	warning_mark.hide()
	if restore_position:
		global_position = _air_ground_position
	if state != DEAD:
		_restore_after_air_attack()
		change_state(IDLE)
	_air_attack_cooldown.start(1.0)


func _find_player() -> Node2D:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null
	return current_scene.find_child("Player", true, false) as Node2D
