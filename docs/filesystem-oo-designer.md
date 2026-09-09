# Object-oriented filesystem — checkpoint manager brief

**Status.** Working handoff for one Grok **checkpoint-manager**
conversation. Not law. Not a checkpoint. `SPEC.md` remains law.

**Your job.** Turn
[`docs/filesystem-oo-vocabulary.md`](filesystem-oo-vocabulary.md) into
small checkpoint documents, **one at a time**. You do not implement
them. You do not reopen the thin library. You do not brainstorm a third
API.

If you have been told “read `docs/filesystem-oo-designer.md`,” this file
is the whole assignment.

## 1. How this conversation works

This is a checkpoint-manager conversation, not a brainstorm and not an
implementer.

1. Read this brief and the authority files in §3.
2. Write **one** checkpoint document under `docs/checkpoints/`.
3. Stop. The human reviews it.
4. If they approve, they hand that file to a **different** implementer
   conversation (often Codex). That conversation implements only that
   slice, adds tests, runs the named verification, and stops when green.
5. The human brings the result back here. Review the diff **against the
   written checkpoint**. Check file scope, tests, non-goals, and whether
   they started the next slice.
6. If the checkpoint was ambiguous, that is a design defect: fix the
   document before authorizing a follow-up.
7. Only then write the next checkpoint.

Never implement, merge, or create a runtime branch in this conversation.
Never write an omnibus “do lib/disk.aloe” checkpoint.

Checkpoint shape follows
`docs/checkpoints/0103-fs-path-algebra.md` and
`docs/checkpoints/0104-fs-entry-and-listing.md`:

- goal
- depends on
- authority / starting point
- exact file scope
- required behavior
- tests and hand check
- acceptance
- explicit non-goals

The implementer will not have this brief. Put every rule they need in
the checkpoint itself.

## 2. Why this pair exists

Thin `lib/fs.aloe` is FileManager-style: `(fs name path)`. The OO
surface is pathlib / FileDirectory-style: `(here name)`. It is a
**second** library on the same `fs-host`.

The program conversation reviewed the sketch and locked the remaining
ambiguities in `docs/filesystem-oo-vocabulary.md`. Treat that file as
the design. Do not “simplify” `Item` back to `Entry`, do not
`load` `lib/fs.aloe`, do not add a `text` method on `Location`.

## 3. Authority and reading order

1. This brief.
2. `docs/filesystem-oo-vocabulary.md` — **locked OO API**.
3. `docs/filesystem-vocabulary.md` and `lib/fs.aloe` — thin library,
   **do not edit**.
4. `AGENTS.md`, `SPEC.md`, `CHECKPOINTS.md`, `docs/handoff.md` on
   `experiment/filesystem`.
5. `lib/option.aloe`, `host/racket/fs.rkt`, `host/racket/fs-repl.rkt`.

Proposal A / `define-family` is not authority.
`docs/filesystem-designer.md` was the thin-library checkpoint manager;
that pair is done through 104. Do not continue it.

## 4. Branch

Stay on **`experiment/filesystem`**. Do not create a new branch. Do not
merge to `main`. Do not merge `codex/unified-nominal-adts`.

New checkpoints start at **105**. Do not renumber 100–104.

## 5. What is already true (do not redesign)

- Thin library: `Fs`, `Path`, `Entry` (`RegularFile` / `Directory` /
  `SymbolicLink` / `Other`), `lib/option.aloe`.
- Injected `fs-host`; default drivers have none; `bin/aloe` has none.
- Crossing: `Int`, `Bool`, `String`, `(List String)`.
- Generic fields retain host-receiver types (`(Disk new fs-host)`).
- Methods are whole-class. No constructor-local methods. No inheritance.
- `load` shares one environment. Two classes named `Entry` cannot coexist.

## 6. Intended checkpoint order

Write them **one at a time**. You may split a phase if it is too large.
You may not skip ahead or combine inspect with listing.

### Phase A — `Disk` and `Location` algebra (checkpoint 105)

First checkpoint. Stop after writing it.

Create `lib/disk.aloe`. `(load "option.aloe")`. Do **not** load
`lib/fs.aloe`.

`Disk` and `Location` as locked: `(fs current)`, `(fs at string)`,
`(here name)`, `(here text)` as **field**, `(here parent)` →
`(Option Location)`, `(here child "lib")`. Resolve via host. No
`inspect`, no `Item`, no live classes.

Goldens: relative `at` becomes absolute; root `parent` is `None`;
`name` of a file path is the last component; default driver still has
no `fs-host`.

### Phase B — `inspect` and live `Item` (next)

`Location.inspect` → `(Option Item)`. Nested `File` / `Directory` /
`SymbolicLink` / `Other` with a `location` field, forwarded `name` /
`text` / `child` / `inspect`, and live `parent` →
`(Option Directory)`.

No `Directory.entries` yet. Goldens: missing → `None`; exhaustive
`Item` `case`; `(file location)` round-trips; live `parent` at root is
`None`; a file’s live parent is `Some` of a `Directory` when that
parent exists on disk.

A test that `load`s **both** `lib/fs.aloe` and `lib/disk.aloe` in one
driver must work (`Entry` and `Item` both bound).

### Phase C — `Directory.entries` (next)

Listing only on live `Directory`, as vocabulary §6. Goldens: mixed
`(List Item)` with at least two constructors; omit vanished names;
`case` on children; Term 88 and thin 103–104 still pass.

### Phase D — stop

Do not add `(here entries)`, `enter`, `size`, `read`, `target`, Gel UI,
or a rewrite of `lib/fs.aloe`. An `archive/` worksheet for `Disk` is
optional and only after C is green, as its own tiny checkpoint or a
note in C’s non-goals.

## 7. Locked rules (do not reopen)

- Library file: `lib/disk.aloe`.
- Listing type: `Item`, not `Entry`.
- `Disk` talks to `H` directly. Duplicate the kind-string table.
- No `text` method on `Location`.
- Live objects: `location` field and forwarded `inspect`.
- Thread `H` through `Disk`, `Location`, live classes, and `Item`.
- Path `parent` is `(Option Location)`. Live `parent` is
  `(Option Directory)`.
- Live `parent` does not follow symlinks; `Some` only for constructor
  `Directory`.
- Same `fs-host`. No second host. No ambient capability.

## 8. When this pair is done

Phases A–C green on `experiment/filesystem`, both libraries loadable
together, thin goldens and Term still pass, `bin/aloe` still has no
`fs-host`. Then tell the human this pair is complete. They return to
the program conversation.

## 9. First action

Write `docs/checkpoints/0105-disk-and-location.md` for phase A only.
Do not write 106 in the same turn. Do not edit `lib/`, `aloe/`,
`host/`, or `tests/`.
