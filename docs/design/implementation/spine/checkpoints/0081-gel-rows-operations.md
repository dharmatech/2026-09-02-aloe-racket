# Checkpoint 0081 — `GelRows` operations

Status: Implemented
Depends on: Checkpoint 0080

## Goal

Make `GelRows` a cohesive row service with named construction and selection
messages. Remove its function-shaped `call` interface and the separate row
selector callable.

## Contract

`GelRows` exposes:

| Selector | Arguments | Result |
|---|---|---|
| `of` | `(mirror Mirror)` | `(List GelRow)` |
| `of` | `(type T) (value T)` | `(List GelRow)` |
| `select` | `(rows (List GelRow)) (index Int)` | `GelRow` |

Rename the two existing `call` overloads to `of`. Preserve the exact `Mirror`
row-building body, and have the generic overload delegate with:

```lisp
(self of (Mirror of value))
```

Move the existing selection algorithm into `GelRows.select` unchanged:

```lisp
(let ((row
       (rows fold
         (rows first)
         (fn (found candidate)
           (if ((candidate index) = index)
               candidate
               found)))))
  (if ((row index) = index)
      row
      ((List empty) first)))
```

## Migration

- Replace `(gel-rows call value)` with `(gel-rows of value)`.
- Remove `GelSelectRow` and `gel-select-row`.
- Replace `(gel-select-row call rows index)` with
  `(gel-rows select rows index)`.
- Update affected tests, add `tests/checkpoint-81.rkt`, and update the Gel and
  checkpoint summaries after implementation.

Do not introduce a nominal row collection or change row construction,
overload selection, selection results or errors, menus, picks, or transitions.

## Acceptance

- `of` preserves ordinary-value and exact-`Mirror` rows without reflecting a
  mirror twice, and remains independently polymorphic across sends.
- `select` returns the same row for every valid one-based index.
- An absent index retains the existing `first on empty List` failure.
- `GelRows` no longer has a `call` method.
- `GelSelectRow` and `gel-select-row` are no longer bound.
- Gel's menus, key behavior, invocation results, and terminal transcript are
  unchanged.
- All checkpoint tests pass.
- By hand, this evaluates to `1`:

  ```lisp
  (load "gel/loop.aloe")
  ((gel-rows select (gel-rows of (Mirror of 10)) 1) index)
  ```

## Result

`GelRows` now exposes named `of` construction overloads and owns indexed row
selection through `select`. All Gel and checkpoint callers use the cohesive
service; the function-shaped `call` methods, `GelSelectRow`, and
`gel-select-row` are removed without changing rows, errors, menus, picks, or
transitions.
