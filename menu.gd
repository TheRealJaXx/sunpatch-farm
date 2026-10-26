extends Control

const SAVE_PATH := "user://sunpatch_save.cfg"
const ROUND_COUNT := 5
const FARM_SCENE := "res://farm.tscn"

var _muted := false
var _best_total := 0
var _best_money := 0
var _sound_btn: Button
var _reset_btn: Button
var _stats: Label
var _reset_armed := false


func _ready() -> void:
    _load()

    var bg := ColorRect.new()
    bg.color = Color(0.10, 0.22, 0.12)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    center.add_child(box)

    var title := Label.new()
    title.text = "Sunpatch Farm"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 72)
    title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
    title.add_theme_color_override("font_outline_color", Color.BLACK)
    title.add_theme_constant_override("outline_size", 10)
    box.add_child(title)

    _stats = Label.new()
    _stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _stats.add_theme_font_size_override("font_size", 26)
    box.add_child(_stats)

    var play := _make_button("Play")
    play.pressed.connect(_on_play)
    box.add_child(play)

    _sound_btn = _make_button("")
    _sound_btn.pressed.connect(_on_sound)
    box.add_child(_sound_btn)

    _reset_btn = _make_button("Reset saved progress")
    _reset_btn.pressed.connect(_on_reset)
    box.add_child(_reset_btn)

    var ver := Label.new()
    ver.text = "Build 11"
    ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ver.add_theme_font_size_override("font_size", 18)
    box.add_child(ver)

    _refresh()


func _make_button(text: String) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(460, 68)
    b.add_theme_font_size_override("font_size", 30)
    b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    return b


func _refresh() -> void:
    _sound_btn.text = "Sound: Off" if _muted else "Sound: On"
    _stats.text = "Best stars: %d of %d     Best money: $%d" % [_best_total, ROUND_COUNT * 3, _best_money]
    _reset_btn.text = "Tap again to confirm reset" if _reset_armed else "Reset saved progress"


func _load() -> void:
    var cf := ConfigFile.new()
    if cf.load(SAVE_PATH) != OK:
        return
    _best_total = 0
    for i in ROUND_COUNT:
        _best_total += int(cf.get_value("best", "round%d" % i, 0))
    _best_money = int(cf.get_value("best", "money", 0))
    _muted = bool(cf.get_value("settings", "muted", false))


func _save_all(reset: bool) -> void:
    var cf := ConfigFile.new()
    if not reset:
        cf.load(SAVE_PATH)
    cf.set_value("settings", "muted", _muted)
    cf.save(SAVE_PATH)


func _on_play() -> void:
    get_tree().change_scene_to_file(FARM_SCENE)


func _on_sound() -> void:
    _muted = not _muted
    _save_all(false)
    _refresh()


func _on_reset() -> void:
    if not _reset_armed:
        _reset_armed = true
        _refresh()
        return
    _reset_armed = false
    _best_total = 0
    _best_money = 0
    _save_all(true)
    _refresh()