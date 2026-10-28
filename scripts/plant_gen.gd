class_name PlantGen
extends RefCounted
## Процедурные растения. Каждое растение полностью определяется сидом.

enum Kind { OAK, BIRCH, CHESTNUT, POPLAR, SPRUCE }

const OakProfile = preload("res://scripts/trees/oak.gd")
const BirchProfile = preload("res://scripts/trees/birch.gd")
const ChestnutProfile = preload("res://scripts/trees/chestnut.gd")
const PoplarProfile = preload("res://scripts/trees/poplar.gd")
const SpruceProfile = preload("res://scripts/trees/spruce.gd")


class TreeP:
    var bark := Color.BLACK
    var leaf := Color.GREEN
    var leaf_alt := Color.YELLOW
    var alt_p := 0.06
    var spot := false
    var roots := 0
    var trunk_h := 30.0
    var r0 := 4.0
    var r1 := 1.5
    var wobble := 0.1
    var lean := 0.1
    var br_min := 4
    var br_max := 6
    var br_start := 0.5
    var br_taper := 0.8
    var br_len_min := 20.0
    var br_len_max := 30.0
    var pitch_min := 0.1
    var pitch_max := 0.6
    var crook := 0.25
    var droop := 0.0
    var lift := 0.0
    var sub_prob := 0.35
    var sub_angle := 0.8
    var max_depth := 1
    var lobe_min := 8.0
    var lobe_max := 12.0
    var lobe_flat := 0.7
    var density := 0.9
    var rough := 0.45
    var hollow := 0.6
    var top_lobe := 1.0
    var fill_p := 0.4
    var root_len_min := 5.0
    var root_len_max := 9.0


class Ctx:
    var g: VoxGrid
    var rng: RandomNumberGenerator
    var noise: FastNoiseLite
    var p: TreeP
    ## Размер ячейки относительно 10 см: 1 для ближнего LOD, 2 для дальнего.
    var lod_scale: float = 1.0
    var bark_s := 1
    var bark_n := 1
    var spot_s := 1
    var spot_n := 1
    var spot_p := 0.0
    var leaf_s := 1
    var leaf_n := 1
    var alt_s := 1
    var alt_n := 1
    var alt_p := 0.0
    var tips: Array = []
    var mids: Array = []


static func _noise(s: int, f: float) -> FastNoiseLite:
    var n := FastNoiseLite.new()
    n.seed = s
    n.frequency = f
    return n


# ---------------------------------------------------------------- параметры

static func _params(kind: int, rng: RandomNumberGenerator) -> TreeP:
    var p := TreeP.new()
    # Линейные размеры указаны в вокселях по 10 см; небольшой разброс сохраняет уникальность.
    var s := rng.randf_range(0.90, 1.10)
    match kind:
        Kind.OAK:
            OakProfile.configure(p, rng, s)
        Kind.BIRCH:
            BirchProfile.configure(p, rng, s)
        Kind.CHESTNUT:
            ChestnutProfile.configure(p, rng, s)
        Kind.POPLAR:
            PoplarProfile.configure(p, rng, s)
        _:
            SpruceProfile.configure(p, rng, s)

    # Индивидуальный оттенок листвы; иногда лиственные деревья переходят в осеннюю палитру.
    if kind != Kind.SPRUCE and rng.randf() < 0.1:
        var autumn := [Color("c9a227"), Color("c4631f"), Color("a8472a"), Color("b8b02a")]
        p.leaf = autumn[rng.randi() % autumn.size()]
        p.leaf_alt = Color("7d8a2a")
        p.alt_p = 0.1
    else:
        var lc := p.leaf
        p.leaf = Color.from_hsv(fposmod(lc.h + rng.randf_range(-0.02, 0.02), 1.0),
                clampf(lc.s + rng.randf_range(-0.08, 0.08), 0.0, 1.0),
                clampf(lc.v + rng.randf_range(-0.07, 0.07), 0.05, 1.0))
    return p

static func _perp_rot(d: Vector3, rng: RandomNumberGenerator, angle: float) -> Vector3:
    var axis := d.cross(Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)))
    if axis.length_squared() < 0.0001:
        axis = d.cross(Vector3.RIGHT)
        if axis.length_squared() < 0.0001:
            axis = d.cross(Vector3.FORWARD)
    return d.rotated(axis.normalized(), angle)


