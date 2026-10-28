extends "res://combat/damageable_actor.gd"


signal hurt_taken
signal died
signal dodge_started
signal health_changed(current_health: int, maximum_health: int)
signal mask_state_changed(
	display_name: String,
	charge: int,
	max_charge: int,
	cooldown_left: float,
	block_cooldown_left: float,
	icon_path: String,
	mask_id: StringName
)

const SPEED = 300.0
const JUMP_VELOCITY = -600.0
const ATTACK_TO_IDLE = "parameters/conditions/attack_to_idle"
const ATTACK_TO_JUMP = "parameters/conditions/attack_to_jump"
const ATTACK_TO_RUNNING = "parameters/conditions/attack_to_running"
const MAX_HEALTH = 5
const DEAD_ANIMATION = "dead"
const HURT_ANIMATION = "hurt"
const HURT_IMMUNITY_DURATION = 1.5
const HURT_KNOCKBACK_DISTANCE = 100.0
const PERSISTENT_CONTACT_TOLERANCE = 1.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER_TIME := 0.12
const JUMP_RELEASE_MULTIPLIER := 0.45
const DODGE_DURATION := 0.15
const DODGE_SPEED := 940.0
const DODGE_AFTERIMAGE_INTERVAL := 0.05
const BASE_ATTACK_DAMAGE := 8
const BASE_ATTACK_RANGE_MULTIPLIER := 1.5
const WHITE_TIGER_ATTACK_DAMAGE_MULTIPLIER := 2.0
const WHITE_TIGER_RANGE_MULTIPLIER := 2.0
const DamageAndHealthModule := preload("res://combat/damage_and_health.gd")
const BurnEffectScript := preload("res://combat/burn_effect.gd")

enum {IDLE, RUN, JUMP, HURT, DEAD, ATTACK, DODGE}
@export_range(1, 100, 1) var maximum_health := MAX_HEALTH:
	set(value):
		maximum_health = value
		if _health != null:
			_initialize_health(maximum_health)
var state = -1
var controls_enabled := true
var _damage_immune := false
var _hurt_response_active := false
var _pending_attack := false
var _burned_targets_this_attack: Dictionary = {}
var _coyote_time_left := 0.0
var _jump_buffer_time_left := 0.0
var _dodge_time_left := 0.0
var _dodge_afterimage_time_left := 0.0
var _dodge_direction := 1.0
var _health := DamageAndHealthModule.new(MAX_HEALTH)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_state: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
@onready var visual_root: Node2D = $VisualRoot
@onready var body_collision_shape: CollisionShape2D = $CollisionShape2D
@onready var weapon_collision_shape: CollisionShape2D = $VisualRoot/AttackFan/CollisionShape2D
@onready var weapon_area: Area2D = $VisualRoot/AttackFan
@onready var attack_cooldown: Timer = $AttackCooldown
@onready var dodge_cooldown: Timer = $DodgeCooldown
@onready var mask_controller = $MaskController


func _init() -> void:
	_connect_health_signals()


func _initialize_health(value: int) -> void:
	_health = DamageAndHealthModule.new(value)
	_connect_health_signals()


func _connect_health_signals() -> void:
	_health.health_changed.connect(_on_health_changed)
	_health.depleted.connect(_on_health_depleted)


func get_current_health() -> int:
	return _health.get_current_health()


func get_maximum_health() -> int:
	return _health.get_maximum_health()


func is_hurt_immune() -> bool:
	return _health.is_hurt_immune()


func is_health_depleted() -> bool:
	return _health.is_depleted()


func is_dodging() -> bool:
	return _dodge_time_left > 0.0


func get_dodge_cooldown_left() -> float:
	return dodge_cooldown.time_left


func set_damage_immune(enabled: bool) -> void:
	_damage_immune = enabled


func apply_debug_health_override(health: int) -> bool:
	return _health.apply_debug_health_override(health)


func change_state(new_state: int) -> void:
	if state == new_state:
		return

	state = new_state
	set_weapon_collision_enabled(state == ATTACK)
	match state:
		IDLE:
			animation_state.travel("idle")
		RUN:
			animation_state.travel("running")
		JUMP:
			animation_state.travel("jump")
		ATTACK:
			_apply_attack_mask_traits()
			animation_state.travel("attack")
		HURT:
			animation_state.travel(HURT_ANIMATION)
		DEAD:
			velocity = Vector2.ZERO
			animation_state.travel(DEAD_ANIMATION)
		DODGE:
			animation_state.start("running")
			animation_tree.advance(0.0)


