class_name GameSettings
extends RefCounted


const SETTINGS_VERSION := 1
const DEFAULT_SETTINGS_PATH := "user://settings.json"
const DEFAULT_MASTER_VOLUME := 0.8
const SILENCE_DB := -80.0


static func defaults() -> Dictionary:
	return {
		"version": SETTINGS_VERSION,
		"master_volume": DEFAULT_MASTER_VOLUME,
		"fullscreen": false,
	}


static func load_settings(path := DEFAULT_SETTINGS_PATH) -> Dictionary:
	for candidate_path in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate_path):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(candidate_path)) != OK:
			continue
		if json.data is not Dictionary:
			continue
		var normalized := normalize(json.data)
		if not normalized.is_empty():
			return normalized
	return defaults()


static func save_settings(settings: Dictionary, path := DEFAULT_SETTINGS_PATH) -> Error:
	var normalized := normalize(settings)
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_tmp_path := absolute_path + ".tmp"
	var absolute_backup_path := absolute_path + ".bak"
	var file := FileAccess.open(absolute_tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(normalized, "\t"))
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


static func normalize(raw_settings: Dictionary) -> Dictionary:
	var version := int(raw_settings.get("version", SETTINGS_VERSION))
	if version <= 0 or version > SETTINGS_VERSION:
		return {}
	return {
		"version": SETTINGS_VERSION,
		"master_volume": clampf(
			float(raw_settings.get("master_volume", DEFAULT_MASTER_VOLUME)),
			0.0,
			1.0
		),
		"fullscreen": bool(raw_settings.get("fullscreen", false)),
	}


static func apply(settings: Dictionary) -> void:
	var normalized := normalize(settings)
	if normalized.is_empty():
		return

	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		var linear_volume := float(normalized["master_volume"])
		AudioServer.set_bus_volume_db(
			master_bus,
			linear_to_db(linear_volume) if linear_volume > 0.0 else SILENCE_DB
		)

	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN
			if bool(normalized["fullscreen"])
			else DisplayServer.WINDOW_MODE_WINDOWED
		)


static func clear(path := DEFAULT_SETTINGS_PATH) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	for candidate_path in [
		absolute_path,
		absolute_path + ".bak",
		absolute_path + ".tmp",
	]:
		if FileAccess.file_exists(candidate_path):
			DirAccess.remove_absolute(candidate_path)
