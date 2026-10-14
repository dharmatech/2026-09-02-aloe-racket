# modules

**Status: Spec accepted 2026-10-13. modules 000 implemented and accepted (5d435a5). modules 001 implemented and accepted (efe39e7). modules 002 implemented and accepted (0f026a6). modules 003 implemented and accepted (1ab41bb). modules 004 implemented and accepted (c6a0333). modules 005 implemented, manager-reviewed, and accepted 2026-10-14.**

**Project root:** `/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Branch:** `experiment/2026-10-12-modules`, cut from `main` at `40344c3`. This series stays on that branch until a human merges it.

Language change. `load` becomes the module system. Not an aloemacs feature layer. Not Gel. Local numbering: do not take the next global checkpoint integer unless a human promotes this series onto `CHECKPOINTS.md` after review.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Whole assignment for the designer |
| [`spec.md`](spec.md) | Written 2026-10-12, accepted for checkpoint planning 2026-10-13. Design authority for the manager and the implementers |
| [`checkpoints/000-run-once.md`](checkpoints/000-run-once.md) | Implemented 2026-10-13, manager-reviewed, accepted, committed as 5d435a5: the per-base load cache in the checker and the evaluator, the changed-bytes error, keyed roots, and the list, string, and int seeds. The shared environment stays. `tests/modules/000-run-once.rkt` 13/13; the whole suite green at 220 files, 2872 tests |
| [`checkpoints/001-explicit-loads.md`](checkpoints/001-explicit-loads.md) | Implemented 2026-10-13, manager-reviewed, accepted, committed as efe39e7: the explicit-load layer, not split by tree. Every census file loads each file whose names it uses; `Math` moves to `examples/mpl/math.aloe`; the census test `tests/modules/001-census.rkt`; 17 pins. Inventory from a scratch census and a scratch suite run. Census 44/44; the whole suite green at 221 files, 2916 tests |
| [`checkpoints/002-option-base.md`](checkpoints/002-option-base.md) | Implemented 2026-10-13, manager-reviewed, accepted, committed as 0f026a6: slice 3a. `lib/option.aloe` installed on the base; `String find` reads the base's `Option`; an editor query of a base library installs it from the buffer; `query-expression-at` gains `#:document-path`. Checkpoint amended after the implementer's first suite run (a missed snapshot stub in `008-adapter-failures.rkt`, the `runner.rkt` fresh-driver loop, and the `(Some "x")` parse rejection). Focused proof 10/10; the whole suite green at 222 files, 2926 tests |
| [`checkpoints/003-overload-identity.md`](checkpoints/003-overload-identity.md) | Implemented 2026-10-13, manager-reviewed, accepted, committed as 1ab41bb: slice 3b. Protocol types unify by record in the checker; `define-protocol` binds a runtime record; a send with more than one candidate matches class and protocol annotations by record in the environment of the send; single candidates, `Mirror invoke`, and `Signature accepts?` keep short names. A scratch prototype left the whole suite green, so no existing test changes. Focused proof 9/9; the whole suite green at 223 files, 2935 tests |
| [`checkpoints/004-method-records.md`](checkpoints/004-method-records.md) | Implemented 2026-10-13, manager-reviewed, accepted, committed as c6a0333: slice 3c. Each method and protocol records the environment that wrote it, in a table on each class record (per base); the checker resolves method, protocol, and field annotations there and the evaluator runs bodies and multi-candidate selection there. A scratch prototype left the whole suite green; it also showed the per-base table is required, because library method declarations are shared across bases. Focused proof 9/9; the whole suite green at 224 files, 2944 tests |
| [`checkpoints/005-conformance.md`](checkpoints/005-conformance.md) | Implemented 2026-10-14, manager-reviewed, accepted, and committed: slice 3d. Conformance at a root's end walks the classes exported by completed cache entries, then the file environment's chain, then the interactive environment's; checker exports become bindings (only the `Option` seed has one). Accepts exactly what today's walk accepts; a scratch prototype left the suite green. Focused proof 4/4; the whole suite green at 225 files, 2949 tests |

Series identity is `modules`. Checkpoint 000 is spoken **modules 000** and will be filed as `checkpoints/000-run-once.md`. Numbers are three digits, start at 000, and are never renumbered. The checkpoint manager writes one checkpoint, then stops.

Process: [`docs/workflow.md`](../../../workflow.md).

The discussion record is [`archive/design-sketches/2026-10-09-module-design-discussion/summary.md`](../../../../archive/design-sketches/2026-10-09-module-design-discussion/summary.md). The code sketch beside it is not a spelling to adopt. This charter closes the questions that record left open.

A load copies the names the loaded file defines, in a file and at the prompt. A second root unions into the interactive environment. A program with a source path is a file module, including `driver-load-file!`, a keyed `driver-load-port!`, and `eval-source` or `typecheck-source` with `#:source-path`. That root's own definitions are copied into the interactive caller. The cache lives on the type environment and the runtime environment. A child environment defers to the root base's cache. A method body and its signature use the file that wrote them. A protocol does the same. Each root, and each hover query, conforms every class in the checker's cache, every class bound in the file being checked, and every class bound in the interactive environment, after that check's forms have run. Overload selection uses the class record and the protocol record. The overload slice resolves annotations in the shared environment, and the method-record slice retargets that lookup to the method record. Method records and the conformance walk are green slices before file environments. The checkpoint that is not split further is file environments and the copy rule. Collisions follow it. A query of an installed base library installs that library from the buffer's bytes and checks it as that one definition. That rule lands with the `Option` install or in the collision slice, and does not wait for defining paths. `Option` from `lib/option.aloe` is installed once on the base, and every load of that file is that same class. The list, string, and int libraries are cache entries from the run-once layer, and each seed stores the bytes that were installed. The explicit-load census includes `file.aloe` loading `lib/text.aloe`, `gel/loop.aloe` loading `menu.aloe`, `gel/main.aloe` loading `stack.aloe`, `core.aloe` and the MPL class files loading the new Math file, and `identities.aloe` loading `sym.aloe`. Hover reports the queried document's path for a class that buffer defines, not the temporary sibling written for a dirty buffer. A queried base library is installed from the buffer's bytes. That install is new: today the query reads the path it is given, and `make-type-environment` always forces the library promises. Hover inside `sym.aloe` stays null.

Code and tests live in the project root. Tests for this series live under `tests/modules/`.

Next step: a checkpoint-manager conversation writes `checkpoints/006-…` for slice 3e (file environments and the copy rule; spec §6.5, the slice that is not split further) and stops.

```text
Read docs/workflow.md. You are the checkpoint manager. Your assignment is
docs/design/implementation/modules/spec.md. modules 000 through 005 are
implemented and accepted. Write the next checkpoint and stop.
```
