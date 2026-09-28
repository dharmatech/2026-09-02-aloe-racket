# Int methods specification

**Status: Accepted.**

This specification lifts only `Int` as a `define-methods` target and adds
`min` and `max` as Aloe library methods. It is the complete design input for
the checkpoint manager and implementers; they need not read the charter or
the discussion. `SPEC.md` remains language law, and this series amends only
its `define-methods` and Int library descriptions.

## Checkpoint series

- **Identity:** `int-methods`. Speak the first checkpoint **int-methods 000**.
  File it as `docs/design/implementation/int-methods/checkpoints/000-<slug>.md`.
  Numbers have three digits, start at 000, and are never renumbered; slugs
  use lowercase words separated by hyphens.
- **Project root:** `/home/dharmatech/journal/2026-09-02-aloe-racket`.
  Code and tests go in this root, not the design folder.
- **Order:** 000 lifts `define-methods Int`, checker/runtime dispatch, and
  reflection, using a test-only method. 001 adds `lib/int.aloe` and its
  default bootstrap. Each layer is a testable checkpoint. A manager may split
  a layer if it exceeds one implementer conversation, keeping this order and
  adding no features.
- The checkpoint manager writes **one** next missing checkpoint under
  `checkpoints/`, then stops. Each implementer takes one checkpoint, adds
  tests in the same change, runs its verification, and stops when green.
  Human review separates these stages. Keep this series local; do not add an
  entry to `CHECKPOINTS.md` or `docs/checkpoints/` unless the human later
  promotes it.

## Product boundary

`(define-methods Int (methods ...))` defines instance methods with
`self : Int`. Ordinary sends check the existing Int kernel selectors first, then
the methods installed in that environment. `min` and `max` are derived from
`<`, `>`, and `if` in `lib/int.aloe`; neither is a Racket builtin or a kernel
signature row. The library is available in default checked environments and
absent from raw environments until explicitly installed or bootstrapped by a
public entry point.

This series does not add kernel arithmetic, `abs`, `clamp`, Float methods,
Bool methods, Symbol methods, class methods, constructors, protocols, syntax,
mutation, implicit Int/Float coercion, or editor and Boids changes. In
particular `(Int new ...)` remains invalid. The aloemacs `clamp-column` and
`max-zero` edits are a later consumer.

## Host and layout

The implementation is Racket under `aloe/` with an Aloe library under
`lib/`. Use the existing parser and method declaration syntax. The primitive
kernel rows come from `aloe/signature-catalog.rkt`; **do not edit that file**.
Its current Int order is `+ - * / < > <= >= = float text` (11 rows), and that
order and those signatures remain unchanged. The existing `String` path in
`aloe/env.rkt`, `aloe/type.rkt`, `aloe/eval.rkt`, `aloe/library.rkt`,
`aloe/main.rkt`, and `aloe/driver.rkt` is the implementation model. Do not
create a general primitive-class framework.

Tests for this series live under `tests/int-methods/`. Write each checkpoint's
focused tests before its implementation. Run from the project root with
`raco test tests/int-methods/<checkpoint-test>.rkt`, then `raco test tests` for
the whole tree, and `git diff --check`. A final hand check uses `racket -e`
as given in layer 001. No setup or dependency installation is needed beyond
the repository's Racket toolchain.

## Layer 000 — Lift `define-methods Int`

**Allowed files:** `aloe/env.rkt`, `aloe/type.rkt`, `aloe/eval.rkt`,
`SPEC.md`, `docs/decisions.md`, `tests/int-methods/000-lift.rkt` (new), and
`tests/checkpoint-114.rkt` (only its now obsolete Int rejection assertion).
No library or bootstrap edits in this layer.

Add an environment-local Int class object with mutable `methods` and its
definition environment, parallel to `string-class-object`. Bind `Int` in a
fresh runtime environment, retain the Int class object in its environment,
and propagate that reference to local environments. The checker gets the
parallel Int class type and per-environment method table. `Int` has no class
type parameter: `T` is not implicitly in scope, though an explicitly
declared method-local type parameter follows existing rules. Install all
declarations before checking bodies, as for String, so methods in one form
may refer to each other. Typecheck each body with `self : Int`, its declared
parameter types, and declared return type. Include the new class type in the
checker's validity, equality, and display paths: the `Int` binding has type
`(Class Int)`, while an integer value has type `Int`. Like the String class
object, the Int class object has no callable class rows.