func set_weapon_collision_enabled(enabled: bool) -> void:
	weapon_collision_shape.set_deferred("disabled", not enabled)


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not controls_enabled:
		_pending_attack = false
		_cancel_dodge()
	if controls_enabled or state == DEAD:
		return

	velocity.x = 0.0
	change_state(IDLE)


func apply_mask_progress(
	mask_ids: Array[StringName],
	equipped_mask_id: StringName
) -> void:
	mask_controller.set_progress(mask_ids, equipped_mask_id)


func unlock_mask(mask_id: StringName) -> bool:
	return mask_controller.unlock_mask(mask_id)


func get_mask_controller() -> Node:
	return mask_controller


func has_mask(mask_id: StringName) -> bool:
	return mask_controller.unlocked_mask_ids.has(mask_id)


func disable_for_cinematic_handoff() -> void:
	_cancel_dodge()
	visible = false
	collision_layer = 0
	collision_mask = 0
	$CollisionShape2D.set_deferred("disabled", true)
	set_weapon_collision_enabled(false)
	velocity = Vector2.ZERO
	set_physics_process(false)


func restore_full_health() -> void:
	_health.restore_full_health()


func set_attack_return_conditions(direction: float) -> void:
	var should_jump := not is_on_floor()
	var should_run := not should_jump and not is_zero_approx(direction)

	animation_tree.set(ATTACK_TO_JUMP, should_jump)
	animation_tree.set(ATTACK_TO_RUNNING, should_run)
	animation_tree.set(ATTACK_TO_IDLE, not should_jump and not should_run)


func apply_knockback(
	knockback_direction: Vector2,
	complete_collision_motion := false
) -> void:
	if knockback_direction.is_zero_approx():
		return

	var remaining_motion := knockback_direction.normalized() * HURT_KNOCKBACK_DISTANCE
	if not complete_collision_motion:
		move_and_collide(remaining_motion)
		return
	for _collision_index in max_slides:
		var collision := move_and_collide(remaining_motion)
		if collision == null:
			return
		remaining_motion = collision.get_remainder().slide(collision.get_normal())
		if remaining_motion.is_zero_approx():
			return


func _ready() -> void:
	animation_tree.active = true
	set_weapon_collision_enabled(false)
	mask_controller.state_changed.connect(_emit_mask_state)
	weapon_area.area_entered.connect(_on_weapon_area_entered)
	change_state(IDLE)
	_emit_mask_state.call_deferred()


func _physics_process(delta: float) -> void:
	if state == DEAD:
		return

	if _dodge_time_left > 0.0:
		_update_dodge(delta)
		return

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		_coyote_time_left = maxf(_coyote_time_left - delta, 0.0)
	else:
		_coyote_time_left = COYOTE_TIME

	if not controls_enabled:
		move_and_slide()
		return

	if (
		Input.is_action_just_pressed("dodge")
		and dodge_cooldown.is_stopped()
		and not _hurt_response_active
		and state != HURT
	):
		_start_dodge()
		return

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_time_left = JUMP_BUFFER_TIME
	else:
		_jump_buffer_time_left = maxf(_jump_buffer_time_left - delta, 0.0)

	if _jump_buffer_time_left > 0.0 and _coyote_time_left > 0.0:
		velocity.y = JUMP_VELOCITY
		_coyote_time_left = 0.0
		_jump_buffer_time_left = 0.0
	elif Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_RELEASE_MULTIPLIER

	if Input.is_action_just_pressed("cycle_mask"):
		mask_controller.cycle_primary()
	if Input.is_action_just_pressed("mask_skill"):
		_try_activate_mask()

	# Handle attack.
	var wants_attack := Input.is_action_just_pressed("attack")

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("left", "right")
	if direction:
		visual_root.scale.x = -1.0 if direction < 0.0 else 1.0
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	if not _health.is_hurt_immune():
		_try_take_persistent_contact_damage()
	if wants_attack and (
		_hurt_response_active or not attack_cooldown.is_stopped()
	):
		_pending_attack = true
	if _hurt_response_active or state == DEAD:
		return

	if attack_cooldown.is_stopped() and (wants_attack or _pending_attack):
		_pending_attack = false
		change_state(ATTACK)
		attack_cooldown.start()
		mask_controller.add_charge(mask_controller.ATTACK_CHARGE)
		set_attack_return_conditions(direction)
		return

	if state == ATTACK and animation_state.get_current_node() == "attack":
		set_attack_return_conditions(direction)
		return

	if not is_on_floor():
		change_state(JUMP)
	elif direction:
		change_state(RUN)
	else:
		change_state(IDLE)


