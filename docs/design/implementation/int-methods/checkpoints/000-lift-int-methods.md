# int-methods 000 — Lift `define-methods Int`

**Status:** Implemented and reviewed.

## Goal

Make `Int` a legal `define-methods` target with environment-local methods,
kernel-first ordinary dispatch, and exact reflected-row invocation. Prove the
lift with test-only methods. Stop before adding `lib/int.aloe`, `min`, `max`, or
default Int-library bootstrap; those belong to int-methods 001.

## Authority and starting point

The implementer receives this checkpoint and the accepted
[`spec.md`](../spec.md); this checkpoint narrows the spec to one slice and does
not revise it. Series identity is `int-methods`, and this is checkpoint 000.
The governing spec sections are “Product boundary,” “Host and layout,” and
“Layer 000 — Lift `define-methods Int`.” The predecessor is the existing String
lift in global checkpoint 114 and String library bootstrap in checkpoint 115;
there is no earlier `int-methods` checkpoint. Work from the project root
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

Read `SPEC.md` and `CHECKPOINTS.md` before code, as `AGENTS.md` requires.
`SPEC.md` is the language authority. Follow the String path in
`aloe/env.rkt`, `aloe/type.rkt`, and `aloe/eval.rkt` without creating a general
primitive-class framework.

## Exact file scope

Create `tests/int-methods/000-lift.rkt` and edit only:

- `aloe/env.rkt`
- `aloe/type.rkt`
- `aloe/eval.rkt`
- `SPEC.md`
- `docs/decisions.md`
- `tests/checkpoint-114.rkt`, only to remove `Int` from its now-obsolete
  target-rejection loop and rename that test accordingly

Leave `aloe/signature-catalog.rkt`, `aloe/library.rkt`, `aloe/main.rkt`,
`aloe/driver.rkt`, all `lib/` files, editor and aloemacs files, parsing, other
tests, `CHECKPOINTS.md`, and prior checkpoint documents untouched. If another
file is necessary, stop and send this checkpoint back for a scope correction.

## Required behavior

1. Add an Int class object and per-environment method table parallel to
   String's runtime and checker class objects. A fresh runtime environment
   binds `Int` to that object and retains it; local environments carry the
   same reference. A fresh checker environment binds `Int` with type
   `(Class Int)`, while integer values keep type `Int`. Int has no class type
   parameter, so `T` is not implicitly in method scope; explicit method-local
   type parameters retain their existing behavior.
2. Accept only `define-methods Int` in addition to the existing targets.
   Install a form's full method declarations before checking bodies, allowing
   methods in that form to call one another. Check bodies with `self : Int`,
   declared parameter types, and declared return types. Runtime bodies use
   their captured definition environment. An Int method installed in one
   environment must not appear in another.
3. Preserve all 11 Int kernel rows, in this order: `+ - * / < > <= >= = float
   text`. Ordinary Int sends use kernel behavior and static checks first,
   then installed Aloe methods for otherwise unknown selectors. Method
   overload, arity, and argument-type rules match String. Do not change
   numeric inference, Float dispatch, or implicit coercion rules.
4. Append installed Int rows after the 11 kernel rows in runtime
   `Mirror.signatures` and checker `type-signature-specs`, with matching order
   and types. `Mirror.messages` remains unique by selector. An ordinary send
   to a selector shared with the kernel uses the kernel; `Mirror.invoke` of
   the installed row invokes that exact method body. The Int class object has
   no callable class rows or constructor, so `(Int new 1)` stays invalid.
5. Keep `define-methods Float`, `Bool`, and `Symbol` rejected in both checked
   and raw runtime paths. Preserve List, String, and user-class behavior.

## Tests first

Add focused tests in `tests/int-methods/000-lift.rkt` before implementation.
Cover at least:

- A test-only `(twice () Int (self + self))` method that typechecks and runs,
  with `Int` as its inferred send result; absence from fresh raw and fresh
  default environments; and isolation across separate environments.
- A method body that confirms `self : Int`, same-form method calls, explicit
  method-local type parameters, and rejection of an undeclared class-level
  `T`.
- Wrong arity and wrong argument types for a test-only Int method, checked
  statically and rejected by raw dispatch. Kernel arithmetic and its
  checker/runtime type rules remain unchanged.
- Rejection of Float, Bool, and Symbol as `define-methods` targets in both
  paths, plus rejection of `(Int new 1)` in both paths.
- Int signature rows in kernel order followed by installed rows, with
  checker/runtime signature parity, unique `Mirror.messages`, direct sends,
  and exact `Mirror.invoke` of an installed row.
- A test-only `text` method returning a different type or value from the
  kernel: ordinary `(3 text)` still uses the kernel, while invocation of the
  installed `text` row runs its Aloe body.

In `tests/checkpoint-114.rkt`, remove only the obsolete Int rejection from
the target-rejection loop and rename that test; preserve its Float, Bool,
Symbol, and all other assertions.

## Language and decision records

In `SPEC.md` §4.6, replace the target description with exactly:

> Adds Aloe method bodies to the existing built-in `List`, `String`, or `Int`
> class. For `List` declarations, `T` denotes the list element type. `String`
> and `Int` have no class type parameter, so `T` is not implicitly in scope
> there.

Leave the Int kernel and conversion description in §7 unchanged for this
checkpoint. Add one dated entry to `docs/decisions.md` stating that Int is
lifted for derived Aloe methods while Float, Bool, and Symbol remain closed to
`define-methods` in this series.

## Verification and completion

From the project root, run:

```sh
raco test tests/int-methods/000-lift.rkt
raco test tests/checkpoint-114.rkt
raco test tests
git diff --check
```

The checkpoint is complete when these pass and the tests prove all behavior
above. Report the files changed and verification results, then stop for human
review. Do not begin int-methods 001, add the Int library, or edit aloemacs.
