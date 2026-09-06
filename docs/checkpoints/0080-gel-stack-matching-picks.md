# Checkpoint 0080 — `GelStack.matching-picks`

Status: Implemented
Depends on: Checkpoint 0079

## Goal

Move pending-pick discovery from its stateless callable onto the `GelStack`
whose items it filters.

## Contract

After `GelPick` and `GelPicks` are defined, attach this method to `GelStack`:

```lisp
(define-methods GelStack
  (methods
    (matching-picks
      (row GelRow)
      GelPicks
      (GelPicks new
        (((self items) fold
            (List empty)
            (fn (picks candidate)
              (if (row accepts? candidate)
                  (picks cons
                    (GelPick new
                      ((picks len) + 1)
                      candidate))
                  picks)))
          reverse)))))
```

This is the existing matching algorithm with `stack` replaced by `self`.
Filtering, compact one-based numbering, and stack order remain unchanged.

## Migration

- Remove `GelMatchingPicks` and `gel-matching-picks`.
- Replace `(gel-matching-picks call stack row)` with
  `(stack matching-picks row)`.
- Update affected tests, add `tests/checkpoint-80.rkt`, and update the Gel and
  checkpoint summaries after implementation.

Do not relocate or otherwise change `GelPick` or `GelPicks`; change selection
or rendering; or alter row acceptance, pending transitions, menus, or stack
storage.

## Acceptance

- `GelStack.matching-picks` returns the same `GelPicks`, in the same order and
  with the same compact one-based indices, as the removed callable.
- Matching and mismatching stack mirrors are filtered through `row.accepts?`.
- `GelMatchingPicks` and `gel-matching-picks` are no longer bound.
- Pending menu text, valid and out-of-range pick handling, invocation results,
  and terminal transcripts are unchanged.
- All checkpoint tests pass.
- By hand, the final two expressions evaluate to `2` and `2`:

  ```lisp
  (load "gel/loop.aloe")
  (define rows (gel-rows call 10))
  (define row
    (rows fold (rows first)
      (fn (found candidate)
        (if (((candidate selector) name) = "+") candidate found))))
  (define stack
    (((gel-empty-stack push 2) push "skip") push 10))
  (define picks (stack matching-picks row))
  (picks len)
  (((picks select 2) mirror) subject)
  ```

## Result

Pending-pick discovery now lives on `GelStack.matching-picks`, using the
stack's immutable mirror items as the existing filter input and returning the
same ordered, compactly indexed `GelPicks`. Menu and transition callers send
the message to their stack, and `GelMatchingPicks` plus `gel-matching-picks`
are removed without changing pick behavior.
