# Checkpoint 0077 — `GelRows` mirror overload

Status: Implemented
Depends on: Checkpoint 0076

## Goal

Consolidate ordinary-value and existing-mirror row construction in `GelRows`.
Remove the separate callable that performs the mirror-specific case.

## Contract

Give `GelRows.call` an exact `Mirror` overload containing the row-building
algorithm, then make the generic overload reflect and delegate:

```lisp
(call
  (mirror Mirror)
  (List GelRow)
  (((mirror signatures) fold
      (List empty)
      (fn (rows signature)
        (rows cons
          (GelRow new
            ((rows len) + 1)
            (signature selector)
            ((signature params) len)
            signature))))
    reverse))

(call (type T)
  (value T)
  (List GelRow)
  (self call (Mirror of value)))
```

The exact overload prevents an existing mirror from being reflected again.
Both cases use the same ordering and one-based indexing algorithm.

## Migration

- Remove `GelRowsFromMirror` and `gel-rows-from-mirror`.
- Replace `(gel-rows-from-mirror call mirror)` with
  `(gel-rows call mirror)`.
- Update affected tests, add `tests/checkpoint-77.rkt`, and update the Gel and
  checkpoint summaries after implementation.

Do not change `GelRow`, row selection, picks, menu formatting, key transitions,
reflection behavior, or signature ordering.

## Acceptance

- Ordinary values produce the same rows as before.
- Existing mirrors produce rows for their subjects, not for the `Mirror` API.
- Both overloads preserve selector, arity, signature, order, and one-based
  index values.
- The generic overload remains independently polymorphic across calls.
- `GelRowsFromMirror` and `gel-rows-from-mirror` are no longer bound.
- Gel's menus, key behavior, and terminal transcript are unchanged.
- All checkpoint tests pass.
- By hand, this evaluates to `#t`:

  ```lisp
  (load "gel/loop.aloe")
  (load "examples/point.aloe")
  (define point (Point new 10 20))
  ((((gel-rows call point) first) label) =
   (((gel-rows call (Mirror of point)) first) label))
  ```

## Result

`GelRows.call` now owns the single row-building algorithm in its exact
`Mirror` overload. The generic overload reflects ordinary values and delegates
to it, all mirror call sites use `gel-rows`, and the duplicate
`GelRowsFromMirror` callable and binding are removed without changing row,
menu, key, or terminal behavior.
