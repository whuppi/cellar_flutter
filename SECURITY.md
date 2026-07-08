# Security Policy

Covers `cellar_flutter` — the Flutter front door. The storage engine itself (encryption seam, tenant scoping, key grammar, durability) is the `cellar` core, consumed from pub.dev at the locked version; its policy lives at [whuppi/cellar](https://github.com/whuppi/cellar/blob/dev/SECURITY.md) — engine reports go there.

## Reporting a vulnerability

Report privately via [GitHub Security Advisories](https://github.com/whuppi/cellar_flutter/security/advisories/new). Do not open a public issue.

## What's in scope

- **Root resolution landing outside the app's private area** — `openCellar` promises storage under the OS-granted support/cache directories. If the resolution ever hands the core a directory outside the app sandbox (a path-join bug, a platform-channel value used unvalidated), that's a security report.

- **The re-export lying about the core** — this package re-exports `package:cellar` wholesale. A packaging mistake that ships against a different core than the release notes name (wrong version constraint at publish) is in scope here, because this repo owns the constraint.

## What's NOT in scope

- **Everything the engine does with the bytes** — encryption, scoping, key validation, atomicity. That's the core's policy (link above); reports there.

- **path_provider itself** — the directory values come from the Flutter plugin; bugs inside it go to [flutter/packages](https://github.com/flutter/packages/issues).

- **The example app** — a demo, never shipped to consumers.

## Operational notes (known, accepted)

- **The core version is locked, not floating** — a core security fix reaches this package one dependency bump later, not automatically; the caret range lets consumer apps pick the fix up immediately.

## Response

Valid reports are fixed and shipped as patch versions.
