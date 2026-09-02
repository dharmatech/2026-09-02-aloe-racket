# Agent rules for Aloe 0.1

Read `SPEC.md` and `CHECKPOINTS.md` before writing code.

- Implement one checkpoint at a time. Do not skip ahead to Boids.
- Add tests in the same change. Run them. Stop when green.
- Evaluation is send, not apply. Head of a list is the receiver. Second element is a literal selector.
- `(f x)` does not call `f`. Function objects only run via `(f call x ...)`.
- `let` = `((fn (names ...) body) call exprs ...)`.
- No inheritance, mutation, macros, implicit Int/Float coercion.
- Int → Float is the message `(n float)`.
- Do not invent special forms that are not in `SPEC.md`.
