# Capability Roadmap

Statuses: **DONE** · **BUILDING** · **PLANNED** · **WONT_DO** (with
reason). The core's capabilities live in the
[cellar roadmap](https://github.com/whuppi/cellar/blob/v1.0.0-dev.0/docs/CAPABILITY_ROADMAP.md).

| Capability | Status | Notes |
|---|---|---|
| `openCellar` (resolve + open, all six platforms) | DONE | Mirrors the core constructor's parameters |
| Full core re-export (one-import rule) | DONE | |
| Stub-default conditional import (web never compiles path_provider) | DONE | |
| Package tests (fake platform seam, roots proven used) | DONE | |
| Example app + journeys + per-platform smoke | DONE | Lives in `example/` |
| Full gate set (analyze / analyze-floor / lint-shell / pana platforms / verify-web dart2js+wasm) | DONE | Stock gates over the hosted core dep; pana verdict 6/6 platforms |
| CI via the shared workflow repo | BUILDING | Stock single-package callers (fast PR gate + label-triggered full-test with the example legs + release lanes); first real run at repo go-live |
| Repo go-live (GitHub whuppi/cellar_flutter, branch protection, environments) | DONE | Live with device_io-parity settings |
| Publish to pub.dev | PLANNED | Maintainer-gated. The core is a hosted dep (`^1.0.0-dev.0`, lock-certified) — no release-time rewriting needed; cellar releases first when a change spans both |
| Extra Flutter sugar (lifecycle widgets, provider glue) | WONT_DO | The package stays a front door; app-state patterns belong to apps |
