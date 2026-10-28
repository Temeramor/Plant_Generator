extends RefCounted
## Параметры кроны и ветвления: oak.

static func configure(p, rng: RandomNumberGenerator, s: float) -> void:
    p.bark = Color("51483d")
    p.leaf = Color("3f632e")
    p.leaf_alt = Color("607d3b")
    p.trunk_h = rng.randf_range(205.0, 255.0) * s
    p.r0 = 12.0 * s
    p.r1 = 4.6 * s
    p.wobble = 0.055
    p.lean = 0.05
    p.roots = 5
    p.root_len_min = 12.0
    p.root_len_max = 18.0
    p.br_min = 8
    p.br_max = 10
    p.br_start = 0.12
    p.br_taper = 0.9
    p.br_len_min = 72.0 * s
    p.br_len_max = 96.0 * s
    p.pitch_min = -0.14
    p.pitch_max = 0.45
    p.crook = 0.22
    p.droop = 0.08
    p.sub_prob = 0.8
    p.sub_angle = 0.85
    p.max_depth = 1
    p.lobe_min = 14.0 * s
    p.lobe_max = 21.0 * s
    p.lobe_flat = 0.62
    p.density = 0.79
    p.rough = 0.68
    p.hollow = 0.60
    p.fill_p = 0.38
