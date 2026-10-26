extends Node2D

const BUILD_NUMBER := 11

# ---- Tunable gameplay values (seconds) ----
const PLANT_TIME := 1.0
const HARVEST_TIME := 1.0
const COLLECT_TIME := 1.0
const DELIVER_TIME := 1.0
const EGG_CAP := 4
const MAIN_TIME := 90.0
const GRACE_TIME := 15.0
const DRAG_THRESHOLD := 14.0

# ---- Crops: 0 = tomato, 1 = corn. Grow time per fertilizer level ----
const CROP_TOMATO := 0
const CROP_CORN := 1
const CROP_GROW: Array = [[8.0, 6.0, 4.0], [12.0, 9.0, 6.0]]
const CORN_FROM_ROUND := 2

# ---- Upgrades: index = level (0 = base) ----
const UP_NAMES: Array[String] = ["Hens", "Fertilizer", "Boots"]
const UP_COSTS: Array = [[100, 200], [120, 240], [80, 160]]
const EGG_TIMES: Array[float] = [12.0, 9.0, 6.0]
const SPEEDS: Array[float] = [280.0, 350.0, 420.0]

# ---- Stars and saving ----
const STAR3_TIME_LEFT := 25.0
const STAR_BONUS := 10
const SAVE_PATH := "user://sunpatch_save.cfg"

# ---- Job queue size and power-up ----
const QUEUE_MAX_BASE := 4
const QUEUE_MAX_BOOSTED := 8
const POWERUP_TIME := 25.0

# ---- Money, shop and soil blocks ----
const START_MONEY := 0
const RUSH_FEE := 0.25
const PLOT_PRICES: Array[int] = [200, 350, 500, 700, 900]
const NEW_PLOT_CELLS: Array[Vector2i] = [Vector2i(2, 5), Vector2i(2, 7), Vector2i(2, 9), Vector2i(4, 3), Vector2i(4, 11)]

# ---- Rounds: one list per round, one entry per order ----
const ROUND_COUNT := 5
const ROUND_TOMATOES: Array = [[2, 3, 3], [3, 3, 4], [3, 3, 3], [3, 3, 4], [3, 4, 4]]
const ROUND_CORN: Array = [[0, 0, 0], [0, 0, 0], [1, 2, 2], [2, 2, 3], [2, 3, 3]]
const ROUND_EGGS: Array = [[1, 2, 2], [2, 2, 2], [2, 2, 3], [2, 3, 3], [2, 3, 3]]
const ROUND_REWARD: Array = [[20, 30, 40], [30, 40, 50], [40, 50, 60], [50, 60, 70], [60, 70, 90]]

# ---- Audio ----
const MIX_RATE := 22050

# ---- Map ----
const GRID_W := 14
const GRID_H := 14
const TILE_W := 128.0
const TILE_H := 64.0
const COLOR_A := Color(0.45, 0.75, 0.36)
const COLOR_B := Color(0.40, 0.69, 0.32)
const COLOR_EDGE := Color(0.25, 0.50, 0.22)
const COLOR_FENCE := Color(0.40, 0.26, 0.14)
const MAP_BOUNDS := Rect2(-896.0, -32.0, 1792.0, 896.0)

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const TREE_CELLS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 12), Vector2i(12, 6), Vector2i(8, 11), Vector2i(6, 2)]
const PLOT_CELLS: Array[Vector2i] = [Vector2i(4, 5), Vector2i(4, 7), Vector2i(4, 9)]
const COOP_CELL := Vector2i(10, 3)
const DELIVERY_CELL := Vector2i(11, 10)
const START_CELL := Vector2i(7, 7)

const PLOT_EMPTY := 0
const PLOT_GROWING := 1
const PLOT_READY := 2

const STATE_PLAYING := 0
const STATE_WON := 1
const STATE_LOST := 2
const STATE_SHOP := 3

class Plot:
    var cell: Vector2i = Vector2i.ZERO
    var state: int = 0
    var crop: int = 0
    var grow_left: float = 0.0

class Order:
    var kind: String = "move"
    var plot: Plot = null
    var cell: Vector2i = Vector2i.ZERO

var _camera: Camera2D
var _entities: Node2D
var _astar: AStarGrid2D
var _plots: Array[Plot] = []
var _blocked: Array[Vector2i] = []

var _pos := Vector2.ZERO
var _path: Array[Vector2i] = []
var _order: Order = null
var _queue: Array[Order] = []
var _boost_left := 0.0

var _act_kind := ""
var _act_left := 0.0
var _act_total := 1.0
var _act_plot: Plot = null

var _tomatoes := 0
var _corn := 0
var _eggs := 0
var _eggs_ready := 0
var _egg_timer := 0.0
var _money := START_MONEY
var _sel_crop := CROP_TOMATO

var _round := 0
var _owned_extra := 0
var _lv: Array[int] = [0, 0, 0]
var _snap_money := 0
var _snap_extra := 0
var _snap_lv: Array[int] = [0, 0, 0]

var _run_stars: Array[int] = [0, 0, 0, 0, 0]
var _best_stars: Array[int] = [0, 0, 0, 0, 0]
var _best_money := 0
var _round_summary := ""
var _muted := false

var _wave := 0
var _del_t := 0
var _del_c := 0
var _del_e := 0
var _time_left := MAIN_TIME
var _in_grace := false
var _game_state := STATE_PLAYING
var _paused := false
var _last_tick_sec := -1

var _anim := 0.0
var _pops: Array = []
var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _player_idx := 0

var _flash_cell := Vector2i.ZERO
var _flash_left := 0.0
var _toast_left := 0.0

var _toast_label: Label
var _inv_label: Label
var _timer_label: Label
var _order_label: Label
var _boost_label: Label
var _pause_btn: Button
var _crop_btn: Button
var _queue_box: VBoxContainer
var _queue_sig := ""
var _overlay: Control
var _ov_title: Label
var _ov_info: Label
var _ov_buttons: Array[Button] = []
var _ov_mode := ""

var _press_active := false
var _press_pos := Vector2.ZERO
var _dragging := false


func grid_to_world(cell: Vector2i) -> Vector2:
    return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)


func _world_to_cell(w: Vector2) -> Vector2i:
    var u := (w.x / (TILE_W * 0.5) + w.y / (TILE_H * 0.5)) * 0.5
    var v := (w.y / (TILE_H * 0.5) - w.x / (TILE_W * 0.5)) * 0.5
    return Vector2i(roundi(u), roundi(v))


func _in_grid(c: Vector2i) -> bool:
    return c.x >= 0 and c.y >= 0 and c.x < GRID_W and c.y < GRID_H


