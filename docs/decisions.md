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

Decided: the host provides `of`, `empty`, `empty?`, `first`, `rest`, `cons`,
and `len`. `fold`, `reverse`, and `map` are Aloe methods in `lib/list.aloe`,
installed with `define-methods List` before user programs run.

Method-local type parameters such as fold's accumulator `A` are rigid while
the method body is checked and freshly inferred at each send.

## Message chains (2026-09-02)

Deferred: (-> recv (sel args ...) ...) desugars to nested sends.
Not now — one force-sum in Boids is not enough pressure.

## Math protocol (2026-09-03)

Decided: empty protocol `Math`; `(define-protocol Math)`;
`(define-class Sym Math ...)`; a method may return `Math` so `(x + 2)`
and `(x + y)` share a type. Lookup stays on the class.

Rejected for this experiment: C# implementation inheritance, closed ADT
`Expr`, `Any`, required protocol methods, `super`.

Deferred: `simplify` as a required protocol method; multiple protocols
per class; ADT control experiment on a separate branch.
