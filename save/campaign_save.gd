class_name CampaignSave
extends RefCounted


const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://campaign_autosave.json"
const CHECKPOINT_LEVEL_START := &"level_start"
const CHECKPOINT_BOSS := &"boss"
const VALID_CAMPAIGN_IDS := [
	&"level_01",
	&"level_02",
	&"level_03",
	&"level_04",
]
const VALID_MASK_IDS := [
	&"white_tiger",
	&"vermilion_bird",
	&"black_tortoise",
	&"azure_dragon",
]


static func create_data(
	campaign_id: StringName,
	checkpoint_id: StringName,
	mask_ids: Array[StringName],
	equipped_mask_id: StringName
) -> Dictionary:
	var serialized_masks: Array[String] = []
	for mask_id in mask_ids:
		if VALID_MASK_IDS.has(mask_id) and not serialized_masks.has(String(mask_id)):
			serialized_masks.append(String(mask_id))
	var serialized_equipped := String(equipped_mask_id)
	if (
		not serialized_masks.has(serialized_equipped)
		and not serialized_masks.is_empty()
	):
		serialized_equipped = serialized_masks[0]

	return {
		"version": SAVE_VERSION,
		"campaign_id": String(campaign_id),
		"checkpoint": String(checkpoint_id),
		"unlocked_masks": serialized_masks,
		"equipped_mask": serialized_equipped,
	}


static func save_game(data: Dictionary, path := DEFAULT_SAVE_PATH) -> Error:
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_tmp_path := absolute_path + ".tmp"
	var absolute_backup_path := absolute_path + ".bak"
	var file := FileAccess.open(absolute_tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	if FileAccess.file_exists(absolute_backup_path):
		var remove_backup_error := DirAccess.remove_absolute(absolute_backup_path)
		if remove_backup_error != OK:
			return remove_backup_error
	if FileAccess.file_exists(absolute_path):
		var backup_error := DirAccess.rename_absolute(
			absolute_path,
			absolute_backup_path
		)
		if backup_error != OK:
			return backup_error
	return DirAccess.rename_absolute(absolute_tmp_path, absolute_path)


static func load_game(path := DEFAULT_SAVE_PATH) -> Dictionary:
	for candidate_path in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate_path):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(candidate_path)) != OK:
			continue
		var parsed: Variant = json.data
		if parsed is not Dictionary:
			continue
		var normalized := _normalize_data(parsed)
		if not normalized.is_empty():
			return normalized
	return {}


static func has_valid_save(path := DEFAULT_SAVE_PATH) -> bool:
	return not load_game(path).is_empty()


static func clear(path := DEFAULT_SAVE_PATH) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	for candidate_path in [
		absolute_path,
		absolute_path + ".bak",
		absolute_path + ".tmp",
	]:
		if FileAccess.file_exists(candidate_path):
			DirAccess.remove_absolute(candidate_path)


static func get_mask_ids(data: Dictionary) -> Array[StringName]:
	var mask_ids: Array[StringName] = []
	for serialized_mask_id in data.get("unlocked_masks", []):
		var mask_id := StringName(str(serialized_mask_id))
		if VALID_MASK_IDS.has(mask_id) and not mask_ids.has(mask_id):
			mask_ids.append(mask_id)
	return mask_ids


static func _normalize_data(raw_data: Dictionary) -> Dictionary:
	var version := int(raw_data.get("version", 0))
	if version <= 0 or version > SAVE_VERSION:
		return {}

	var campaign_id := StringName(str(raw_data.get("campaign_id", "")))
	if not VALID_CAMPAIGN_IDS.has(campaign_id):
		return {}
	var checkpoint_id := StringName(str(raw_data.get("checkpoint", "")))
	if checkpoint_id not in [CHECKPOINT_LEVEL_START, CHECKPOINT_BOSS]:
		return {}

	var mask_ids := get_mask_ids(raw_data)
	var equipped_mask_id := StringName(str(raw_data.get("equipped_mask", "")))
	if not mask_ids.has(equipped_mask_id):
		equipped_mask_id = mask_ids[0] if not mask_ids.is_empty() else &""

	return create_data(campaign_id, checkpoint_id, mask_ids, equipped_mask_id)
