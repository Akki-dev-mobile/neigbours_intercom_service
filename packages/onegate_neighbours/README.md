# onegate_neighbours

Plug-and-play Neighbours feature package.

## Host integration

1. Add dependency (path during development):
   - `onegate_neighbours: { path: packages/onegate_neighbours }`
   - `onegate_feature_core: { path: packages/onegate_feature_core }`
2. Implement `FeatureHost` in your app shell.
3. Call:
   - `openNeighbours(context, host: myHost);`

This package is intentionally decoupled from app singletons and expects the host to provide auth + society context.

