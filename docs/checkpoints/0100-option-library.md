# Checkpoint 100 — Option library

**Branch.** Create `experiment/filesystem` from current
`experiment/host-boundary`.

**Depends on.** Checkpoint 99 (generic host-type retention)

**Status.** Complete (reviewed 2026-09-08 on `experiment/filesystem`)

## Goal

Make `Option` a loadable Aloe library at `lib/option.aloe`, matching
the locked class in `docs/filesystem-vocabulary.md` §2 and the SPEC
§3.1 Option example. Tests `load` that file. The class includes
`present?` and exhaustive `case`.

Do not add Option to the default driver bootstrap. `List` stays
special. Do not add a filesystem host, `Path`, `Entry`, or `Fs`.

This is the first filesystem-pair slice. Stop when it is green. Do not
start the host-capability checkpoint.

## Depends on

- Parent: current `experiment/host-boundary` (constructors through 96,
  sealed host 83–88, `(List String)` crossing, generic host-type
  retention). Tests through checkpoint 99 are green there.
- Law: `SPEC.md` on that parent — Option in §3.1, construction and
  `case` in §§3.2 / 4.10 / 5.3, Option goldens and rejects in §9,
  `load` in §11.
- Locked public class: `docs/filesystem-vocabulary.md` §2 Option.
  Do not “simplify” constructors, `present?`, or `case`.
- Historical context only: `docs/class-constructors.md` Proposal B.
  Its `map` method is **not** part of this library.
- Checkpoint 94 already runs these goldens against an **inline**
  Option in `tests/checkpoint-94.rkt`. Leave that test alone. This
  slice makes the same class loadable from `lib/`.
- Not authority: `codex/unified-nominal-adts`, Proposal A,
  `define-family`.

The implementer will not have the filesystem designer brief. Every
rule needed to implement this slice is in this document.

## Authority / starting point

Facts on `experiment/host-boundary` after 99 (do not redesign them):

- Evaluation is send. `(f x)` does not call `f`. Function objects run
  only via `(f call x ...)`. `let` is
  `((fn (names ...) body) call exprs ...)`.
- No inheritance, mutation, macros, or implicit `Int`/`Float`
  coercion. Do not invent special forms that are not in `SPEC.md`.
- Named construction and exhaustive `case` already work. Option is
  not a kernel type and is not bound in a fresh driver.
- `lib/list.aloe` is the only library `make-driver` bootstraps
  (`aloe/library.rkt` → `list-library-expressions`). Option is not
  there.
- `load` reads, typechecks, and evaluates another Aloe file in the
  same environment (SPEC §11). Tests already `load` Gel and example
  files via `define-runtime-path` plus `(load <path>)`, or via
  `driver-load-file!`.
- Host crossing remains `Int`, `Bool`, `String`, and homogeneous
  `(List String)`. Term is unchanged and still optional. Default
  drivers have no `term` and no `fs-host`.
- Generic `(Holder T)` retains an injected host-receiver type.
  `(define fs (Fs new fs-host))` is a viable *later* encoding. Do not
  add `Fs` here.

## Branch topology

```
experiment/class-constructors
  └── experiment/host-boundary     # parent: through checkpoint 99
        └── experiment/filesystem  # this checkpoint creates this
```

Exact steps:

1. Start from current `experiment/host-boundary`. Do not switch the
   working copy to `main` or `experiment/class-constructors`.
2. `git checkout -b experiment/filesystem`
3. Implement only this checkpoint on that branch.

Do not merge `main`. Do not merge `codex/unified-nominal-adts`. Do
not merge this branch back to `main`. Do not renumber historical
checkpoints.

## Exact file scope

**May edit:**

- `lib/option.aloe` (new)
- `tests/checkpoint-100.rkt` (new)
- `CHECKPOINTS.md` (append 100 only)
- `docs/handoff.md` (current-state test line; application-pressures
  paragraph: Option is now loadable, `Path` / `Entry` / `Fs` and
  `fs-host` still do not exist)
- `docs/decisions.md` (short dated addendum only: Option is a
  loadable library, not a `make-driver` bootstrap, not a host type)
- `docs/filesystem-vocabulary.md` **status sentences only** (see
  below). Do not change Path, Entry, Fs, or host-message tables.

**Do not edit:**