func _queue_max() -> int:
    return QUEUE_MAX_BOOSTED if _boost_left > 0.0 else QUEUE_MAX_BASE


# ---- Upgrade-driven values ----

func _egg_time() -> float:
    return EGG_TIMES[_lv[0]]


func _grow_time(crop: int) -> float:
    return float(CROP_GROW[crop][_lv[1]])


func _speed() -> float:
    return SPEEDS[_lv[2]]


func _upgrade_cost(u: int) -> int:
    var lvl: int = _lv[u]
    if lvl >= 2:
        return -1
    return int(UP_COSTS[u][lvl])


func _upgrade_label(u: int) -> String:
    var cost := _upgrade_cost(u)
    if cost < 0:
        return "%s: MAX" % UP_NAMES[u]
    var next_lv: int = _lv[u] + 1
    if u == 0:
        return "Hens: egg every %ds - $%d" % [int(EGG_TIMES[next_lv]), cost]
    if u == 1:
        return "Fertilizer: tomato %ds, corn %ds - $%d" % [
            int(CROP_GROW[0][next_lv]), int(CROP_GROW[1][next_lv]), cost]
    return "Boots: walk +%d%% - $%d" % [roundi((SPEEDS[next_lv] / SPEEDS[0] - 1.0) * 100.0), cost]


func _buy_upgrade(u: int) -> void:
    var cost := _upgrade_cost(u)
    if cost < 0 or _money < cost:
        return
    _money -= cost
    _lv[u] += 1
    _sfx("buy")
    _show_shop()


# ---- Round data helpers ----

func _wave_count() -> int:
    return int(ROUND_TOMATOES[_round].size())


func _need_t(i: int) -> int:
    return int(ROUND_TOMATOES[_round][i])


func _need_c(i: int) -> int:
    return int(ROUND_CORN[_round][i])


func _need_e(i: int) -> int:
    return int(ROUND_EGGS[_round][i])


func _reward(i: int) -> int:
    return int(ROUND_REWARD[_round][i])


func _corn_unlocked() -> bool:
    return _round >= CORN_FROM_ROUND


# ---- Soil block helpers ----

func _next_slot_exists() -> bool:
    return _owned_extra < NEW_PLOT_CELLS.size()


func _price(rush: bool) -> int:
    var base: int = PLOT_PRICES[_owned_extra]
    if rush:
        return roundi(base * (1.0 + RUSH_FEE))
    return base


# ---- Save / stars ----

func _load_game() -> void:
    var cf := ConfigFile.new()
    if cf.load(SAVE_PATH) != OK:
        return
    for i in ROUND_COUNT:
        _best_stars[i] = int(cf.get_value("best", "round%d" % i, 0))
    _best_money = int(cf.get_value("best", "money", 0))
    _muted = bool(cf.get_value("settings", "muted", false))


func _save_game() -> void:
    var cf := ConfigFile.new()
    for i in ROUND_COUNT:
        cf.set_value("best", "round%d" % i, _best_stars[i])
    cf.set_value("best", "money", _best_money)
    cf.set_value("settings", "muted", _muted)
    cf.save(SAVE_PATH)


func _best_total() -> int:
    var total := 0
    for s in _best_stars:
        total += s
    return total


func _calc_stars() -> int:
    if _in_grace:
        return 1
    if _time_left >= STAR3_TIME_LEFT:
        return 3
    return 2


func _stars_text(n: int) -> String:
    return "[" + "*".repeat(n) + "-".repeat(3 - n) + "]"


# ---- Audio ----

func _make_stream(notes: Array, vol: float) -> AudioStreamWAV:
    var samples := PackedFloat32Array()
    for n in notes:
        var f0: float = n[0]
        var f1: float = n[1]
        var dur: float = n[2]
        var count := int(dur * MIX_RATE)
        var phase := 0.0
        for i in count:
            var t := float(i) / float(count)
            var f := lerpf(f0, f1, t)
            phase += TAU * f / float(MIX_RATE)
            var env := minf(1.0, minf(t * 12.0, (1.0 - t) * 8.0))
            samples.append(sin(phase) * env * vol)
    var data := PackedByteArray()
    data.resize(samples.size() * 2)
    for i in samples.size():
        data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
    var s := AudioStreamWAV.new()
    s.format = AudioStreamWAV.FORMAT_16_BITS
    s.mix_rate = MIX_RATE
    s.stereo = false
    s.data = data
    return s


func _init_audio() -> void:
    _sounds["plant"] = _make_stream([[330.0, 260.0, 0.08]], 0.35)
    _sounds["harvest"] = _make_stream([[520.0, 700.0, 0.10]], 0.35)
    _sounds["collect"] = _make_stream([[700.0, 900.0, 0.07], [900.0, 700.0, 0.07]], 0.30)
    _sounds["deliver"] = _make_stream([[440.0, 440.0, 0.08], [660.0, 660.0, 0.12]], 0.35)
    _sounds["coin"] = _make_stream([[880.0, 880.0, 0.07], [1320.0, 1320.0, 0.18]], 0.30)
    _sounds["buy"] = _make_stream([[1100.0, 1100.0, 0.06], [740.0, 740.0, 0.06], [980.0, 980.0, 0.12]], 0.30)
    _sounds["win"] = _make_stream([[523.0, 523.0, 0.14], [659.0, 659.0, 0.14], [784.0, 784.0, 0.14], [1047.0, 1047.0, 0.35]], 0.35)
    _sounds["lose"] = _make_stream([[392.0, 330.0, 0.25], [330.0, 262.0, 0.25], [262.0, 196.0, 0.45]], 0.35)
    _sounds["tick"] = _make_stream([[1000.0, 1000.0, 0.04]], 0.20)
    _sounds["click"] = _make_stream([[600.0, 500.0, 0.04]], 0.25)
    _sounds["error"] = _make_stream([[200.0, 160.0, 0.12]], 0.30)
    for i in 4:
        var p := AudioStreamPlayer.new()
        add_child(p)
        _players.append(p)


func _sfx(sound_name: String) -> void:
    if _muted or not _sounds.has(sound_name) or _players.is_empty():
        return
    var p: AudioStreamPlayer = _players[_player_idx]
    _player_idx = (_player_idx + 1) % _players.size()
    p.stream = _sounds[sound_name]
    p.play()


func _sound_label() -> String:
    return "Sound: Off" if _muted else "Sound: On"


