# int-methods 001 — Int `min` and `max` library

**Status:** Implemented and reviewed.

## Goal

Define `min` and `max` as Aloe methods in `lib/int.aloe` and install them in
every default checked environment. This checkpoint completes the
`int-methods` series. Stop without changing the Int kernel, adding Float
methods, or editing aloemacs.

## Authority and starting point

The implementer receives this checkpoint and the accepted
[`spec.md`](../spec.md); this checkpoint narrows the spec to one slice and does
not revise it. Series identity is `int-methods`, and this is checkpoint 001.
The governing spec sections are “Product boundary,” “Host and layout,” “Layer
001 — Library `min` and `max`,” and “Verification and acceptance.” Its
predecessor, [int-methods 000](000-lift-int-methods.md), is implemented and
reviewed in the current tree. Work from the project root
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

Read `SPEC.md` and `CHECKPOINTS.md` before code, as `AGENTS.md` requires.
The Int method dispatch, checker support, and reflection added in 000 are the
starting point. Follow the existing String library and bootstrap paths in
`aloe/library.rkt`, `aloe/main.rkt`, and `aloe/driver.rkt`.

## Exact file scope

Create `lib/int.aloe` and `tests/int-methods/001-library.rkt`. Edit only:

- `aloe/library.rkt`
- `aloe/main.rkt`
- `aloe/driver.rkt`
- `SPEC.md`
- `tests/editor/expression-query/003-public-query.rkt`, only for default Int
  row expectations
- `tests/editor/completion/002-public-query.rkt`, only for default Int row
  expectations
- `tests/int-methods/000-lift.rkt`, only for default Int signature-row
  lists, `Mirror.messages` uniqueness counts, and `Mirror.invoke` indexes
  that assumed a default environment had the 11 kernel rows and then the
  test-only methods. After this slice, default Int rows are the 11 kernel
  rows, then `min` and `max`, then any methods that test installs. Do not
  weaken the lift assertions (test-only `twice` / `triple` / `keep` /
  `text`, kernel precedence, isolation, rejected targets).
- `tests/checkpoint-86.rkt`, only the `int-transcript` fixture: append
  `"12  min  1\r\n"` and `"13  max  1\r\n"` after the existing `text` line.
  Preserve its Point transcript, key lines, and every other assertion.

Leave `aloe/env.rkt`, `aloe/type.rkt`, `aloe/eval.rkt`,
`aloe/signature-catalog.rkt`, all other libraries, editor implementation
files, aloemacs, `CHECKPOINTS.md`, prior checkpoints, and unrelated tests
untouched. Preserve raw-kernel fixtures that expect the 11 Int kernel rows.
If another file is necessary, stop and send this checkpoint back for a scope
correction.

## Exact Aloe library

`lib/int.aloe` contains one `define-methods Int` form and exactly these two
methods, in this order:

```aloe
(define-methods Int
  (methods
    (min (other Int) Int
      (if (self < other) self other))
    (max (other Int) Int
      (if (self > other) self other))))
```

The arms return the operands themselves, including on ties. Use ordinary
Aloe sends and `if`; do not add Racket `min` or `max` cases, kernel signature
rows, coercion, or a constructor.

## Default bootstrap

Add a cached `int-library-expressions` reader in `aloe/library.rkt` for
`lib/int.aloe`, parallel to `string-library-expressions`. Install its
expressions **after List and String**, pairing typechecking and evaluation
where default environments are built:

1. `aloe/main.rkt`'s public `make-type-environment` and
   `make-top-level-env`;
2. `aloe/main.rkt`'s `type-environment-for` fallback when a caller supplies a
   raw runtime environment to `eval-source`, `eval-datum`, or `eval-program`;
3. `aloe/driver.rkt`'s `make-driver`, which also supplies `bin/aloe`.

A fresh default environment can send `min` and `max` without an explicit
`load`. The raw constructors in `aloe/env.rkt` and `aloe/type.rkt` remain raw:
direct raw runtime and checker environments reject these messages before
library installation. A public evaluator may bootstrap a supplied raw
runtime environment through its existing fallback. Keep the installed
methods local to each environment.

## Tests first and acceptance

Add focused tests in `tests/int-methods/001-library.rkt` before implementing
the library and loader. Cover at least:

- Both methods and `Int` as the inferred result type for every row here:

  | Receiver and argument | `min` | `max` |
  | --- | ---: | ---: |
  | `3`, `2` | `2` | `3` |
  | `-3`, `2` | `-3` | `2` |
  | `3`, `-2` | `-2` | `3` |
  | `-3`, `-2` | `-3` | `-2` |
  | `3`, `3` | `3` | `3` |
  | `-3`, `-3` | `-3` | `-3` |

  Write negative literals directly as receivers, for example
  `(-3 min 2)`. `((-3) min 2)` is invalid Aloe syntax.
- Static type errors for `(3 min "x")` and `(3 max 2.0)`, plus raw runtime
  rejection of wrong argument types. Keep Int/Float separation and ordinary
  method arity checks.
- The exact one-form, two-method library source and absence of Int kernel
  `min`/`max` cases or rows. Confirm the 11 kernel signatures remain in their
  existing order.
- Default availability through public `make-type-environment`,
  `make-top-level-env`, `eval-source`, and a fresh `make-driver`; exercise the
  public fallback with a supplied raw runtime environment. Direct raw
  runtime and checker environments must still reject `min` and `max` before
  installation. A method added to one fresh environment must not leak into
  another.
- Default Int reflection has 13 rows: `+ - * / < > <= >= = float text`,
  then `(min (Int) Int)` and `(max (Int) Int)`. Check the runtime rows against
  checker `type-signature-specs`, unique `Mirror.messages`, direct sends, and
  exact `Mirror.invoke` of both library rows.
- The two named editor test files expect the appended `min` and `max` rows
  for default Int queries. Change only those fixture expectations; leave
  their implementation and raw-kernel expectations unchanged.
- `tests/int-methods/000-lift.rkt` uses public `make-type-environment` /
  `make-top-level-env`, then installs test-only methods. Update its
  expected selector list and invoke indexes so `min` and `max` sit after
  the 11 kernel rows and before `twice`. Keep the test-only methods and
  the `(Int new 1)` / Float-Bool-Symbol rejections.
- `tests/checkpoint-86.rkt` expects the two new Int rows in its default
  driver transcript. Change only `int-transcript`; this is fixture
  maintenance for the existing Gel run, not a Gel behavior change.

## Language record

Add this sentence to the Int part of `SPEC.md` §7 after its existing kernel
and conversion description:

> `min` and `max` are Aloe methods defined in `lib/int.aloe` and installed in
> default checked environments; they are derived from `<`, `>`, and `if`, not
> kernel messages.

Preserve the existing Int kernel operation list and explicit `(n float)`
conversion.

## Verification and completion

From the project root, run:

```sh
raco test tests/int-methods/001-library.rkt
raco test tests/checkpoint-86.rkt
raco test tests
git diff --check
racket -e '(require "aloe/main.rkt") (displayln (eval-source "(-3 min 2)")) (displayln (eval-source "(-3 max 2)"))'
```

The hand check must print `-3` and `2` on separate lines. If the full suite
needs a writable temporary directory, use `TMPDIR=/tmp raco test tests`.
The checkpoint is complete when all verification passes and the acceptance
tests above hold. Report results, then stop for review. Do not start the
later aloemacs consumer work.
