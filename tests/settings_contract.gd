extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const SettingsModule := preload("res://settings/game_settings.gd")
const SETTINGS_PATH := "res://.tmp/settings_contract.json"

var fixture: HeadlessGameplayFixture


func _init() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	SettingsModule.clear(SETTINGS_PATH)
	var settings := {
		"version": SettingsModule.SETTINGS_VERSION,
		"master_volume": 0.35,
		"fullscreen": true,
	}
	fixture.expect(
		SettingsModule.save_settings(settings, SETTINGS_PATH) == OK,
		"Settings save writes to the configured path"
	)
	var loaded := SettingsModule.load_settings(SETTINGS_PATH)
	fixture.expect(
		is_equal_approx(float(loaded["master_volume"]), 0.35)
		and bool(loaded["fullscreen"]),
		"Settings round-trip volume and fullscreen preferences"
	)

	SettingsModule.apply(loaded)
	var master_bus := AudioServer.get_bus_index("Master")
	fixture.expect(
		is_equal_approx(
			AudioServer.get_bus_volume_db(master_bus),
			linear_to_db(0.35)
		),
		"Applying settings updates the Master audio bus"
	)

	var clamped := SettingsModule.normalize({
		"version": SettingsModule.SETTINGS_VERSION,
		"master_volume": 4.0,
		"fullscreen": false,
	})
	fixture.expect(
		is_equal_approx(float(clamped["master_volume"]), 1.0),
		"Settings validation clamps volume to the supported range"
	)

	SettingsModule.apply(SettingsModule.defaults())
	SettingsModule.clear(SETTINGS_PATH)
	fixture.complete(false)
	await process_frame
	fixture.complete()