func _ready() -> void:
    _load_game()
    _init_audio()
    _build_map_data()

    _entities = Node2D.new()
    add_child(_entities)
    _entities.draw.connect(_draw_entities)

    _camera = Camera2D.new()
    _camera.position = MAP_BOUNDS.get_center()
    add_child(_camera)
    _camera.make_current()

    _build_hud()
    _clamp_camera()
    queue_redraw()
    _start_round()


func _build_map_data() -> void:
    _blocked.clear()
    _plots.clear()
    for tree_cell in TREE_CELLS:
        _blocked.append(tree_cell)
    for plot_cell in PLOT_CELLS:
        var p := Plot.new()
        p.cell = plot_cell
        _plots.append(p)
        _blocked.append(plot_cell)
    for i in _owned_extra:
        var ep := Plot.new()
        ep.cell = NEW_PLOT_CELLS[i]
        _plots.append(ep)
        _blocked.append(NEW_PLOT_CELLS[i])
    _blocked.append(COOP_CELL)
    _blocked.append(DELIVERY_CELL)

    _astar = AStarGrid2D.new()
    _astar.region = Rect2i(0, 0, GRID_W, GRID_H)
    _astar.cell_size = Vector2(1, 1)
    _astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    _astar.update()
    for blocked_cell in _blocked:
        _astar.set_point_solid(blocked_cell, true)


# ---------------- Rounds ----------------

func _start_round() -> void:
    _game_state = STATE_PLAYING
    _paused = false
    _wave = 0
    _del_t = 0
    _del_c = 0
    _del_e = 0
    _tomatoes = 0
    _corn = 0
    _eggs = 0
    _eggs_ready = 0
    _egg_timer = 0.0
    _time_left = MAIN_TIME
    _in_grace = false
    _last_tick_sec = -1
    _boost_left = 0.0
    _sel_crop = CROP_TOMATO
    _crop_btn.text = "Plant: Tomato"
    _timer_label.remove_theme_color_override("font_color")
    _queue.clear()
    _pops.clear()
    _cancel_action()
    _pos = grid_to_world(START_CELL)
    for p in _plots:
        p.state = PLOT_EMPTY
        p.crop = CROP_TOMATO
        p.grow_left = 0.0
    _snap_money = _money
    _snap_extra = _owned_extra
    for i in 3:
        _snap_lv[i] = _lv[i]
    _overlay.visible = false
    _pause_btn.visible = true
    _queue_sig = ""
    if _round == 0 and _best_total() == 0:
        _toast("Tap a brown plot to plant, tap it again when ripe. Coop = eggs. Crate = deliver.", 5.0)
    elif _round == CORN_FROM_ROUND:
        _toast("Customers now want CORN! Use the Plant button to switch crops.", 5.0)
    else:
        _toast("Round %d - finish with %ds+ left for 3 stars!" % [_round + 1, int(STAR3_TIME_LEFT)])


func _restart_round() -> void:
    _money = _snap_money
    _owned_extra = _snap_extra
    for i in 3:
        _lv[i] = _snap_lv[i]
    _build_map_data()
    _start_round()


func _start_next_round() -> void:
    _round += 1
    _start_round()


func _end_round() -> void:
    _queue.clear()
    _cancel_action()
    var stars := _calc_stars()
    var bonus := stars * STAR_BONUS
    _money += bonus
    _run_stars[_round] = stars
    if stars > _best_stars[_round]:
        _best_stars[_round] = stars
    _round_summary = "Stars: %s  (+$%d bonus)   Best: %s" % [
        _stars_text(stars), bonus, _stars_text(_best_stars[_round])]

    if _round >= ROUND_COUNT - 1:
        if _money > _best_money:
            _best_money = _money
        _save_game()
        var total := 0
        for s in _run_stars:
            total += s
        _game_state = STATE_WON
        _sfx("win")
        var labels: Array[String] = ["Play again", "Main menu"]
        _show_overlay("win", "YOU WIN!",
            "%s\nAll %d rounds complete!\nTotal stars: %d of %d\nMoney: $%d     Best money: $%d" % [
                _round_summary, ROUND_COUNT, total, ROUND_COUNT * 3, _money, _best_money],
            labels)
    else:
        _save_game()
        _game_state = STATE_SHOP
        _sfx("coin")
        _show_shop()


# ---------------- HUD ----------------

func _make_label(font_size: int) -> Label:
    var l := Label.new()
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_outline_color", Color.BLACK)
    l.add_theme_constant_override("outline_size", 6)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l


func _make_button(text: String, w: float, h: float = 64.0) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(w, h)
    b.add_theme_font_size_override("font_size", 30)
    return b


func _build_hud() -> void:
    var hud := CanvasLayer.new()
    add_child(hud)

    var title := _make_label(20)
    title.text = "Sunpatch Farm - Build %d\nTap to queue jobs\nDrag to scroll" % BUILD_NUMBER
    hud.add_child(title)
    title.position = Vector2(16, 12)

    _boost_label = _make_label(24)
    _boost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
    _boost_label.visible = false
    hud.add_child(_boost_label)
    _boost_label.position = Vector2(16, 100)

    _inv_label = _make_label(28)
    _inv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    hud.add_child(_inv_label)
    _inv_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _inv_label.offset_top = 12.0
    _inv_label.offset_right = -16.0

    _timer_label = _make_label(52)
    _timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hud.add_child(_timer_label)
    _timer_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _timer_label.offset_top = 4.0

    _order_label = _make_label(26)
    _order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hud.add_child(_order_label)
    _order_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _order_label.offset_top = 66.0

    _queue_box = VBoxContainer.new()
    _queue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _queue_box.visible = false
    hud.add_child(_queue_box)
    _queue_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    _queue_box.offset_left = -360.0
    _queue_box.offset_right = -16.0
    _queue_box.offset_top = 128.0

    _toast_label = _make_label(30)
    _toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hud.add_child(_toast_label)
    _toast_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _toast_label.offset_left = 180.0
    _toast_label.offset_right = -180.0
    _toast_label.offset_top = -100.0
    _toast_label.offset_bottom = -16.0
    _toast_label.modulate.a = 0.0

    _pause_btn = _make_button("Pause", 140.0)
    hud.add_child(_pause_btn)
    _pause_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    _pause_btn.offset_left = 16.0
    _pause_btn.offset_top = -80.0
    _pause_btn.offset_right = 156.0
    _pause_btn.offset_bottom = -16.0
    _pause_btn.pressed.connect(_on_pause_pressed)

    _crop_btn = _make_button("Plant: Tomato", 240.0)
    hud.add_child(_crop_btn)
    _crop_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    _crop_btn.offset_left = -256.0
    _crop_btn.offset_top = -80.0
    _crop_btn.offset_right = -16.0
    _crop_btn.offset_bottom = -16.0
    _crop_btn.visible = false
    _crop_btn.pressed.connect(_on_crop_pressed)

    _build_overlay(hud)
    _update_hud()


