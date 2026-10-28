extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const LEVEL_02_SCENE := "res://levels/level_02.tscn"
const LEVEL_02_STORY := "res://levels/level_02_story.json"

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	var level := (load(LEVEL_02_SCENE) as PackedScene).instantiate() as CampaignLevel
	fixture.expect(level != null, "Level02 implements CampaignLevel")
	if level == null:
		fixture.complete()
		return

	level.prepare_for_campaign(true)
	fixture.add_node(level)
	fixture.set_current_scene(level)
	await fixture.process_frames(1)
	await fixture.wait_for_act_announcement(level)

	var story := level.get_node_or_null("Story") as CanvasLayer
	fixture.expect(story != null, "Level02 contains an opening Story")
	if story != null:
		fixture.expect(
			story.get("story_path") == LEVEL_02_STORY,
			"Level02 uses level_02_story.json"
		)
		var story_nodes: Array = story.get("story_nodes")
		fixture.expect(not story_nodes.is_empty(), "Level02 opening Story is loaded")
		for _story_node in story_nodes:
			story.call("show_next_node")

	await fixture.process_frames(1)
	fixture.expect(
		not level.is_campaign_story_phase_active(),
		"Level02 completes its opening Story"
	)
	fixture.expect(level.get_node_or_null("Leif") == null, "Level02 has no Ahe NPC")

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()
