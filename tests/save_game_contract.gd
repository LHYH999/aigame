extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const SaveSystem := preload("res://save/campaign_save.gd")
const SAVE_PATH := "res://.tmp/campaign_save_contract.json"
const NEWER_SAVE_PATH := "res://.tmp/campaign_save_contract_newer.json"
const INVALID_SAVE_PATH := "res://.tmp/campaign_save_contract_invalid.json"

var fixture: HeadlessGameplayFixture


func _init() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	SaveSystem.clear(SAVE_PATH)
	SaveSystem.clear(NEWER_SAVE_PATH)
	SaveSystem.clear(INVALID_SAVE_PATH)

	var first_masks: Array[StringName] = [&"white_tiger", &"vermilion_bird"]
	var first_data := SaveSystem.create_data(
		&"level_02",
		SaveSystem.CHECKPOINT_BOSS,
		first_masks,
		&"vermilion_bird"
	)
	fixture.expect(
		SaveSystem.save_game(first_data, SAVE_PATH) == OK,
		"Campaign save writes to the configured save path"
	)
	var loaded := SaveSystem.load_game(SAVE_PATH)
	fixture.expect(
		int(loaded.get("version", -1)) == SaveSystem.SAVE_VERSION
		and loaded.get("campaign_id") == "level_02"
		and loaded.get("checkpoint") == "boss"
		and SaveSystem.get_mask_ids(loaded)
		== [&"white_tiger", &"vermilion_bird"]
		and loaded.get("equipped_mask") == "vermilion_bird",
		"Campaign save round-trips campaign, checkpoint, and mask progress"
	)

	var second_masks: Array[StringName] = [
		&"white_tiger",
		&"vermilion_bird",
		&"black_tortoise",
	]
	var second_data := SaveSystem.create_data(
		&"level_03",
		SaveSystem.CHECKPOINT_BOSS,
		second_masks,
		&"black_tortoise"
	)
	SaveSystem.save_game(second_data, SAVE_PATH)
	var primary_file := FileAccess.open(
		ProjectSettings.globalize_path(SAVE_PATH),
		FileAccess.WRITE
	)
	primary_file.store_string("{invalid")
	primary_file.close()
	var recovered := SaveSystem.load_game(SAVE_PATH)
	fixture.expect(
		recovered.get("campaign_id") == "level_02",
		"Corrupt primary save falls back to the previous backup"
	)

	var newer_data := first_data.duplicate(true)
	newer_data["version"] = SaveSystem.SAVE_VERSION + 1
	SaveSystem.save_game(newer_data, NEWER_SAVE_PATH)
	fixture.expect(
		SaveSystem.load_game(NEWER_SAVE_PATH).is_empty(),
		"Saves created by a newer schema are rejected"
	)

	var invalid_data := first_data.duplicate(true)
	invalid_data["campaign_id"] = "missing_level"
	SaveSystem.save_game(invalid_data, INVALID_SAVE_PATH)
	fixture.expect(
		not SaveSystem.has_valid_save(INVALID_SAVE_PATH),
		"Unknown campaign identifiers make a save invalid"
	)

	SaveSystem.clear(SAVE_PATH)
	SaveSystem.clear(NEWER_SAVE_PATH)
	SaveSystem.clear(INVALID_SAVE_PATH)
	fixture.complete(false)
	await process_frame
	fixture.complete()
