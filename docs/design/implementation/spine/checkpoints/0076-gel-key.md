# Checkpoint 0076 — `GelKey`

Status: Implemented
Depends on: Checkpoint 0075

## Goal

Replace the callable key-parsing helpers with an immutable `GelKey` whose
methods express the meanings Gel assigns to terminal key text.

## Contract

Add `GelKey` with field `(text String)` and these methods:

| Selector | Result | Behavior |
|---|---|---|
| `digit-value` | `Int` | `"0"`–`"9"` become `0`–`9`; anything else is `-1` |
| `menu-index` | `Int` | Delegates to `digit-value`; `1`–`9` stay unchanged and everything else is `0` |
| `quit?` | `Bool` | True exactly when `text` is `"q"` |
| `return?` | `Bool` | True exactly when `text` is `"return"` |

Keep the public transition `(step handle-key text)` with a `String` argument.
It constructs one `GelKey`, then passes that value through `handle-idle`,
`handle-pending`, `handle-int`, and `handle-pick`; those four methods now accept
`GelKey` rather than `String`.

Use the key messages in transition code:

```lisp
(key menu-index)
(key digit-value)
(key quit?)
(key return?)
```

## Migration

- Remove `GelKeyIndex`, `GelDigitValue`, `gel-key-index`, and
  `gel-digit-value`.
- Replace their sends and the corresponding raw `"q"` and `"return"`
  comparisons with `GelKey` messages.
- Update affected tests, add `tests/checkpoint-76.rkt`, and update the Gel and
  checkpoint summaries after implementation.

Do not change the public `handle-key` argument type, terminal input or echo,
key mappings, state transitions, or any row, pick, menu, or text helpers.

## Acceptance

- All four `GelKey` messages have the mappings above, including distinct
  handling of `"0"` as digit value `0` but menu index `0`.
- Existing callers still send key strings with `(step handle-key text)`.
- Idle, pending, integer-entry, typed-pick, and quit behavior are unchanged.
- The four removed class and value names are no longer bound.
- `gel-main` produces the same terminal transcript.
- All checkpoint tests pass.
- By hand, this evaluates to `0`, `0`, and `#t`:

  ```lisp
  (load "gel/loop.aloe")
  (define zero-key (GelKey new "0"))
  (zero-key menu-index)
  (zero-key digit-value)
  ((GelKey new "q") quit?)
  ```

## Result

Terminal key meaning now lives on immutable `GelKey` values. `GelStep` keeps
its public String transition, constructs one key per send, and passes it
through idle and pending handling; the two callable parsers are removed while
all key mappings and transitions remain unchanged.
