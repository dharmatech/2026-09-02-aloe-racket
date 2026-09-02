# Aloe philosophy

Programming languages should be designed not by piling feature on top of
feature, but by removing the weaknesses and restrictions that make additional
features appear necessary.  — R4RS / R5RS

Aloe is a small diamond: Scheme’s growable core, with two facets changed.

- Evaluation is message send, not apply.
  `(receiver selector arg ...)` — eval receiver and args, not the selector.
- The language is typed. Structure is declared; expressions are inferred.

The kernel should stay small enough that new programs grow as *libraries and
classes*, not as new host builtins. If a feature feels necessary, look for a
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
- `define`, `define-class`, `self`, generated `new`
- `Bool` and `(b if then-fn else-fn)`; `(if …)` is sugar
- `let` is sugar for `fn` + `call`
- primitive objects: `Int`, `Float`, and a walkable list representation
- types in annotation position; checker, not a second language

## Not kernel (grow later)

- collections beyond list primitives — `fold` / `map` / `reverse` already live
  in `lib/list.aloe`
- application libraries: `Point`, `Boid`, `Sim`, Boids
- `#lang aloe`, `require`, macros

## Test of the diamond

A new program that does not force a new Racket builtin — only new classes
and methods — means the core is still small enough.
