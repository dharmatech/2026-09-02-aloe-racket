# Filesystem designer brief

**Status.** Thin-library pair complete on `experiment/filesystem` through
checkpoint 104. Kept as the assignment that conversation followed. Not
law. OO surface checkpoints: [`docs/filesystem-oo-designer.md`](filesystem-oo-designer.md).

**Your job.** You are the **designer** for the first read-only
filesystem vocabulary on `experiment/host-boundary`. You write small
checkpoint documents. You do not implement them.

If you have been told “read `docs/filesystem-designer.md`,” this file is
the whole assignment. Follow it until the human says the filesystem pair
is done.

## 1. How this conversation works

1. Read this brief and the authority files in §3.
2. Write **one** checkpoint document under `docs/checkpoints/`.
3. Stop. The human reviews it.
4. If they approve, they hand that checkpoint to a **different**
   implementer conversation (possibly a different agent). That
   conversation implements only that slice, adds tests, runs the named
   verification, and stops when green.
5. The human brings the result back here. Review the diff **against the
   written checkpoint**, not against this chat. Check file scope, tests,
   non-goals, and whether they started the next slice.
6. If the checkpoint was ambiguous, that is a design defect: fix the
   document before authorizing a follow-up. Do not patch the language in
   passing.
7. Only then write the next checkpoint.

Never implement, merge, or create a runtime branch in this conversation.
Never write an omnibus “do the filesystem” checkpoint.

Checkpoint shape follows the existing ones
(`docs/checkpoints/0090-parse-constructors-and-case.md`,
`docs/checkpoints/0098-list-string-crossing.md`,
`docs/checkpoints/0099-generic-host-type-retention.md`):

- goal
- depends on
- authority / starting point
- exact file scope
- required behavior
- tests and hand check
- acceptance
- explicit non-goals

The implementer will not have this brief in context. Put every rule they
need in the checkpoint itself.

## 2. Program context (why you exist)

Aloe is a prototype interpreter in Racket. Class constructors
(Proposal B: constructor sets + `case`) are implemented through
checkpoint 96. They stay off `main` until an application proves them.

That application is this vocabulary: a directory listing is mixed, so
`(List Entry)` plus exhaustive `case` is the proof. Gel may later
consume these objects; it must not define them.

The host-boundary pair already finished on `experiment/host-boundary`:

- 97 — constructors + sealed host (83–88) on one branch
- 98 — homogeneous `(List String)` crossing
- 99 — a generic field retains an injected host-receiver type, so
  `(define fs (Fs new fs-host))` typechecks without source-written host
  names. The argument-passing fallback was **not** taken.

You consume that line. You do not reopen it. You do not merge to
`main`. Unified Nominal ADTs / `define-family` is not authority.

## 3. Authority and reading order

Read these before writing the first checkpoint:

1. This brief.
2. `docs/filesystem-vocabulary.md` — **locked public Aloe API**. Do not
   “simplify” Path, Entry, Option, or the `fs` messages. Host selector
   spellings may tighten only as §8 allows.
3. `AGENTS.md`, `SPEC.md`, `docs/philosophy.md`, `docs/decisions.md`,
   `CHECKPOINTS.md`, `docs/handoff.md` on `experiment/host-boundary`.
4. Host seam as it exists now: `aloe/host.rkt`, `aloe/driver.rkt`,
   `host/racket/term.rkt` (pattern for a second optional capability),
   checkpoints 83–88 and 97–99, `docs/host-boundary-extensions.md`.
5. Constructor law: `docs/class-constructors.md` (historical) and SPEC
   on this line. `Option` goldens live in checkpoint 94; they are
   test-only, not a loadable library yet.

Do not check out other branches as your working copy. Browse with
`git show` if needed. Parent of the implementer’s branch is
`experiment/host-boundary`.

## 4. Branch topology

```
experiment/class-constructors
  └── experiment/host-boundary     # parent: through checkpoint 99
        └── experiment/filesystem  # implementer creates this
```

The first checkpoint must tell the implementer to create
`experiment/filesystem` from current `experiment/host-boundary`. Do not
branch off `main` or `experiment/class-constructors`. Do not merge
`codex/unified-nominal-adts`. Do not merge back to `main`.

Do not renumber historical checkpoints. New work starts at **100**.

## 5. What is already true (do not redesign)

- Evaluation is send. `(f x)` is not a call. `let` is `fn`/`call`.
- Host capabilities are descriptor-defined, injected with
  `driver-inject-host!`, absent from default drivers.
- Crossing types are `Int`, `Bool`, `String`, and `(List String)` only.
  Nested lists and `(List Entry)` are not crossing types.
- Term is unchanged and still optional.
- Generic `(Holder T)` / future `(Fs H)` retains the exact injected
  interface identity. Do not add source-written host type names.
- `lib/list.aloe` is bootstrapped by `make-driver`. Option is not.

Keep host facts in Racket. Keep `Path`, `Entry`, `Option`, and `Fs` in
Aloe.

## 6. Intended checkpoint order

Write them **one at a time**. You may split a phase further if a slice
is too large; you may not skip ahead or combine host + Aloe domain into
one checkpoint.

### Phase A — `lib/option.aloe` (checkpoint 100)

First checkpoint. Stop after writing it.

Loadable Option as specified in `docs/filesystem-vocabulary.md` §2 and
the SPEC Option example. Tests `load` it (or the library-load equivalent
already used for Aloe files). Include `present?` and exhaustive `case`.