static func _ball(c: Ctx, pos: Vector3, r: float) -> void:
    var g := c.g
    var rng := c.rng
    if r < 0.8 / c.lod_scale:
        g.put(roundi(pos.x), roundi(pos.y), roundi(pos.z), c.bark_s + rng.randi_range(0, c.bark_n - 1))
        return
    var ri := ceili(r)
    var r2 := r * r + 0.3 / (c.lod_scale * c.lod_scale)
    var cx := roundi(pos.x)
    var cy := roundi(pos.y)
    var cz := roundi(pos.z)
    for y in range(maxi(cy - ri, 0), cy + ri + 1):
        var dy := y - pos.y
        for z in range(cz - ri, cz + ri + 1):
            var dz := z - pos.z
            for x in range(cx - ri, cx + ri + 1):
                var dx := x - pos.x
                if dx * dx + dy * dy + dz * dz > r2:
                    continue
                var idx: int
                if c.spot_p > 0.0 and rng.randf() < c.spot_p:
                    idx = c.spot_s + rng.randi_range(0, c.spot_n - 1)
                else:
                    # вертикальные "полосы" коры + немного случайности
                    var sh := ((x * 73 + z * 151) & 0xff) % c.bark_n
                    if rng.randf() < 0.2:
                        sh = rng.randi_range(0, c.bark_n - 1)
                    idx = c.bark_s + sh
                c.g.put(x, y, z, idx)


static func _line(c: Ctx, a: Vector3, b: Vector3, ra: float, rb: float) -> void:
    var dist := a.distance_to(b)
    var steps := maxi(1, int(dist / (0.7 / c.lod_scale)))
    for i in steps + 1:
        var t := float(i) / steps
        _ball(c, a.lerp(b, t), lerpf(ra, rb, t))


## Пышный пучок листвы: эллипсоид, "съеденный" 3D-шумом, с прорехами и полостью внутри.
static func _blob(c: Ctx, ctr: Vector3, rad: Vector3) -> void:
    var g := c.g
    var rng := c.rng
    var noise := c.noise
    var p := c.p
    var rough := p.rough
    var hollow := p.hollow
    var density := p.density
    var ext := 1.0 + rough
    var lim := ext * ext
    var ln := c.leaf_n
    var inv := Vector3(1.0 / rad.x, 1.0 / rad.y, 1.0 / rad.z)
    var x0 := floori(ctr.x - rad.x * ext)
    var x1 := ceili(ctr.x + rad.x * ext)
    var y0 := maxi(floori(ctr.y - rad.y * ext), 0)
    var y1 := ceili(ctr.y + rad.y * ext)
    var z0 := floori(ctr.z - rad.z * ext)
    var z1 := ceili(ctr.z + rad.z * ext)
    for y in range(y0, y1 + 1):
        var ny := (y - ctr.y) * inv.y
        var ny2 := ny * ny
        if ny2 > lim:
            continue
        for z in range(z0, z1 + 1):
            var nz := (z - ctr.z) * inv.z
            var nyz := ny2 + nz * nz
            if nyz > lim:
                continue
            for x in range(x0, x1 + 1):
                var nx := (x - ctr.x) * inv.x
                var d2 := nyz + nx * nx
                if d2 > lim:
                    continue
                var n := noise.get_noise_3d(x, y, z)
                var dd := sqrt(d2) + n * rough
                if dd > 1.0 or dd < hollow:
                    continue
                var edge := clampf((dd - 0.55) / 0.45, 0.0, 1.0)
                if rng.randf() > density * (1.0 - edge * 0.5):
                    continue
                var idx: int
                if c.alt_p > 0.0 and rng.randf() < c.alt_p:
                    idx = c.alt_s + rng.randi_range(0, c.alt_n - 1)
                else:
                    var t := 0.5 + ny * 0.28 + (dd - 0.6) * 0.5 + n * 0.22 + rng.randf_range(-0.12, 0.12)
                    idx = c.leaf_s + clampi(int(t * ln), 0, ln - 1)
                g.put(x, y, z, idx)


static func _trunk_at(pts: Array[Vector3], f: float) -> Vector3:
    var fi := clampf(f, 0.0, 1.0) * (pts.size() - 1)
    var i := mini(int(fi), pts.size() - 2)
    return pts[i].lerp(pts[i + 1], fi - i)


# ---------------------------------------------------------------- деревья

