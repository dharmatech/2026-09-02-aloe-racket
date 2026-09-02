# Aloe (Racket prototype)

S-expression language. Evaluation is message send:

```text
(receiver selector arg ...)
```

Not Scheme apply. See `SPEC.md`.

## Layout

- `SPEC.md` — language 0.1
- `CHECKPOINTS.md` — implementation order
- `AGENTS.md` — rules for a coding agent
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

Legal now: Aloe 0.1 typechecks and evaluates the complete `boids.sexpr` program, including both trailing `step` sends.
