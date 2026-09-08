# Checkpoint 94 — named construction and Option goldens

**Branch.** `experiment/class-constructors`

**Depends on.** Checkpoint 93

**Status.** Ready to implement

## Goal

Evaluate `(ClassName Constructor arg …)` and run the Proposal B §10
Option goldens. Do not add Tree. Do not migrate MPL or Gel. Do not
change `SPEC.md` language rules.

## Authority

- Design: `docs/class-constructors.md` (Proposal B), §3–§4, §8, §10, §11.6.
- Law for running code: `SPEC.md` on this branch (checkpoint 88).
- Not authority: `codex/unified-nominal-adts` (Proposal A).

## Runtime facts on this branch

- `lookup-message` on a `class-value` accepts only `new`.
- `construct-instance` always stores constructor `new` and uses
  `class-value-fields` for arity and type-argument inference.
- `define-class-expr` eval still ignores parsed constructors
  (`class-value` has no constructor set).
- `case` already switches on the stored constructor id.
- The checker already accepts named construction and Option `case`.

## Files

May edit: `aloe/eval.rkt`, new tests under `tests/`, and mechanical
`class-value` plumbing elsewhere if the struct grows a constructor list.

Do not edit `SPEC.md` language rules, `examples/`, `lib/`, `gel/`, or MPL.

## Construction

Install the constructor set on the class object.

- `(fields …)` → one constructor `new` with those fields.
- `(constructors …)` → those constructors.
- `(ClassName Constructor arg …)` allocates an `instance-value` whose
  constructor id is `Constructor` and whose payload is the arguments in
  field order.
- Arity follows that constructor’s fields.
- Unknown constructor remains `unknown message`.

After a successful check, do not fail at runtime merely because a type
parameter was determined only by expected type (`None`). The checker
already rejected `(define n (Option None))`. Runtime inference from
payload may leave a parameter undetermined; that is not a new kernel
type language.

Instance equality includes constructor identity.

## Option goldens

Define `Option` as in B §3 (`present?` is enough; `map` is optional).

Must run:

```aloe
(Option Some "x")
((Option Some "x") present?)    ; => #t
((Option Some "x") case
  (None () "unknown")
  (Some (name) name))           ; => "x"
```

`((Option None) present?)` needs a harness that determines `T` without
weakening §6. One acceptable spelling:

```aloe
((if #t (Option None) (Option Some "x")) present?)    ; => #f
```

Must still reject (checker):

```aloe
(define n (Option None))
((Option Some "x") case (Some (name) name))
```

Must still reject (runtime/unbound):

```aloe
(Some "x")
```

## Out of scope

- `Tree`
- moving Option into `lib/`
- Mirror / printer / Gel listing constructors
- ratifying B into `SPEC.md`

## Done when

Those goldens run through `eval-source`. Named construction stores the
constructor id `case` already uses. `raco test` is green. Existing
`(Point new …)` programs unchanged. No MPL/Gel migration.
