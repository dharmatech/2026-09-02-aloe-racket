# Aloe decisions

Spec is law: `SPEC.md`. This file is what we considered and rejected, so a
new conversation does not replay them.

## Evaluation (2026-09-02)

Decided: send, not Scheme apply. Selector is a source symbol.

Rejected: `(step demo-flock)` as function application.

## let (2026-09-02)

Decided: `(let ((n e1) (bs e2)) body)` → `((fn (n bs) body) call e1 e2)`.
Parallel bindings.

Rejected: Scheme’s `((lambda (n bs) body) e1 e2)` (treats `e1` as selector).

## if / Bool (2026-09-02)

Decided: `#t` / `#f` understand `(b if then-fn else-fn)`; only one zero-arg
thunk is sent `call`. Sugar: `(if test then else)` desugars to that send.

Rejected:

- `if` as a special form that secretly evaluates one arm (two conditionals)
- `[10]` or `T[10]` as thunk literals (keep `[]` / custom reader for later)
- requiring programs to write only the send spelling (too noisy for Boids)

## Sim and numerics (2026-09-02)

Decided: `Point` and `Boid` are generic. `Sim` is not. Flock is
`(List (Boid Float))`. No implicit `Int`/`Float` mix; `(n float)` converts.

Rejected: `Sim[T]` whose `step` body hard-codes `0.0` / `0.01` and pretends
to be parametric.

## Implementation host (2026-09-02)

Decided: definitional interpreter + checker in `racket/base`. `#lang aloe`
later as a wrapper around that pipeline, not a rewrite.

Rejected for 0.1: Turnstile, PLAI student languages, expanding sends into
Racket apply.

## Collections (2026-09-02)

Decided for now: `List of` / `len` / `map` / `fold` live in the host so
Boids can run.

Intent: `fold` and `map` become Aloe methods once `empty?`, `first`, `rest`
(and `cons`) exist. They are scaffolding, not kernel.
