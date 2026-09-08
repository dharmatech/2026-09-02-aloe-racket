# Checkpoint 92 — evaluate case

**Branch.** `experiment/class-constructors`

**Depends on.** Checkpoint 91

**Status.** Ready to implement

## Goal

Evaluate `(e case …)`. Switch on the instance’s stored constructor id.
Bind payload names to that constructor’s fields. Do not add named
constructor sends. Do not typecheck exhaustiveness. Do not migrate MPL
or Gel.

## Authority

- Design: `docs/class-constructors.md` (Proposal B), §5, §8, §11.4.
- Law for running code: `SPEC.md` on this branch (checkpoint 88). Do not
  change its language rules here.
- Not authority: `codex/unified-nominal-adts` (Proposal A).

## Runtime facts on this branch

- `case-expr` is `(scrutinee clauses else-body)`. Each `case-clause` is
  `(selector payload-names body)`.
- `eval-expr` has no `case-expr` clause. `eval-source` typechecks first.
- Every instance from `construct-instance` has constructor `new`.
- Class objects still accept only selector `new`. Parsed
  `(constructors …)` is still ignored at eval.

## Files

May edit: `aloe/eval.rkt`, new tests under `tests/`. Touch `aloe/type.rkt`
only if a test must go through `eval-source` and the checker would
otherwise reject `case-expr`; do not implement B §5 exhaustiveness or
§6 inference there.

Do not edit `SPEC.md` language rules, `examples/`, `lib/`, `gel/`, or MPL.

## Accept

On a fields class, after `(define-class Point (fields (x Int) (y Int))
(methods))`:

```aloe
((Point new 1 2) case
  (new (x y) x))                 ; => 1

((Point new 1 2) case
  (Some (v) v)
  (else 0))                      ; => 0
```

Evaluate the scrutinee once. Evaluate only the matching body. Payload
names bind field values in declaration order via `make-local-env`,
parent = the `case` environment (`self` and outer bindings stay visible).

## Reject at runtime

- scrutinee is not an instance
- payload arity ≠ field count
- no matching constructor and no `else`

## Out of scope

- `(Option Some "x")` / `(Option None)`
- checker exhaustiveness, missing-constructor reports, constructor-set
  validation
- `case` on protocol-typed values (type rule, later)

Tests may use `parse-datum` + `eval-expr` so the checker can stay closed.

## Done when

Those accepts run. Those runtime rejects error. `raco test` is green.
`case` still has no exhaustiveness check. No `Option` goldens.
