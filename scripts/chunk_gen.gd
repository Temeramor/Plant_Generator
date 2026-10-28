class_name ChunkGen
extends RefCounted
## Генерация одного чанка 16x16 м полностью по (seed, cx, cz). Работает в потоке.

const CH_VOX := 160
const CH_M := 16.0
const VS := 0.1
const COVER_H := 32
const GRASS_CLUMPS := 90     # число пучков травы на чанк


static func mix(a: int, b: int, c: int) -> int:
    var h := a * 374761393 + b * 668265263 + c * 1442695041 + 1013904223
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return h & 0x7fffffff


static func _noise(s: int, f: float) -> FastNoiseLite:
    var n := FastNoiseLite.new()
    n.seed = s
    n.frequency = f
    return n


static func _near_spawn(wx: float, wz: float) -> bool:
    return wx * wx + wz * wz < 16.0


## Координаты чанков тестовой пятёрки: дуб, берёза, каштан, тополь, ель.
## Все остальные чанки не создают деревья; подлесок генерируется как обычно.
static func _comparison_tree_kind(cx: int, cz: int) -> int:
    if cx == 2 and cz == 2:
        return PlantGen.Kind.OAK
    if cx == -2 and cz == 0:
        return PlantGen.Kind.BIRCH
    if cx == 2 and cz == 0:
        return PlantGen.Kind.CHESTNUT
    if cx == 0 and cz == -2:
        return PlantGen.Kind.POPLAR
    if cx == 0 and cz == 2:
        return PlantGen.Kind.SPRUCE
    return -1


