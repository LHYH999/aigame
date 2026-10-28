extends CanvasLayer


@onready var life_counter: HBoxContainer = $MarginContainer/LifeCounter
@onready var mask_icon: TextureRect = $MaskPanel/MaskContent/MaskIcon
@onready var mask_name: Label = $MaskPanel/MaskContent/MaskText/MaskName
@onready var mask_status: Label = $MaskPanel/MaskContent/MaskText/MaskStatus


func present_health(current_health: int, maximum_health: int) -> void:
	ensure_life_slots(maximum_health)
	var displayed_health := clampi(current_health, 0, maximum_health)
	for i in range(life_counter.get_child_count()):
		var heart := life_counter.get_child(i) as CanvasItem
		heart.visible = i < displayed_health


func is_presenting_health(current_health: int, maximum_health: int) -> bool:
	if maximum_health < 0 or life_counter.get_child_count() < maximum_health:
		return false

	var displayed_health := clampi(current_health, 0, maximum_health)
	for i in range(life_counter.get_child_count()):
		var heart := life_counter.get_child(i) as CanvasItem
		if heart.visible != (i < displayed_health):
			return false
	return true


func ensure_life_slots(maximum_health: int) -> void:
	if life_counter.get_child_count() == 0:
		return

	var target_count: int = maxi(maximum_health, 0)
	var template := life_counter.get_child(0)
	while life_counter.get_child_count() < target_count:
		life_counter.add_child(template.duplicate())


func present_mask(
	display_name: String,
	charge: int,
	max_charge: int,
	cooldown_left: float,
	block_cooldown_left: float,
	icon_path: String,
	mask_id: StringName
) -> void:
	mask_name.text = display_name
	mask_icon.texture = load(icon_path) as Texture2D if not icon_path.is_empty() else null
	mask_icon.visible = mask_icon.texture != null
	if mask_id.is_empty():
		mask_status.text = "击败神兽后获得"
		return
	match mask_id:
		&"white_tiger":
			mask_status.text = "伤害 ×2 · 范围 ×3"
		&"vermilion_bird":
			mask_status.text = "攻击附加灼烧 2 秒"
		&"black_tortoise":
			var block_text := (
				"格挡恢复 %.1f 秒" % block_cooldown_left
				if block_cooldown_left > 0.05
				else "自动格挡就绪"
			)
			var heal_text := (
				"Q 龙栖恢复 %.1f 秒" % cooldown_left
				if cooldown_left > 0.05
				else "Q 龙栖就绪"
			)
			mask_status.text = "%s · %s" % [block_text, heal_text]
		&"azure_dragon":
			mask_status.text = (
				"Q 照岁恢复 %.1f 秒" % cooldown_left
				if cooldown_left > 0.05
				else "契息 %d/%d · Q 照岁 · E 切换" % [charge, max_charge]
			)
