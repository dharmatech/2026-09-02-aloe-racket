# Checkpoint 0072 — Nominal `GelStack`

Status: Implemented
Depends on: Checkpoint 0071

## Goal

Replace Gel's raw `(List Mirror)` stack with an immutable, data-bearing
`GelStack`. The first item remains TOS, and every item remains exactly one
`Mirror`.

## Contract

Add this class to `gel/stack.aloe`:

```lisp
(define-class GelStack
  (fields
    (items (List Mirror)))
  (methods
    (tos () Mirror
      ((self items) first))

    (push (value Mirror) GelStack
      (GelStack new
        ((self items) cons value)))

    (push (type T)
      (value T)
      GelStack
      (self push (Mirror of value)))))
```

The exact `Mirror` overload performs the stack reconstruction. The generic
overload wraps an ordinary value and delegates to it, so existing mirrors are
never wrapped twice.

## Migration

- Remove `GelPush` and `gel-push`.
- Change Gel's internal stack annotations from `(List Mirror)` to `GelStack`,
  including `GelStep` and `GelMain`.
- Update `GelStart` and `GelStartTwo` to construct and return `GelStack`.
- Replace pushes and TOS reads with `(stack push value)` and `(stack tos)`.
- Adapt `GelInvokeZero` and both `GelInvokeOne` overloads to accept and return
  `GelStack`; keep those classes and their bindings in this checkpoint.
- Where code must iterate over the underlying storage, use `(stack items)`.
- Update affected tests and add `tests/checkpoint-72.rkt`.

Do not otherwise reorganize invocation, key handling, menus, or text output,
and do not add new stack operations or Aloe language features.

## Acceptance

- Ordinary values are wrapped once; existing mirrors retain their identity.
- `tos` returns the most recently pushed mirror and fails on an empty stack as
  `List.first` does today.
- Existing zero- and one-argument invocation behavior still works through the
  adapted helper classes.
- Gel's menu behavior and scripted terminal transcript are unchanged.
- All checkpoint tests pass.
- By hand, this evaluates to `10`:

  ```lisp
  (load "gel/stack.aloe")
  (define stack
    ((GelStack new (List empty)) push 10))
  ((stack tos) subject)
  ```

## Result

Gel now uses the nominal, immutable `GelStack` throughout. Its overloads wrap
ordinary values once and retain existing mirrors, while invocation, menu,
pending-pick, TOS text, and terminal-loop behavior remain unchanged.
