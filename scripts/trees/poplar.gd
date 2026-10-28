extends RefCounted
## Параметры кроны и ветвления: poplar.

static func configure(p, rng: RandomNumberGenerator, s: float) -> void:
    p.bark = Color("625b51")
    p.leaf = Color("4b7840")
    p.leaf_alt = Color("729357")
    p.trunk_h = rng.randf_range(250.0, 320.0) * s
    p.r0 = 3.2 * s
    p.r1 = 1.2 * s
    p.wobble = 0.025
    p.lean = 0.025
    p.br_min = 13
    p.br_max = 18
    p.br_start = 0.16
    p.br_taper = 0.55
    p.br_len_min = 28.0 * s
    p.br_len_max = 44.0 * s
    p.pitch_min = 1.02
    p.pitch_max = 1.38
    p.crook = 0.10
    p.sub_prob = 0.25
    p.max_depth = 0
    p.lobe_min = 7.5 * s
    p.lobe_max = 13.0 * s
    p.lobe_flat = 1.8
    p.density = 0.94
    p.rough = 0.62
    p.hollow = 0.38
    p.top_lobe = 1.1
    p.fill_p = 0.32