static func make_tree(kind: int, seed_val: int, lod: int = 0) -> VoxGrid:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_val
    var p := _params(kind, rng)

    # Размеры для коллизий храним в исходных ячейках по 10 см.
    var base_trunk_h: float = p.trunk_h
    var base_trunk_r: float = p.r0
    # Дальний LOD создаётся сразу на сетке 20 см, но сохраняет физический размер.
    # Объём обрабатываемой 3D-сетки уменьшается примерно в 8 раз.
    var resolution_factor: float = 1.0 if lod <= 0 else 2.0
    p.trunk_h /= resolution_factor
    p.r0 /= resolution_factor
    p.r1 /= resolution_factor
    p.br_len_min /= resolution_factor
    p.br_len_max /= resolution_factor
    p.lobe_min /= resolution_factor
    p.lobe_max /= resolution_factor

    # Учёт вторичных ветвей и объёма листвы, чтобы широкие кроны не обрезались сеткой.
    var branch_extent: float = 1.45 if kind != Kind.SPRUCE and p.max_depth > 0 else 1.0
    var half: int = ceili(p.br_len_max * branch_extent + p.lobe_max * (1.0 + p.rough) + 6.0 / resolution_factor)
    # Высота соответствует контуру кроны без избыточного пустого объёма.
    var hgt: int = ceili(p.trunk_h + p.br_len_max * 0.55 + p.lobe_max * (p.lobe_flat + 0.45) + 6.0 / resolution_factor)
    var g := VoxGrid.new(half * 2, hgt, half * 2)

    var c := Ctx.new()
    c.g = g
    c.rng = rng
    c.p = p
    c.lod_scale = resolution_factor
    c.noise = _noise(seed_val ^ 0x5bd1e995, 0.17)

    var bark_cols := VoxPalette.shades(p.bark, 5, rng, 0.015, 0.08, 0.1)
    c.bark_s = g.add_ramp(bark_cols)
    c.bark_n = bark_cols.size()
    if p.spot:
        var sp := VoxPalette.shades(Color("2a2a2a"), 2, rng, 0.0, 0.02, 0.06)
        c.spot_s = g.add_ramp(sp)
        c.spot_n = sp.size()
        c.spot_p = 0.07
    var leaf_cols := VoxPalette.shades(p.leaf, 6, rng, 0.02, 0.1, 0.2)
    c.leaf_s = g.add_ramp(leaf_cols)
    c.leaf_n = leaf_cols.size()
    var alt_cols := VoxPalette.shades(p.leaf_alt, 3, rng, 0.015, 0.08, 0.1)
    c.alt_s = g.add_ramp(alt_cols)
    c.alt_n = alt_cols.size()
    c.alt_p = p.alt_p

    if kind == Kind.SPRUCE:
        _build_spruce(c)
    else:
        _build_broadleaf(c)

    _prune_floating_leaf_voxels(c)
    g.meta = {"trunk_h": base_trunk_h * 0.9, "trunk_r": base_trunk_r}
    return g


static func _is_leaf_material(material_id: int, c: Ctx) -> bool:
    var main_leaf: bool = material_id >= c.leaf_s and material_id < c.leaf_s + c.leaf_n
    var alternate_leaf: bool = material_id >= c.alt_s and material_id < c.alt_s + c.alt_n
    return main_leaf or alternate_leaf


static func _has_adjacent_voxel(g: VoxGrid, x: int, y: int, z: int) -> bool:
    for ny in range(maxi(0, y - 1), mini(g.h, y + 2)):
        for nz in range(maxi(0, z - 1), mini(g.d, z + 2)):
            for nx in range(maxi(0, x - 1), mini(g.w, x + 2)):
                if nx == x and ny == y and nz == z:
                    continue
                if g.cells[nx + nz * g.w + ny * g.wd] != 0:
                    return true
    return false


## Удаляет одиночные листовые воксели, не соприкасающиеся с ветвями или другими листьями.
## Соседство по диагонали считается связным.
static func _prune_floating_leaf_voxels(c: Ctx) -> void:
    var g: VoxGrid = c.g
    var remove := PackedInt32Array()
    for idx in g.filled:
        var material_id: int = int(g.cells[idx])
        if not _is_leaf_material(material_id, c):
            continue
        var y: int = idx / g.wd
        var rem: int = idx - y * g.wd
        var z: int = rem / g.w
        var x: int = rem - z * g.w
        if not _has_adjacent_voxel(g, x, y, z):
            remove.push_back(idx)
    if remove.is_empty():
        return
    for idx in remove:
        g.cells[idx] = 0
    var compact := PackedInt32Array()
    compact.resize(g.filled.size() - remove.size())
    var write_idx := 0
    for idx in g.filled:
        if g.cells[idx] == 0:
            continue
        compact[write_idx] = idx
        write_idx += 1
    g.filled = compact

