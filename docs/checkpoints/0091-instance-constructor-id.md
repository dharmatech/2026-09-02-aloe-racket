# Checkpoint 91 — constructor id on instances

**Branch.** `experiment/class-constructors`

**Depends on.** Checkpoint 90

**Status.** Ready to implement

## Goal

Every runtime instance records which constructor built it. Current
`(fields …)` classes store `new`. Do not evaluate `case`. Do not add named
constructor sends. Do not typecheck constructor sets. Do not migrate MPL
or Gel.

## Authority

- Design: `docs/class-constructors.md` (Proposal B), §2, §8, §11.3.
- Law for running code: `SPEC.md` on this branch (checkpoint 88). Do not
  change its language rules here.
- Not authority: `codex/unified-nominal-adts` (Proposal A).

## Runtime facts on this branch

- `instance-value` is `(class type-arguments field-values)`.
- The only allocator is `construct-instance`, used by class-object
  selector `new` (including `Mirror.invoke` of `new`).
- `class-value` still has a single `fields` list. Eval of
  `define-class-expr` ignores the parsed constructors field.
- `lookup-message` on a `class-value` accepts only `new`.

## Files

May edit: `aloe/eval.rkt`, new tests under `tests/`, and other `aloe/*.rkt`
only as mechanical struct plumbing so existing matches still load.

Do not edit `SPEC.md` language rules, `examples/`, `lib/`, `gel/`, or MPL.

## Accept

After `(Point new 1 2)` (fields class as today):

- the value is an `instance-value`
- its constructor identity is `new`
- `(point x)` / existing Point methods / `check` equality still work

All current suite programs keep their meaning. Every instance they
allocate carries `new`.

## Reject / out of scope

- Evaluating `(e case …)`
- `(Option Some "x")` / `(Option None)` as construction
- exhaustiveness or constructor-set checking
- changing Mirror / printer / Gel to mention constructors

Installing the parsed constructor list on `class-value` is allowed
plumbing. It is not required if the fields-`new` path stays green
without it. Do not use it to add new construction selectors yet.

## Done when

Tests observe `new` on a fields-class instance (export the accessor or
the struct). `raco test` is green. `case` is still parse-only.
No `Option` runtime goldens.
