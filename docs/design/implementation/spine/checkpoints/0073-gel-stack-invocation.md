# Checkpoint 0073 — `GelStack` invocation

Status: Implemented
Depends on: Checkpoint 0072

## Goal

Move reflected invocation onto the `GelStack` receiver. Replace the remaining
callable invocation helpers with the messages `invoke-zero` and `invoke-one`.

## Contract

Add these methods to `GelStack`:

```lisp
(invoke-zero
  (row GelRow)
  GelStack
  (self push
    ((self tos) invoke (row signature))))

(invoke-one
  (row GelRow)
  (arg Mirror)
  GelStack
  (self push
    ((self tos) invoke
      (row signature)
      (arg subject))))

(invoke-one (type T)
  (row GelRow)
  (arg T)
  GelStack
  (self push
    ((self tos) invoke
      (row signature)
      arg)))
```

The exact `Mirror` overload unwraps the argument with `subject`; the generic
overload passes an ordinary argument directly. Both send the selected exact
signature to TOS and push the result through `GelStack.push`.

## Migration

- Remove `GelInvokeZero`, `GelInvokeOne`, `gel-invoke-zero`, and
  `gel-invoke-one`.
- Replace their call sites with `(stack invoke-zero row)` and
  `(stack invoke-one row argument)`.
- Update affected tests and add `tests/checkpoint-73.rkt`.
- Update the Gel and checkpoint summaries after implementation.

Do not change `GelStack` storage, `tos`, or `push`; reorganize start, step,
menu, key, or text classes; or alter reflection and invocation semantics.

## Acceptance

- Zero-argument invocation pushes the same mirrored result as before.
- One-argument invocation works with both ordinary and mirrored arguments.
- Signature ownership, arity, argument-type, and result-type errors remain
  enforced by `Mirror.invoke`.
- The removed helper names are no longer bound.
- Gel's menus, key behavior, and terminal transcript are unchanged.
- All checkpoint tests pass.
- By hand, invoking the first row here evaluates to `10`:

  ```lisp
  (load "gel/loop.aloe")
  (load "examples/point.aloe")
  (define stack (gel-start call (Point new 10 20)))
  (define row ((gel-rows-from-mirror call (stack tos)) first))
  (((stack invoke-zero row) tos) subject)
  ```

## Result

Reflected zero- and one-argument invocation now lives on `GelStack`. Both
one-argument overloads preserve their ordinary-value and mirror behavior, the
old callable helpers are gone, and `Mirror.invoke` remains the validation
boundary.
