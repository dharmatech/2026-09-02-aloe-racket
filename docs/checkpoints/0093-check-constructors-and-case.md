# Checkpoint 93 — constructor sets and case checking

**Branch.** `experiment/class-constructors`

**Depends on.** Checkpoint 92

**Status.** Ready to implement

## Goal

Typecheck constructor sets, `case` exhaustiveness, and generic
construction as in Proposal B §5–§6. Do not evaluate named constructor
sends. Do not migrate MPL or Gel. Do not change `SPEC.md` language rules.

## Authority

- Design: `docs/class-constructors.md` (Proposal B), §3, §5, §6, §11.5.
- Law for running code: `SPEC.md` on this branch (checkpoint 88).
- Not authority: `codex/unified-nominal-adts` (Proposal A).

## Checker facts on this branch

- `define-class-expr` already carries `fields` or `constructors`.
- `class-info` and `check-class-definition!` only see `fields`.
- `infer-send` on a `class-type` accepts only selector `new`.
- `infer-construction` does not take an expected type.
- `infer-expression` has no `case-expr` clause.
- Generic class method bodies are not checked today
  (`check-body?` is `(null? type-parameters)`).

## Files

May edit: `aloe/type.rkt`, new tests under `tests/`, and `aloe/eval.rkt`
only if `class-value` must record the constructor set for later slices.
Do not add named constructor evaluation.

Do not edit `SPEC.md` language rules, `examples/`, `lib/`, `gel/`, or MPL.

## Record the set

A class has a finite nonempty constructor set `S`, declaration order.

- `(fields …)` → one constructor `new` with those fields.
- `(constructors …)` → those constructors.
- Constructor selectors are unique and are not instance method names.
- `define-methods` may not add constructors (already true) and may not
  collide with a constructor selector.

## Check `case`

Scrutinee type must be a concrete class instance, not a protocol.

- Without `else`: clauses name each constructor in `S` exactly once.
- With `else`: named constructors are a nonempty proper subset of `S`.
- Reject unknown, duplicate, or impossible constructors.
- Report missing constructors in declaration order.
- Payload arity matches that constructor’s fields. Binders get those
  field types (after the instance’s generic substitution). That
  knowledge does not escape the clause.
- Bodies are checked against the expected type when there is one;
  otherwise they unify with each other.

Walk `case` in `infer-expression`. Also walk method bodies of
`(constructors …)` classes, including generic ones, far enough to apply
these rules. Do not use 92’s Point/`Some`/`else` program as a type
golden: `Some` is not in Point’s set.

## Infer construction

`(ClassName Constructor arg …)` is construction when `Constructor` ∈ `S`.
Reuse field-order arity and field-type checks.

Generic parameters must be determined by the end of the expression:

- payload argument types constrain them
- an expected type constrains them (`(Option None)` is legal where
  `(Option String)` is expected)
- still unknown → type error (`(define n (Option None))`)

No send-site `(type …)` header. Thread `expected` into construction.
`List empty` staying a fresh variable is unchanged.

Tests for named construction should use `typecheck-source` / `type-of`,
not `eval-source`. Runtime of `(Option Some "x")` stays later.

## Accept (checker)

```aloe
((Point new 1 2) case (new (x y) x))

(define-class (Option T)
  (constructors
    (None (fields))
    (Some (fields (value T))))
  (methods))

(Option Some "x")
(if ok (Option Some "x") (Option None))
```

## Reject (checker)

```aloe
(define n (Option None))
((Option Some "x") case (Some (name) name))
((Point new 1 2) case (Some (v) v) (else 0))
```

Also reject `case` on a protocol-typed scrutinee, constructor/method
name clash, and payload arity mismatch.

## Done when

Those accepts typecheck. Those rejects are type errors. `raco test` is
green. Named constructors still do not evaluate. No `Option` runtime
goldens. No MPL/Gel migration.
