extends RefCounted
## Параметры кроны и ветвления: chestnut.

static func configure(p, rng: RandomNumberGenerator, s: float) -> void:
    p.bark = Color("4a3a2a")
    p.leaf = Color("3f6b24")
    p.leaf_alt = Color("6f9a30")
    p.trunk_h = rng.randf_range(185.0, 245.0) * s
    p.r0 = 5.8 * s
    p.r1 = 2.6 * s
    p.wobble = 0.1
    p.lean = 0.08
    p.roots = 5
    p.root_len_min = 9.0
    p.root_len_max = 14.0
    p.br_min = 6
    p.br_max = 8
    p.br_start = 0.19
    p.br_taper = 0.94
    p.br_len_min = 58.0 * s
    p.br_len_max = 76.0 * s
    p.pitch_min = -0.10
    p.pitch_max = 0.42
    p.crook = 0.24
    p.droop = 0.12
    p.sub_prob = 0.78
    p.sub_angle = 0.9
    p.max_depth = 1
    p.lobe_min = 14.0 * s
    p.lobe_max = 20.0 * s
    p.lobe_flat = 0.68
    p.density = 0.96
    p.rough = 0.58
    p.hollow = 0.52
    p.fill_p = 0.65
