# Editor class-name definition

Local experiment. Not Aloe law. Not Gel. Not a global checkpoint.

Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

Series identity `definition`, spoken **editor-definition 000**.
Checkpoints live in `checkpoints/` and are numbered from 000. The
manager writes one, then stops. Tests live in
`tests/editor/definition/`. Code stays in the project root.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment that produces the spec |
| [`spec.md`](spec.md) | Design specification. Reviewed 2026-10-14; the authority for the checkpoints |
| [`checkpoints/000-spans.md`](checkpoints/000-spans.md) | Implemented 2026-10-15, manager-reviewed (conforming), accepted: layer 1. `name-loc`, `target-loc`, and type span trees from `read-program`; the class-name span on the class record. Focused test: 7 test cases in `tests/editor/definition/000-spans.rkt`. Whole suite: 3026 tests, all passing under `-j 4` (3017, the 7 new cases, and 2 modules-census cases for the new fixtures) |

Depends on **source locations**, **expression query**, **editor-lsp
000–009**, and a class record that already stores its defining path.
Parent map: [`../README.md`](../README.md), project 8.

**Status.** Spec reviewed. Editor-definition 000 (spans) implemented
and accepted. The hand check moved from
`examples/aloemacs/main.aloe` to `examples/aloemacs/file.aloe`
(spec §8, §9; decided by the human 2026-10-14).
