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
- `examples/boids.sexpr` — target program

## 0.1 goal

Typecheck `examples/boids.sexpr` and evaluate `(demo step)`.

Interpreter + type checker in Racket only. No compiler.

Legal now: Aloe 0.1 typechecks and evaluates the complete `boids.sexpr` program, including both trailing `step` sends.
