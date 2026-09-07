# Aloe philosophy

The kernel summary follows the unified target in [SPEC.md](../SPEC.md),
promoted in the **89I ratification change submitted for review**. Runtime
behavior remains at checkpoint 88; acceptance completes the design arc, and
each future implementation slice requires separate authorization.

Programming languages should be designed not by piling feature on top of
feature, but by removing the weaknesses and restrictions that make additional
features appear necessary.  — R4RS / R5RS

Aloe is a small diamond: Scheme’s growable core, with two facets changed.

- Evaluation is message send, not apply.
  `(receiver selector arg ...)` — eval receiver and args, not the selector.
- The language is typed. Structure is declared; expressions are inferred.

The kernel should stay small enough that new programs grow as *libraries and
families*, not as new host builtins. If a feature feels necessary, look for a
restriction first and lift that.

Grow the language from applications. Write a program in Aloe. Where it cannot
be expressed, decide whether the hole is a library, a lifted restriction, or
(rarely) a new kernel piece. Do not add syntax because it is fashionable.
Boids already drove send, `if`, `List`, and `fold`. The next hole should
come from the next program.

Send plus types exist so an editor can ask “what messages does this expression understand?” before the program runs.

## Kernel (keep small)

- send
- `fn` + `call`
- `define`, `define-family`, `self`, explicitly declared constructors
- products and closed variants in one immutable nominal model
- receiver-anchored exhaustive `case`; constructor refinements remain checker knowledge
- `Bool` and `(b if then-fn else-fn)`; `(if …)` is sugar
- `let` retains parallel `fn` + `call` behavior, with source aliases preserved through checking
- primitive objects: `Int`, `Float`, and a walkable list representation
- types in annotations and complete static send headers; checker, not a second language

## Not kernel (grow later)

- collections beyond list primitives — `fold` / `map` / `reverse` already live
  in `lib/list.aloe`
- application libraries: `Point`, `Boid`, `Sim`, Boids
- `#lang aloe`, `require`, macros

## Host boundary

Racket supplies irreducible host facts and effects through explicitly injected
capability values. Aloe owns domain objects, application policy, and the
composition around those effects. A capability is authority carried by a
value, never an ambient kernel power.

## Test of the diamond

A new program that does not force a new Racket builtin — only new families
and methods — means the core is still small enough.
