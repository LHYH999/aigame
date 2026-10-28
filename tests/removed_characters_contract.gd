extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const LEVELS := [
	"res://levels/level_02.tscn",
	"res://levels/level_03.tscn",
	"res://levels/level_04.tscn",
]
const ELK_KING_SCENE := "res://enemies/elk_king.tscn"

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	for scene_path in LEVELS:
		var level := (load(scene_path) as PackedScene).instantiate()
		fixture.expect(
			level.get_node_or_null("Leif") == null,
			"%s contains no Ahe NPC" % scene_path
		)
		fixture.expect(
			level.get_node_or_null("Ivar") == null,
			"%s contains no legacy scribe NPC" % scene_path
		)
		level.free()

	for filename in DirAccess.get_files_at("res://levels"):
		if not filename.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string("res://levels/" + filename)
		fixture.expect(not text.contains("阿禾"), "%s contains no Ahe dialogue" % filename)
		fixture.expect(not text.contains("莱夫"), "%s contains no legacy Ahe name" % filename)
		fixture.expect(not text.contains("青蘅"), "%s contains no Qingheng dialogue" % filename)
		fixture.expect(not text.contains("墨川"), "%s contains no Mochuan dialogue" % filename)

	var elk_king := (load(ELK_KING_SCENE) as PackedScene).instantiate()
	fixture.expect(
		elk_king.get_node_or_null("DeadAnimation/Leif") == null,
		"Elk King death tableau contains no Ahe"
	)
	fixture.expect(
		elk_king.get_node_or_null("DeadAnimation/Videl") == null,
		"Elk King death tableau contains no Qingheng"
	)
	elk_king.free()

	var story_test := FileAccess.get_file_as_string("res://ui/story_test.json")
	fixture.expect(not story_test.contains("青蘅"), "UI story fixture contains no Qingheng")
	fixture.expect(not story_test.contains("墨川"), "UI story fixture contains no Mochuan")

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()
