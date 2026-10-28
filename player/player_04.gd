extends "res://player/player.gd"


const SHIELD_BREAK_ANIMATION := &"break"
const SHIELD_IDLE_ANIMATION := &"idle"

@onready var _shield: Area2D = $VisualRoot/ShieldSkill/Shield
@onready var _shield_animation_player: AnimationPlayer = $VisualRoot/ShieldSkill/Shield/AnimationPlayer

var _was_block_ready := false


func _ready() -> void:
	super._ready()
	mask_controller.state_changed.connect(_sync_shield_visual)
	_sync_shield_visual.call_deferred()


func _sync_shield_visual() -> void:
	if not is_node_ready():
		return

	if mask_controller.primary_mask_id != &"black_tortoise":
		_shield.hide()
		_shield_animation_player.stop()
		_was_block_ready = false
		return

	var cooldown_left: float = mask_controller.get_black_tortoise_block_cooldown()
	if cooldown_left > 0.0:
		if _was_block_ready:
			_shield.show()
			_shield_animation_player.play(SHIELD_BREAK_ANIMATION)
		_was_block_ready = false
		return

	_shield.show()
	_shield_animation_player.play(SHIELD_IDLE_ANIMATION)
	_was_block_ready = true