Only the `Int` target is newly accepted. `define-methods Float`, `Bool`, and
`Symbol` still fail in both checked and raw runtime paths. Preserve the
existing List, String, and user-class cases. A fresh raw environment has no
installed Int methods, and defining a method in one environment cannot make
it visible in another.

For an Int receiver, keep kernel send behavior and its static checks first.
For an unknown kernel selector, select an installed Int method with the same
overload, arity, and argument-type rules used by String methods; execute its
body in the captured definition environment with `self` and parameters
bound. Do not change `+`, numeric inference for unresolved type variables,
or Float dispatch. The checker makes the same kernel-then-method choice.
An installed method whose selector matches a kernel selector remains a
separate reflected row, while an ordinary send still uses the kernel row.

Runtime `Mirror.signatures` and checker `type-signature-specs` for Int append
installed method rows after all 11 kernel rows. `Mirror.messages` stays
unique by selector. `Mirror.invoke` on an installed Int row executes that
exact method body, even when its selector shadows a kernel selector; it must
not redispatch by selector. Interpret Int row indexes using the existing
kernel signature count, just as String does. Keep the Int class object free
of class sends and constructor rows.

Focused tests first in `tests/int-methods/000-lift.rkt` must prove a test-only
method such as `(twice () Int (self + self))` typechecks and runs, appears
only in the defining environment, and is absent from a fresh raw and a fresh
default environment. Check `self : Int`, no implicit `T`, rejected Float /
Bool / Symbol targets, wrong arity and argument type on a test-only method,
and unchanged kernel arithmetic. Check Int reflection order and signature
parity, including exact invocation of an installed row. Use a test-only
shadow of `text` with a different result to prove kernel precedence for an
ordinary send and exact-row invocation for the Aloe row. In
the raw and checked paths, `(Int new 1)` must remain invalid. In
`tests/checkpoint-114.rkt`, remove `Int` from the target-rejection loop and
rename that test accordingly; preserve its Float / Bool / Symbol rejection
and every other assertion.

Amend `SPEC.md` §4.6 to say exactly: “Adds Aloe method bodies to the existing
built-in `List`, `String`, or `Int` class. For `List` declarations, `T`
denotes the list element type. `String` and `Int` have no class type
parameter, so `T` is not implicitly in scope there.” Leave the Int kernel
description in §7 unchanged in this layer. Add one dated `docs/decisions.md`
entry: Int is lifted for derived Aloe methods; Float, Bool, and Symbol remain
closed to `define-methods` in this series.

Verification: `raco test tests/int-methods/000-lift.rkt`,
`raco test tests/checkpoint-114.rkt`, `raco test tests`, and
`git diff --check`. Stop after green and review; do not start layer 001.

## Layer 001 — Library `min` and `max`

**Allowed files:** `lib/int.aloe` (new), `aloe/library.rkt`, `aloe/main.rkt`,
`aloe/driver.rkt`, `SPEC.md`, `tests/int-methods/001-library.rkt` (new),
`tests/editor/expression-query/003-public-query.rkt`,
`tests/editor/completion/002-public-query.rkt`,
`tests/int-methods/000-lift.rkt`, and `tests/checkpoint-86.rkt`.
The two editor test files may update only Int default-row expectations;
`tests/int-methods/000-lift.rkt` may update only default Int row and invoke
expectations; `tests/checkpoint-86.rkt` may add only the `min` and `max` lines
to `int-transcript`. Their other assertions and implementation files stay
untouched. No `aloe/env.rkt`, `aloe/type.rkt`, `aloe/eval.rkt`, or
`aloe/signature-catalog.rkt` edit belongs in this layer.

`lib/int.aloe` contains exactly one `define-methods Int` form and exactly
these two methods, in this order:

