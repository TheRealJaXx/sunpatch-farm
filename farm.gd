extends Node2D

const BUILD_NUMBER := 4
const GRID_W := 14
const GRID_H := 14
const TILE_W := 128.0
const TILE_H := 64.0
const COLOR_A := Color(0.45, 0.75, 0.36)
const COLOR_B := Color(0.40, 0.69, 0.32)
const COLOR_EDGE := Color(0.25, 0.50, 0.22)
const MAP_BOUNDS := Rect2(-896.0, -32.0, 1792.0, 896.0)

var _camera: Camera2D

func grid_to_world(cell: Vector2i) -> Vector2:
    return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)

func _ready() -> void:
    _camera = Camera2D.new()
    _camera.position = MAP_BOUNDS.get_center()
    add_child(_camera)
    _camera.make_current()

    var hud := CanvasLayer.new()
    add_child(hud)
    var label := Label.new()
    label.text = "Sunpatch Farm - Build %d - drag to scroll" % BUILD_NUMBER
    label.position = Vector2(16, 12)
    label.add_theme_font_size_override("font_size", 28)
    label.add_theme_color_override("font_outline_color", Color.BLACK)
    label.add_theme_constant_override("outline_size", 6)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(label)

    _clamp_camera()
    queue_redraw()

func _draw() -> void:
    for y in GRID_H:
        for x in GRID_W:
            var c := grid_to_world(Vector2i(x, y))
            var pts := PackedVector2Array([
                c + Vector2(0, -TILE_H * 0.5),
                c + Vector2(TILE_W * 0.5, 0),
                c + Vector2(0, TILE_H * 0.5),
                c + Vector2(-TILE_W * 0.5, 0),
            ])
            draw_colored_polygon(pts, COLOR_A if (x + y) % 2 == 0 else COLOR_B)
            var outline := pts.duplicate()
            outline.append(pts[0])
            draw_polyline(outline, COLOR_EDGE, 1.5)

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
        _camera.position -= event.relative / _camera.zoom
        _clamp_camera()

func _clamp_camera() -> void:
    var half := get_viewport_rect().size * 0.5 / _camera.zoom
    var min_p := MAP_BOUNDS.position + half
    var max_p := MAP_BOUNDS.end - half
    var c := MAP_BOUNDS.get_center()
    _camera.position.x = c.x if min_p.x > max_p.x else clampf(_camera.position.x, min_p.x, max_p.x)
    _camera.position.y = c.y if min_p.y > max_p.y else clampf(_camera.position.y, min_p.y, max_p.y)