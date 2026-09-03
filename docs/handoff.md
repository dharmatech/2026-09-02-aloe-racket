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

## What 0.1 already is (main)

- Interpreter + type checker in Racket. No compiler, no macros.
- `define-class`, `fn`/`call`, `let`, `if`/`cond`, `load`.
- Generics, `define-methods`, `List` library in `lib/list.aloe`.
- `String` primitive.
- Boids in `examples/boids.aloe` + `examples/point.aloe`.
- Tag: `v0.1.0-boids` (older); current main includes strings.

## Branches

| Branch | Role |
|---|---|
| `main` | Validated Aloe + Boids + strings |
| `experiment/math-interface` | `define-protocol`, empty `Math` |
| `experiment/mpl-interface` | MPL on `Math`; `plus` for like terms |
| `experiment/overload` | **current** C# overloading; `((x + 2) + x)` is `+` |
| `experiment/mpl` | Old blocked sums; ignore |

Language that you would keep if MPL died belongs on `main` or
`experiment/math-interface`. Incomplete CAS stays on an MPL branch.

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

Port piecemeal, idiomatic Aloe (methods, not Wright `match`).
`examples/mpl/` only. Do not put MPL in `lib/` until a second app wants it.

## Open / deferred

- `x + 0 = x` needs `zero?` on `Math` or a typecase; not a union punch.
- Closed `data` / ADTs: later control experiment, not now.
- Macros, `->`, `sl` / `bi`, `#lang aloe`: later.
- Graphics / FFI: later.

## Current goal (as of 2026-09-03)

`experiment/overload`, checkpoint 32 green: `Sum` has two `+` methods
(`Int` and `Sym`). Next algebra only if the user asks. Next language
work only if an application golden requires it.

## Designer vs implementer

If you are the designer: propose spec text and a checkpoint prompt;
wait for human approval; review the diff against this file.

If you are the implementer: implement only the approved checkpoint;
stop when `raco test` is green; do not add features from this file
that the prompt did not ask for.