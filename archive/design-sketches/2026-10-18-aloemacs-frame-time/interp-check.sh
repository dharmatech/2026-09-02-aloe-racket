#!/bin/bash
# Name each aloe/ module whose phase-0 body Racket CS compiles in
# interpretable mode, because it is larger than PLT_CS_COMPILE_LIMIT.
# Scratch script from the 2026-10-18 frame-time discussion; not a test.
#   interp-check.sh <work-dir> [limit]     (limit defaults to 10000, Racket's)
# Copies aloe/ into <work-dir>, compiles every module there with
# PLT_LINKLET_SHOW_POST_INTERP=1, and reports the module linklets that took
# the post-interp step. At 21d1a36 with the default limit: eval and type.
set -e
repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
work=$1; limit=${2:-10000}
rm -rf "$work" && mkdir -p "$work"
cp -a "$repo/aloe" "$work/"
find "$work" -name compiled -prune -exec rm -rf {} +
(cd "$work" && PLT_CS_COMPILE_LIMIT=$limit PLT_LINKLET_SHOW_POST_INTERP=1 \
   TMPDIR=/tmp raco make aloe/*.rkt > linklets.txt 2>&1)
grep -E '^;; compile-linklet: (module|phase|name|step)' "$work/linklets.txt" |
  awk '/module:/{m=$4} /phase:/{p=$4} /name:/{n=$4}
       /step: post-interp/ && m != "#f" {print m, "phase", p, n}' | sort -u
