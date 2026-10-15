#!/usr/bin/env bash
# Usage: build-info.sh stamp | verify
#
# `stamp` overwrites the build-info source with the checkout's commit and dirty
# flag; `verify` fails unless the committed file is in its `None` form.
set -euo pipefail

target="redmoon/src/build/info.mbt"

render() {
  local build="$1"
  cat <<MBT
///|
/// The commit a binary was built from.
pub(all) struct BuildInfo {
  commit : String
  dirty : Bool
} derive(ToJson)

///|
pub extend BuildInfo with ToJson::{to_json}

///|
/// The build info embedded in this binary; CI overwrites this file before a
/// release build, so a build from source reports \`None\`.
pub let build : BuildInfo? = ${build}
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
  render "Some({ commit: \"${commit}\", dirty: ${dirty} })" >"$target"
  ;;
verify)
  if ! render None | diff -u - "$target"; then
    echo "$target must be committed in its None form" >&2
    exit 1
  fi
  ;;
*)
  echo "usage: $0 stamp|verify" >&2
  exit 2
  ;;
esac
