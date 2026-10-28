extends SceneTree


const PLAYER_SCENE := preload("res://player/player.tscn")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	fixture.set_project_setting("physics/2d/default_gravity", 0.0)
	var player := fixture.instantiate_scene(PLAYER_SCENE) as CharacterBody2D
	fixture.set_current_scene(player)
	await fixture.process_frames(1)
	player.set_physics_process(false)

	var model := player.get_node("VisualRoot/RedesignedModel") as Sprite2D
	var first_attack := await sample_attack_frames(player, model)
	fixture.expect(
		first_attack.has("frame_000.png") and first_attack.has("frame_007.png"),
		"Repeated attacks start at frame zero and reach the final attack frame"
	)

	player.change_state(player.IDLE)
	await fixture.process_frames(1)
	var second_attack := await sample_attack_frames(player, model)
	fixture.expect(
		second_attack.has("frame_000.png") and second_attack.has("frame_007.png"),
		"An attack after returning to idle replays the complete animation"
	)

	player.change_state(player.IDLE)
	await fixture.process_frames(1)
	player.change_state(player.HURT)
	await fixture.process_frames(1)
	player.change_state(player.IDLE)
	await fixture.process_frames(1)
	var attack_after_hurt := await sample_attack_frames(player, model)
	fixture.expect(
		attack_after_hurt.has("frame_000.png")
		and attack_after_hurt.has("frame_007.png"),
		"An attack after hurt restarts instead of resuming at the last frame"
	)

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func sample_attack_frames(player: CharacterBody2D, model: Sprite2D) -> Dictionary:
	var observed: Dictionary = {}
	player.change_state(player.ATTACK)
	for _frame in 24:
		await process_frame
		observed[model.texture.resource_path.get_file()] = true
	return observed
