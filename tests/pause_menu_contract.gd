extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const MAIN_SCENE := preload("res://main.tscn")
const SettingsModule := preload("res://settings/game_settings.gd")
const SETTINGS_PATH := "res://.tmp/pause_menu_settings.json"

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	SettingsModule.clear(SETTINGS_PATH)

	var main := MAIN_SCENE.instantiate()
	main.get_node("PauseMenu").set("settings_path", SETTINGS_PATH)
	fixture.add_node(main)
	fixture.set_current_scene(main)
	await fixture.process_frames(2)
	main.call("start_level_02", false)
	await fixture.process_frames(2)

	var pause_menu := main.get_node("PauseMenu")
	var menu_page := pause_menu.get_node(
		"CenterContainer/Panel/Margin/Root/MenuPage"
	) as VBoxContainer
	var settings_page := pause_menu.get_node(
		"CenterContainer/Panel/Margin/Root/SettingsPage"
	) as VBoxContainer
	fixture.expect(
		main.call("can_open_pause_menu"),
		"Gameplay permits opening the pause menu"
	)

	await press_cancel(main)
	fixture.expect(
		paused and bool(pause_menu.get("visible")) and menu_page.visible,
		"Escape opens the pause menu and pauses the SceneTree"
	)

	var resume_button := pause_menu.get_node(
		"CenterContainer/Panel/Margin/Root/MenuPage/Resume"
	) as Button
	resume_button.emit_signal("pressed")
	await fixture.process_frames(1)
	fixture.expect(
		not paused and not bool(pause_menu.get("visible")),
		"Resume closes the pause menu and restores gameplay"
	)

	var level_before_retry := main.call("get_active_campaign_level") as CampaignLevel
	await press_cancel(main)
	var retry_button := pause_menu.get_node(
		"CenterContainer/Panel/Margin/Root/MenuPage/Retry"
	) as Button
	retry_button.emit_signal("pressed")
	await fixture.process_frames(2)
	fixture.expect(
		not paused
		and not bool(pause_menu.get("visible"))
		and main.call("get_active_campaign_level") != level_before_retry
		and not is_instance_valid(level_before_retry),
		"Pause-menu retry replaces the current Level from its checkpoint"
	)

	await press_cancel(main)
	var settings_button := pause_menu.get_node(
		"CenterContainer/Panel/Margin/Root/MenuPage/Settings"
	) as Button
	settings_button.emit_signal("pressed")
	await fixture.process_frames(1)
	fixture.expect(
		settings_page.visible and not menu_page.visible,
		"Settings opens as a subpage of the pause menu"
	)

	var volume_slider := pause_menu.get_node(
		"CenterContainer/Panel/Margin/Root/SettingsPage/MasterVolume"
	) as HSlider
	var fullscreen_toggle := pause_menu.get_node(
		"CenterContainer/Panel/Margin/Root/SettingsPage/Fullscreen"
	) as CheckButton
	volume_slider.value = 0.35
	fullscreen_toggle.button_pressed = true
	await fixture.process_frames(2)
	var saved := SettingsModule.load_settings(SETTINGS_PATH)
	fixture.expect(
		is_equal_approx(float(saved["master_volume"]), 0.35)
		and bool(saved["fullscreen"]),
		"Pause settings apply and persist volume and fullscreen changes"
	)

	await press_cancel(main)
	fixture.expect(
		paused and menu_page.visible and not settings_page.visible,
		"Escape from Settings returns to the pause menu without resuming play"
	)
	await press_cancel(main)
	fixture.expect(
		not paused and not bool(pause_menu.get("visible")),
		"Escape from the pause menu resumes gameplay"
	)

	SettingsModule.apply(SettingsModule.defaults())
	SettingsModule.clear(SETTINGS_PATH)
	fixture.set_current_scene(null)
	main.queue_free()
	await fixture.process_frames(2)
	fixture.complete(false)
	await fixture.process_frames(2)
	fixture.complete()


func press_cancel(main: Node) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	main.get_viewport().push_input(event, true)
	await fixture.process_frames(1)
