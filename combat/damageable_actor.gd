@abstract
class_name DamageableActor
extends CharacterBody2D


@abstract
func take_damage(amount: int, knockback_direction: Vector2) -> void


func take_damage_over_time(amount: int) -> void:
	take_damage(amount, Vector2.ZERO)
