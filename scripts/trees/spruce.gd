extends RefCounted
## Параметры кроны и ветвления: spruce.

static func configure(p, rng: RandomNumberGenerator, s: float) -> void:
    p.bark = Color("594b3d")
    p.leaf = Color("294f36")
    p.leaf_alt = Color("426848")
    p.alt_p = 0.04
    p.trunk_h = rng.randf_range(250.0, 335.0) * s
    p.r0 = 3.2 * s
    p.r1 = 0.8 * s
    p.wobble = 0.02
    p.lean = 0.02
    p.roots = 3
    p.br_len_min = 28.0 * s
    p.br_len_max = 42.0 * s
    p.lobe_min = 4.5 * s
    p.lobe_max = 7.5 * s
    p.density = 0.96
    p.rough = 0.38
    p.hollow = 0.42
