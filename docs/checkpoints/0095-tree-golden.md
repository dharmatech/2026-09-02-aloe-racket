# Checkpoint 95 — Tree golden

**Branch.** `experiment/class-constructors`

**Depends on.** Checkpoint 94

**Status.** Ready to implement

## Goal

Run the Proposal B §10 Tree golden. Do not migrate MPL or Gel. Do not
change `SPEC.md` language rules.

## Authority

- Design: `docs/class-constructors.md` (Proposal B), §10 (later golden), §11.6.
- Law for running code: `SPEC.md` on this branch (checkpoint 88).
- Not authority: `codex/unified-nominal-adts` (Proposal A).

## Facts on this branch

Option named construction, `case`, exhaustiveness, and generic inference
already work. Tree is the same machinery with recursive field types
`(Tree T)` and recursive method sends on payloads.

## Files

May edit: `aloe/type.rkt` / `aloe/eval.rkt` only if recursive field types
or recursive `case` sends fail, plus new tests under `tests/`.

Do not edit `SPEC.md` language rules, `examples/`, `lib/`, `gel/`, or MPL.

## Accept

```aloe
(define-class (Tree T)
  (constructors
    (Leaf (fields (value T)))
    (Branch (fields (left (Tree T)) (right (Tree T)))))
  (methods
    (size () Int
      (self case
        (Leaf (value) 1)
        (Branch (left right)
          (((left size) + (right size))))))))

((Tree Leaf 1) size)                                 ; => 1
((Tree Branch (Tree Leaf 1) (Tree Leaf 2)) size)     ; => 2
```

Use `eval-source`. `T` is determined from the `Leaf` payloads.

A two-level tree is enough. Nested `Branch` is welcome if it stays small.

## Reject

- missing `Leaf` or `Branch` in `size`’s `case`
- `(Tree Branch (Tree Leaf 1) (Tree Leaf 2.0))` — `T` inconsistent
- `(define t (Tree Branch))` — arity

Do not add new pattern forms. Payloads stay flat: `(left right)`, not
nested patterns.

## Out of scope

- ratifying B into `SPEC.md`
- moving Tree or Option into `lib/`
- Mirror / printer / Gel
- MPL migration

## Done when

Those accepts run. Those rejects are type or arity errors. `raco test`
is green. Option goldens still pass. No MPL/Gel work.
