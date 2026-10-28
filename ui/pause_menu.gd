extends CanvasLayer


const SettingsModule := preload("res://settings/game_settings.gd")

signal resume_requested
signal retry_requested
signal title_requested
signal quit_requested

@export var settings_path := "user://settings.json"

@onready var menu_page: VBoxContainer = $CenterContainer/Panel/Margin/Root/MenuPage
@onready var settings_page: VBoxContainer = $CenterContainer/Panel/Margin/Root/SettingsPage
@onready var resume_button: Button = $CenterContainer/Panel/Margin/Root/MenuPage/Resume
@onready var retry_button: Button = $CenterContainer/Panel/Margin/Root/MenuPage/Retry
@onready var settings_button: Button = $CenterContainer/Panel/Margin/Root/MenuPage/Settings
@onready var title_button: Button = $CenterContainer/Panel/Margin/Root/MenuPage/Title
@onready var quit_button: Button = $CenterContainer/Panel/Margin/Root/MenuPage/Quit
@onready var settings_back_button: Button = (
	$CenterContainer/Panel/Margin/Root/SettingsPage/Back
)
@onready var master_volume_slider: HSlider = (
	$CenterContainer/Panel/Margin/Root/SettingsPage/MasterVolume
)
@onready var fullscreen_toggle: CheckButton = (
	$CenterContainer/Panel/Margin/Root/SettingsPage/Fullscreen
)

var settings: Dictionary = SettingsModule.defaults()
var _syncing_settings := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(close_pause)
	retry_button.pressed.connect(_on_retry_pressed)
	settings_button.pressed.connect(_show_settings_page)
	title_button.pressed.connect(_on_title_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_back_button.pressed.connect(_show_main_page)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	reload_settings()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		if settings_page.visible:
			_show_main_page()
		else:
			close_pause()
	elif _can_open_pause_menu():
		open_pause()
	else:
		return
	get_viewport().set_input_as_handled()


func open_pause() -> void:
	if visible or not _can_open_pause_menu():
		return
	visible = true
	_show_main_page()
	get_tree().paused = true
	resume_button.call_deferred("grab_focus")


func close_pause() -> void:
	if not visible:
		return
	visible = false
	settings_page.visible = false
	menu_page.visible = true
	get_tree().paused = false


func reload_settings() -> void:
	settings = SettingsModule.load_settings(settings_path)
	SettingsModule.apply(settings)
	_syncing_settings = true
	master_volume_slider.value = float(settings["master_volume"])
	fullscreen_toggle.button_pressed = bool(settings["fullscreen"])
	_syncing_settings = false


func _can_open_pause_menu() -> bool:
	var parent := get_parent()
	return (
		parent != null
		and parent.has_method("can_open_pause_menu")
		and bool(parent.call("can_open_pause_menu"))
	)


func _show_settings_page() -> void:
	menu_page.visible = false
	settings_page.visible = true
	master_volume_slider.call_deferred("grab_focus")


func _show_main_page() -> void:
	settings_page.visible = false
	menu_page.visible = true
	resume_button.call_deferred("grab_focus")


func _on_master_volume_changed(value: float) -> void:
	if _syncing_settings:
		return
	settings["master_volume"] = clampf(value, 0.0, 1.0)
	_apply_and_save_settings()


func _on_fullscreen_toggled(enabled: bool) -> void:
	if _syncing_settings:
		return
	settings["fullscreen"] = enabled
	_apply_and_save_settings()


func _apply_and_save_settings() -> void:
	SettingsModule.apply(settings)
	var save_error: Error = SettingsModule.save_settings(settings, settings_path)
	if save_error != OK:
		push_warning("Settings could not be saved: %s" % save_error)


func _on_retry_pressed() -> void:
	visible = false
	retry_requested.emit()


func _on_title_pressed() -> void:
	visible = false
	title_requested.emit()


func _on_quit_pressed() -> void:
	visible = false
	quit_requested.emit()
