class_name TouchControls
extends Control
## Левый джойстик (плавающий в левой части экрана) + взгляд правой частью + кнопка прыжка.
## В редакторе на ПК работает мышью благодаря emulate_touch_from_mouse.

const JOY_R := 120.0
const KNOB_R := 52.0
const JUMP_R := 72.0

var player: Player
var joy_id := -1
var look_id := -1
var jump_id := -1
var joy_center := Vector2.ZERO
var joy_knob := Vector2.ZERO


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _home() -> Vector2:
    return Vector2(200.0, get_viewport_rect().size.y - 190.0)


func _jump_pos() -> Vector2:
    var s := get_viewport_rect().size
    return Vector2(s.x - 160.0, s.y - 190.0)


func _update_move() -> void:
    var v := (joy_knob - joy_center) / JOY_R
    if v.length() < 0.12:
        v = Vector2.ZERO
    player.move_input = Vector2(v.x, -v.y)


func _input(event: InputEvent) -> void:
    if player == null:
        return
    var s := get_viewport_rect().size
    if event is InputEventScreenTouch:
        var t := event as InputEventScreenTouch
        if t.pressed:
            if joy_id == -1 and t.position.x < s.x * 0.45:
                joy_id = t.index
                joy_center = t.position
                joy_knob = t.position
                _update_move()
            elif jump_id == -1 and t.position.distance_to(_jump_pos()) < JUMP_R * 1.25:
                jump_id = t.index
                player.jump_request = true
            elif look_id == -1 and t.position.x >= s.x * 0.45:
                look_id = t.index
        else:
            if t.index == joy_id:
                joy_id = -1
                player.move_input = Vector2.ZERO
            elif t.index == jump_id:
                jump_id = -1
            elif t.index == look_id:
                look_id = -1
        queue_redraw()
    elif event is InputEventScreenDrag:
        var dr := event as InputEventScreenDrag
        if dr.index == joy_id:
            joy_knob = joy_center + (dr.position - joy_center).limit_length(JOY_R)
            _update_move()
        elif dr.index == look_id:
            player.look(dr.relative)
        queue_redraw()


func _draw() -> void:
    var c := joy_center if joy_id != -1 else _home()
    var k := joy_knob if joy_id != -1 else _home()
    draw_circle(c, JOY_R, Color(1, 1, 1, 0.12))
    draw_arc(c, JOY_R, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
    draw_circle(k, KNOB_R, Color(1, 1, 1, 0.35))
    var j := _jump_pos()
    draw_circle(j, JUMP_R, Color(1, 1, 1, 0.3 if jump_id != -1 else 0.15))
    draw_arc(j, JUMP_R, 0.0, TAU, 40, Color(1, 1, 1, 0.4), 3.0)
    draw_colored_polygon(PackedVector2Array([j + Vector2(0, -26), j + Vector2(26, 16), j + Vector2(-26, 16)]),
            Color(1, 1, 1, 0.6))