static func _build_trunk(c: Ctx) -> Array[Vector3]:
    var rng := c.rng
    var p := c.p
    var n := maxi(3, int(p.trunk_h / 6.0))
    var seg := p.trunk_h / n
    var pts: Array[Vector3] = [Vector3.ZERO]
    var pos := Vector3.ZERO
    var lx := rng.randf_range(-1.0, 1.0) * p.lean
    var lz := rng.randf_range(-1.0, 1.0) * p.lean
    for i in n:
        var progress: float = float(i + 1) / float(n)
        # Не даём накопленному случайному отклонению увести ствол в сторону.
        # Чем выше дерево, тем сильнее направление возвращается к вертикали.
        var return_to_axis: float = lerpf(0.12, 0.90, pow(progress, 1.7))
        lx = lerpf(lx, 0.0, return_to_axis)
        lz = lerpf(lz, 0.0, return_to_axis)
        var bend_noise: float = (1.0 - progress * 0.72) * 0.45
        lx = clampf(lx + rng.randf_range(-1.0, 1.0) * p.wobble * bend_noise, -0.22, 0.22)
        lz = clampf(lz + rng.randf_range(-1.0, 1.0) * p.wobble * bend_noise, -0.22, 0.22)
        var dir := Vector3(lx, 1.0, lz).normalized()
        var nxt := pos + dir * seg
        var ra := lerpf(p.r0, p.r1, float(i) / n)
        var rb := lerpf(p.r0, p.r1, float(i + 1) / n)
        if i == 0:
            ra += 1.2 / c.lod_scale
        _line(c, pos, nxt, ra, rb)
        pos = nxt
        pts.append(pos)
    for i in p.roots:
        var a := TAU * i / p.roots + rng.randf_range(-0.4, 0.4)
        var start := Vector3(cos(a) * p.r0 * 0.5, 3.0 / c.lod_scale, sin(a) * p.r0 * 0.5)
        var dir := Vector3(cos(a), -0.45, sin(a))
        var root_len: float = rng.randf_range(p.root_len_min, p.root_len_max) / c.lod_scale
        _line(c, start, start + dir * root_len, p.r0 * 0.45, 0.8 / c.lod_scale)
    return pts


static func _branch(c: Ctx, start: Vector3, dir: Vector3, length: float, radius: float, depth: int) -> void:
    var rng := c.rng
    var p := c.p
    var segs := maxi(2, int(length / (7.0 / c.lod_scale)))
    var step := length / segs
    var pos := start
    var d := dir.normalized()
    for i in segs:
        d += Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.7, 0.7), rng.randf_range(-1.0, 1.0)) * p.crook
        d.y += p.lift - p.droop * float(i + 1) / segs * 0.9
        d = d.normalized()
        var nxt := pos + d * step
        var ra := lerpf(radius, radius * 0.45, float(i) / segs)
        var rb := lerpf(radius, radius * 0.45, float(i + 1) / segs)
        _line(c, pos, nxt, ra, rb)
        pos = nxt
        if i >= 1:
            if depth < p.max_depth and rng.randf() < p.sub_prob:
                var sd := _perp_rot(d, rng, p.sub_angle * rng.randf_range(0.7, 1.3))
                if sd.y < -0.2:
                    sd.y = -sd.y * 0.5
                _branch(c, pos, sd, length * rng.randf_range(0.4, 0.6), radius * 0.55, depth + 1)
            elif rng.randf() < p.fill_p:
                c.mids.append(pos)
    c.tips.append(Vector4(pos.x, pos.y, pos.z, depth))


