#!/bin/bash
# Run tests/aloemacs/window-pictures.rkt alone at several commits, round-robin,
# and print its three medians (first screen, widest leaf deep, one window deep).
# Scratch script from the 2026-10-18 frame-time discussion; not a test.
#   bisect.sh <work-dir> <rounds> <commit>...
# Each commit is extracted with git archive into <work-dir>/<commit> (the
# checkout is not touched) and its test compiled there. Set
# PLT_CS_COMPILE_LIMIT before the call to compile with another limit; a
# commit already extracted keeps the bytecode it has.
set -e
repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
work=$1; rounds=$2; shift 2
mkdir -p "$work"
for c in "$@"; do
  if [ ! -d "$work/$c" ]; then
    mkdir -p "$work/$c"
    git -C "$repo" archive "$c" | tar -x -C "$work/$c"
    (cd "$work/$c" && TMPDIR=/tmp raco make tests/aloemacs/window-pictures.rkt)
  fi
done
for r in $(seq 1 "$rounds"); do
  for c in "$@"; do
    out=$(cd "$work/$c" && TMPDIR=/tmp racket tests/aloemacs/window-pictures.rkt 2>&1 || true)
    pick() { printf '%s\n' "$out" | grep -oE "$1: median [0-9.]+" | head -1 | awk '{printf "%.1f", $NF}'; }
    echo "round $r $c first $(pick 'first screen') wide-deep $(pick 'widest leaf deep') one-deep $(pick 'one window, deep')"
  done
done
