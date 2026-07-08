# Contributing

Contributions are welcome.

---

## Setup

```bash
git clone https://github.com/whuppi/cellar_flutter.git
cd cellar_flutter
make hooks               # activates commit-msg + pre-commit (run once)
fvm install              # downloads the SDK version pinned in .fvmrc
fvm flutter pub get
fvm flutter test
```

**Requires:** [FVM](https://fvm.app) (`.fvmrc` pins the exact Flutter
version). The `cellar` core resolves from pub.dev at the locked version.
Co-developing against a local core checkout? Drop a gitignored
`pubspec_overrides.yaml` next to each pubspec:

```yaml
dependency_overrides:
  cellar:
    path: ../cellar   # ../../cellar from example/
```

**Without FVM:** all Makefile commands accept `DART` and `FLUTTER`
overrides:

```bash
make check DART=dart FLUTTER=flutter
```

---

## Before submitting a PR

```bash
make check
```

Runs `format` + `analyze` (package + example) + `analyze-floor`
(lowest allowed deps) + `lint-shell` + `platforms` (pana attribution)
+ `test` (the openCellar root-resolution tests) +
`test-example-matrix` (the example app's UI journeys across every
device profile, on the host VM). Must pass. Don't suppress with
`// ignore:` — fix the underlying issue.

Touching the `cellar` core too? Its changes land in its own repo and
release first; the Dependabot bump PR here runs the full matrix against
that release.

---

## PR workflow

All PRs target `dev`. That's the only branch contributors touch.

```
your fork / feature branch ──PR──► dev
                                    ↓ CI: make targets via the make-target action
                                    ↓ PR title: Conventional Commits (feat: / fix: / etc.)
                                    ↓ squash-merge when green
                                    ↓ Full test suite via "ready-to-test" label
                                      (journeys × OS, real-device integration smokes)
```

CI calls Makefile targets — same commands locally and in CI.

You don't write changelog entries, bump versions, or touch `prod`.
The maintainer handles releases.

---

## Code style

- Match existing code in the repo.
- This package holds ONLY what needs the Flutter engine. Anything pure
  Dart belongs in the `cellar` core — including web code (`package:web`
  is SDK, not Flutter).
- path_provider is imported ONLY inside `flutter_roots_native.dart`,
  behind the stub-default conditional import — its API returns
  `dart:io` types, which don't compile for web.
- `openCellar` mirrors the core's `Cellar` constructor parameter for
  parameter — a new core parameter means the same parameter here,
  forwarded, in the same PR.
- The example app is the living demo: one file, seven tabs, journeys
  + integration smoke. New capability in the core → new op button +
  journey step there.

---

## Adding parameters, upgrading the core

Step-by-step recipes in [`docs/UPDATING.md`](docs/UPDATING.md).

---

## Releases

Handled by the maintainer. Details in [`docs/UPDATING.md`](docs/UPDATING.md).
