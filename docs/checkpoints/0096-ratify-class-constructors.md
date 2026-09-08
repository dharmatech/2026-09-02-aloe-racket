# Checkpoint 96 — ratify class constructors into SPEC

**Branch.** `experiment/class-constructors`

**Depends on.** Checkpoint 95

**Status.** Complete (documentation only)

## Goal

Copy the accepted Proposal B rules into `SPEC.md` so spec is law for
the running language. Update the design notes to match. No interpreter,
example, lib, Gel, or MPL change.

## Authority

- Accepted design: `docs/class-constructors.md` as implemented through
  checkpoint 95.
- Current law until this lands: `SPEC.md` (checkpoint 88 + later 0.2/0.3
  sections).
- Not authority: `codex/unified-nominal-adts` (Proposal A).

## Files

Edit only:

- `SPEC.md`
- `docs/class-constructors.md` (status line)
- `docs/decisions.md`
- `docs/handoff.md`
- `docs/philosophy.md` (kernel bullet only, if it still says generated
  `new` is the only construction story)
- `CHECKPOINTS.md` and this file

Do not edit `aloe/`, `examples/`, `lib/`, `gel/`, or MPL.

## SPEC edits

Keep existing Point / `new` text as the one-constructor case. Add the
generalization. Do not paste Proposal A.

### §3 Objects and classes

An instance records its class, generic arguments, constructor, and that
constructor’s payload. A class has a finite nonempty constructor set in
declaration order. Constructors are not types, not subtypes, and not
top-level bindings.

### §3.1 `define-class`

A class has either `(fields …)` or `(constructors …)`, not both.
`(fields …)` means one constructor named `new`. Each explicit
constructor is `(Name (fields …))`; the payload may be empty.
Constructor selectors are unique and are not instance method names.
Methods stay whole-class. Protocol opt-in is unchanged.
`define-methods` may not add constructors or collide with one.

### §3.2 Construction

```
(ClassName Constructor arg ...)
```

The selector is the constructor name. Arguments are the payload in
declaration order. `(Point new 1 2)` is the fields-class case.
No `(Some "x")` without the class object.

### §4 Special forms

Add `case`. It is syntax, not a send. `case` in second position is
reserved.

```
(scrutinee case
  (Constructor (payload-name ...) body)
  ...
  (else body)?)
```

Clause shape is the implemented examples, names in a list.

### §5 Types

Constructor names are not source types. `case` requires a concrete
class instance, not a protocol. Exhaustiveness: without `else`, name
each constructor in `S` exactly once; with `else`, a nonempty proper
subset. Reject unknown, duplicate, or impossible constructors. Report
missing constructors in declaration order. Payload binders have that
constructor’s field types inside the clause only.

Generic construction must determine every class type parameter from
payload arguments and/or an expected type. Unknown at the end of the
expression is a type error (`(define n (Option None))`). No send-site
`(type …)` header. `List empty` is unchanged.

### §9 Goldens

Keep the current Point / List / Boids goldens. Add the implemented
Option and Tree accepts and the three Option rejects from B §10.

### New §13 0.4 additions

Short bullets pointing at the sections above: constructors, `case`,
generic construction from expected type.

## Other docs

- `docs/class-constructors.md`: status is ratified on this branch;
  `SPEC.md` is law. Leave the historical proposal text.
- `docs/decisions.md`: record that this branch took Proposal B, not A.
  Rejected here: `define-family`, factories, constructor-local methods,
  `per-constructor`, send-site `(type …)`, constructor names as types,
  nested patterns, elaboration IR.
- `docs/handoff.md`: B is implemented through 95 and ratified by this
  checkpoint. Stop saying SPEC is only checkpoint 88.
- `docs/philosophy.md`: construction is class-object send of a
  constructor selector; `new` remains the fields-class selector.

## Done when

Those documents match the running language. `raco test` is still green
with no code change. Proposal A is still not on this branch.
