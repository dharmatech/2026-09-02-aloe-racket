
# ALOE

Scheme is a small gem. Aloe is a similar gem with two new facets.

1. **Send, not apply.** A list is `(receiver selector arg …)`. The selector is a
   symbol; it is not evaluated. Functions are objects that understand `call`.
2. **Types, inferred where you do not write them.** Classes declare fields and
   methods. The rest of the program should not repeat those types.

In the 1970s Steele and Sussman studied Hewitt’s actor model and found that
message send and function application could express each other. Scheme took
application as the primitive. Aloe takes the other branch: a Lisp whose kernel
is sending a message.

The core stays small on purpose. Libraries and programs grow the rest
(`lib/list.aloe`, `examples/`). See `docs/philosophy.md` and `SPEC.md`.

`ALOE = Scheme + Smalltalk + Types`

## Layout

- `SPEC.md` — language 0.1
- `CHECKPOINTS.md` — implementation order
- `AGENTS.md` — rules for a coding agent
- `lib/list.aloe` — Aloe implementations of `fold`, `reverse`, and `map`
- `examples/boids.aloe` — target program

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

Typecheck `examples/boids.aloe` and evaluate `(demo step)`.

Interpreter + type checker in Racket only. No compiler.

Legal now: Aloe 0.1 typechecks and evaluates the complete `examples/boids.aloe` program, including both trailing `step` sends.
