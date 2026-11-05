#!/usr/bin/env bash
# Usage: build-info.sh stamp | verify
#
# Only the `pub let build` line is touched, so the rest of info.mbt is owned by
# the source alone and a comment edit there needs no change here.
set -euo pipefail

target="redmoon/src/build/info.mbt"
prefix="pub let build : BuildInfo? = "

case "${1:-}" in
stamp)
  commit="$(git rev-parse HEAD)"
  if [ -n "$(git status --porcelain)" ]; then
    dirty=true
  else
    dirty=false
  fi
  BUILD="Some({ commit: \"${commit}\", dirty: ${dirty} })" PREFIX="$prefix" \
    perl -pi -e 's/^\Q$ENV{PREFIX}\E.*$/$ENV{PREFIX}$ENV{BUILD}/' "$target"
  if ! grep -Fq "${prefix}Some(" "$target"; then
    echo "$target has no '${prefix}' line to stamp" >&2
    exit 1
  fi
  ;;
verify)
  if ! grep -Fxq "${prefix}None" "$target"; then
    echo "$target must be committed in its None form" >&2
    exit 1
  fi
  ;;
*)
  echo "usage: $0 stamp|verify" >&2
  exit 2
  ;;
esac
