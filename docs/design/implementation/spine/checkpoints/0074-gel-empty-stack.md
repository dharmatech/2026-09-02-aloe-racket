# Checkpoint 0074 — Empty `GelStack`

Status: Implemented
Depends on: Checkpoint 0073

## Goal

Remove the callable start wrappers now that `GelStack.push` owns generic stack
construction. Reuse one immutable empty `GelStack` as the starting value.

## Contract

Define:

```lisp
(define gel-empty-stack
  (GelStack new (List empty)))
```

Start stacks by sending `push` directly:

```lisp
(gel-empty-stack push value)
((gel-empty-stack push under) push tos)
```

`GelStack` is immutable, so every `push` returns a new stack and leaves
`gel-empty-stack` unchanged. The method-local type in `push` is still fresh at
each send.

## Migration

- Remove `GelStart`, `GelStartTwo`, `gel-start`, and `gel-start-two`.
- Replace their call sites with the direct `push` forms above.
- Update affected tests, add `tests/checkpoint-74.rkt`, and update the Gel and
  checkpoint summaries after implementation.

Do not change `GelStack` methods or storage, reorganize step, menu, key, or text
classes, or alter Gel behavior.

## Acceptance

- Starting with one value produces that value at TOS.
- Starting with `under` and then `tos` preserves the existing TOS order.
- The same `gel-empty-stack` starts stacks containing different value types.
- Starting a stack does not change `gel-empty-stack`.
- The four removed class and value names are no longer bound.
- Gel's menus, key behavior, and terminal transcript are unchanged.
- All checkpoint tests pass.
- By hand, this evaluates to `"two"` and leaves the empty stack length at `0`:

  ```lisp
  (load "gel/loop.aloe")
  (define stack
    ((gel-empty-stack push 1) push "two"))
  ((stack tos) subject)
  ((gel-empty-stack items) len)
  ```

## Result

Gel now reuses the immutable `gel-empty-stack` and starts stacks with direct
`push` sends. The callable start wrappers are removed, heterogeneous starts
remain supported, and existing menu, key, and terminal behavior is unchanged.
