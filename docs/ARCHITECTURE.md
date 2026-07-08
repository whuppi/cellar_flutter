# cellar_flutter — Architecture

How the package is wired. One call (`openCellar`), one conditional
import, one re-export of the core. For capability status see
[`CAPABILITY_ROADMAP.md`](CAPABILITY_ROADMAP.md); for maintenance
recipes see [`UPDATING.md`](UPDATING.md); for the engine itself see the
[core's docs](https://github.com/whuppi/cellar/tree/v1.0.0-dev.0/docs).

---

## The contract

One job: give Flutter apps `openCellar` — a single call, identical on
all six platforms, that resolves the storage roots, opens, and returns
a ready `Cellar`. Everything else is a re-export of `package:cellar`.

The load-bearing promises:

1. **One import.** `package:cellar_flutter/cellar_flutter.dart`
   re-exports the full core API; apps never also import `cellar`.
2. **No platform branches in app code.** `openCellar` is byte-identical
   on iOS, Android, macOS, Windows, Linux, and web. The conditional
   machinery lives HERE, once.
3. **Web builds never compile path_provider.** Its API returns dart:io
   types, which don't compile for web — so the glue sits behind a
   conditional import whose web branch returns null (IndexedDB needs no
   roots) and whose STUB is the default target (pana attribution).
4. **This package is where the autos live.** The core never guesses
   storage locations — native roots are caller-supplied, always. The
   sugar that answers "where?" for a Flutter app is the path_provider
   ask, and it lives here, uniformly on every native platform.

---

## The file tree

```
lib/
  cellar_flutter.dart          ← barrel: re-export cellar + openCellar
  src/
    flutter_roots.dart         ← conditional switch (stub default)
    flutter_roots_native.dart  ← path_provider → StorageRoots
    flutter_roots_web.dart     ← null (IndexedDB needs no roots)
    flutter_roots_stub.dart    ← neutral default target
    open_cellar.dart           ← openCellar: resolve → construct → open
example/                       ← the 7-tab demo app (journeys + smoke)
```

---

## Test architecture

The package's own tests fake path_provider at its platform-interface
seam and prove `openCellar` (a) round-trips data, (b) actually lands
storage under the resolved roots, (c) splits `osManaged` partitions to
the cache root.

The example app carries the heavy layers: host-VM journeys (six device
profiles, memory disk) and per-platform integration smokes — the smoke
is where openCellar's REAL path_provider path is proven per platform,
Android included. See the test-architecture section of the core's `ARCHITECTURE.md` for the model.

---

## The one-line summary

> **openCellar = resolve roots (path_provider, behind a stub-default
> conditional import) → construct → open → return. One import, one
> call, six platforms, zero branches in app code. Everything else is
> the core, re-exported.**
