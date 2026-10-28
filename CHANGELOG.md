# Changelog

- Added a comparison branch with exactly five fixed trees (one per species); all existing grass, flowers, bushes and rock generation remains unchanged.

- Straighter tree trunks with stronger vertical correction towards the top.
- Split species parameter profiles into separate scripts under `scripts/trees/` for easier tuning.
- Broadened and roughened birch foliage with drooping branches; broadened horse-chestnut crown and lowered its thicker branches; made poplar foliage fuller and more vertical.
- Reshaped spruce foliage into a hollow cone with thick needle-covered branch ends rather than a filled centre.
- Strengthened the oak silhouette, trunk and exposed roots; increased oak spawn weight in broadleaf regions.
- Pruned isolated leaf voxels with no adjacent occupied voxel, allowing diagonal connectivity.
- Reduced empty tree-grid bounds while preserving direct 0.2 m generation for distant LOD trees.
