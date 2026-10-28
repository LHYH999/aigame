class_name MaskController
extends Node


signal state_changed
signal mask_unlocked(mask_id: StringName)

const MAX_CHARGE := 100
const ATTACK_CHARGE := 8
const MASKS := {
	&"white_tiger": {
		"display_name": "白虎面具",
		"icon": "res://assets/ui/masks/white_tiger.png",
		"cost": 0,
		"cooldown": 0.0,
		"active_supported": false,
	},
	&"vermilion_bird": {
		"display_name": "朱雀面具",
		"icon": "res://assets/ui/masks/vermilion_bird.png",
		"cost": 0,
		"cooldown": 0.0,
		"active_supported": false,
	},
	&"black_tortoise": {
		"display_name": "玄武面具",
		"icon": "res://assets/ui/masks/black_tortoise.png",
		"cost": 0,
		"cooldown": 15.0,
		"active_supported": true,
		"block_cooldown": 10.0,
	},
	&"azure_dragon": {
		"display_name": "青龙面具",
		"icon": "res://assets/ui/masks/azure_dragon.png",
		"cost": 40,
		"cooldown": 2.4,
		"active_supported": true,
	},
}

var unlocked_mask_ids: Array[StringName] = []
var primary_mask_id: StringName = &""
var charge := 0
var _cooldowns_left: Dictionary = {}
var _black_tortoise_block_cooldown := 0.0


func _process(delta: float) -> void:
	var changed := false
	if _black_tortoise_block_cooldown > 0.0:
		_black_tortoise_block_cooldown = maxf(
			_black_tortoise_block_cooldown - delta,
			0.0
		)
		changed = true
	for mask_id in _cooldowns_left.keys():
		var cooldown_left := float(_cooldowns_left[mask_id])
		if cooldown_left <= 0.0:
			continue
		_cooldowns_left[mask_id] = maxf(cooldown_left - delta, 0.0)
		changed = true
	if changed:
		state_changed.emit()


func set_progress(mask_ids: Array[StringName], equipped_mask_id: StringName) -> void:
	unlocked_mask_ids.clear()
	for mask_id in mask_ids:
		if MASKS.has(mask_id) and not unlocked_mask_ids.has(mask_id):
			unlocked_mask_ids.append(mask_id)

	primary_mask_id = equipped_mask_id
	if not unlocked_mask_ids.has(primary_mask_id):
		primary_mask_id = unlocked_mask_ids[0] if not unlocked_mask_ids.is_empty() else &""
	charge = maxi(charge, 60 if not unlocked_mask_ids.is_empty() else 0)
	_cooldowns_left.clear()
	_black_tortoise_block_cooldown = 0.0
	state_changed.emit()


func unlock_mask(mask_id: StringName) -> bool:
	if not MASKS.has(mask_id) or unlocked_mask_ids.has(mask_id):
		return false

	unlocked_mask_ids.append(mask_id)
	if primary_mask_id.is_empty():
		primary_mask_id = mask_id
	charge = maxi(charge, 60)
	state_changed.emit()
	mask_unlocked.emit(mask_id)
	return true


func add_charge(amount: int) -> void:
	if unlocked_mask_ids.is_empty() or amount <= 0:
		return
	var previous_charge := charge
	charge = mini(charge + amount, MAX_CHARGE)
	if charge != previous_charge:
		state_changed.emit()


func cycle_primary() -> StringName:
	if unlocked_mask_ids.size() < 2:
		return primary_mask_id

	var index := unlocked_mask_ids.find(primary_mask_id)
	primary_mask_id = unlocked_mask_ids[(index + 1) % unlocked_mask_ids.size()]
	state_changed.emit()
	return primary_mask_id


func try_activate() -> StringName:
	if primary_mask_id.is_empty() or get_cooldown_left() > 0.0:
		return &""
	var definition: Dictionary = MASKS[primary_mask_id]
	if not bool(definition.get("active_supported", false)):
		return &""
	var cost := int(definition["cost"])
	if charge < cost:
		return &""

	charge -= cost
	_cooldowns_left[primary_mask_id] = float(definition["cooldown"])
	state_changed.emit()
	return primary_mask_id


func get_mask_definition(mask_id: StringName = primary_mask_id) -> Dictionary:
	return MASKS.get(mask_id, {})


func get_display_name(mask_id: StringName = primary_mask_id) -> String:
	return str(get_mask_definition(mask_id).get("display_name", "未获得面具"))


func get_icon_path(mask_id: StringName = primary_mask_id) -> String:
	return str(get_mask_definition(mask_id).get("icon", ""))


func get_cooldown_left(mask_id: StringName = &"") -> float:
	var resolved_mask_id := mask_id if not mask_id.is_empty() else primary_mask_id
	return float(_cooldowns_left.get(resolved_mask_id, 0.0))


func try_block_with_black_tortoise() -> bool:
	if (
		primary_mask_id != &"black_tortoise"
		or _black_tortoise_block_cooldown > 0.0
	):
		return false
	_black_tortoise_block_cooldown = float(
		MASKS[&"black_tortoise"]["block_cooldown"]
	)
	state_changed.emit()
	return true


func get_black_tortoise_block_cooldown() -> float:
	return _black_tortoise_block_cooldown


func get_max_charge() -> int:
	return MAX_CHARGE
