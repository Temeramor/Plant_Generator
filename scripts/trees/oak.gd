extends RefCounted
## Параметры кроны и ветвления: oak.

static func configure(p, rng: RandomNumberGenerator, s: float) -> void:
    p.bark = Color("5b4631")
    p.leaf = Color("4f7d2b")
    p.leaf_alt = Color("8aaa3a")
    p.trunk_h = rng.randf_range(205.0, 255.0) * s
    p.r0 = 7.2 * s
    p.r1 = 2.8 * s
    p.wobble = 0.055
    p.lean = 0.05
    p.roots = 5
    p.root_len_min = 12.0
    p.root_len_max = 18.0
    p.br_min = 6
    p.br_max = 8
    p.br_start = 0.28
    p.br_taper = 0.9
    p.br_len_min = 50.0 * s
    p.br_len_max = 68.0 * s
    p.pitch_min = -0.14
    p.pitch_max = 0.45
    p.crook = 0.22
    p.droop = 0.08
    p.sub_prob = 0.8
    p.sub_angle = 0.85
    p.max_depth = 1
    p.lobe_min = 12.0 * s
    p.lobe_max = 18.0 * s
    p.lobe_flat = 0.70
    p.density = 0.95
    p.rough = 0.62
    p.hollow = 0.48
    p.fill_p = 0.58
