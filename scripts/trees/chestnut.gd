extends RefCounted
## Параметры кроны и ветвления: chestnut.

static func configure(p, rng: RandomNumberGenerator, s: float) -> void:
    p.bark = Color("6d6257")
    p.leaf = Color("3e713d")
    p.leaf_alt = Color("5f8849")
    p.trunk_h = rng.randf_range(185.0, 245.0) * s
    p.r0 = 7.8 * s
    p.r1 = 3.1 * s
    p.wobble = 0.1
    p.lean = 0.08
    p.roots = 5
    p.root_len_min = 9.0
    p.root_len_max = 14.0
    p.br_min = 7
    p.br_max = 9
    p.br_start = 0.09
    p.br_taper = 0.94
    p.br_len_min = 78.0 * s
    p.br_len_max = 104.0 * s
    p.pitch_min = -0.10
    p.pitch_max = 0.42
    p.crook = 0.24
    p.droop = 0.12
    p.sub_prob = 0.78
    p.sub_angle = 0.9
    p.max_depth = 1
    p.lobe_min = 16.0 * s
    p.lobe_max = 24.0 * s
    p.lobe_flat = 0.60
    p.density = 0.78
    p.rough = 0.64
    p.hollow = 0.62
    p.fill_p = 0.42