func _try_take_persistent_contact_damage() -> void:
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		var actor := collision.get_collider() as DamageableActor
		if not _can_deal_persistent_contact_damage(actor):
			continue

		take_damage(1, collision.get_normal(), true)
		return

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body_collision_shape.shape
	query.transform = body_collision_shape.global_transform
	query.margin = PERSISTENT_CONTACT_TOLERANCE
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var actor := result["collider"] as DamageableActor
		if not _can_deal_persistent_contact_damage(actor):
			continue

		take_damage(1, global_position - actor.global_position, true)
		return


func _can_deal_persistent_contact_damage(actor: DamageableActor) -> bool:
	return actor != null and is_instance_valid(actor) and actor.is_in_group("enemies")


func take_damage(
	amount: int,
	knockback_direction: Vector2,
	complete_knockback_collision_motion := false
) -> void:
	if (
		amount <= 0
		or _damage_immune
		or _health.is_hurt_immune()
		or _health.is_depleted()
	):
		return
	if _try_mask_damage_block():
		return

	if not _health.accept_damage(amount):
		return

	_cancel_dodge()
	hurt_taken.emit()
	if _health.is_depleted():
		return

	apply_knockback(knockback_direction, complete_knockback_collision_motion)
	_hurt_response_active = true
	change_state(HURT)
	get_tree().create_timer(
		animation_player.get_animation(HURT_ANIMATION).length
	).timeout.connect(_end_hurt_response)
	await get_tree().create_timer(HURT_IMMUNITY_DURATION).timeout
	_health.end_hurt_immunity()


func _end_hurt_response() -> void:
	_hurt_response_active = false


func _start_dodge() -> void:
	var direction := Input.get_axis("left", "right")
	if is_zero_approx(direction):
		direction = signf(visual_root.scale.x)
	if is_zero_approx(direction):
		direction = 1.0

	_dodge_direction = signf(direction)
	visual_root.scale.x = _dodge_direction
	_dodge_time_left = DODGE_DURATION
	_dodge_afterimage_time_left = 0.0
	_pending_attack = false
	dodge_cooldown.start()
	change_state(DODGE)
	_spawn_dodge_afterimage()
	dodge_started.emit()


func _update_dodge(delta: float) -> void:
	_dodge_time_left = maxf(_dodge_time_left - delta, 0.0)
	_dodge_afterimage_time_left -= delta
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	velocity.x = _dodge_direction * DODGE_SPEED
	move_and_slide()
	if _dodge_afterimage_time_left <= 0.0:
		_dodge_afterimage_time_left = DODGE_AFTERIMAGE_INTERVAL
		_spawn_dodge_afterimage()
	if _dodge_time_left <= 0.0:
		_finish_dodge()


func _finish_dodge() -> void:
	_dodge_time_left = 0.0
	velocity.x = _dodge_direction * SPEED * 0.35
	if not is_on_floor():
		change_state(JUMP)
	elif not is_zero_approx(Input.get_axis("left", "right")):
		change_state(RUN)
	else:
		change_state(IDLE)


func _cancel_dodge() -> void:
	_dodge_time_left = 0.0


func _spawn_dodge_afterimage() -> void:
	var model := visual_root.get_node_or_null("RedesignedModel") as Sprite2D
	if model == null or model.texture == null:
		return
	var afterimage := Sprite2D.new()
	afterimage.name = "DodgeAfterimage"
	afterimage.texture = model.texture
	afterimage.flip_h = model.flip_h
	afterimage.offset = model.offset
	afterimage.centered = model.centered
	afterimage.modulate = Color(0.55, 0.88, 1.0, 0.42)
	afterimage.z_index = model.z_index - 1
	afterimage.add_to_group("dodge_afterimages")
	get_parent().add_child(afterimage)
	afterimage.global_transform = model.global_transform
	var tween := create_tween()
	tween.tween_property(afterimage, "modulate:a", 0.0, 0.22)
	tween.tween_callback(afterimage.queue_free)


func _on_health_changed(current_health: int, observed_maximum_health: int) -> void:
	health_changed.emit(current_health, observed_maximum_health)


func _on_health_depleted() -> void:
	_cancel_dodge()
	change_state(DEAD)
	died.emit()


func _try_activate_mask() -> void:
	var mask_id: StringName = mask_controller.try_activate()
	if mask_id.is_empty():
		return

	match mask_id:
		&"black_tortoise":
			_health.heal(1)
			_spawn_mask_ring(95.0, Color("#59b7c7"))
		&"azure_dragon":
			_health.heal(1)
			_spawn_mask_ring(110.0, Color("#58c48f"))
			_grant_temporary_immunity(0.8)


