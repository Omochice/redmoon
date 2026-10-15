#!/usr/bin/env bash
# Usage: build-info.sh stamp | verify
#
# `stamp` overwrites the build-info source with the checkout's commit and dirty
# flag; `verify` fails unless the committed file is in its all-`None` form.
set -euo pipefail

target="redmoon/src/build/info.mbt"

render() {
  local commit="$1" dirty="$2"
  cat <<MBT
///|
/// The commit the binary was built from; CI overwrites this file before a
/// release build, so a build from source reports \`None\`.
pub let commit : String? = ${commit}

///|
/// Whether the tree had uncommitted changes at build time.
pub let dirty : Bool? = ${dirty}
MBT
}

case "${1:-}" in
stamp)
  commit="$(git rev-parse HEAD)"
  if [ -n "$(git status --porcelain)" ]; then
    dirty=true
  else
    dirty=false
  fi
  render "Some(\"${commit}\")" "Some(${dirty})" >"$target"
  ;;
verify)
  if ! render None None | diff -u - "$target"; then
    echo "$target must be committed in its all-None form" >&2
    exit 1
  fi
  ;;
*)
  echo "usage: $0 stamp|verify" >&2
  exit 2
  ;;
esac
