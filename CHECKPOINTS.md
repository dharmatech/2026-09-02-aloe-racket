# Aloe 0.1 checkpoints

> Checkpoints 12–52 live as `tests/checkpoint-N.rkt`; the original 1–11
> implementation sequence remains below unchanged.

Work one checkpoint at a time. Each ends when `raco test` is green and you have run one expression by hand. Do not start Boids until checkpoint 11.

Rules for every slice:

- One feature.
- Tests live in the same change.
- Never treat list head as a function. `(f x)` is a send of selector `x` to `f`.
- `let` desugars to `(fn … call …)`, nothing else.
- Stop and wait for review when a checkpoint is green.

## 1. Reader + atoms

`1`, `1.0`, bound symbol lookup. No sends.

## 2. Send skeleton

`(r sel)` on a dummy object errors `unknown message`. Selector is not evaluated.

## 3. `define-class` + `new` + field read

Non-generic `Point` is enough.

```text
(Point new 1 2)
((Point new 1 2) x)    ; => 1
```

## 4. Method send + `self`

```text
((Point new 1 2) + (Point new 3 4))    ; => (Point new 4 6)
```

## 5. Numbers as objects

```text
(1 + 2)          ; => 3
(3.0 * 4.0)      ; => 12.0
(1 + 2.0)        ; type/runtime error — no mix
```

## 6. `fn` + `call`

```text
((fn (x) (x + 1)) call 2)    ; => 3
((fn (x) x) 2)               ; illegal (2 would be the selector)
```

## 7. `let`

Parallel bindings. Must expand to `call`.

## 8. `List of` / `len` / `map` / `fold`

Monomorphic list is enough.

## 9. Generics

`(Point T)`, infer `T` from `new`. `(Point new 1 2.0)` fails.

## 10. Type checker on 1–9

Accept the must-run goldens in `SPEC.md` §9. Reject the five must-fail programs.

## 11. Boids

Load `examples/boids.aloe`. Typecheck. Evaluate `(demo step)` twice.
`len` is `Int`; divide points by `(n float)`, not `n`.

## 52. `check` + MPL identities workbook

`(check left right)` compares same-typed values, returns the right value on
success, and reports both source datums and displayed values on failure.
`examples/mpl/identities.aloe` records the established MPL show-identities.

## 53. MPL identities use normalized value equality

## 54. `Symbol`

- Primitive interned names support `(Symbol intern String)`, `(sym name)`, and
  `(sym = other)`; selectors remain implicit and `perform` is not implemented.
