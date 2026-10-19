# Checkpoint 0082 — Unified `GelText` renderer

Status: Implemented
Depends on: Checkpoint 0081

## Goal

Consolidate Gel menu and TOS rendering in one cohesive service with named
messages. Remove the remaining function-shaped rendering interfaces.

## Contract

Rename `GelMenuText` to `GelText` and `gel-menu-text` to `gel-text`. Preserve
its existing `line`, `rows-text`, `pick-line`, `picks-text`, and `pending-text`
methods unchanged.

Replace its three `call` overloads with `menu` overloads:

| Selector | Arguments | Result |
|---|---|---|
| `menu` | `(value Mirror)` | `String` |
| `menu` | `(state GelStep)` | `String` |
| `menu` | `(type T) (value T)` | `String` |

Preserve their bodies, changing only the internal delegation to:

```lisp
(self menu ((state stack) tos))
```

Move TOS rendering into `GelText` as:

```lisp
(tos
  (stack GelStack)
  String
  (let ((top (stack tos)))
    ("TOS: " append (top raw))))
```

The resulting public rendering sends are:

```lisp
(gel-text menu value)
(gel-text menu state)
(gel-text tos stack)
```

## Migration

- Remove `GelMenuText`, `gel-menu-text`, `GelTosText`, and `gel-tos-text`.
- Migrate all public and internal rendering sends to `gel-text` and the named
  selectors above.
- Update affected tests, add `tests/checkpoint-82.rkt`, and update the Gel and
  checkpoint summaries after implementation.

Do not change any rendered bytes, row or pick ordering, generic overload
behavior, stack behavior, key transitions, terminal sequencing, or `GelMain`.

## Acceptance

- `menu` renders ordinary values, exact mirrors, idle states, pending typed
  picks, and pending integer input exactly as before.
- Its generic overload remains independently polymorphic across sends.
- `tos` preserves the exact `"TOS: "` plus mirror-`raw` output.
- `GelText` has no `call` method.
- All four removed class and value names are no longer bound.
- `gel-main` emits the identical terminal transcript in the same order.
- All checkpoint tests pass.
- By hand, the final two expressions evaluate to `"TOS: 10"` and `#t`:

  ```lisp
  (load "gel/loop.aloe")
  (gel-text tos (gel-empty-stack push 10))
  ((gel-text menu 10) =
   (gel-text menu (Mirror of 10)))
  ```

## Result

`GelText` now owns all Gel menu and TOS rendering through named `menu` and
`tos` messages. Existing row, pick, pending, and generic rendering bodies are
preserved, `gel-main` uses the unified service without changing sequencing,
and the four former menu/TOS class and value names are removed.
