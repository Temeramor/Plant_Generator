extends Node3D
## Точка входа: окружение, плоскость, мир по сиду, экран загрузки, игрок и сенсорное управление.

@export var world_seed: int = 20260101   # меняйте сид здесь или запуском с аргументом: -- --seed=777

const GROUND_PERIOD := 12.8   # 128 пикселей * 0.1 м

var world: VoxWorld
var player: Player
var ground: MeshInstance3D
var loading_layer: CanvasLayer
var loading_label: Label
var hud: Label
var started := false
var hud_timer := 0.0


func _ready() -> void:
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--seed="):
            world_seed = int(a.substr(7))
    _setup_environment()
    _setup_ground()
    world = VoxWorld.new()
    world.world_seed = world_seed
    add_child(world)
    world.cast_shadows = _shadows_enabled()
    world.begin(Vector3.ZERO)
    _setup_loading_ui()


func _shadows_enabled() -> bool:
    return not OS.has_feature("mobile")


func _setup_environment() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sm := ProceduralSkyMaterial.new()
    sm.sky_top_color = Color("4d86c9")
    sm.sky_horizon_color = Color("b9d3e8")
    sm.ground_horizon_color = Color("b9d3e8")
    sm.ground_bottom_color = Color("9fb8cc")
    sky.sky_material = sm
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.9
    env.fog_enabled = true
    env.fog_light_color = Color("b9d3e8")
    env.fog_density = 0.008
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
    sun.light_energy = 1.3
    sun.shadow_enabled = _shadows_enabled()
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    sun.directional_shadow_max_distance = 40.0
    add_child(sun)


func _make_ground_texture() -> ImageTexture:
    var rng := RandomNumberGenerator.new()
    rng.seed = world_seed
    var greens := VoxPalette.shades(Color("4f8a31"), 6, rng, 0.015, 0.08, 0.1)
    var dirt := VoxPalette.shades(Color("6b5a3a"), 3, rng, 0.02, 0.1, 0.1)
    var img := Image.create_empty(128, 128, false, Image.FORMAT_RGB8)
    for y in 128:
        for x in 128:
            var col: Color
            if rng.randf() < 0.03:
                col = dirt[rng.randi() % dirt.size()]
            else:
                col = greens[rng.randi() % greens.size()]
            img.set_pixel(x, y, col)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)


func _setup_ground() -> void:
    var body := StaticBody3D.new()
    var cs := CollisionShape3D.new()
    cs.shape = WorldBoundaryShape3D.new()
    body.add_child(cs)
    add_child(body)

    ground = MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(1024.0, 1024.0)
    ground.mesh = pm
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = _make_ground_texture()
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
    mat.uv1_scale = Vector3(80.0, 80.0, 1.0)   # 1024 м / 12.8 м
    mat.roughness = 1.0
    ground.material_override = mat
    add_child(ground)


func _setup_loading_ui() -> void:
    loading_layer = CanvasLayer.new()
    loading_layer.layer = 10
    var bg := ColorRect.new()
    bg.color = Color("14201a")
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    loading_layer.add_child(bg)
    loading_label = Label.new()
    loading_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    loading_label.add_theme_font_size_override("font_size", 32)
    loading_layer.add_child(loading_label)
    add_child(loading_layer)


func _start_game() -> void:
    player = Player.new()
    player.position = Vector3(0.0, 0.2, 0.0)
    add_child(player)

    var ui := CanvasLayer.new()
    var tc := TouchControls.new()
    tc.player = player
    ui.add_child(tc)
    hud = Label.new()
    hud.position = Vector2(16.0, 10.0)
    hud.add_theme_font_size_override("font_size", 18)
    ui.add_child(hud)
    add_child(ui)

    loading_layer.queue_free()
    started = true


func _process(delta: float) -> void:
    if not started:
        var pr := world.initial_progress()
        loading_label.text = "Генерация мира…  %d%%\nСид: %d" % [int(pr * 100.0), world_seed]
        if pr >= 1.0:
            _start_game()
        return
    var pp := player.global_position
    world.set_focus(pp)
    ground.position = Vector3(snappedf(pp.x, GROUND_PERIOD), 0.0, snappedf(pp.z, GROUND_PERIOD))
    hud_timer -= delta
    if hud_timer <= 0.0:
        hud_timer = 0.5
        hud.text = "Сид: %d   FPS: %d   Чанков: %d" % [world_seed, Engine.get_frames_per_second(), world.chunks.size()]