func _build_overlay(hud: CanvasLayer) -> void:
    _overlay = Control.new()
    hud.add_child(_overlay)
    _overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _overlay.visible = false

    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.78)
    _overlay.add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var center := CenterContainer.new()
    _overlay.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    center.add_child(box)

    _ov_title = _make_label(52)
    _ov_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(_ov_title)

    _ov_info = _make_label(26)
    _ov_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(_ov_info)

    for i in 5:
        var b := _make_button("", 600.0, 54.0)
        b.add_theme_font_size_override("font_size", 26)
        b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        b.pressed.connect(_on_ov_button.bind(i))
        box.add_child(b)
        _ov_buttons.append(b)


func _show_overlay(mode: String, title: String, info: String, labels: Array[String]) -> void:
    _ov_mode = mode
    _ov_title.text = title
    _ov_info.text = info
    for i in 5:
        var b := _ov_buttons[i]
        if i < labels.size() and labels[i] != "":
            b.text = labels[i]
            b.disabled = false
            b.visible = true
        else:
            b.visible = false
    _overlay.visible = true
    _pause_btn.visible = false


func _close_overlay() -> void:
    _paused = false
    _overlay.visible = false
    _pause_btn.visible = true


func _go_menu() -> void:
    get_tree().change_scene_to_file("res://menu.tscn")


func _on_ov_button(i: int) -> void:
    _sfx("click")
    match _ov_mode:
        "pause":
            if i == 0:
                _close_overlay()
            elif i == 1:
                _restart_round()
            elif i == 2:
                _muted = not _muted
                _ov_buttons[2].text = _sound_label()
                _save_game()
            elif i == 3:
                _go_menu()
        "confirm":
            if i == 0:
                _do_buy(true)
            else:
                _close_overlay()
        "shop":
            if i == 0:
                _do_buy(false)
            elif i >= 1 and i <= 3:
                _buy_upgrade(i - 1)
            elif i == 4:
                _start_next_round()
        "win":
            if i == 0:
                get_tree().reload_current_scene()
            else:
                _go_menu()
        "lose":
            if i == 0:
                _restart_round()
            elif i == 1:
                get_tree().reload_current_scene()
            else:
                _go_menu()


func _on_pause_pressed() -> void:
    if _game_state != STATE_PLAYING or _paused:
        return
    _sfx("click")
    _paused = true
    var labels: Array[String] = ["Resume", "Restart round", _sound_label(), "Main menu"]
    _show_overlay("pause", "PAUSED", "The game clock is stopped.", labels)


func _on_crop_pressed() -> void:
    if _paused or _game_state != STATE_PLAYING:
        return
    _sel_crop = CROP_CORN if _sel_crop == CROP_TOMATO else CROP_TOMATO
    _crop_btn.text = "Plant: Tomato" if _sel_crop == CROP_TOMATO else "Plant: Corn"
    _sfx("click")


func _show_shop() -> void:
    var labels: Array[String] = []
    if _next_slot_exists():
        labels.append("Soil block - $%d" % _price(false))
    else:
        labels.append("Soil blocks: all bought")
    labels.append(_upgrade_label(0))
    labels.append(_upgrade_label(1))
    labels.append(_upgrade_label(2))
    labels.append("Start round %d" % (_round + 2))
    var info := "%s\nMoney: $%d     Soil blocks: %d of %d" % [
        _round_summary, _money, _owned_extra, NEW_PLOT_CELLS.size()]
    _show_overlay("shop", "ROUND %d COMPLETE" % (_round + 1), info, labels)
    _ov_buttons[0].disabled = not (_next_slot_exists() and _money >= _price(false))
    for u in 3:
        var cost := _upgrade_cost(u)
        _ov_buttons[u + 1].disabled = cost < 0 or _money < cost


func _open_buy_confirm() -> void:
    var cost := _price(true)
    _paused = true
    var labels: Array[String] = ["Buy for $%d" % cost, "Cancel"]
    _show_overlay("confirm", "Buy soil block?",
        "Cost: $%d (includes %d%% rush fee)\nYou have: $%d" % [cost, roundi(RUSH_FEE * 100.0), _money],
        labels)
    _ov_buttons[0].disabled = _money < cost


func _do_buy(rush: bool) -> void:
    if not _next_slot_exists():
        return
    var cost := _price(rush)
    if _money < cost:
        return
    var cell := NEW_PLOT_CELLS[_owned_extra]
    if rush and _world_to_cell(_pos) == cell:
        _toast("Move the farmer off that spot first")
        _close_overlay()
        return

    _money -= cost
    _owned_extra += 1
    _sfx("buy")
    var p := Plot.new()
    p.cell = cell
    _plots.append(p)
    _blocked.append(cell)
    _astar.set_point_solid(cell, true)

    if rush:
        _toast("Soil block bought for $%d" % cost)
        _close_overlay()
        var o := _order
        if o != null and _act_kind == "":
            if not _start_order(o):
                _cancel_action()
                _after_action()
    else:
        _show_shop()


func _update_hud() -> void:
    var inv := "Tomatoes: %d" % _tomatoes
    if _corn_unlocked():
        inv += "     Corn: %d" % _corn
    inv += "     Eggs: %d\nMoney: $%d" % [_eggs, _money]
    _inv_label.text = inv

    if _in_grace:
        _timer_label.text = "GRACE  %d" % ceili(_time_left)
    else:
        _timer_label.text = "%d" % ceili(_time_left)

    var w := mini(_wave, _wave_count() - 1)
    var line := ""
    if _need_t(w) > 0:
        line += "Tomatoes %d/%d" % [_del_t, _need_t(w)]
    if _need_c(w) > 0:
        line += ("    " if line != "" else "") + "Corn %d/%d" % [_del_c, _need_c(w)]
    if _need_e(w) > 0:
        line += ("    " if line != "" else "") + "Eggs %d/%d" % [_del_e, _need_e(w)]
    var txt := "Round %d of %d - Order %d of %d\n%s    Reward $%d" % [
        _round + 1, ROUND_COUNT, w + 1, _wave_count(), line, _reward(w)]
    if _del_t == 0 and _del_c == 0 and _del_e == 0:
        txt += "\nDeliver it all in one trip for a queue boost!"
    _order_label.text = txt

    if _boost_left > 0.0:
        _boost_label.visible = true
        _boost_label.text = "QUEUE BOOST: %d jobs - %d s" % [QUEUE_MAX_BOOSTED, ceili(_boost_left)]
    else:
        _boost_label.visible = false

    _crop_btn.visible = _corn_unlocked() and _game_state == STATE_PLAYING and not _paused


