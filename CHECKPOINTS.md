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

## 55. `Mirror` + `messages`

- `(Mirror of value)` reflects a value and `(mirror messages)` returns its
  unique `(List Symbol)` selectors; `signatures` and `invoke` are not included.

## 56. `Signature` + `(mirror signatures)`

- `(mirror signatures)` returns one kernel-created `Signature` per dispatch
  row. `selector`, `params`, and `return` expose the row as `Symbol`/`List`
  type-grammar data; `invoke` remains deferred.

## 57. `(mirror invoke signature argument ...)`

- `Mirror.invoke` checks the signature owner, arity, argument types, and result
  type, then runs that exact dispatch-table row without resolving its selector
  again; `perform` remains absent.

## 58. Gel menu rows in Aloe

- `gel/menu.aloe` turns any value's reflected signatures into ordered,
  one-based `GelRow` menu data; keyboard input, the stack loop, and send
  building remain deferred.

## 59. Gel `(List Mirror)` stack + zero-argument invoke

- `gel/stack.aloe` stores one mirror per stack slot, treats `first` as TOS,
  and invokes an arity-zero `GelRow` before pushing its mirrored result;
  subject unwrapping and argument builders remain deferred.

## 60. `(mirror subject)`

- `(mirror subject)` returns the value held by a `Mirror`; its checker result
  is the expected type when available and otherwise a fresh type variable.

## 61. One-argument Gel invoke from the stack

- `(gel-invoke-one call stack row argument)` invokes the row against the TOS
  mirror, unwrapping a mirrored argument with `subject`, then pushes the
  mirrored result.

## 62. Pure Gel key step

- `(gel-handle-key call stack key)` maps `"q"` and digit strings in Aloe;
  digits select arity-zero reflected rows, while TTY input remains a host skin.

## 63. Gel menu text + runner

- `(gel-menu-text call value)` formats indexed selector/arity rows in Aloe;
  `host/racket/gel-run.rkt` is the thin interactive TTY skin.

## 64. `(term write-line String)`

- The injected `term` receiver writes a `String`, CRLF, and a flush using
  Racket `display`, then returns the original string; it is not a tui-term API.

## 65. `gel-main` in Aloe

- `gel/main.aloe` prints menus, reads `String` keys, steps, and recurses;
  `host/racket/gel-run.rkt` only injects `term`, loads Gel, and starts it.

## 66. Print Gel TOS from Aloe

- `(gel-tos-text call stack)` builds a `String` containing `TOS` and a
  subject presentation; `gel-main` writes it before the unchanged menu.

## 67. One-argument Gel keys from the stack

- Selecting an arity-one row uses the subject of the mirror immediately under
  TOS as its argument; a one-item stack leaves the key as a no-op.

## 68. `(mirror raw)` + structural TOS text

- `(mirror raw)` returns the reflected subject's structural printer text;
  `gel-tos-text` prefixes that text with `TOS: ` and does not use `show`.

## 69. Pending arity-one sends + typed stack picks

- Selecting an arity-one row stores it in `GelStep.pending`; the pending menu
  numbers only stack mirrors accepted by that signature, and a second digit
  invokes with the chosen subject. Pending `q` cancels without quitting Gel.
