# Capability Roadmap

Statuses: **DONE** · **BUILDING** · **PLANNED** · **WONT_DO** (with
reason). The core's capabilities live in
[`cellar/docs/CAPABILITY_ROADMAP.md`](../cellar/docs/CAPABILITY_ROADMAP.md).

| Capability | Status | Notes |
|---|---|---|
| `openCellar` (resolve + open, all six platforms) | DONE | Mirrors the core constructor's parameters |
| Full core re-export (one-import rule) | DONE | |
| Stub-default conditional import (web never compiles path_provider) | DONE | |
| Package tests (fake platform seam, roots proven used) | DONE | |
| Example app + journeys + per-platform smoke | DONE | Lives in `example/` |
| Full gate set (analyze / analyze-floor / lint-shell / pana platforms / verify-web dart2js+wasm) | DONE | Stock platforms gate — the `cellar/` submodule travels inside pana's snapshot, so the path dep resolves; verdict 6/6 platforms |
| CI via the shared workflow repo | BUILDING | Stock single-package callers (fast PR gate + label-triggered full-test with the example legs + release lanes); first real run at repo go-live |
| Repo go-live (GitHub whuppi/cellar_flutter, submodule URL flip, branch protection) | DONE | Live with device_io-parity settings; `.gitmodules` points at github.com/whuppi/cellar and a fresh `--recursive` clone resolves it |
| Publish to pub.dev | PLANNED | Maintainer-gated; release flow swaps the submodule path dep to the published `cellar` version |
| Extra Flutter sugar (lifecycle widgets, provider glue) | WONT_DO | The package stays a front door; app-state patterns belong to apps |
