# Checkpoint 0075 — `GelStep` key transitions

Status: Implemented
Depends on: Checkpoint 0074

## Goal

Move key-transition behavior from the stateless `GelHandleKey` callable onto
the `GelStep` value whose state it reads and replaces.

## Contract

Keep the early `GelStep` declaration so later classes can name its type. After
the transition helpers are bound, use `define-methods GelStep` to attach:

| Selector | Arguments | Result |
|---|---|---|
| `handle-key` | `(key String)` | `GelStep` |
| `handle-idle` | `(key String)` | `GelStep` |
| `handle-pending` | `(key String)` | `GelStep` |
| `handle-int` | `(row GelRow) (key String)` | `GelStep` |
| `handle-pick` | `(row GelRow) (key String)` | `GelStep` |

Translate the existing behavior mechanically: the former `state` argument is
now `self`, and idle handling reads `(self stack)`. Each method returns either
`self` or a newly constructed immutable `GelStep` exactly as before.

The public transition send becomes:

```lisp
(step handle-key key)
```

## Migration

- Remove `GelHandleKey` and `gel-handle-key`, including both `call` overloads.
- Change state call sites to `(step handle-key key)`.
- Where a test previously passed a bare `GelStack`, construct its initial
  `GelStep` explicitly before sending `handle-key`; do not add another wrapper.
- Update affected tests, add `tests/checkpoint-75.rkt`, and update the Gel and
  checkpoint summaries after implementation.

Do not consolidate key parsing, row or pick selection, menu, or text helpers;
rename `GelStep`; or change any transition semantics.

## Acceptance

- Idle quit, no-op, zero-arity invocation, and arity-one pending behavior are
  unchanged.
- Pending cancellation, integer entry and return, and typed stack-pick behavior
  are unchanged.
- `GelStep` exposes `handle-key`; `GelHandleKey` and `gel-handle-key` are no
  longer bound.
- `gel-main` uses the new send and preserves its terminal transcript.
- All checkpoint tests pass.
- By hand, this evaluates to `#t` and then `#f`, showing that the transition
  returns a new state without changing the old one:

  ```lisp
  (load "gel/loop.aloe")
  (define state
    (GelStep new (gel-empty-stack push 10) #f (List empty) 0 #f))
  (define next (state handle-key "q"))
  (next quit)
  (state quit)
  ```

## Result

Key transitions now live on immutable `GelStep` values through `handle-key`
and its four supporting methods. The stateless callable handler is removed,
while idle, pending, integer-entry, typed-pick, menu, and terminal behavior
remain unchanged.