- `aloe/` — including `aloe/library.rkt` and `aloe/driver.rkt`
- `host/`
- `lib/list.aloe`
- `SPEC.md`
- `docs/philosophy.md`
- historical checkpoints 83–99, including
  `tests/checkpoint-94.rkt` and `tests/checkpoint-95.rkt`
- `examples/`, `gel/`, MPL
- no `host/racket/fs.rkt`, no `lib/fs.aloe`, no `lib/path.aloe`,
  no `Path` / `Entry` / `Fs` classes

Required `docs/filesystem-vocabulary.md` status-only edits:

§2 Option closing sentence currently says the library *may* `load`
`lib/option.aloe` if Option is not already loadable. Replace that
with: programs `load` `lib/option.aloe`; Option is not bootstrapped
by `make-driver`; it is not a host crossing type.

§7 item 4 currently asks for a loadable Option. Mark it done as
checkpoint 100. Do not reopen items 1–3.

## Required behavior

### Library text

`lib/option.aloe` is Aloe source (no `#lang`). It contains exactly
this class, matching SPEC §3.1 and filesystem-vocabulary §2:

```aloe
(define-class (Option T)
  (constructors
    (None (fields))
    (Some (fields (value T))))
  (methods
    (present? () Bool
      (self case
        (None () #f)
        (Some (value) #t)))))
```

Lock:

- Constructors are `None` (empty payload) and `Some` (one field
  `value` of type `T`), in that declaration order.
- The only method is `present?`. Its body is exhaustive `case` over
  both constructors. Do not add `else`.
- Construction is `(Option None)` and `(Option Some expr)`, never
  `(None)` or `(Some expr)`.
- Payload of `Some` is read through `case`, not through a whole-class
  `value` method. Constructor-class payload fields are not a public
  field-send API in this library.

Do not add `map`, `unwrap`, `value`, `show`, a protocol, or extra
defines. Match `lib/list.aloe`: no narrative comments.

### Loading, not bootstrap

A program obtains Option by loading the file. Tests must exercise the
Aloe `load` special form (the same mechanism Gel and examples use),
not only a Racket helper that bypasses it.

Accepted test spelling, following `tests/checkpoint-20.rkt` /
`tests/checkpoint-75.rkt`:

