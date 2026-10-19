# Checkpoint 0078 — `GelRow` semantics

Status: Implemented
Depends on: Checkpoint 0077

## Goal

Make `GelRow` own the pending-argument semantics currently derived from its
signature by external helpers and callers.

## Contract

Add these methods to `GelRow`:

```lisp
(expected-text () String
  ((Mirror of (((self signature) params) first)) raw))

(int-hole? () Bool
  ((self expected-text) = "#<Symbol Int>"))

(accepts? (candidate Mirror) Bool
  ((self signature) accepts? candidate))
```

These methods preserve the current first-parameter representation and exact
`Signature.accepts?` behavior. They are used only for pending arity-one rows.

## Migration

- Remove `GelIntHole` and `gel-int-hole?`.
- Replace `(gel-int-hole? call row)` with `(row int-hole?)`.
- Replace external first-parameter text construction with
  `(row expected-text)`.
- Replace `((row signature) accepts? candidate)` with
  `(row accepts? candidate)`.
- Update affected tests, add `tests/checkpoint-78.rkt`, and update the Gel and
  checkpoint summaries after implementation.

Do not change row construction or selection, pick construction or selection,
menu formatting, key transitions, signature acceptance, or type presentation.

## Acceptance

- An exact `Int` argument row reports `int-hole?` as true and presents
  `"#<Symbol Int>"`.
- A non-`Int` argument row reports `int-hole?` as false.
- `accepts?` returns the same result as the row's signature for matching and
  mismatching mirrors.
- `GelIntHole` and `gel-int-hole?` are no longer bound.
- Pending menus, integer entry, typed picks, and terminal transcripts are
  unchanged.
- All checkpoint tests pass.
- By hand, these final three expressions evaluate to `"#<Symbol Int>"`, `#t`,
  and `#t`:

  ```lisp
  (load "gel/loop.aloe")
  (define rows (gel-rows call 10))
  (define row
    (rows fold (rows first)
      (fn (found candidate)
        (if (((candidate selector) name) = "+") candidate found))))
  (row expected-text)
  (row int-hole?)
  (row accepts? (Mirror of 2))
  ```

## Result

`GelRow` now owns first-parameter presentation, exact `Int`-hole detection,
and candidate-mirror acceptance. Pending menus, pick filtering, and key
transitions send those messages to the row; `GelIntHole` and `gel-int-hole?`
are removed without changing their behavior.