func _toast(text: String, secs: float = 2.5) -> void:
    _toast_label.text = text
    _toast_label.modulate.a = 1.0
    _toast_left = secs


func _flash(cell: Vector2i) -> void:
    _flash_cell = cell
    _flash_left = 0.6


func _pop(text: String, world_pos: Vector2, color: Color) -> void:
    _pops.append({"t": text, "p": world_pos, "a": 0.0, "c": color})


# ---------------- Job queue UI ----------------

func _order_text(o: Order) -> String:
    match o.kind:
        "plot":
            return "Tend plot"
        "coop":
            return "Collect eggs"
        "delivery":
            return "Deliver"
    return "Go to tile"


func _current_text() -> String:
    if _act_kind != "":
        match _act_kind:
            "plant":
                return "Now: Planting"
            "harvest":
                return "Now: Harvesting"
            "collect":
                return "Now: Collecting eggs"
            "deliver":
                return "Now: Delivering"
        return "Now: Working"
    if _order != null:
        return "Now: " + _order_text(_order)
    return ""


func _add_queue_row(text: String, on_press: Callable) -> void:
    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var l := _make_label(22)
    l.text = text
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(l)
    var b := Button.new()
    b.text = "X"
    b.custom_minimum_size = Vector2(52, 44)
    b.add_theme_font_size_override("font_size", 22)
    b.pressed.connect(on_press)
    row.add_child(b)
    _queue_box.add_child(row)


func _refresh_queue_ui() -> void:
    var cur := _current_text()
    var sig := "%s|%d" % [cur, _queue_max()]
    for q in _queue:
        sig += "|" + _order_text(q)
    if sig == _queue_sig:
        return
    _queue_sig = sig

    for ch in _queue_box.get_children():
        _queue_box.remove_child(ch)
        ch.queue_free()

    _queue_box.visible = cur != "" or not _queue.is_empty()
    if not _queue_box.visible:
        return

    var header := _make_label(22)
    header.text = "Jobs - queued %d of %d" % [_queue.size(), _queue_max()]
    _queue_box.add_child(header)

    if cur != "":
        _add_queue_row(cur, _on_cancel_current_pressed)
    for i in _queue.size():
        _add_queue_row("%d. %s" % [i + 1, _order_text(_queue[i])], _on_remove_queued.bind(i))


func _on_cancel_current_pressed() -> void:
    if _paused or _game_state != STATE_PLAYING:
        return
    if not _is_busy():
        return
    _cancel_action()
    _toast("Job cancelled")
    _after_action()


func _on_remove_queued(i: int) -> void:
    if _paused or _game_state != STATE_PLAYING:
        return
    if i >= 0 and i < _queue.size():
        _queue.remove_at(i)


# ---------------- Game loop ----------------

func _process(delta: float) -> void:
    _anim += delta
    if _flash_left > 0.0:
        _flash_left -= delta
    if _toast_left > 0.0:
        _toast_left -= delta
        _toast_label.modulate.a = clampf(_toast_left / 0.5, 0.0, 1.0)
    for i in range(_pops.size() - 1, -1, -1):
        _pops[i]["a"] = float(_pops[i]["a"]) + delta
        if float(_pops[i]["a"]) > 1.2:
            _pops.remove_at(i)
    if not _paused and _game_state == STATE_PLAYING:
        _tick_world(delta)
    _update_hud()
    _refresh_queue_ui()
    _entities.queue_redraw()


func _tick_world(delta: float) -> void:
    _time_left -= delta
    if _time_left <= 0.0:
        if not _in_grace:
            _in_grace = true
            _time_left = GRACE_TIME
            _last_tick_sec = -1
            _timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
            _toast("Time's up! Grace period - finish your orders!")
        else:
            _time_left = 0.0
            _game_over()
            return

    var sec := ceili(_time_left)
    if sec != _last_tick_sec:
        _last_tick_sec = sec
        if _in_grace or sec <= 10:
            _sfx("tick")

    if _boost_left > 0.0:
        _boost_left -= delta
        if _boost_left <= 0.0:
            _boost_left = 0.0
            _toast("Queue boost ended")

    for p in _plots:
        if p.state == PLOT_GROWING:
            p.grow_left -= delta
            if p.grow_left <= 0.0:
                p.grow_left = 0.0
                p.state = PLOT_READY

    if _eggs_ready < EGG_CAP:
        _egg_timer += delta
        if _egg_timer >= _egg_time():
            _egg_timer = 0.0
            _eggs_ready += 1

    if _act_kind != "":
        _act_left -= delta
        if _act_left <= 0.0:
            _finish_action()
        return

    _move_farmer(delta)


func _game_over() -> void:
    _game_state = STATE_LOST
    _sfx("lose")
    var labels: Array[String] = ["Retry round", "New game", "Main menu"]
    _show_overlay("lose", "TIME'S UP",
        "Round %d - orders completed: %d of %d" % [_round + 1, _wave, _wave_count()],
        labels)


func _move_farmer(delta: float) -> void:
    if _path.is_empty():
        return
    var target := grid_to_world(_path[0])
    var step := _speed() * delta
    if _pos.distance_to(target) <= step:
        _pos = target
        _path.remove_at(0)
        if _path.is_empty():
            _arrive()
    else:
        _pos += (target - _pos).normalized() * step


func _is_busy() -> bool:
    return _order != null or _act_kind != ""


func _is_walking() -> bool:
    return not _path.is_empty() and _act_kind == "" and not _paused and _game_state == STATE_PLAYING


func _arrive() -> void:
    var o := _order
    _order = null
    if o == null or o.kind == "move":
        _after_action()
        return
    match o.kind:
        "plot":
            _begin_plot_action(o.plot)
        "coop":
            if _eggs_ready > 0:
                _start_action("collect", COLLECT_TIME, null)
            else:
                _toast("No eggs yet")
                _sfx("error")
                _after_action()
        "delivery":
            var give := _deliverable()
            if give.x + give.y + give.z > 0:
                _start_action("deliver", DELIVER_TIME, null)
            else:
                _toast("Nothing in your basket for this order")
                _sfx("error")
                _after_action()


