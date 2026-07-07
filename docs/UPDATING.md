# Updating cellar_flutter

Maintenance recipes. Architecture: [`ARCHITECTURE.md`](ARCHITECTURE.md).
The core's recipes: [`cellar/docs/UPDATING.md`](../cellar/docs/UPDATING.md).

---

## The pinned-behavior watchlist

| Pinned behavior | Where | Re-verify when |
|---|---|---|
| path_provider directory semantics: `getApplicationSupportDirectory` (persistent) vs `getApplicationCacheDirectory` (OS may evict on iOS/Android) | `flutter_roots_native.dart` — feeds `StorageRoots.support`/`.cache`, which the core's `osManaged` flag selects between | any path_provider bump |
| path_provider's API returns dart:io types (why the conditional import exists) | `flutter_roots.dart` switch | any path_provider major — if it ever goes dart:io-free, the web branch could unify |

## S1 — Add a parameter to openCellar

Mirror the core's `Cellar` default constructor exactly — openCellar is
a pass-through plus roots. New core constructor parameter → same
parameter here, forwarded. Test: the package test constructs with it.

## S2 — Bump the core pin

`cellar` is a pinned git submodule at `cellar/` (pubspec path dep into
it). To pick up core changes: land them in whuppi/cellar first, then
`cd cellar && git fetch && git checkout <ref>`, `cd .. && git add
cellar`, commit, and run `make check`. The submodule-commit trap
applies (workspace rule): never leave the pin pointing at a commit
that isn't pushed in the core repo.

## S3 — Release

Same two-lane changelog model as the core (`CHANGELOG.pre.md` dev /
`CHANGELOG.md` stable), stamped by the release tooling when the repo
opens. The packages version independently; this one constrains its
`cellar` dependency to the compatible range at publish time.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Web build fails compiling path_provider (`dart:io` unavailable) | Something imported `flutter_roots_native.dart` directly | Only `flutter_roots.dart` (the conditional switch) may import the branch files; import that |
| `openCellar` throws `StateError` about roots on a real device | path_provider returned null paths (no platform implementation registered) | Run through a full Flutter app build — the plugin registrant only exists there, not in plain `dart` runs |
| Package tests can't fake path_provider | Fake set on the wrong seam | Set `PathProviderPlatform.instance` (the platform interface), as `test/open_cellar_test.dart` does |
