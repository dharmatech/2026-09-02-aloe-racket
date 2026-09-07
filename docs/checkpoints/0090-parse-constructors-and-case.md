# Checkpoint 90 — parse constructors and case

**Branch.** `experiment/class-constructors`

**Depends on.** Checkpoint 89

**Status.** Ready to implement

## Goal

Parse Proposal B’s two new surface forms. Do not evaluate `case`. Do not
typecheck constructor sets or exhaustiveness. Do not migrate MPL or Gel.

## Authority

- Design: `docs/class-constructors.md` (Proposal B), §3, §5, §11.2.
- Law for running code: `SPEC.md` on this branch (checkpoint 88). Do not
  change its language rules here.
- Not authority: `codex/unified-nominal-adts` (Proposal A).

## Parse facts on this branch

- `define-class` currently matches only
  `(define-class header (fields …) (methods …))` and
  `(define-class header Protocol (fields …) (methods …))`.
- After special-form matches, a list whose second element is a symbol is a
  `send-expr`. `(e case …)` is therefore a send of `case` today and must be
  matched as a special form first.

## Files

May edit: `aloe/parse.rkt`, new tests under `tests/`, and other `aloe/*.rkt`
only as mechanical AST plumbing so existing struct matches still load.

Do not edit `SPEC.md` language rules, `examples/`, `lib/`, `gel/`, or MPL.

## Accept

Fields classes still parse and still mean one constructor named `new`:

```aloe
(define-class Point
  (fields (x Int) (y Int))
  (methods))
```

Constructors section plus `case` as syntax. Clause shape is the B examples:
`(Constructor (payload-name ...) body)`, optional final `(else body)`.

```aloe
(define-class (Option T)
  (constructors
    (None (fields))
    (Some (fields (value T))))
  (methods
    (present? () Bool
      (self case
        (None () #f)
        (Some (value) #t)))))
```

Incomplete `case` still parses. Exhaustiveness is a later checkpoint.

## Reject at parse

- `(fields …)` and `(constructors …)` on the same class, either order
- malformed constructor entries (not `(Name (fields …))`)
- duplicate constructor selectors; empty `(constructors …)`
- malformed `case` (no clauses; `else` not last; clause not
  `(Name (id ...) body)` or `(else body)`)

## Done when

Those accepts parse; those rejects raise `parse-datum` errors.
`(e case …)` is not a `send-expr`. `raco test` is green.
`case` bodies are parsed as expressions only — no eval, no exhaustiveness
check, no `Option` runtime goldens.