func _deliverable() -> Vector3i:
    return Vector3i(
        mini(_tomatoes, _need_t(_wave) - _del_t),
        mini(_corn, _need_c(_wave) - _del_c),
        mini(_eggs, _need_e(_wave) - _del_e))


func _begin_plot_action(p: Plot) -> void:
    if p.state == PLOT_EMPTY:
        _start_action("plant", PLANT_TIME, p)
    elif p.state == PLOT_READY:
        _start_action("harvest", HARVEST_TIME, p)
    else:
        _toast("Still growing...")
        _sfx("error")
        _after_action()


func _start_action(kind: String, duration: float, p: Plot) -> void:
    _act_kind = kind
    _act_left = duration
    _act_total = duration
    _act_plot = p


func _cancel_action() -> void:
    _act_kind = ""
    _act_left = 0.0
    _act_plot = null
    _path.clear()
    _order = null


func _finish_action() -> void:
    var kind := _act_kind
    var p := _act_plot
    _act_kind = ""
    _act_left = 0.0
    _act_plot = null
    match kind:
        "plant":
            p.state = PLOT_GROWING
            p.crop = _sel_crop
            p.grow_left = _grow_time(p.crop)
            _sfx("plant")
        "harvest":
            p.state = PLOT_EMPTY
            if p.crop == CROP_CORN:
                _corn += 1
                _pop("+1 Corn", grid_to_world(p.cell) + Vector2(0, -50), Color(1.0, 0.9, 0.3))
                _toast("+1 Corn")
            else:
                _tomatoes += 1
                _pop("+1 Tomato", grid_to_world(p.cell) + Vector2(0, -50), Color(1.0, 0.45, 0.4))
                _toast("+1 Tomato")
            _sfx("harvest")
        "collect":
            _eggs += _eggs_ready
            _pop("+%d Eggs" % _eggs_ready, grid_to_world(COOP_CELL) + Vector2(0, -100), Color(1.0, 1.0, 0.9))
            _toast("+%d Eggs" % _eggs_ready)
            _eggs_ready = 0
            _sfx("collect")
        "deliver":
            var give := _deliverable()
            var fresh := _del_t == 0 and _del_c == 0 and _del_e == 0
            _tomatoes -= give.x
            _corn -= give.y
            _eggs -= give.z
            _del_t += give.x
            _del_c += give.y
            _del_e += give.z
            if _del_t >= _need_t(_wave) and _del_c >= _need_c(_wave) and _del_e >= _need_e(_wave):
                _complete_wave(fresh)
            else:
                _sfx("deliver")
                _toast("Delivered %d tomatoes, %d corn, %d eggs" % [give.x, give.y, give.z])
    _after_action()


func _complete_wave(perfect: bool) -> void:
    var reward := _reward(_wave)
    _money += reward
    _pop("+$%d" % reward, grid_to_world(DELIVERY_CELL) + Vector2(0, -70), Color(1.0, 0.85, 0.2))
    _wave += 1
    _del_t = 0
    _del_c = 0
    _del_e = 0
    if _wave >= _wave_count():
        _end_round()
    elif perfect:
        _boost_left = POWERUP_TIME
        _sfx("coin")
        _toast("Perfect delivery! +$%d - queue boosted to %d jobs for %d s" % [reward, QUEUE_MAX_BOOSTED, int(POWERUP_TIME)])
    else:
        _sfx("coin")
        _toast("Order complete! +$%d - next customer is here" % reward)


func _after_action() -> void:
    if _game_state != STATE_PLAYING:
        return
    while not _queue.is_empty():
        var q: Order = _queue[0]
        _queue.remove_at(0)
        if _start_order(q):
            return


# ---------------- Orders and pathfinding ----------------

func _order_for_cell(cell: Vector2i) -> Order:
    var o := Order.new()
    o.cell = cell
    if cell == COOP_CELL:
        o.kind = "coop"
        return o
    if cell == DELIVERY_CELL:
        o.kind = "delivery"
        return o
    for p in _plots:
        if p.cell == cell:
            o.kind = "plot"
            o.plot = p
            return o
    if _blocked.has(cell):
        return null
    return o


func _path_to_adjacent(target: Vector2i) -> Array[Vector2i]:
    var best: Array[Vector2i] = []
    var start := _world_to_cell(_pos)
    for d in DIRS:
        var n: Vector2i = target + d
        if not _in_grid(n) or _astar.is_point_solid(n):
            continue
        var p: Array[Vector2i] = _astar.get_id_path(start, n)
        if p.is_empty():
            continue
        if best.is_empty() or p.size() < best.size():
            best = p
    return best


func _start_order(order: Order) -> bool:
    var path: Array[Vector2i] = []
    if order.kind == "move":
        path = _astar.get_id_path(_world_to_cell(_pos), order.cell)
    else:
        path = _path_to_adjacent(order.cell)
    if path.is_empty():
        _flash(order.cell)
        _toast("Can't reach that spot")
        _sfx("error")
        return false
    _order = order
    _path = path
    return true


func _cell_at_world(w: Vector2) -> Vector2i:
    var cc := grid_to_world(COOP_CELL)
    if Rect2(cc.x - 46.0, cc.y - 90.0, 92.0, 104.0).has_point(w):
        return COOP_CELL
    var dc := grid_to_world(DELIVERY_CELL)
    if Rect2(dc.x - 34.0, dc.y - 60.0, 68.0, 80.0).has_point(w):
        return DELIVERY_CELL
    return _world_to_cell(w)


func _handle_tap(screen_pos: Vector2) -> void:
    if _paused or _game_state != STATE_PLAYING:
        return
    var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
    var cell := _cell_at_world(world)
    if not _in_grid(cell):
        return

    if _next_slot_exists() and cell == NEW_PLOT_CELLS[_owned_extra]:
        _open_buy_confirm()
        return

    var order := _order_for_cell(cell)
    if order == null:
        _flash(cell)
        _toast("Blocked")
        _sfx("error")
        return

    if _is_busy():
        if _queue.size() >= _queue_max():
            _toast("Queue full (%d jobs)" % _queue_max())
            _sfx("error")
            return
        _queue.append(order)
    else:
        _start_order(order)


# ---------------- Input ----------------

func _unhandled_input(event: InputEvent) -> void:
    if _paused or _game_state != STATE_PLAYING:
        return
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index != MOUSE_BUTTON_LEFT:
            return
        if mb.pressed:
            _press_active = true
            _press_pos = mb.position
            _dragging = false
        else:
            if _press_active and not _dragging:
                _handle_tap(mb.position)
            _press_active = false
            _dragging = false
    elif event is InputEventMouseMotion and _press_active:
        var mm := event as InputEventMouseMotion
        if not _dragging and mm.position.distance_to(_press_pos) > DRAG_THRESHOLD:
            _dragging = true
        if _dragging:
            _camera.position -= mm.relative / _camera.zoom
            _clamp_camera()


