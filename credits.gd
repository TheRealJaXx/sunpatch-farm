extends Control

const FADE_SECONDS := 0.8
const HOLD_SECONDS := 1.4
const NEXT_SCENE := "res://menu.tscn"
const LOGO_WIDTH := 1100.0

var _done := false
var _logo: TextureRect
var _presents: Label

func _ready() -> void:
    var bg := ColorRect.new()
    bg.color = Color.BLACK
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    var box := VBoxContainer.new()
    box.set_anchors_preset(Control.PRESET_FULL_RECT)
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 24)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(box)

    var tex: Texture2D = load("res://gdg em.png")
    if tex == null:
        push_error("Logo failed to load, skipping credits")
        _go_next.call_deferred()
        return

    _logo = TextureRect.new()
    _logo.texture = tex
    _logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _logo.custom_minimum_size = Vector2(LOGO_WIDTH, LOGO_WIDTH * tex.get_height() / tex.get_width())
    _logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _logo.modulate.a = 0.0
    box.add_child(_logo)

    _presents = Label.new()
    _presents.text = "presents"
    _presents.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _presents.add_theme_font_size_override("font_size", 40)
    _presents.add_theme_color_override("font_color", Color.WHITE)
    _presents.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _presents.modulate.a = 0.0
    box.add_child(_presents)

    var tween := create_tween()
    tween.tween_property(_logo, "modulate:a", 1.0, FADE_SECONDS)
    tween.tween_property(_presents, "modulate:a", 1.0, FADE_SECONDS)
    tween.tween_interval(HOLD_SECONDS)
    tween.tween_callback(_go_next)

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        _go_next()

func _go_next() -> void:
    if _done:
        return
    _done = true
    get_tree().change_scene_to_file(NEXT_SCENE)