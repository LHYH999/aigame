class_name BurnEffect
extends Node

const TICK_INTERVAL := 0.5
const TICK_COUNT := 4
const TICK_DAMAGE := 1
const FLASH_HZ := 3.0
const FLASH_TINT := Color(1.35, 0.28, 0.22, 1.0)

var _ticks_left := 0
var _timer: Timer
var _elapsed := 0.0
var _sprites: Array[Sprite2D] = []
var _base_modulates: Array[Color] = []


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = TICK_INTERVAL
	_timer.one_shot = false
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	_collect_sprites()
	refresh()


func refresh() -> void:
	_ticks_left = TICK_COUNT
	get_parent().set_meta(&"burning", true)
	_timer.start()


func _process(delta: float) -> void:
	_elapsed += delta
	var pulse := 0.5 + 0.5 * sin(_elapsed * TAU * FLASH_HZ)
	var blend := 0.18 + 0.34 * pulse
	for index in _sprites.size():
		var sprite := _sprites[index]
		if is_instance_valid(sprite):
			sprite.self_modulate = _base_modulates[index].lerp(
				FLASH_TINT,
				blend
			)


func _collect_sprites() -> void:
	_sprites.clear()
	_base_modulates.clear()
	var target := get_parent()
	for node in target.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite == null:
			continue
		_sprites.append(sprite)
		_base_modulates.append(sprite.self_modulate)


func _on_tick() -> void:
	var target := get_parent()
	if not is_instance_valid(target) or not target.has_method("take_damage_over_time"):
		_end()
		return
	target.call("take_damage_over_time", TICK_DAMAGE)
	_ticks_left -= 1
	if _ticks_left <= 0:
		_end()


func _end() -> void:
	var target := get_parent()
	if is_instance_valid(target):
		target.remove_meta(&"burning")
	_restore_sprites()
	queue_free()


func _exit_tree() -> void:
	var target := get_parent()
	if is_instance_valid(target) and target.has_meta(&"burning"):
		target.remove_meta(&"burning")
	_restore_sprites()


func _restore_sprites() -> void:
	for index in _sprites.size():
		var sprite := _sprites[index]
		if is_instance_valid(sprite):
			sprite.self_modulate = _base_modulates[index]
	_sprites.clear()
	_base_modulates.clear()
