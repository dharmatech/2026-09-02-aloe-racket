# Checkpoint 0079 — Nominal `GelPicks`

Status: Implemented
Depends on: Checkpoint 0078

## Goal

Replace the raw `(List GelPick)` boundary with an immutable nominal collection
that owns pick length and valid-index selection.

## Contract

Add:

```lisp
(define-class GelPicks
  (fields
    (items (List GelPick)))
  (methods
    (len () Int
      ((self items) len))

    (select
      (index Int)
      GelPick
      ((self items) fold
        ((self items) first)
        (fn (found candidate)
          (if ((candidate index) = index)
              candidate
              found))))))
```

`select` is used only with a one-based index from `1` through `len`; the
existing `GelStep` bounds check remains responsible for that precondition.

Change `GelMatchingPicks.call` to wrap its existing ordered list in
`GelPicks`. Preserve its filtering, numbering, and stack order exactly.

## Migration

- Change pending-pick boundaries from `(List GelPick)` to `GelPicks`.
- Remove `GelSelectPick` and `gel-select-pick`.
- Replace raw-list length and selection with `(picks len)` and
  `(picks select index)`.
- Make `GelMenuText.picks-text` accept `GelPicks` and fold `(picks items)`.
- Update affected tests, add `tests/checkpoint-79.rkt`, and update the Gel and
  checkpoint summaries after implementation.

Do not move matching onto `GelStack` yet; change `GelPick` rendering; or alter
row acceptance, menus, key transitions, selection results, or pick order.

## Acceptance

- `GelMatchingPicks.call` returns `GelPicks` with the same mirrors, one-based
  indices, and stack order as before.
- `len` reports the wrapped list length and `select` returns each valid indexed
  pick.
- Out-of-range keys remain no-ops because `GelStep` retains its bounds check.
- `GelSelectPick` and `gel-select-pick` are no longer bound.
- Pending menu text, typed-pick invocation, and terminal transcripts are
  unchanged.
- All checkpoint tests pass.
- By hand, the final two expressions evaluate to `2` and `20`:

  ```lisp
  (load "gel/loop.aloe")
  (define picks
    (GelPicks new
      (List of
        (GelPick new 1 (Mirror of 10))
        (GelPick new 2 (Mirror of 20)))))
  (picks len)
  (((picks select 2) mirror) subject)
  ```

## Result

Pending matches now cross Gel boundaries as immutable `GelPicks` values, with
the existing ordered list retained in `items` and collection-owned `len` and
valid-index `select` methods. Matching, menu rendering, and key transitions
use the nominal collection, while `GelSelectPick` and `gel-select-pick` are
removed without changing filtering, numbering, selection, or rendering.