static func generate(world_seed: int, cx: int, cz: int, lod: int) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = mix(world_seed, cx, cz)
    var meadow := _noise(world_seed + 37, 0.035)
    var rockn := _noise(world_seed + 51, 0.022)
    var ox_m := cx * CH_M
    var oz_m := cz * CH_M
    var vs := VS * (1.0 if lod == 0 else 2.0)
    var md := MeshData.new()
    var cols: Array = []
    var face_seed := mix(world_seed, cx, cz)

    # ---------- фиксированный тест: по одному дереву каждого вида
    # Сохраняем прежнее количество обращений к RNG чанка: это оставляет
    # размещение кустов, камней, цветов и травы прежним.
    for sx in 2:
        for sz in 2:
            var _tx := rng.randf_range(1.5, 6.5) + sx * 8.0
            var _tz := rng.randf_range(1.5, 6.5) + sz * 8.0
            var _roll := rng.randf()
            var _kroll := rng.randf()
            var _tseed := rng.randi()

    var fixed_kind := _comparison_tree_kind(cx, cz)
    if fixed_kind >= 0:
        # Дерево стоит в центре назначенного чанка и не меняет позицию от сида.
        var tx := CH_M * 0.5
        var tz := CH_M * 0.5
        var tseed := mix(world_seed + 101 + fixed_kind * 7919, cx, cz)
        var g := PlantGen.make_tree(fixed_kind, tseed, lod)
        var th: float = g.meta.get("trunk_h", 30.0)
        var tr: float = g.meta.get("trunk_r", 3.0)
        # Дальняя детализация создаётся напрямую в сетке 20 см, без повторного downsample.
        g.emit(md, Vector3(tx, 0.0, tz), vs, tseed)
        cols.append({"kind": "cyl", "pos": Vector3(tx, th * VS * 0.5, tz),
                "r": maxf(0.15, tr * VS * 0.85), "h": th * VS})

    # ---------- подлесок: кусты, камни (общая сетка чанка)
    var cover := VoxGrid.new(CH_VOX, COVER_H, CH_VOX)
    cover.ox = 0
    cover.oz = 0

    for i in rng.randi_range(0, 4):
        var bx := rng.randi_range(18, CH_VOX - 19)
        var bz := rng.randi_range(18, CH_VOX - 19)
        var bseed := rng.randi()
        if _near_spawn(ox_m + bx * VS, oz_m + bz * VS):
            continue
        PlantGen.add_bush(cover, bseed, bx, bz)

    var rr := rng.randf()
    var gray_a := VoxPalette.shades(Color("8b8984"), 5, rng, 0.01, 0.05, 0.14)
    var gray_b := VoxPalette.shades(Color("77706a"), 5, rng, 0.01, 0.05, 0.14)
    var moss := VoxPalette.shades(Color("5e7b3a"), 3, rng, 0.02, 0.08, 0.1)
    var rp := PackedInt32Array()
    rp.append(cover.add_ramp(gray_a))
    rp.append(gray_a.size())
    rp.append(cover.add_ramp(gray_b))
    rp.append(gray_b.size())
    rp.append(cover.add_ramp(moss))
    rp.append(moss.size())
    var rn := rockn.get_noise_2d(ox_m + 8.0, oz_m + 8.0) * 0.5 + 0.5
    var nrocks := int(rr * 3.0)
    if rn > 0.5:
        nrocks += int((rn - 0.5) * 12.0)
    for i in nrocks:
        var rx := rng.randi_range(18, CH_VOX - 19)
        var rz := rng.randi_range(18, CH_VOX - 19)
        var rseed := rng.randi()
        var sroll := rng.randf()
        var radius := lerpf(2.5, 14.0, pow(sroll, 2.5))
        if _near_spawn(ox_m + rx * VS, oz_m + rz * VS):
            continue
        var col := PlantGen.add_rock(cover, rseed, rx, rz, radius, rp)
        if not col.is_empty():
            cols.append(col)

    # ---------- цветы и трава — только в зоне детализации
    if lod == 0:
        var fset := PlantGen.make_flower_set(cover, rng)
        var stem := VoxPalette.shades(Color("4c8a30"), 4, rng, 0.02, 0.1, 0.15)
        var stem_s := cover.add_ramp(stem)
        var stem_n := stem.size()
        var m := meadow.get_noise_2d(ox_m + 8.0, oz_m + 8.0) * 0.5 + 0.5
        var patches := rng.randi_range(0, 2)
        if m > 0.55:
            patches += 2
        for i in patches:
            var pxv := rng.randi_range(20, CH_VOX - 21)
            var pzv := rng.randi_range(20, CH_VOX - 21)
            var fl1: Dictionary = fset[rng.randi() % fset.size()]
            var fl2: Dictionary = fset[rng.randi() % fset.size()]
            var cnt := rng.randi_range(8, 28)
            var sigma := rng.randf_range(10.0, 28.0)
            for j in cnt:
                var fx := pxv + roundi(rng.randfn(0.0, sigma))
                var fz := pzv + roundi(rng.randfn(0.0, sigma))
                var fl := fl1 if rng.randf() < 0.75 else fl2
                PlantGen.add_flower(cover, rng, fx, fz, fl, stem_s, stem_n)
        for i in 6:  # одиночные цветы
            var fl3: Dictionary = fset[rng.randi() % fset.size()]
            PlantGen.add_flower(cover, rng, rng.randi_range(2, CH_VOX - 3), rng.randi_range(2, CH_VOX - 3),
                    fl3, stem_s, stem_n)

        var hue := rng.randf_range(-0.02, 0.02)
        var gr_a := VoxPalette.shades(Color.from_hsv(0.27 + hue, 0.62, 0.55), 5, rng, 0.015, 0.08, 0.12)
        var gr_b := VoxPalette.shades(Color.from_hsv(0.24 + hue, 0.58, 0.68), 5, rng, 0.015, 0.08, 0.12)
        var gr_dry := VoxPalette.shades(Color.from_hsv(0.15, 0.45, 0.66), 5, rng, 0.02, 0.08, 0.12)
        var sa := cover.add_ramp(gr_a)
        var sb := cover.add_ramp(gr_b)
        var sd := cover.add_ramp(gr_dry)
        for i in GRASS_CLUMPS:
            var gx := rng.randi_range(0, CH_VOX - 1)
            var gz := rng.randi_range(0, CH_VOX - 1)
            var nbl := rng.randi_range(3, 9)
            var hmax := rng.randi_range(3, 7)
            var kr := rng.randf()
            var dn := meadow.get_noise_2d(ox_m + gx * VS, oz_m + gz * VS)
            var rs := sa
            var rcount := gr_a.size()
            if kr > 0.85:
                rs = sd
                rcount = gr_dry.size()
            elif kr > 0.45:
                rs = sb
                rcount = gr_b.size()
            for j in nbl:
                var bx2 := gx + roundi(rng.randfn(0.0, 4.0))
                var bz2 := gz + roundi(rng.randfn(0.0, 4.0))
                var bh := rng.randi_range(2, hmax)
                if dn < -0.35:
                    continue  # проплешина
                PlantGen.add_blade(cover, rng, bx2, bz2, bh, rs, rcount)

    if lod == 0:
        cover.emit(md, Vector3.ZERO, VS, face_seed)
    else:
        cover.downsampled().emit(md, Vector3.ZERO, vs, face_seed)

    return {"mesh": md.build(), "colliders": cols}
