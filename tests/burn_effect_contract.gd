extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const PLAYER_SCENE := preload("res://player/player.tscn")


class BurnTarget:
	extends DamageableActor

	var total_damage := 0

	func take_damage(amount: int, _knockback_direction: Vector2) -> void:
		total_damage += amount

	func take_damage_over_time(amount: int) -> void:
		total_damage += amount


var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	var player := fixture.instantiate_scene(PLAYER_SCENE)
	var mask_ids: Array[StringName] = [&"white_tiger", &"vermilion_bird"]
	player.apply_mask_progress(mask_ids, &"vermilion_bird")
	player.change_state(player.ATTACK)

	var target := BurnTarget.new()
	target.add_to_group("enemies")
	fixture.add_node(target)
	var sprite := Sprite2D.new()
	target.add_child(sprite)
	var hurt_box := Area2D.new()
	target.add_child(hurt_box)
	player.call("_on_weapon_area_entered", hurt_box)

	await fixture.wait_seconds(0.15)
	fixture.expect(
		target.get_node_or_null("BurnEffect") != null
		and sprite.self_modulate.g < 0.95,
		"Burn applies an animated red flash to enemy sprites"
	)
	await fixture.wait_seconds(2.15)
	fixture.expect(
		target.total_damage == 4,
		"Vermilion attack burn deals one damage every 0.5 seconds for 2 seconds"
	)
	fixture.expect(
		not target.has_meta(&"burning"),
		"Burn clears its visual state after four ticks"
	)
	fixture.expect(
		sprite.self_modulate.is_equal_approx(Color.WHITE),
		"Burn restores the enemy sprite tint after expiring"
	)

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()
