<!--
============================================================================
AUTO-GENERATED — DO NOT EDIT
============================================================================
This file is rendered by:
  /Users/deepanshu/personal1/whuppi/.claude/scripts/stamp-agents.sh
from:
  /Users/deepanshu/personal1/whuppi/AGENTS.template.md
  with per-repo data inlined in the stamper itself.

To change content:
  - Workspace-wide: edit AGENTS.template.md, then re-run the stamper.
  - One repo only:  edit the `repo_data` case for "cellar_flutter" in stamp-agents.sh,
                    then re-run the stamper.
Manual edits to this file will be overwritten on the next stamp.
============================================================================
-->

# cellar_flutter

> **Public AI agent contract** for cellar_flutter — read by Cursor, OpenAI Codex, Aider, Devin, JetBrains Junie, and any AI tool that follows the [agents.md](https://agents.md) convention.
>
> Claude Code reads the deeper workspace config at `whuppi/.claude/rules/` and `whuppi/.claude/memory/` automatically — this AGENTS.md exists for every *other* AI tool.
>
> Stamped from `whuppi/AGENTS.template.md`. Per-repo content lives in the placeholder sections; everything else is identical workspace-wide.

---

## What this tool does

cellar_flutter is the Flutter front door for the pure-Dart `cellar`
object-storage core (a hosted dependency, version-locked). It holds ONLY
what needs the Flutter engine: `openCellar()`, which resolves the
platform storage roots via path_provider (behind a stub-default
conditional import — web builds never compile path_provider) and
returns an opened, ready `Cellar`. The full core API is re-exported, so
one import serves a Flutter app on iOS, Android, macOS, Windows, Linux,
and web. The seven-tab example app, its device-matrix journeys, and the
per-platform integration smoke live here.

This repo is one tool inside the **whuppi** workspace — a multi-tool monorepo. The workspace ships shared engineering standards, code conventions, brand identity, and build patterns that apply across every tool. They're documented in three layers:

- **Repo-specific architecture, design, reference:** `./docs/`
- **Workspace human-readable standards:** `../docs/` (when this repo is cloned as part of the whuppi workspace) — engineering principles, decision frameworks, secret/CI patterns
- **Workspace AI-only directives:** `../.claude/rules/` (Claude Code reads these automatically; other AI tools can read them as supplementary context)

If you're working on this tool standalone (cloned outside the workspace), the in-repo `./docs/` is your authority; ignore the workspace pointers.

---

## Build and test commands

Run these after every code change. A failing test or analyzer error means the task is not done — don't suppress with `// ignore:`, `# noqa`, or `--no-verify`. Fix the underlying issue.

```bash
make check                # full gate: format + analyze (package + example)
                          # + package tests + example journey matrix
make test                 # openCellar root-resolution tests (flutter test)
make test-example-matrix  # example journeys, six device profiles, host VM
make test-example-macos   # integration smoke on a real platform
make verify-web           # example release-builds for web
```

---

## Code style

Match the style of existing code in this repo first. Workspace-wide standards live at:

- **Engineering standards** (seven questions before every decision, env-blind code, twelve-factor checklist): `../docs/universal/development-standards.md`
- **Secrets and environments** (GitHub Environments, branch=env, security walls, files-not-env-vars): `../docs/universal/secrets-and-environments.md`
- **Python tools** (SDK/CLI/MCP three-layer pattern, ruff config, hatchling): `../.claude/rules/python-shared/sdk-cli-mcp-pattern.md`
- **Flutter packages** (opaque boundaries, async at edges, dependency flow): `../.claude/rules/flutter-shared/package-design.md`
- **Comments and doc-comments** (what earns a comment, what doesn't): `../.claude/rules/universal/comments.md`
- **Renaming anything** (sweep all references in one session): `../.claude/rules/universal/rename-hygiene.md`

When in doubt, read existing code in this repo and match it. Per-repo style consistency beats general-best-practice consistency.

---

## Tool-specific notes

- **Only engine-bound code lives here.** Anything pure Dart — including
  web code (`package:web` is SDK, not Flutter) — belongs in the
  `cellar` core (its own repo; consumed from pub.dev at the locked
  version). This package exists because path_provider needs the Flutter
  plugin chain.
- **path_provider is imported ONLY in `flutter_roots_native.dart`**,
  behind the conditional import in `flutter_roots.dart` — its API
  returns dart:io types, which don't compile for web. Never import the
  branch files directly.
- **`openCellar` mirrors the core's `Cellar` constructor parameter for
  parameter.** A new core parameter means the same parameter here,
  forwarded, in the same change.
- **The core is a hosted dependency; `pubspec.lock` is the pin.**
  Core changes land and release in whuppi/cellar first; the Dependabot
  bump PR here certifies them against the matrix. For local
  co-development use a gitignored `pubspec_overrides.yaml`
  (`cellar: {path: ../cellar}`).
- **Tests fake path_provider at `PathProviderPlatform.instance`** (the
  platform-interface seam) and assert storage actually lands under the
  fake roots — never just that calls succeed.

---

## Data, secrets, and gitignore

This repo's `.gitignore` is stamped from `../.gitignore.template` (workspace canonical). It already covers:

- `data/.env` and every other `.env` flavor (only `.env.example` / `.env.template` / `.env.sample` are committed)
- `data/auth/` (captured tokens, cookies, OAuth credentials)
- `data/db/*.sqlite*` (full app state — irreplaceable)
- `cookies*.json`, `*.token`, `*.pem`, `*.key`
- `output/`, `debug/`, `logs/`, `cache/`

Never commit a sensitive file even if it's somehow not gitignored — surface to the maintainer instead. The gitignore is defense-in-depth, not the only check.

---

## Working with AI agents

- **Run the test suite before claiming completion.** Always.
- **Don't add `TODO` comments as a substitute for fixing things.** If you found it, you own it — fix in this pass or surface to the maintainer.
- **Don't add backwards-compat shims** for code that hasn't shipped. Code assumes the latest schema and contracts; migrations handle old data once.
- **Don't refactor "for cleanliness" without a stated reason.** Surface the suggestion before changing surrounding code.
- **No co-authored-by AI in commits.** The maintainer is the author.
- **Never force-push protected branches** (`prod`, `main`, `dev`). Never skip pre-commit hooks.

For the engineering philosophy that informs every line of code in this workspace, see `../.claude/rules/universal/dc-engineering-philosophy.md` if available.

---

*This file is stamped from `whuppi/AGENTS.template.md`. The placeholder sections (`{{...}}`) are the only parts customized per repo. Re-stamping refreshes the shared content; per-repo placeholders are preserved.*
