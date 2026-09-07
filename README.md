
# ALOE

Scheme is a small gem. Aloe is a similar gem with two new facets.

1. **Send, not apply.** A list is `(receiver selector arg …)`. The selector is a
   symbol; it is not evaluated. Functions are objects that understand `call`.
2. **Types, inferred where you do not write them.** Nominal declarations give
   structure and methods. The rest of the program should not repeat those types.

In the 1970s Steele and Sussman studied Hewitt’s actor model and found that
message send and function application could express each other. Scheme took
application as the primitive. Aloe takes the other branch: a Lisp whose kernel
is sending a message.

The core stays small on purpose. Libraries and programs grow the rest
([lib/list.aloe](lib/list.aloe), [examples/](examples/)). See
[docs/philosophy.md](docs/philosophy.md) and [SPEC.md](SPEC.md).

`ALOE = Scheme + Smalltalk + Types`

## Status

Aloe 0.2 is an exploratory prototype.
The implementation is a definitional interpreter
plus a type checker,
written in Racket.
There is no bytecode VM and no native compiler.
Types are checked before evaluation;
inference fills in what you do not write.

Executable behavior remains complete through checkpoint 88. The unified family
target is promoted into [SPEC.md](SPEC.md) in the **89I ratification change
submitted for review**. The audit, corrected roadmap, and implementation
handoff are accepted; acceptance of 89I completes checkpoint 89's design and
documentation arc. It does not implement families, `case`, send type headers,
or `invoke-mirrored`.

[CHECKPOINTS.md](CHECKPOINTS.md#future-family-implementation) governs the future
order; the [family implementation handoff](docs/unified-nominal-adts-implementation-handoff.md)
explains the transition. 90A needs its own checkpoint document and authorization.
The examples and commands below remain runnable checkpoint-88 programs using
the current class syntax until their assigned migration.

## Layout

- [SPEC.md](SPEC.md) — complete normative target, with implementation status
- [CHECKPOINTS.md](CHECKPOINTS.md) — implementation order
- [AGENTS.md](AGENTS.md) — rules for a coding agent
- [Family handoff](docs/unified-nominal-adts-implementation-handoff.md) — accepted implementation guidance and current review boundary
- [Family roadmap](docs/unified-nominal-adts-implementation-roadmap.md) — supporting prerequisites, allocation rationale, and evidence
- [lib/list.aloe](lib/list.aloe) — Aloe implementations of `fold`, `reverse`, and `map`
- [examples/boids.aloe](examples/boids.aloe) — target program
- [examples/mpl/](examples/mpl/) — 0.2 computer algebra fragment
- [docs/journal/](docs/journal/) — release notes

## Driver

From the project directory, after loading the Racket path from your profile:

```sh
./bin/aloe
./bin/aloe examples/boids.aloe
./bin/aloe --quit examples/boids.aloe
```

The first command starts the REPL. Loading a file without `--quit` evaluates it
and then opens the REPL with its definitions and classes still available.

## 0.1 goal

Typecheck [examples/boids.aloe](examples/boids.aloe) and evaluate `(demo step)`.

Interpreter + type checker in Racket only. No compiler.

Legal now: Aloe 0.1 typechecks and evaluates the complete [examples/boids.aloe](examples/boids.aloe) program, including both trailing `step` sends.

## 0.2 additions

Aloe 0.2 adds protocols and method overloads. [examples/mpl/](examples/mpl/) is a
Cohen-style CAS fragment built around the `Math` protocol: primitive `Int` is
not `Math`, so algebraic constants use `Num`. The default printer sends `show`
when an object provides it, while the REPL command `:raw` prints the structural
`#<…>` form. To try it, load the MPL core and bind a symbol:

```lisp
(load "examples/mpl/core.aloe")
(define x (Sym new "x"))
```
