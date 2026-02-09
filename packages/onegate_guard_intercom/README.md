# onegate_guard_intercom

Plug-and-play Guard Intercom feature package.

## Host integration

1. Add dependency (path during development):
   - `onegate_guard_intercom: { path: packages/onegate_guard_intercom }`
   - `onegate_feature_core: { path: packages/onegate_feature_core }`
2. Implement `FeatureHost` in your app shell.
3. Call:
   - `startIntercom(context, host: myHost);`

This package is intentionally decoupled from app singletons and expects the host to provide auth + society context.