Do not add Option to the default driver bootstrap. List stays special.
Do not touch host code, Path, Entry, or Fs.

### Phase B — injected filesystem host (next)

A second optional capability, modeled on Term:

- Racket module under `host/racket/` (name locked in the checkpoint).
- One `host-interface`, crossing values only.
- Injected as `fs-host` (that binding name is locked unless a
  collision with an existing test forces a documented rename).
- Default drivers do not get it. Ordinary `bin/aloe` does not get it.
- A **test double** with the same exact interface and controlled state
  is required. Production tests that touch the real filesystem use
  isolated temporary directories.
- Host messages implement the facts in filesystem-vocabulary §4
  (table below). No Aloe `Path` / `Entry` / `Fs` yet. Tests send
  `String` / `Bool` / `(List String)` through `fs-host`.

Do not follow symlinks when classifying. `names` returns immediate
children, no `.` or `..`. `parent` is only called by Aloe when `root?`
is false; still define host `parent` and make root behavior explicit
in the checkpoint (host failure vs returning the same string — pick
one and test it).

POSIX/Linux goldens are enough. Do not build a Windows path layer.

### Phase C — Aloe domain wrapper

`Path`, `Entry`, and `Fs` as locked in the vocabulary. Public receiver
is `fs`, constructed as `(define fs (Fs new fs-host))` after injection
and load.

Host methods still take and return crossing values. Aloe maps:

- `"missing"` → `None`
- `"file"` → `RegularFile`
- `"directory"` → `Directory`
- `"symlink"` → `SymbolicLink`
- any other kind string → `Other` with that string

Listing is Aloe composition: host `names`, then `child` + `inspect` per
name; omit `None`; host failure inspecting a name fails the whole
`entries` send. `entries` on a missing path or non-directory is a host
failure, not `None` and not an empty list.

Split this phase if needed (for example Path algebra first, then
`inspect`/`Entry`, then `entries`). Goldens in §9 must exist before you
declare the pair done.

### Phase D — stop

Do not start file-text reading, Gel UI, or ratification into SPEC
unless the human, after a program-conversation review, asks for a
follow-up checkpoint.

## 7. Locked public Aloe vocabulary

Do not change these selectors or types:

```aloe
(fs current)                 ; Path, absolute
(fs path string)             ; Path, via host resolution
(fs child path name)         ; Path; name is one component
(fs parent path)             ; (Option Path); None at root
(fs name path)               ; String
(fs inspect path)            ; (Option Entry); None if absent
(fs entries path)            ; (List Entry), immediate children only
```

`Path` is `(fields (text String))` with no host-effect methods.
`Entry` has exactly `RegularFile`, `Directory`, `SymbolicLink`,
`Other`. No `Missing`. No `exists?`. No `directory?` as the required
API (goldens use `case`). No nested `File` / `Directory` classes.

`(Path new …)` exists because every fields class has `new`; it is not
the public vocabulary.

## 8. Host messages

Starting lock (tighten only if the Term pattern or crossing rules
require it; never to change §7):

| Host selector | Arguments | Result |
| --- | --- | --- |
| `current` | none | `String` |
| `resolve` | `String` | `String` |
| `child` | `String`, `String` | `String` |
| `root?` | `String` | `Bool` |
| `parent` | `String` | `String` |
| `name` | `String` | `String` |
| `kind` | `String` | `String` |
| `names` | `String` | `(List String)` |

Normalization (`..`, trailing slashes, Unicode) is host-owned. Lock
concrete goldens in the host checkpoint, not by reimplementing paths
in Aloe.

Absence is Aloe `None`. Permission and I/O errors are host failures.
No `Result` crossing.

## 9. Required goldens before the pair is done

- Exhaustive `case` over `Entry`.
- `(fs inspect path)` is `None` for a missing path.
- `(fs parent path)` is `None` at root.
- A directory whose children include at least two different
  constructors.
- Test-double host with the same interface.
- At least one production-host test in an isolated temp directory.
- Default driver still has no `fs-host` / `term` unless a test injects
  them.
- Term checkpoint 88 hand check still `'("sealed" "sealed\r\n")`.
- Constructor Option/Tree goldens (94–95) still pass.

## 10. Explicit non-goals for this pair

- Read/write bytes, copy, move, delete, mkdir, chmod, cwd mutation,
  recursive walk, glob, watch, processes, Git.
- Opaque mutable directory handles, `(List Entry)` crossing, delimiter-
  packed listings, `Result` as a host type.
- Gel filesystem UI, constructor-aware Mirror as a prerequisite.
- Source-written host type names.
- `Path` methods that perform host effects; Path capturing `fs-host`.
- Adding Option to `make-driver` bootstrap.
- Redesigning injection, Term, or crossing validation.
- Proposal A / `define-family`.
- Merging to `main` or claiming class constructors are proven enough to
  merge.

## 11. When this pair is done

Stop when phases A–C are green on `experiment/filesystem`, the goldens
in §9 pass, Term still works, and the non-goals in §10 were not
implemented.

Then tell the human this pair is complete. They return to the program
conversation.

## 12. First action

Write `docs/checkpoints/0100-option-library.md` for phase A only. Do
not write the host-capability checkpoint in the same turn. Do not edit
`aloe/`, `host/`, `lib/`, `tests/`, or create `experiment/filesystem`.
