class_name VoxWorld
extends Node3D
## Стриминг чанков: ближние — с полной детализацией (воксель 0.1 м),
## дальние — упрощённые (0.2 м). Генерация идёт в рабочих потоках.

const CH_M := 16.0
const INITIAL_R := 2     # чанки, которые ждём на экране загрузки (радиус)

var world_seed := 1
var view_radius := 3
var lod0_radius := 1
var max_tasks := 3
var material: StandardMaterial3D
var cast_shadows := false

var chunks := {}      # Vector2i -> {node, lod}
var pending := {}     # Vector2i -> {id, lod}
var desired: Array = []
var results: Array = []
var mutex := Mutex.new()
var focus_chunk := Vector2i.ZERO


func _ready() -> void:
    material = StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.vertex_color_is_srgb = true
    material.roughness = 1.0
    material.metallic = 0.0
    if OS.has_feature("mobile"):
        view_radius = 2
    max_tasks = clampi(OS.get_processor_count() - 1, 1, 4)


func begin(pos: Vector3) -> void:
    focus_chunk = _chunk_of(pos)
    _plan()


func set_focus(pos: Vector3) -> void:
    var c := _chunk_of(pos)
    if c != focus_chunk:
        focus_chunk = c
        _plan()


func _chunk_of(pos: Vector3) -> Vector2i:
    return Vector2i(floori(pos.x / CH_M), floori(pos.z / CH_M))


func initial_progress() -> float:
    var need := 0
    var have := 0
    for dz in range(-INITIAL_R, INITIAL_R + 1):
        for dx in range(-INITIAL_R, INITIAL_R + 1):
            need += 1
            if chunks.has(focus_chunk + Vector2i(dx, dz)):
                have += 1
    return float(have) / float(need)


func _plan() -> void:
    desired.clear()
    for dz in range(-view_radius, view_radius + 1):
        for dx in range(-view_radius, view_radius + 1):
            var ring := maxi(absi(dx), absi(dz))
            desired.append({"c": focus_chunk + Vector2i(dx, dz),
                    "lod": 0 if ring <= lod0_radius else 1,
                    "d": dx * dx + dz * dz})
    desired.sort_custom(func(a, b): return a.d < b.d)


func _process(_delta: float) -> void:
    _drain_results(4)
    _unload_far()
    _dispatch()


func _dispatch() -> void:
    for item in desired:
        if pending.size() >= max_tasks:
            break
        var c: Vector2i = item.c
        var lod: int = item.lod
        if pending.has(c):
            continue
        if chunks.has(c) and chunks[c].lod == lod:
            continue
        var id := WorkerThreadPool.add_task(_gen_task.bind(c, lod), false, "voxel_chunk")
        pending[c] = {"id": id, "lod": lod}


func _gen_task(c: Vector2i, lod: int) -> void:
    var data := ChunkGen.generate(world_seed, c.x, c.y, lod)
    data["coord"] = c
    data["lod"] = lod
    mutex.lock()
    results.append(data)
    mutex.unlock()


func _drain_results(limit: int) -> void:
    mutex.lock()
    var take := mini(results.size(), limit)
    var batch := results.slice(0, take)
    results = results.slice(take)
    mutex.unlock()
    for data in batch:
        var c: Vector2i = data.coord
        if pending.has(c):
            WorkerThreadPool.wait_for_task_completion(pending[c].id)
            pending.erase(c)
        if absi(c.x - focus_chunk.x) > view_radius + 1 or absi(c.y - focus_chunk.y) > view_radius + 1:
            continue
        _install(c, data)


func _install(c: Vector2i, data: Dictionary) -> void:
    if chunks.has(c):
        chunks[c].node.queue_free()
    var mi := MeshInstance3D.new()
    mi.mesh = data.mesh
    mi.material_override = material
    mi.position = Vector3(c.x * CH_M, 0.0, c.y * CH_M)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows \
            else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var lod: int = data.lod
    if lod == 0 and not data.colliders.is_empty():
        var body := StaticBody3D.new()
        for col in data.colliders:
            var cs := CollisionShape3D.new()
            if col.kind == "cyl":
                var sh := CylinderShape3D.new()
                sh.radius = col.r
                sh.height = col.h
                cs.shape = sh
            else:
                var bx := BoxShape3D.new()
                bx.size = col.size
                cs.shape = bx
            cs.position = col.pos
            body.add_child(cs)
        mi.add_child(body)
    add_child(mi)
    chunks[c] = {"node": mi, "lod": lod}


func _unload_far() -> void:
    for c in chunks.keys():
        if absi(c.x - focus_chunk.x) > view_radius + 1 or absi(c.y - focus_chunk.y) > view_radius + 1:
            chunks[c].node.queue_free()
            chunks.erase(c)


func _exit_tree() -> void:
    for c in pending.keys():
        WorkerThreadPool.wait_for_task_completion(pending[c].id)