static func _build_broadleaf(c: Ctx) -> void:
    var rng := c.rng
    var p := c.p
    var pts := _build_trunk(c)
    var nb := rng.randi_range(p.br_min, p.br_max)
    var az0 := rng.randf() * TAU
    for i in nb:
        var f := p.br_start + (1.0 - p.br_start) * (float(i) + rng.randf_range(0.0, 0.9)) / nb
        var origin := _trunk_at(pts, f)
        var rad := lerpf(p.r0, p.r1, f)
        var az := az0 + 2.39996 * i + rng.randf_range(-0.3, 0.3)
        var pitch := rng.randf_range(p.pitch_min, p.pitch_max)
        var dir := Vector3(cos(az) * cos(pitch), sin(pitch), sin(az) * cos(pitch))
        var tf := lerpf(1.0, p.br_taper, (f - p.br_start) / maxf(0.01, 1.0 - p.br_start))
        var blen := rng.randf_range(p.br_len_min, p.br_len_max) * tf
        _branch(c, origin, dir, blen, maxf(0.9, rad * 0.6), 0)

    # листва: на концах ветвей
    for t in c.tips:
        var tv: Vector4 = t
        var r := rng.randf_range(p.lobe_min, p.lobe_max) * (1.0 - 0.2 * tv.w)
        var off := Vector3(rng.randf_range(-2.0, 2.0) / c.lod_scale,
                r * 0.2 + rng.randf_range(0.0, 2.0) / c.lod_scale,
                rng.randf_range(-2.0, 2.0) / c.lod_scale)
        _blob(c, Vector3(tv.x, tv.y, tv.z) + off, Vector3(r, r * p.lobe_flat, r * rng.randf_range(0.85, 1.15)))
    # листва: вдоль ветвей (полнота кроны)
    for m in c.mids:
        var mv: Vector3 = m
        var r2 := rng.randf_range(p.lobe_min, p.lobe_max) * 0.65
        _blob(c, mv + Vector3(0, r2 * 0.2, 0), Vector3(r2, r2 * p.lobe_flat, r2))
    # верхушка
    var top := pts[pts.size() - 1]
    var tr := p.lobe_max * p.top_lobe
    _blob(c, top + Vector3(0, tr * 0.35, 0), Vector3(tr, tr * p.lobe_flat, tr))


static func _build_spruce(c: Ctx) -> void:
    var rng := c.rng
    var p := c.p
    var pts := _build_trunk(c)
    var y_start := p.trunk_h * 0.16
    var y_end := p.trunk_h * 0.97
    var y := y_start
    while y < y_end:
        var frac := (y - y_start) / (y_end - y_start)
        var base := _trunk_at(pts, y / p.trunk_h)
        var alen := lerpf(p.br_len_max, 3.0 / c.lod_scale, pow(frac, 0.85)) * rng.randf_range(0.85, 1.15)
        var arms := 5 + int((1.0 - frac) * 2.0)
        var az := rng.randf() * TAU
        for k in arms:
            var a := az + TAU * k / arms + rng.randf_range(-0.25, 0.25)
            var dir := Vector3(cos(a), -0.3 - 0.12 * (1.0 - frac), sin(a)).normalized()
            var endp := base + dir * alen
            _line(c, base, endp, 0.9 / c.lod_scale, 0.5 / c.lod_scale)
            # Хвоя лежит на внешней части каждой ветви; центр конуса остаётся воздушным.
            var two := alen > 11.0 / c.lod_scale
            var rx := maxf(1.6 / c.lod_scale, alen * (0.20 if two else 0.24))
            var lobe_count: int = 2 if two else 1
            for q in range(lobe_count):
                var branch_t: float = (0.70 + 0.21 * float(q)) if two else 0.93
                var cc := base.lerp(endp, branch_t)
                var thickness: float = rng.randf_range(2.8, 3.8) / c.lod_scale
                _blob(c, cc + Vector3(0, 0.5 / c.lod_scale, 0),
                        Vector3(rx, thickness, rx * rng.randf_range(0.88, 1.08)))
        y += rng.randf_range(4.5, 6.0) / c.lod_scale
    var top := pts[pts.size() - 1]
    _blob(c, top + Vector3(0, 3.0 / c.lod_scale, 0),
            Vector3(2.2 / c.lod_scale, 5.5 / c.lod_scale, 2.2 / c.lod_scale))


# ---------------------------------------------------------------- кусты

