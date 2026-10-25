extends Control

const BUILD_NUMBER := 1

var taps := 0
var label: Label

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.43, 0.75, 0.35)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 48)
	add_child(label)
	_refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		taps += 1
		_refresh()

func _refresh() -> void:
	label.text = "Sunpatch Farm\nBuild %d\nTaps: %d" % [BUILD_NUMBER, taps]