func _clamp_camera() -> void:
    var half := get_viewport_rect().size * 0.5 / _camera.zoom
    var min_p := MAP_BOUNDS.position + half
    var max_p := MAP_BOUNDS.end - half
    var c := MAP_BOUNDS.get_center()
    _camera.position.x = c.x if min_p.x > max_p.x else clampf(_camera.position.x, min_p.x, max_p.x)
    _camera.position.y = c.y if min_p.y > max_p.y else clampf(_camera.position.y, min_p.y, max_p.y)


# ---------------- Drawing ----------------

func _diamond_points(c: Vector2, s: float) -> PackedVector2Array:
    return PackedVector2Array([
        c + Vector2(0, -TILE_H * 0.5 * s),
        c + Vector2(TILE_W * 0.5 * s, 0),
        c + Vector2(0, TILE_H * 0.5 * s),
        c + Vector2(-TILE_W * 0.5 * s, 0),
    ])


func _draw() -> void:
    for y in GRID_H:
        for x in GRID_W:
            var c := grid_to_world(Vector2i(x, y))
            var pts := _diamond_points(c, 1.0)
            draw_colored_polygon(pts, COLOR_A if (x + y) % 2 == 0 else COLOR_B)
            pts.append(pts[0])
            draw_polyline(pts, COLOR_EDGE, 1.5)
            _draw_decor(x, y, c)

    var fence := PackedVector2Array([
        grid_to_world(Vector2i(0, 0)) + Vector2(0, -TILE_H * 0.5),
        grid_to_world(Vector2i(GRID_W - 1, 0)) + Vector2(TILE_W * 0.5, 0),
        grid_to_world(Vector2i(GRID_W - 1, GRID_H - 1)) + Vector2(0, TILE_H * 0.5),
        grid_to_world(Vector2i(0, GRID_H - 1)) + Vector2(-TILE_W * 0.5, 0),
    ])
    fence.append(fence[0])
    draw_polyline(fence, COLOR_FENCE, 8.0)


func _draw_decor(x: int, y: int, c: Vector2) -> void:
    var cell := Vector2i(x, y)
    if TREE_CELLS.has(cell) or PLOT_CELLS.has(cell) or NEW_PLOT_CELLS.has(cell):
        return
    if cell == COOP_CELL or cell == DELIVERY_CELL or cell == START_CELL:
        return
    var h: int = absi((x * 73 + y * 151 + x * y * 31) % 13)
    if h == 0:
        for k in 3:
            var off := Vector2(-14.0 + k * 14.0, -3.0 + (k % 2) * 7.0)
            var col := Color(1.0, 0.9, 0.3) if k != 1 else Color(1.0, 0.5, 0.7)
            draw_circle(c + off, 3.5, col)
    elif h == 1:
        for k in 3:
            var bx := c.x - 10.0 + k * 10.0
            draw_line(Vector2(bx, c.y + 5.0), Vector2(bx + (k - 1) * 3.0, c.y - 6.0), COLOR_EDGE, 2.0)


func _diamond_outline(cell: Vector2i, color: Color) -> void:
    var pts := _diamond_points(grid_to_world(cell), 0.9)
    pts.append(pts[0])
    _entities.draw_polyline(pts, color, 4.0)


func _hen_phase(i: int) -> float:
    return _anim * (0.6 + 0.13 * i) + i * 2.1


func _hen_pos(i: int) -> Vector2:
    var base := grid_to_world(COOP_CELL + Vector2i(-1, 1))
    var a := _hen_phase(i)
    return base + Vector2(sin(a) * (50.0 + 8.0 * i), cos(a * 1.3) * 22.0 + i * 6.0)


func _draw_entities() -> void:
    if _order != null:
        _diamond_outline(_order.cell, Color(1, 1, 1, 0.9))
    for q in _queue:
        _diamond_outline(q.cell, Color(1.0, 0.65, 0.1, 0.95))
    if _flash_left > 0.0:
        _diamond_outline(_flash_cell, Color(1.0, 0.2, 0.2, clampf(_flash_left * 2.0, 0.0, 1.0)))

    if _next_slot_exists() and _game_state == STATE_PLAYING:
        _draw_forsale()

    var items: Array = []
    for t in TREE_CELLS:
        items.append({"y": grid_to_world(t).y, "fn": _draw_tree.bind(t)})
    for p in _plots:
        items.append({"y": grid_to_world(p.cell).y, "fn": _draw_plot.bind(p)})
    items.append({"y": grid_to_world(COOP_CELL).y, "fn": _draw_coop})
    items.append({"y": grid_to_world(DELIVERY_CELL).y, "fn": _draw_delivery})
    for i in 2 + _lv[0]:
        items.append({"y": _hen_pos(i).y, "fn": _draw_hen.bind(i)})
    items.append({"y": _pos.y, "fn": _draw_farmer})
    items.sort_custom(func(a, b): return a["y"] < b["y"])
    for item in items:
        item["fn"].call()

    for i in _queue.size():
        var qc := grid_to_world(_queue[i].cell)
        _entities.draw_string(ThemeDB.fallback_font, qc + Vector2(-20, 10), str(i + 1),
            HORIZONTAL_ALIGNMENT_CENTER, 40.0, 30, Color.WHITE)

    for pop in _pops:
        var age: float = pop["a"]
        var col: Color = pop["c"]
        var at: Vector2 = pop["p"]
        col.a = clampf(1.0 - age / 1.2, 0.0, 1.0)
        at += Vector2(-100.0, -age * 40.0)
        _entities.draw_string(ThemeDB.fallback_font, at + Vector2(2, 2), pop["t"],
            HORIZONTAL_ALIGNMENT_CENTER, 200.0, 26, Color(0, 0, 0, col.a))
        _entities.draw_string(ThemeDB.fallback_font, at, pop["t"],
            HORIZONTAL_ALIGNMENT_CENTER, 200.0, 26, col)


func _draw_forsale() -> void:
    var c := grid_to_world(NEW_PLOT_CELLS[_owned_extra])
    _entities.draw_colored_polygon(_diamond_points(c, 0.92), Color(0.45, 0.30, 0.17, 0.35))
    var pts := _diamond_points(c, 0.92)
    pts.append(pts[0])
    _entities.draw_polyline(pts, Color(1.0, 0.85, 0.2), 3.0)
    _entities.draw_string(ThemeDB.fallback_font, c + Vector2(-60, 7), "SOIL $%d" % _price(true),
        HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20, Color(1.0, 0.95, 0.5))