func _apply_attack_mask_traits() -> void:
	_burned_targets_this_attack.clear()
	var mask_id: StringName = mask_controller.primary_mask_id
	var range_scale := BASE_ATTACK_RANGE_MULTIPLIER
	var damage_multiplier := 1.0
	if mask_id == &"white_tiger":
		range_scale *= WHITE_TIGER_RANGE_MULTIPLIER
		damage_multiplier = WHITE_TIGER_ATTACK_DAMAGE_MULTIPLIER
	var attack_damage := BASE_ATTACK_DAMAGE * damage_multiplier
	weapon_collision_shape.scale = Vector2.ONE * range_scale
	weapon_area.set_meta(&"attack_damage", attack_damage)
	_spawn_attack_arc(_get_weapon_reach(), _get_attack_effect_color(mask_id))


func _get_attack_effect_color(mask_id: StringName) -> Color:
	match mask_id:
		&"white_tiger":
			return Color("#e7c766")
		&"vermilion_bird":
			return Color("#ff7a32")
		&"black_tortoise":
			return Color("#59b7c7")
		&"azure_dragon":
			return Color("#76d6ae")
		_:
			return Color("#c7e7f2")


func _get_weapon_reach() -> float:
	var polygon := weapon_collision_shape.shape as ConvexPolygonShape2D
	if polygon == null:
		return 0.0
	var maximum_radius := 0.0
	for point in polygon.points:
		maximum_radius = maxf(maximum_radius, point.length())
	return maximum_radius * absf(weapon_collision_shape.global_scale.x)


func _on_weapon_area_entered(area: Area2D) -> void:
	if (
		state != ATTACK
		or mask_controller.primary_mask_id != &"vermilion_bird"
	):
		return
	var target := area.get_parent() as DamageableActor
	if (
		target == null
		or not target.is_in_group("enemies")
		or _burned_targets_this_attack.has(target.get_instance_id())
	):
		return
	_burned_targets_this_attack[target.get_instance_id()] = true
	var burn := target.get_node_or_null("BurnEffect")
	if burn == null:
		burn = BurnEffectScript.new()
		burn.name = "BurnEffect"
		target.add_child(burn)
	else:
		burn.call("refresh")


func _try_mask_damage_block() -> bool:
	if not mask_controller.try_block_with_black_tortoise():
		return false
	_spawn_mask_ring(80.0, Color("#59b7c7"))
	return true


func _spawn_attack_arc(radius: float, color: Color) -> void:
	var facing := signf(visual_root.scale.x)
	if is_zero_approx(facing):
		facing = 1.0
	var points := PackedVector2Array()
	for point_index in 13:
		var angle := lerpf(-0.8, 0.8, float(point_index) / 12.0)
		points.append(
			Vector2(cos(angle) * radius * facing, sin(angle) * radius)
		)
	_spawn_attack_stroke(
		points,
		Color(color.r, color.g, color.b, 0.42),
		12.0,
		19,
		true
	)
	_spawn_attack_stroke(
		points,
		color.lightened(0.68),
		5.0,
		20,
		false
	)


func _spawn_attack_stroke(
	points: PackedVector2Array,
	color: Color,
	width: float,
	depth: int,
	is_glow: bool
) -> void:
	var arc := Line2D.new()
	arc.width = width
	arc.default_color = color
	arc.z_index = depth
	arc.antialiased = true
	if is_glow:
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		arc.material = material
	arc.points = points
	arc.scale = Vector2(0.76, 0.76)
	add_child(arc)
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(arc, "scale", Vector2.ONE, 0.12)
	tween.tween_property(arc, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(arc.queue_free)


func _spawn_mask_ring(radius: float, color: Color) -> void:
	var ring := Line2D.new()
	ring.width = 6.0
	ring.default_color = color
	ring.z_index = 20
	var points := PackedVector2Array()
	for point_index in 25:
		var angle := TAU * float(point_index) / 24.0
		points.append(Vector2(cos(angle), sin(angle)) * radius * 0.5)
	ring.points = points
	ring.position = Vector2(signf(visual_root.scale.x) * radius * 0.5, 0.0)
	add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "modulate:a", 0.0, 0.28)
	tween.tween_callback(ring.queue_free)


func _grant_temporary_immunity(duration: float) -> void:
	set_damage_immune(true)
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		set_damage_immune(false)


func _emit_mask_state() -> void:
	if not is_node_ready():
		return
	mask_state_changed.emit(
		mask_controller.get_display_name(),
		mask_controller.charge,
		mask_controller.get_max_charge(),
		mask_controller.get_cooldown_left(),
		mask_controller.get_black_tortoise_block_cooldown(),
		mask_controller.get_icon_path(),
		mask_controller.primary_mask_id
	)
