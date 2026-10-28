extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	var files := DirAccess.get_files_at("res://levels")
	files.append("res://ui/story_test.json")
	for file_path in files:
		var path := (
			"res://levels/" + file_path
			if not file_path.begins_with("res://")
			else file_path
		)
		if not path.ends_with(".json"):
			continue
		var nodes = JSON.parse_string(FileAccess.get_file_as_string(path))
		if nodes is not Array:
			continue
		for node in nodes:
			if node is Dictionary and node.get("name", "") == "砚":
				fixture.expect(
					str(node.get("left", "")).ends_with("/yan_mirrored.png")
					and str(node.get("right", "")).is_empty(),
					"%s presents the mirrored Player portrait on the left" % path
				)

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()