```racket
(define-runtime-path option-path "../lib/option.aloe")
(define state (make-driver))
(driver-eval! state `(load ,(path->string option-path)))
```

`driver-load-file!` of that same path is an allowed *additional*
check. It is not a substitute for at least one Aloe `(load ...)`
through `driver-eval!` (or `eval-source` / `typecheck-source` of a
`(load ...)` form).

After a successful load, `Option` is bound in that driver's runtime
and type environments. Later expressions on that driver may construct
and send to Option.

A fresh `make-driver` still does **not** bind `Option`. Do not add
`option-library-expressions` to `aloe/library.rkt`. Do not call the
Option file from `make-driver`. `List` bootstrap is unchanged:
`((List of 1 2 3) len)` is still `3` on a fresh driver, and still
`3` after loading Option.

Default drivers still have no `term` and no `fs-host`.

### Goldens after load

On a driver that has loaded `lib/option.aloe`, these SPEC §9 Option
programs must typecheck and evaluate:

```aloe
(Option Some "x")    ; type (Option String)
((Option Some "x") present?)    ; => #t
((if #t (Option None) (Option Some "x")) present?)    ; => #f
((Option Some "x") case
  (None () "unknown")
  (Some (name) name))    ; => "x"
```

The `if` form is the required way to construct `None` with `T`
determined. Do not weaken the checker so `(define n (Option None))`
starts to pass.

Also confirm the library method itself is exhaustive `case`:
`present?` on both a `Some` and a `None` (via the `if` golden)
returns a `Bool`. Do not add a non-exhaustive `case` in the library.

Must still reject after load:

```aloe
(define n (Option None))
((Option Some "x") case (Some (name) name))
```

Checker: cannot infer `T` for Option; missing constructor `None`.
Use the existing error shapes (`cannot infer type parameter T for
Option`, `missing constructors: (None)`). Do not invent new
diagnostics.

Must still reject (constructor is not a top-level binding):

```aloe
(Some "x")
```

Unbound `Some` and/or the existing send-grammar error for a
non-symbol selector are both acceptable, matching checkpoint 94.
Do not install `None` or `Some` as top-level bindings.

Inline Option in `tests/checkpoint-94.rkt` and Tree in
`tests/checkpoint-95.rkt` must still pass unchanged.

## Tests and hand check

Add `tests/checkpoint-100.rkt`. Do not repeat 83–88 or 90–99.

Cover:

1. Fresh `make-driver`: `Option` is unbound in the runtime
   environment (`env-bound?`) and the type environment
   (`type-environment-bound?`). `term` and `fs-host` are also
   unbound. `List` still works (`((List of 1 2 3) len)` is `3`).
2. Aloe `(load <option-path>)` on that driver (or a second fresh
   driver) succeeds. After load, `Option` is bound on both sides.
3. The four SPEC Option goldens above, including types
   `(Option String)` and `Bool` where listed. Use `driver-eval!` /
   `type-of` on the loaded driver, same idea as
   `tests/checkpoint-99.rkt`'s `driver-type-datum`.
4. Checker rejects `(define n (Option None))` and incomplete
   `case` missing `None`. `(Some "x")` is not a valid construction.
5. After load, List is still present:
   `((List of 1 2 3) len)` is `3`.
6. Term on a **different** driver that injects Term:
   `(term write-line "sealed")` still returns `"sealed"`. Do not
   inject Term into the Option-load driver unless a separate
   test-case needs it.

Do not add a real-filesystem test. Do not inject an `fs-host`.

### Hand check

From the repository root, after creating `experiment/filesystem` and
the library:

```racket
(require racket/runtime-path
         "aloe/driver.rkt"
         (only-in "aloe/env.rkt" env-bound?))

(define-runtime-path option-path "lib/option.aloe")

(define fresh (make-driver))
(env-bound? (driver-runtime-environment fresh) 'Option)
; => #f

(define state (make-driver))
(driver-eval! state `(load ,(path->string option-path)))
(list
 (driver-eval! state '((Option Some "x") present?))
 (driver-eval! state
               '((if #t (Option None) (Option Some "x")) present?))
 (driver-eval! state
               '((Option Some "x") case
                  (None () "unknown")
                  (Some (name) name))))
```

Expected: `#f` for the unbound check, then `'(#t #f "x")`.

Term check unchanged from checkpoint 88/97/99:

```racket
(require "aloe/driver.rkt"
         "host/racket/term.rkt")

(define output (open-output-string))
(define state (make-driver))
(driver-inject-host!
 state 'term (make-term-receiver output (lambda () "unused")))

(list (driver-eval! state '(term write-line "sealed"))
      (get-output-string output))
```

Expected: `'("sealed" "sealed\r\n")`

## CHECKPOINTS.md and handoff

`CHECKPOINTS.md` compact entry:

```text
## 100. [Option library](docs/checkpoints/0100-option-library.md)

- `lib/option.aloe` is a loadable Option class (`None` / `Some`,
  `present?`, exhaustive `case`). Tests load it. It is not
  bootstrapped by `make-driver`. No filesystem capability.
```

`docs/handoff.md`:

- Current state: tests through checkpoint 100. Option is loadable
  from `lib/option.aloe` and is not a default-driver binding.
- Application pressures: the filesystem pair has started on
  `experiment/filesystem`. `Path`, `Entry`, `Fs`, and `fs-host` still
  do not exist. Do not claim constructors are ready to merge to
  `main`.

`docs/decisions.md`: one dated addendum (2026-09-08) that Option is a
loadable Aloe library under filesystem pressure, not added to
`make-driver`, and not a host crossing type. Do not rewrite older
entries.

## Acceptance

- `experiment/filesystem` exists and was created from current
  `experiment/host-boundary`, not from `main`.
- `raco test` green, including 94, 95, 98, 99, and new 100.
- Hand checks above hold.
- `git diff --check` clean.
- `make-driver` still does not bind `Option`, `term`, or `fs-host`.
- No host/filesystem library, no `Path` / `Entry` / `Fs`, no
  source-written host type names.
- Stop. Do not start the injected filesystem-host checkpoint.

## Explicit non-goals

- Adding Option to `make-driver` or `aloe/library.rkt`.
- `map`, `unwrap`, `value`, `show`, or any method beyond `present?`.
- `Path`, `Entry`, `Fs`, `lib/fs.aloe`, `host/racket/fs.rkt`,
  `fs-host`, real directories.
- Touching Term, crossing validation, or injection.
- `(List Entry)` crossing, `Result`, opaque handles.
- Gel filesystem UI.
- Ratifying Option as a kernel type in `SPEC.md`.
- Proposal A / `define-family`.
- Merging to `main` or claiming class constructors are proven enough
  to merge.
