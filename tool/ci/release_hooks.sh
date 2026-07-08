# shellcheck shell=bash
# cellar_flutter's consumer-extension for the shared release.sh — sourced by
# the release flow inside the stamped tag commit. Source, don't execute.
#
# The swap (why this hook exists)
# ───────────────────────────────
# Development resolves the cellar core from the pinned git submodule (the
# `cellar:` path dep). A published package can't carry a path dep, and the
# only honest version to publish against is the one the pin certifies —
# every journey and smoke ran against exactly that commit, never "latest".
# So inside the stamped release tree this hook:
#   1. reads the pin's release tag (`git describe --exact-match`) — the
#      release ABORTS if the pin doesn't sit exactly on a published cellar
#      tag: release cellar first, bump the pin here, then release this,
#   2. rewrites the dep to `cellar: ^<pin-version>` — caret with the
#      certified version as the floor (resolver-friendly; semver guards the
#      range above; the floor is never "whatever pub.dev has"),
#   3. drops the submodule from the tag tree — the hosted dep replaces it
#      for pub-tarball and `git: ref:` consumers alike (the shared flow's
#      de-registration has already inlined it by the time this runs, so the
#      inlined copy and its false_secrets entry are removed here too).
release_stamp_tree() {
  local tag="$1"
  echo "── cellar path dep → hosted swap (pin-certified version)"

  local core_tag
  core_tag=$(git -C cellar describe --tags --exact-match 2>/dev/null) || {
    echo "::error::the cellar submodule pin ($(git -C cellar rev-parse --short HEAD 2>/dev/null || echo 'unreadable')) is not on a cellar release tag — release cellar first, bump the pin, then release cellar_flutter ($tag)" >&2
    return 1
  }
  local core_version="${core_tag#v}"

  python3 - "$core_version" <<'PY'
import re
import sys

version = sys.argv[1]
path = 'pubspec.yaml'
src = open(path).read()

# The path dep (with its dev-time comment block above it) becomes the
# hosted, pin-certified caret dep.
new, n = re.subn(
    r'(  # [^\n]*\n)*  cellar:\n    path: cellar\n',
    f'  cellar: ^{version}\n',
    src,
)
if n != 1:
    sys.exit(f'expected exactly one cellar path dep in pubspec.yaml, found {n}')

# The shared de-registration adds a false_secrets entry for the inlined
# submodule; the directory is dropped below, so the entry goes too.
new = new.replace('false_secrets:\n  - /cellar/**\n', '')
new = new.replace('  - /cellar/**\n', '')

open(path, 'w').write(new)
PY

  git rm -q -r --cached cellar 2>/dev/null || true
  rm -rf cellar
  echo "  cellar dep → ^$core_version (from pin tag $core_tag); submodule dropped from the tag tree"
}
