extends Control


signal start_requested
signal continue_requested

const BACKGROUND_LAYER_SPEEDS := {
	"Background/Sky": Vector2(-6.0, 0.0),
	"Background/FarTree": Vector2(-14.0, 0.0),
	"Background/Fog": Vector2(-24.0, 0.0),
	"Background/NearTree": Vector2(-42.0, 0.0),
}

var background_offsets := {}

@onready var title_label: Label = $Label
@onready var menu: VBoxContainer = $VBoxContainer
@onready var start_button: Button = $VBoxContainer/Start
@onready var continue_button: Button = $VBoxContainer/Continue
@onready var quit_button: Button = $VBoxContainer/Quit


func _ready() -> void:
	fit_to_viewport()
	get_viewport().size_changed.connect(fit_to_viewport)

	for path in BACKGROUND_LAYER_SPEEDS:
		background_offsets[path] = Vector2.ZERO

	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	continue_button.disabled = true


func set_continue_available(available: bool) -> void:
	continue_button.visible = available
	continue_button.disabled = not available
	call_deferred("fit_to_viewport")


func fit_to_viewport() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport_size := get_viewport_rect().size

	var menu_size := menu.get_combined_minimum_size()
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	menu.size = menu_size
	menu.position = Vector2(
		(viewport_size.x - menu_size.x) * 0.5,
		viewport_size.y - menu_size.y - 24.0
	)

	var title_size := title_label.get_combined_minimum_size()
	title_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	title_label.size = Vector2(viewport_size.x, title_size.y)
	title_label.position = Vector2(
		0.0,
		maxf(24.0, menu.position.y - title_size.y - 32.0)
	)


func _process(delta: float) -> void:
	for path in BACKGROUND_LAYER_SPEEDS:
		var layer := get_node_or_null(NodePath(path)) as Parallax2D
		if layer == null:
			continue

		var offset: Vector2 = background_offsets[path]
		offset += BACKGROUND_LAYER_SPEEDS[path] * delta
		background_offsets[path] = offset
		layer.set("scroll_offset", offset)


func _on_start_pressed() -> void:
	start_requested.emit()


func _on_continue_pressed() -> void:
	if not continue_button.disabled:
		continue_requested.emit()


func _on_quit_pressed() -> void:
	get_tree().quit()
