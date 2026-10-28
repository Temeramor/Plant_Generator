# Voxel Flora (Godot 4.x)

Процедурная воксельная растительность (воксель 0.1 м), зависящая только от сида.

Запуск: откройте папку в Godot, нажмите F5. Сид — переменная `world_seed` у узла Main
(или аргумент `-- --seed=777`). ПК: WASD + пробел, мышь — как "палец" (эмуляция тача).

Настройки: `scripts/chunk_gen.gd` (TREE_DENSITY, GRASS_CLUMPS), `scripts/world.gd` (view_radius, lod0_radius),
параметры видов деревьев — `PlantGen._params`.

Android: Project > Install Android Build Template, Project > Export > Android, ориентация уже landscape,
рендерер GL Compatibility.
