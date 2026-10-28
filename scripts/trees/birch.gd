extends RefCounted
## Параметры кроны и ветвления: birch.

static func configure(p, rng: RandomNumberGenerator, s: float) -> void:
    p.bark = Color("e6e2d8")
    p.leaf = Color("6b9a32")
    p.leaf_alt = Color("a7c24a")
    p.spot = true
    p.trunk_h = rng.randf_range(165.0, 215.0) * s
    p.r0 = 2.6 * s
    p.r1 = 0.8 * s
    p.wobble = 0.06
    p.lean = 0.08
    p.br_min = 9
    p.br_max = 13
    p.br_start = 0.30
    p.br_taper = 0.55
    p.br_len_min = 30.0 * s
    p.br_len_max = 46.0 * s
    p.pitch_min = 0.25
    p.pitch_max = 0.88
    p.crook = 0.22
    p.droop = 0.68
    p.sub_prob = 0.72
    p.sub_angle = 0.95
    p.max_depth = 1
    p.lobe_min = 8.0 * s
    p.lobe_max = 12.0 * s
    p.lobe_flat = 0.95
    p.density = 0.93
    p.rough = 0.68
    p.hollow = 0.38
    p.fill_p = 0.6
