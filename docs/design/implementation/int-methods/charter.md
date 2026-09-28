# Charter — Int `min` / `max` via `define-methods`

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not a checkpoint. Not an implementer
assignment. Specification will live beside this file as
[`spec.md`](spec.md). Process:
[`docs/workflow.md`](../../workflow.md).

**Your job.** Turn this charter into a specification that makes
**`define-methods Int` legal** and installs **`(n min m)`** and
**`(n max m)`** as Aloe methods, derived from `<` / `>` and `if`.
Then **stop**. Do not write checkpoints. Do not implement. Do not
specify kernel `min`, `define-methods Float`, or the aloemacs
editor cleanup.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §5.
2. Record the locked decisions in §4. Resolve the open questions
   in §4.6–§4.7.
3. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **int-methods 000**, … under
   `docs/design/implementation/int-methods/checkpoints/` (not
   `docs/checkpoints/0116` unless the human promotes after
   review).
4. Stop. The human reviews it. Do not write those checkpoint files.

Keep the spec **small enough to slice**. Kernel arithmetic, Float
`min`, class methods, and rewriting `AloemacsEditor` are defects
in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| `SPEC.md` §4.6 / §7 | `define-methods` targets are `List` and `String` only; `Int` kernel is `+ - * / < > <= >= =` and `(n float)` |
| Checkpoint 114 | `define-methods String`; **explicitly rejected** `define-methods Int` |
| Checkpoint 115 / [`lib/string.aloe`](../../../lib/string.aloe) | Derived methods in Aloe, default env via [`aloe/library.rkt`](../../../aloe/library.rkt) |
| [`lib/list.aloe`](../../../lib/list.aloe) | Same install pattern |

**Consumer (do not implement here):** aloemacs
`(self clamp-column column text)` is
`(if (column > (text line-length)) (text line-length) column)`,
and `max-zero` is `(if (value < 0) 0 value)`. After this series
those become `(column min (text line-length))` and
`(value max 0)` in a **later** aloemacs standalone checkpoint.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. `(define-methods Int (methods ...))` typechecks and runs.
   Bodies see `self : Int`. Kernel `Int` selectors still win
   dispatch, then installed Aloe methods, same shape as `String`.
2. `min` and `max` are **Aloe**, not `aloe/eval.rkt` builtins:

   ```aloe
   (min (other Int) Int
     (if (self < other) self other))
   (max (other Int) Int
     (if (self > other) self other))
   ```

   Equal operands return that value (either arm is the same
   integer). Negatives work: `((-3) min 2)` is `-3`;
   `((-3) max 2)` is `2`.
3. Default checked environments load the library (parallel
   `lib/string.aloe`). A fresh driver can send `min` / `max`
   without the test file `load`ing it by hand. A raw / empty
   environment used for isolation tests must not leak the
   methods unless it loads the library.
4. `define-methods Float`, `Bool`, and `Symbol` remain
   **rejected** in this series. No kernel `min` / `max`. No
   `(Int new ...)`. No implicit `Int`/`Float` mix.
5. Tests first, under `tests/int-methods/` (not
   `tests/checkpoint-N.rkt` unless promoted). Goldens for the
   four sign combinations, ties, and that `(3 min "x")` is a
   type error.

## 4. Locked decisions (record these; do not reopen 4.1–4.5)

### 4.1 Derived, not kernel

`min` / `max` are expressible with `<` / `>` and `if`. They
must not appear as Racket cases in `lookup-message` for `Int`.
Checkpoint 114's diamond: irreducible facts are kernel;
everything else is Aloe.

### 4.2 Int only

Reopen 114 **only** for `Int`. Do not generalize a
“all primitives” framework. Do not add `define-methods Float`
here. A later charter may copy this slice for `Float` if a
program needs it (Boids has not asked).

### 4.3 Library file and install

New `lib/int.aloe` with `define-methods Int`. Wire it through
`aloe/library.rkt` the way `string.aloe` is wired. Do not dump
`min` into `lib/list.aloe` or `lib/string.aloe`.

### 4.4 Where code may live

- `aloe/eval.rkt`, `aloe/type.rkt`, `aloe/env.rkt` as needed
  so `Int` is a `define-methods` target (mirror `String`, do
  not invent a third mechanism)
- `aloe/library.rkt` and whichever default-environment loader
  already installs String methods
- `lib/int.aloe`
- `SPEC.md` §4.6 and the Int subsection of §7: name `min` /
  `max` as library methods, not kernel rows
- `docs/decisions.md` — one dated entry: Int is lifted for
  derived methods; Float/Bool/Symbol still rejected
- Tests under `tests/int-methods/`
- Reflection (`Mirror` / `Signature`) only as far as 114 did
  for String: installed rows appear after kernel rows
- **Not** `examples/aloemacs/`, Gel, host Term/Fs, parsing
  syntax, `CHECKPOINTS.md` (unless the human promotes)

### 4.5 Out of this series

- Kernel `min` / `max` / `abs` / `clamp`
- `define-methods Float` / `Bool` / `Symbol`
- Class methods, a `MathUtils` class, protocols for `min`
- Changing `+` or mixing `Int` and `Float`
- Inlining aloemacs `clamp-column` / `max-zero` (follow-on)
- Boids / MPL rewrites to use `min`

### 4.6 SPEC and dispatch (resolve this)

Write the exact SPEC sentences: §4.6 target list becomes `List`,
`String`, or `Int`; `T` is not in scope on `Int`. Kernel Int
table unchanged. Say that `min` / `max` live in `lib/int.aloe`
like `starts-with?`.

Name how Int method tables are stored (parallel
`string-class-object-methods`). Kernel selectors must not become
Aloe stubs.

If a test-only `define-methods Int` method is useful to prove
the lift before `lib/int.aloe` (114 used a throwaway `empty?`
on String), the spec may split: lift first, library second.
If one checkpoint can hold both without blowing context, say
so; the manager still writes one file at a time.

### 4.7 Default env vs isolation (resolve this)

Name the loader function and that `make-driver` (non-raw)
installs Int methods. Checkpoint-style tests that build a
stripped environment must still be able to reject unknown
`min` before load. Follow the existing String tests rather
than inventing a second bootstrap.

## 5. Authority

- `SPEC.md` §3.1 (`define-methods` instance methods only),
  §4.6, §7 (Int kernel)
- [`docs/checkpoints/0114-string-len-take.md`](../../checkpoints/0114-string-len-take.md)
  — lift one primitive; do not lift all
- [`docs/checkpoints/0115-string-starts-with.md`](../../checkpoints/0115-string-starts-with.md)
  — derived method + default env
- [`docs/decisions.md`](../../decisions.md) — String library
  boundary
- [`docs/philosophy.md`](../../philosophy.md) — kernel small;
  grow from applications
- [`aloe/library.rkt`](../../../aloe/library.rkt),
  [`lib/string.aloe`](../../../lib/string.aloe)

`SPEC.md` remains language law. This spec **does** amend it
for `define-methods Int` and the library mention of `min` /
`max`. It is not a kernel arithmetic change.

## 6. Non-goals

- Float `min` / `max` (later charter if needed)
- aloemacs editor edits
- `abs`, `clamp` of three arguments, bitwise ops
- Promoting this series onto `CHECKPOINTS.md` in the spec
  (the human may copy it after green)
- Macros, class methods, mutation
