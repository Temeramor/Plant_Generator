class_name Player
extends CharacterBody3D
## Капсула 0.7 x 1.8 м (невидимая) + камера от первого лица.

const SPEED := 5.0
const JUMP_V := 5.2
const GRAV := 15.0

var look_sens := 0.0042
var move_input := Vector2.ZERO   # x: вправо, y: вперёд
var jump_request := false
var yaw := 0.0
var pitch := 0.0
var cam: Camera3D


func _ready() -> void:
    var col := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.35
    cap.height = 1.8
    col.shape = cap
    col.position = Vector3(0.0, 0.9, 0.0)
    add_child(col)
    cam = Camera3D.new()
    cam.position = Vector3(0.0, 1.62, 0.0)
    cam.fov = 75.0
    cam.near = 0.05
    cam.far = 220.0
    add_child(cam)
    cam.make_current()


func look(rel: Vector2) -> void:
    yaw -= rel.x * look_sens
    pitch = clampf(pitch - rel.y * look_sens, -1.5, 1.5)
    rotation.y = yaw
    cam.rotation.x = pitch


func _physics_process(delta: float) -> void:
    var v := move_input
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        v.y += 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        v.y -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        v.x += 1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        v.x -= 1.0
    v = v.limit_length(1.0)
    var wish := global_transform.basis * Vector3(v.x, 0.0, -v.y)
    var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * SPEED, 40.0 * delta)
    velocity.x = hv.x
    velocity.z = hv.z
    if is_on_floor():
        if jump_request or Input.is_key_pressed(KEY_SPACE):
            velocity.y = JUMP_V
    else:
        velocity.y -= GRAV * delta
    jump_request = false
    move_and_slide()