static func add_bush(g: VoxGrid, seed_val: int, x: int, z: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_val
    var c := Ctx.new()
    c.g = g
    c.rng = rng
    c.noise = _noise(seed_val, 0.22)
    var p := TreeP.new()
    p.density = 0.9
    p.rough = 0.4
    p.hollow = 0.25
    c.p = p
    var leafs := [Color("4c7c2e"), Color("5a8a35"), Color("3f6b2c"), Color("6d8f3a"), Color("7a7a3a"), Color("456f3a")]
    var base: Color = leafs[rng.randi() % leafs.size()]
    var lc := VoxPalette.shades(base, 6, rng, 0.02, 0.1, 0.2)
    c.leaf_s = g.add_ramp(lc)
    c.leaf_n = lc.size()
    if rng.randf() < 0.55:
        var alts := [Color("b3262e"), Color("3b4f9a"), Color("e58fb6"), Color("f0eee0"), Color("e8c530")]
        var ac := VoxPalette.shades(alts[rng.randi() % alts.size()], 3, rng, 0.015, 0.08, 0.1)
        c.alt_s = g.add_ramp(ac)
        c.alt_n = ac.size()
        c.alt_p = rng.randf_range(0.04, 0.12)
    var radius := rng.randf_range(5.0, 11.0)
    var tall := rng.randf_range(0.8, 1.5)
    for i in rng.randi_range(3, 6):
        var a := rng.randf() * TAU
        var dist := rng.randf() * radius
        var r := rng.randf_range(4.0, 7.5)
        var ry := r * rng.randf_range(0.7, 1.0) * tall
        var ctr := Vector3(x + cos(a) * dist, ry * 0.75, z + sin(a) * dist)
        _blob(c, ctr, Vector3(r, ry, r * rng.randf_range(0.85, 1.2)))


# ---------------------------------------------------------------- камни

## rp = [серый1_старт, n, серый2_старт, n, мох_старт, n]
static func add_rock(g: VoxGrid, seed_val: int, x: int, z: int, r: float, rp: PackedInt32Array) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_val
    var noise := _noise(seed_val, 0.2)
    var pick := rng.randf() < 0.5
    var rs := rp[0] if pick else rp[2]
    var rn := rp[1] if pick else rp[3]
    var moss := rng.randf() < 0.45
    var rx := r * rng.randf_range(0.9, 1.3)
    var ry := r * rng.randf_range(0.5, 0.85)
    var rz := r * rng.randf_range(0.9, 1.3)
    var cy := ry * 0.45
    var ext := 1.3
    for y in range(0, ceili(cy + ry * ext) + 1):
        var ny := (y - cy) / ry
        for zz in range(-ceili(rz * ext), ceili(rz * ext) + 1):
            var nz := zz / rz
            for xx in range(-ceili(rx * ext), ceili(rx * ext) + 1):
                var nx := xx / rx
                var s := pow(absf(nx), 2.4) + pow(absf(ny), 2.4) + pow(absf(nz), 2.4)
                if s > 2.2:
                    continue
                var nv := noise.get_noise_3d(xx + x, y, zz + z)
                var dd := pow(s, 1.0 / 2.4) + nv * 0.28
                if dd > 1.0:
                    continue
                var t := 0.5 + ny * 0.35 + nv * 0.35 + rng.randf_range(-0.15, 0.15)
                var idx := rs + clampi(int(t * rn), 0, rn - 1)
                if moss and ny > 0.25 and nv > -0.05:
                    idx = rp[4] + rng.randi_range(0, rp[5] - 1)
                g.put(x + xx, y, z + zz, idx)
    if r >= 5.0:
        var hgt := (cy + ry) * 0.1 * 0.9
        return {"kind": "box", "pos": Vector3(x * 0.1, hgt * 0.5, z * 0.1),
                "size": Vector3(rx * 1.6 * 0.1, hgt, rz * 1.6 * 0.1)}
    return {}


# ---------------------------------------------------------------- цветы

static func make_flower_set(g: VoxGrid, rng: RandomNumberGenerator) -> Array:
    var defs := [
        [Color("d8322b"), Color("2b1a1a"), 0],  # мак
        [Color("4a6fd6"), Color("e8e0a0"), 0],  # василёк
        [Color("f2f0ea"), Color("f0c020"), 1],  # ромашка
        [Color("f2c418"), Color("d89a10"), 2],  # одуванчик
        [Color("e870a0"), Color("f5c0d0"), 3],  # тюльпан
        [Color("8a5fc8"), Color("6a3fa8"), 4],  # лаванда
        [Color("f7e04a"), Color("e0b020"), 0],  # лютик
        [Color("5a7fe0"), Color("3a5fc0"), 3],  # колокольчик
    ]
    var out: Array = []
    for dfn in defs:
        var pet := VoxPalette.shades(dfn[0], 3, rng, 0.01, 0.06, 0.08)
        var ctr := VoxPalette.shades(dfn[1], 2, rng, 0.01, 0.05, 0.06)
        out.append({"ps": g.add_ramp(pet), "pn": pet.size(), "cs": g.add_ramp(ctr),
                "cn": ctr.size(), "shape": dfn[2]})
    return out


static func _pet(g: VoxGrid, rng: RandomNumberGenerator, x: int, y: int, z: int, fl: Dictionary) -> void:
    var ps: int = fl.ps
    var pn: int = fl.pn
    g.put_empty(x, y, z, ps + rng.randi_range(0, pn - 1))


static func _ctr(g: VoxGrid, rng: RandomNumberGenerator, x: int, y: int, z: int, fl: Dictionary) -> void:
    var cs: int = fl.cs
    var cn: int = fl.cn
    g.put_empty(x, y, z, cs + rng.randi_range(0, cn - 1))


static func add_flower(g: VoxGrid, rng: RandomNumberGenerator, x: int, z: int, fl: Dictionary,
        stem_s: int, stem_n: int) -> void:
    var shape: int = fl.shape
    var h := rng.randi_range(5, 10)
    if shape == 4:
        h = rng.randi_range(8, 13)
    for y in h:
        g.put_empty(x, y, z, stem_s + clampi(int(float(y) / h * stem_n), 0, stem_n - 1))
    # листочки у основания
    g.put_empty(x + (1 if rng.randf() < 0.5 else -1), 2, z, stem_s + stem_n - 1)
    g.put_empty(x, 3, z + (1 if rng.randf() < 0.5 else -1), stem_s + stem_n - 1)
    match shape:
        0:
            _ctr(g, rng, x, h, z, fl)
            _pet(g, rng, x + 1, h, z, fl)
            _pet(g, rng, x - 1, h, z, fl)
            _pet(g, rng, x, h, z + 1, fl)
            _pet(g, rng, x, h, z - 1, fl)
        1:
            for dx in range(-1, 2):
                for dz in range(-1, 2):
                    if dx == 0 and dz == 0:
                        _ctr(g, rng, x, h, z, fl)
                    else:
                        _pet(g, rng, x + dx, h, z + dz, fl)
        2:
            for dx in range(-1, 2):
                for dz in range(-1, 2):
                    _pet(g, rng, x + dx, h, z + dz, fl)
            _ctr(g, rng, x, h + 1, z, fl)
            _pet(g, rng, x + 1, h + 1, z, fl)
            _pet(g, rng, x - 1, h + 1, z, fl)
            _pet(g, rng, x, h + 1, z + 1, fl)
            _pet(g, rng, x, h + 1, z - 1, fl)
        3:
            _ctr(g, rng, x, h, z, fl)
            for dx in range(-1, 2):
                for dz in range(-1, 2):
                    if dx != 0 or dz != 0:
                        _pet(g, rng, x + dx, h + 1, z + dz, fl)
            _pet(g, rng, x + 1, h + 2, z, fl)
            _pet(g, rng, x - 1, h + 2, z, fl)
            _pet(g, rng, x, h + 2, z + 1, fl)
            _pet(g, rng, x, h + 2, z - 1, fl)
        _:
            for y in range(h - 5, h + 1):
                _pet(g, rng, x, y, z, fl)
                if (y & 1) == 0:
                    _pet(g, rng, x + 1, y, z, fl)
                    _pet(g, rng, x - 1, y, z, fl)
                else:
                    _pet(g, rng, x, y, z + 1, fl)
                    _pet(g, rng, x, y, z - 1, fl)
            _ctr(g, rng, x, h + 1, z, fl)


# ---------------------------------------------------------------- трава

static func add_blade(g: VoxGrid, rng: RandomNumberGenerator, x: int, z: int, height: int,
        ramp_s: int, ramp_n: int) -> void:
    var lean := rng.randi_range(0, 3)  # 0..1 без наклона, 2: +x, 3: -z
    for y in height:
        var t := float(y) / float(maxi(height - 1, 1))
        var idx := ramp_s + clampi(int(t * ramp_n + rng.randf_range(-0.6, 0.6)), 0, ramp_n - 1)
        var bx := x
        var bz := z
        if height >= 4 and y >= height - 2:
            if lean == 2:
                bx += 1
            elif lean == 3:
                bz -= 1
        g.put_empty(bx, y, bz, idx)