func _draw_tree(cell: Vector2i) -> void:
    var c := grid_to_world(cell)
    _entities.draw_rect(Rect2(c.x - 7.0, c.y - 46.0, 14.0, 46.0), Color(0.42, 0.28, 0.16))
    _entities.draw_circle(c + Vector2(0, -64), 34.0, Color(0.14, 0.45, 0.20))
    _entities.draw_circle(c + Vector2(-14, -52), 22.0, Color(0.18, 0.52, 0.24))


func _draw_plot(p: Plot) -> void:
    var c := grid_to_world(p.cell)
    _entities.draw_colored_polygon(_diamond_points(c, 0.92), Color(0.45, 0.30, 0.17))
    if p.state == PLOT_GROWING:
        var t := 1.0 - p.grow_left / _grow_time(p.crop)
        var h := lerpf(6.0, 26.0, t)
        _entities.draw_line(c + Vector2(0, 4), c + Vector2(0, 4.0 - h), Color(0.2, 0.65, 0.2), 4.0)
        _entities.draw_circle(c + Vector2(-8, 2.0 - h * 0.6), 5.0 + 3.0 * t, Color(0.25, 0.70, 0.25))
        _entities.draw_circle(c + Vector2(8, 2.0 - h * 0.8), 5.0 + 3.0 * t, Color(0.25, 0.70, 0.25))
    elif p.state == PLOT_READY:
        if p.crop == CROP_CORN:
            _entities.draw_line(c + Vector2(0, 4), c + Vector2(0, -36), Color(0.25, 0.6, 0.2), 5.0)
            _entities.draw_line(c + Vector2(0, -10), c + Vector2(-14, -22), Color(0.3, 0.7, 0.25), 4.0)
            _entities.draw_line(c + Vector2(0, -16), c + Vector2(14, -28), Color(0.3, 0.7, 0.25), 4.0)
            _entities.draw_rect(Rect2(c.x - 6.0, c.y - 34.0, 12.0, 22.0), Color(0.98, 0.85, 0.2))
            _entities.draw_rect(Rect2(c.x - 6.0, c.y - 34.0, 12.0, 22.0), Color(0.75, 0.6, 0.1), false, 2.0)
        else:
            _entities.draw_line(c + Vector2(0, 4), c + Vector2(0, -26), Color(0.2, 0.6, 0.2), 4.0)
            _entities.draw_circle(c + Vector2(-11, -12), 9.0, Color(0.85, 0.12, 0.10))
            _entities.draw_circle(c + Vector2(11, -10), 9.0, Color(0.85, 0.12, 0.10))
            _entities.draw_circle(c + Vector2(0, -26), 9.0, Color(0.90, 0.16, 0.12))


func _draw_coop() -> void:
    var c := grid_to_world(COOP_CELL)
    _entities.draw_rect(Rect2(c.x - 38.0, c.y - 50.0, 76.0, 50.0), Color(0.70, 0.30, 0.22))
    _entities.draw_colored_polygon(
        PackedVector2Array([c + Vector2(-46, -50), c + Vector2(0, -86), c + Vector2(46, -50)]),
        Color(0.45, 0.18, 0.14))
    _entities.draw_rect(Rect2(c.x - 10.0, c.y - 28.0, 20.0, 28.0), Color(0.25, 0.14, 0.10))
    for i in _eggs_ready:
        _entities.draw_circle(c + Vector2(-30.0 + i * 20.0, 12), 8.0, Color(0.98, 0.96, 0.88))


func _draw_hen(i: int) -> void:
    var c := _hen_pos(i)
    var dir := 1.0 if cos(_hen_phase(i)) >= 0.0 else -1.0
    _entities.draw_circle(c + Vector2(0, 2), 9.0, Color(0, 0, 0, 0.2))
    _entities.draw_circle(c + Vector2(0, -10), 10.0, Color(0.97, 0.95, 0.90))
    _entities.draw_circle(c + Vector2(dir * 9.0, -18.0), 5.5, Color(0.97, 0.95, 0.90))
    _entities.draw_circle(c + Vector2(dir * 9.0, -24.0), 2.5, Color(0.85, 0.15, 0.10))
    _entities.draw_colored_polygon(
        PackedVector2Array([c + Vector2(dir * 13.0, -19.0), c + Vector2(dir * 19.0, -17.0), c + Vector2(dir * 13.0, -15.0)]),
        Color(0.95, 0.70, 0.20))


func _draw_delivery() -> void:
    var c := grid_to_world(DELIVERY_CELL)
    _entities.draw_rect(Rect2(c.x - 30.0, c.y - 36.0, 60.0, 36.0), Color(0.78, 0.62, 0.35))
    _entities.draw_rect(Rect2(c.x - 30.0, c.y - 36.0, 60.0, 36.0), Color(0.45, 0.32, 0.15), false, 3.0)
    _entities.draw_string(ThemeDB.fallback_font, c + Vector2(-60, -44), "DROP-OFF",
        HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20, Color.WHITE)


func _draw_farmer() -> void:
    var bob := 0.0
    if _act_kind != "":
        bob = absf(sin(_anim * 10.0)) * 3.0
    elif _is_walking():
        bob = absf(sin(_anim * 14.0)) * 5.0
    var c := _pos + Vector2(0, -bob)
    _entities.draw_circle(_pos + Vector2(0, 2), 14.0, Color(0, 0, 0, 0.25))
    _entities.draw_rect(Rect2(c.x - 10.0, c.y - 34.0, 20.0, 30.0), Color(0.20, 0.35, 0.75))
    _entities.draw_circle(c + Vector2(0, -44), 10.0, Color(0.95, 0.78, 0.62))
    _entities.draw_rect(Rect2(c.x - 16.0, c.y - 52.0, 32.0, 5.0), Color(0.95, 0.80, 0.25))
    _entities.draw_rect(Rect2(c.x - 8.0, c.y - 60.0, 16.0, 10.0), Color(0.95, 0.80, 0.25))
    if _act_kind != "":
        var frac := 1.0 - _act_left / _act_total
        _entities.draw_rect(Rect2(c.x - 24.0, c.y - 78.0, 48.0, 9.0), Color(0, 0, 0, 0.6))
        _entities.draw_rect(Rect2(c.x - 22.0, c.y - 76.0, 44.0 * frac, 5.0), Color(0.4, 0.9, 0.3))