# Aloe handoff

Read first, in order: `SPEC.md`, `docs/philosophy.md`, `docs/decisions.md`,
`AGENTS.md`, `CHECKPOINTS.md`, this file. Spec is law. Decisions are
rejected ideas. Do not replay rejected designs.

## What Aloe is

S-expression language. A list is a **send**, not Scheme apply:

    (receiver selector arg ...)

Selector is a source symbol and is not evaluated. Functions are objects
that understand `call`. Types are static; infer where the user did not
write them.

Slogan / equation: Scheme + Smalltalk + Types. Grow the kernel only when
an application forces it. Convenience that adds a second meaning of a
list, or a second lookup rule, loses.

## Current state (0.2 on main)

- Interpreter + type checker in Racket. No compiler, no macros.
- `define-class`, `fn`/`call`, `let`, `if`/`cond`, `load`.
- Generics, `define-methods`, `List` library in `lib/list.aloe`.
- `String` primitive.
- Boids in `examples/boids.aloe` + `examples/point.aloe`.
- Protocols with required methods and C#-style method overloads.
- Cohen-style CAS fragment in `examples/mpl/`, with `Math` implemented by
  `Sym`, `Num`, `Sum`, `Prod`, and `Pow`; primitive `Int` is not `Math`.
- Like-term addition, product merging, power merging, and identity unwrapping:
  `x+0`, `x*0`, `x*1`, `x^0`, `x^1`, and a zero combined coefficient becomes
  `Num 0`.
- `Math.show` and default display through `show`; REPL `:raw` retains the
  structural `#<…>` printer.
- Tests through checkpoint 51 are green on `main`.
- Tag: `v0.1.0-boids` records the older 0.1 milestone.

## How to work

- Small checkpoints. `raco test` green before the next feature.
- Do not one-shot MPL or the checker.
- Do not weaken the type checker to make a golden pass.
- Do not patch `Int.+` for algebra. CAS lives on `Sym` / `Sum` / `Prod` / `Num`.
- Convention: math object first (`x + 2`). `(2 + x)` is still machine `Int`.
- `Math` is a **supertype**. Do not erase the class type of a send you
  will send to again. `(x + 2)` stays `(Sum Sym Int)`, which is also `Math`.
- Protocols are types, not method tables. Lookup stays on the class
  (now: class + selector + argument types).
- Overloading is C# (receiver class, then argument types), not Julia/CLOS.
- Most specific wins (exact class beats protocol). Tie → ambiguity error.
- No implicit `Int` → `Math` lift.
- `define-methods` after both classes exist (no forward declarations).

## Driving application for 0.2

MPL: Cohen-style automatic simplification.
Scheme: `github.com/dharmatech/mpl`
C# objects: `github.com/dharmatech/Symbolism`
Lean closed ADT: `github.com/dharmatech/symbolism.lean`

The current port is deliberately a fragment, written as idiomatic Aloe methods
rather than Wright `match`. Keep MPL in `examples/mpl/`; do not put it in
`lib/` until a second application wants it.

## Open / deferred

- N-ary `+`.
- `show-math`.
- Macros.
- `#lang aloe`.
- Graphics / FFI.

The implemented identities and algebra rules above are current behavior, not a
plan. Add further algebra only as a separately approved checkpoint.

## Designer vs implementer

If you are the designer: propose spec text and a checkpoint prompt;
wait for human approval; review the diff against this file.

If you are the implementer: implement only the approved checkpoint;
stop when `raco test` is green; do not add features from this file
that the prompt did not ask for.
