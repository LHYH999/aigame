extends SceneTree


const PLAYER_02_SCENE := preload("res://player/player_02.tscn")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	fixture.set_project_setting("physics/2d/default_gravity", 0.0)
	var player := fixture.instantiate_scene(PLAYER_02_SCENE) as CharacterBody2D
	fixture.set_current_scene(player)
	await fixture.process_frames(1)

	fixture.expect(
		player.get_node_or_null("Player_Thunder") == null,
		"Player no longer owns the obsolete thunder weapon node"
	)

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()