```aloe
(define-methods Int
  (methods
    (min (other Int) Int
      (if (self < other) self other))
    (max (other Int) Int
      (if (self > other) self other))))
```

The `if` arms return the operands themselves. Equal operands therefore
return the common value. These are ordinary Aloe sends, with no Int/Float
mixing and no Racket `min` / `max` dispatch cases.

In `aloe/library.rkt`, add a cached `int-library-expressions` reader for
`lib/int.aloe`, parallel to `string-library-expressions`. Typecheck and
evaluate the Int expressions after List and String in every default checked
environment: `aloe/main.rkt`'s `make-type-environment`,
`make-top-level-env`, and `type-environment-for` fallback for a supplied raw
runtime environment; and `aloe/driver.rkt`'s `make-driver`, which covers
`bin/aloe`. Pair checker and runtime installation. Do not put bootstrap
policy in the raw constructors `aloe/type.rkt:make-type-environment` or
`aloe/env.rkt:make-top-level-env`. A fresh `make-driver`, `eval-source`, and
public `make-top-level-env` can send `min` and `max` without a test loading
the library. Direct raw runtime and checker environments still reject them
before load; the public fallback may then bootstrap a supplied raw runtime
environment as it already does for String.

Test both methods on all four receiver/argument sign combinations, including
`(3 min 2)`, `(-3 min 2)`, `(3 min -2)`, and `(-3 min -2)` with their `max`
counterparts. Test positive and negative ties. In valid Aloe source a
negative literal is the receiver in `(-3 min 2)`; `((-3) min 2)` is not valid
syntax because `(-3)` has no selector. Check `Int` as the inferred result
type; `(3 min "x")` and `(3 max 2.0)` are static type errors, and raw
dispatch rejects wrong argument types. Prove the library has only the two
declared methods and that `min` / `max` do not appear as Int kernel cases or
kernel signature rows. Default Int reflection has 13 rows: the unchanged 11
kernel rows, then `(min (Int) Int)` and `(max (Int) Int)`. Test `Mirror.messages`
uniqueness, checker/runtime signature parity, direct sends, and exact
`Mirror.invoke` of both library rows. Test fresh environment isolation.
Update the two named editor test fixtures that expect Int's default
signature catalog, and `tests/int-methods/000-lift.rkt` default-row
lists and invoke indexes (kernel, then `min`/`max`, then its test-only
methods). Raw-kernel fixture tests must keep the 11-row expectation.
In `tests/checkpoint-86.rkt`, update only `int-transcript` to append
`"12  min  1\r\n"` and `"13  max  1\r\n"` after its existing `text` line.
Preserve the Point transcript, key lines, and every other assertion.

Add this sentence to the Int part of `SPEC.md` §7 after its existing kernel
and conversion description: “`min` and `max` are Aloe methods defined in
`lib/int.aloe` and installed in default checked environments; they are
derived from `<`, `>`, and `if`, not kernel messages.” Preserve the existing
Int kernel operation list and the explicit `(n float)` conversion.

Verification: `raco test tests/int-methods/001-library.rkt`,
`raco test tests/checkpoint-86.rkt`, `raco test tests`, and
`git diff --check`. Hand-check from the project root:

```sh
racket -e '(require "aloe/main.rkt") (displayln (eval-source "(-3 min 2)")) (displayln (eval-source "(-3 max 2)"))'
```

It prints `-3` and `2`, on separate lines. Stop after green and review.

## Verification and acceptance

Automated tests must show the Int-only lift, environment-local method
tables, kernel-first dispatch, exact reflected row invocation, library
bootstrap at every named public path, raw isolation, all signed and tied
value cases, and static rejection of wrong types. The full `raco test tests`
run must stay green after each checkpoint. The layer 001 `racket -e` command
is the hand check for a fresh public evaluator.

The series is complete only when `define-methods Int` typechecks and runs
with `self : Int`; `min` and `max` are the exact Aloe methods above and are
available by default; the 11 kernel rows are unchanged and precede the two
installed rows; Float, Bool, and Symbol remain closed to `define-methods`;
and no kernel `min` / `max`, constructor, implicit numeric coercion, or
aloemacs edit has been added.
