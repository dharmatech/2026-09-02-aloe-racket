# Checkpoint 111 — Collision-free Gel item keys

**Branch.** Continue on `experiment/gel-directory-surface`.

**Depends on.** Checkpoint 110 (Gel `List` value rows)

**Status.** Complete (reviewed 2026-09-10 on
`experiment/gel-directory-surface`).

## Goal

Replace checkpoint 110's provisional digit labels for value rows with one
explicit, position-bound item-key pool:

```text
a b c d e f g h i j k l m n o p r s t v w x y z
```

This is the lowercase English alphabet with the active/reserved command keys
`q` and `u` removed. Escape is the named terminal key `"escape"`, so it is
also outside the one-character item pool. The first visible value gets `a`,
the second gets `b`, and so on for at most 24 visible values.

The policy separates two existing jobs:

- authored value items use the new letter pool;
- reflected message rows, pending stack picks, and pending Int entry keep
  their existing digit behavior exactly.

`q` remains quit, Escape remains back/cancel, and `u` is reserved for the
later Directory `parent` command. In this checkpoint `u` is still a no-op;
there is no Directory surface or filesystem capability yet.

## Depends on

- Parent: `experiment/gel-directory-surface` after reviewed checkpoint 110.
- Design authority: `docs/gel-directory-surface.md` §3 single-key items and
  command-key exclusion, §5 spatial item keys, progression item 4 in §7, and
  the alphabet choice left open in §8.
- Current Gel behavior and structure: `docs/gel.md`, `gel/menu.aloe`, and
  `gel/loop.aloe`.
- Aloe law: `SPEC.md`. The pool, lookup, rendering, and selection are ordinary
  immutable Aloe objects and sends. There is no computed selector or new
  evaluation rule.
- Checkpoint 110 already gives each `GelValueRow` a one-based presentation
  `index` and exact `value` mirror. This checkpoint binds that position to a
  key; it does not bind a permanent key to the underlying value.
- `GelKey.text` is the ordinary field accessor for the exact terminal string.
  Existing `digit-value` and `menu-index` remain the digit parser for derived
  message and pending paths.
- Checkpoint 109 handles `q` and Escape before idle menu selection. That
  command precedence remains unchanged.

The implementer will not have a separate checkpoint-manager brief. Every rule
needed for this slice is in this document.

## Why letters

The Directory north star uses `a`, `b`, `c` for visible children while command
keys stay mnemonic. Keeping digits on reflected method rows makes the two
surfaces visually and behaviorally distinct during this transition, and 24
letters are enough to exercise a useful in-memory listing before overflow UI
exists.

The order is alphabetical and fixed. It is not based on an item's name,
value, type, hash, or prior position. Building a new listing assigns the pool
again from its beginning, so the first visible item is always at the same
physical key.

`n` and `p` are ordinary item keys in this checkpoint because paging does not
exist yet. If later overflow pressure assigns them command meanings, that
checkpoint must first remove them from the item pool so a rendered page never
has a command/item collision. Do not add dormant paging commands or reserve
additional speculative keys here.

## Authority / starting point

Facts before this checkpoint (do not redesign them):

- `GelMenu.Messages` contains reflected `(List GelRow)` rows.
- `GelMenu.Values` contains `GelValueRows` built from the exact mirrors in a
  `GelListValues` carrier.
- `GelValueRow` currently stores `(index Int)` and `(value Mirror)`. Its
  constructor is already covered by checkpoint-110 tests.
- `GelMenus.value-rows` preserves source order and currently stops after nine
  rows with a literal bound.
- `GelText.value-line` currently renders `index`, two spaces, raw value, and
  CRLF.
- `GelStep.handle-values` currently reads `(key menu-index)` and pushes the
  selected row's exact mirror.
- `GelStep.handle-messages` and `GelStep.handle-pick` use `menu-index`.
  `GelStep.handle-int` uses `digit-value`.
- Value selection leaves the containing List mirror below the selected mirror
  as history; idle Escape returns to that exact List mirror.
- `q` quits from idle and pending states. Idle Escape pops; pending Escape
  cancels without popping. `u` has no behavior yet.
- The minimal `examples/gel-list.aloe` application and generic runner contract
  are complete and do not need to change.

## Exact file scope

**May edit during implementation:**

- `gel/menu.aloe` (item-key data, lookup, value-row label, and pool-sized row
  construction)
- `gel/loop.aloe` (`GelKey.item-index`, value-row text, and value selection by
  item key)
- `tests/checkpoint-111.rkt` (new)
- `tests/checkpoint-110.rkt` only for the living List-value expectations that
  necessarily change from provisional digits/nine rows to letters/the pool
  length, as detailed below
- `CHECKPOINTS.md` (append checkpoint 111 only)
- `docs/gel.md` (current item/message key behavior only)
- `docs/handoff.md` (current state and next pressure only)
- `docs/gel-directory-surface.md` status/progression and resolved-alphabet
  notes only after the checkpoint is green; do not change the locked screen or
  deferred scope
- `docs/decisions.md` (optional short dated note recording the alphabet choice)

**Do not edit:**

- `aloe/`, including evaluator, checker, parser, `Mirror`, and `Signature`
- `host/`, including Term, filesystem, and both runners
- `gel/stack.aloe` and `gel/main.aloe`
- `lib/`, including `lib/list.aloe`, `lib/disk.aloe`, and `lib/fs.aloe`
- `examples/gel-list.aloe`, `examples/gel-point.aloe`, or other examples
- `bin/aloe`
- `SPEC.md`
- historical checkpoint documents
- historical tests 1–109
- checkpoint-110 assertions unrelated to value-row keys, the visible-row
  bound, or the scripted keys that select those rows
- filesystem tests or documentation beyond the permitted current-status note

Do not begin checkpoint 112's Directory presentation, `u` action, `fs-host`
injection, or live directory start in this change.

## Required behavior

### Nominal item-key pool

In `gel/menu.aloe`, add these two nominal data types:

```aloe
(define-class GelItemKey
  (fields
    (index Int)
    (text String))
  (methods))

(define-class GelItemKeys
  (fields
    (items (List GelItemKey)))
  (methods
    (len () Int
      ((self items) len))

    (select (index Int) GelItemKey
      ...valid one-based selection...)

    (index (text String) Int
      ...exact text lookup, or 0 when absent...)))
```

Bind one immutable `gel-item-keys` value whose `items` are exactly, in order:

```text
(GelItemKey new 1 "a")
(GelItemKey new 2 "b")
...
(GelItemKey new 16 "p")
(GelItemKey new 17 "r")
(GelItemKey new 18 "s")
(GelItemKey new 19 "t")
(GelItemKey new 20 "v")
...
(GelItemKey new 24 "z")
```

The omitted letters are exactly `q` and `u`.

Locks:

- `items` contains exactly 24 entries.
- Every text is a distinct, one-character, lowercase ASCII letter.
- Indexes are exactly `1` through `24`, in list order.
- `select` is required to support valid one-based indexes only. Callers check
  bounds; do not add Option, a sentinel item, or an exception protocol.
- `(gel-item-keys index text)` compares exact strings and returns the matching
  one-based index. It returns `0` for `q`, `u`, `"escape"`, digits, uppercase
  letters, multi-character strings, named terminal keys, punctuation, and all
  other absent text.
- Build lookup through ordinary Aloe data and sends. Do not use Racket
  tables, Symbol interning, computed sends, a host keycode, or `perform`.
- The pool is Gel application data, not an Aloe library, global keymap,
  configurable preference, protocol, or plugin extension point.
- Do not add paging/search entries, an overflow marker, or command rows to
  this pool.

It is acceptable for `select` to follow the existing valid-index fold pattern
used by `GelValueRows`. The absent-key path must be total because arbitrary
terminal text reaches `index`.

### Bind value-row position to an item key

Keep the existing `GelValueRow` fields and constructor unchanged so earlier
code remains valid:

```aloe
(GelValueRow new index mirror)
```

Add:

```aloe
(key () String
  ((gel-item-keys select (self index)) text))
```

The exact spelling may vary, but `(row key)` must have type `String` and
return the pool text at the row's one-based position.

Locks:

- `index` remains the row's presentation position and source-order index.
- `value` remains the exact mirror produced by checkpoint 110.
- `key` is derived from position; it is not stored on or sent to the subject.
- Do not unwrap/re-reflect the value or change `GelMirrors`, `gel-values`, or
  `GelListValues`.
- Do not put item labels on `GelRow`, reflected signatures, or pending picks.

### Size value rows from the pool

Replace `GelMenus.value-rows`' literal nine-row bound with the length of
`gel-item-keys`.

- A list of 24 or fewer values exposes every value.
- A list of more than 24 values exposes exactly its first 24 values.
- Source order, one-based indexes, and exact mirror identity remain unchanged.
- There is no row 25, overflow text, next/previous action, search, wrapping,
  or way to select a hidden value.
- The capacity comes from `(gel-item-keys len)`, not from another copied
  literal or a second key list.

This intentionally supersedes checkpoint 110's provisional nine-row cap.

### Parse item keys without changing digit keys

Add this ordinary `GelKey` method in `gel/loop.aloe`:

```aloe
(item-index () Int
  (gel-item-keys index (self text)))
```

Locks:

- Exact lowercase item letters map to the corresponding pool index.
- `q` and `u` map to `0` as item keys.
- `"escape"`, digits, uppercase letters, `/`, `return`, and unknown strings
  map to `0`.
- Preserve `digit-value`, `menu-index`, `quit?`, `escape?`, and `return?`
  behavior exactly.
- Do not add `up?` or make `u` act on any current object. Its reservation is
  represented by absence from `gel-item-keys`; checkpoint 112 will give the
  Directory surface its command meaning.

### Render item letters

Change only `GelText.value-line` so a value row is:

```text
key␠␠raw-value\r\n
```

For `examples/gel-list.aloe`, the menu becomes exactly:

```text
a  "alpha"\r\n
b  "beta"\r\n
c  "gamma"\r\n
```

Use `(row key)`. Do not derive the character with integer/string arithmetic,
inspect the value, or duplicate the pool in the renderer.

Reflected message rows remain exactly `index`, two spaces, selector, two
spaces, arity, and CRLF. Pending typed-pick rows remain digit-indexed. Pending
Int text remains unchanged.

### Select values by item letter

In `GelStep.handle-values`, replace `(key menu-index)` with
`(key item-index)`. Keep the rest of checkpoint 110's bounds check and exact
mirror push unchanged.

Consequences:

- `a` selects visible value 1, `b` value 2, through `z` value 24 with `q` and
  `u` skipped according to the pool.
- In particular, `p` selects value 16, `r` selects value 17, `t` selects value
  19, and `v` selects value 20.
- A digit no longer selects a List value. Digits still select reflected
  messages and pending picks and still enter pending Int values.
- `q` is handled before menu selection and quits; it never selects a value.
- Escape is handled before menu selection and pops/cancels; it never selects a
  value.
- `u` is a no-op on a List in this checkpoint; it never selects a value.
- Uppercase letters, `/`, named keys, absent strings, and item keys beyond a
  short list's visible length are no-ops by identity on the value-menu state.
- Valid selection still pushes the exact row mirror immediately, never enters
  pending mode, and leaves the List mirror immediately below it.
- Escape after selection still returns to the identical List mirror.

Do not change `handle-messages`, `handle-pick`, or `handle-int` to use item
keys. Do not make key meaning depend on an item's contents or add a general
key-dispatch framework.

### Narrow checkpoint-110 test migration

Checkpoint 110 deliberately called its digit mapping and nine-row cap
provisional. Update only its living value-surface expectations so the full
suite states current behavior:

- `1  ` / `2  ` / `3  ` List-value lines become `a  ` / `b  ` / `c  `.
- List-value selection key `"2"` becomes `"b"`.
- The scripted List application uses `("b" "escape" "q")`.
- The visible-bound case uses more than 24 values, expects exactly 24 rows,
  and proves the 25th is hidden/unselectable.
- Digit keys move into the invalid/no-op coverage for a value menu.
- Adjust names and prose that say “nine” or “digit” only where they describe
  the superseded List-value policy.

Do not weaken or remove checkpoint 110's identity, source-order, empty-list,
nested-list, exact transcript, unfamiliar-object, pending-menu, application,
or dependency assertions. Do not change its derived message expectations.

## Tests and hand checks

Add `tests/checkpoint-111.rkt`. Use checked drivers and scripted production
Term receivers. Automated tests must not require a physical TTY.

Cover at least:

1. `GelItemKey`, `GelItemKeys`, `gel-item-keys`, `GelValueRow.key`, and
   `GelKey.item-index` have the specified types and remain absent from a fresh
   default driver before Gel is loaded.
2. The pool contains exactly the ordered 24 letters above with indexes
   `1`–`24`; texts are unique and `q`/`u` are absent.
3. Pool selection and reverse lookup agree for every entry. Absent, uppercase,
   digit, punctuation, named, and multi-character strings return index zero.
4. Lists of lengths `0`, `1`, `24`, and greater than `24` build the expected
   number of rows without empty-list or off-by-one failures.
5. A long List exposes values `1`–`24` in source order with exact mirror
   identity and hides value 25. Row keys around both omissions prove `p` is
   index 16, `r` is 17, `t` is 19, and `v` is 20.
6. List menu bytes are exactly letter, two spaces, raw value, and CRLF. No
   value row is labeled `q` or `u`, and there is no overflow/paging/search
   text.
7. The same underlying value at different positions in two listings receives
   the position's current key, proving keys are rebound per listing rather
   than attached to values.
8. Every valid visible item letter selects its matching value. Selection
   pushes the exact mirror, preserves prior history, stays idle, and Escape
   restores the identical List mirror.
9. On a value menu, digits, `q`, `u`, Escape, uppercase, `/`, `return`, unknown
   strings, and valid pool letters past the row count have the required
   command/no-op behavior. In particular `q` quits, Escape pops/floors, and
   `u` does not select or invoke anything.
10. Point and Int derived menus retain their exact digit-labeled bytes and
    digit selection behavior. Letter keys do not become reflected-message
    indexes.
11. Pending typed-pick digits and pending Int digits/return remain unchanged;
    letters do not select a pick or enter a number. Pending `q` and Escape keep
    checkpoint 109 behavior.
12. A nested List selected with a letter receives its own letter-labeled value
    menu.
13. A scripted `gel-main start` over `(List of 10 20)` with keys
    `("b" "escape" "q")` renders `a`/`b`, pushes `20`, redraws its unchanged
    digit-labeled Int menu, returns to the identical List, and quits.
14. Source/dependency assertions confirm there is one Gel-local pool and no
    kernel, host, runner, filesystem, reusable-library, app, or default-driver
    capability change.
15. Checkpoints 108–110 and the full existing suite remain green after the
    narrow checkpoint-110 expectation migration.

### Pure hand check

With Gel loaded, evaluate:

```aloe
(define values (List of "alpha" "beta" "gamma"))
(define stack (gel-empty-stack push values))
(gel-text menu (stack tos))
(define step
  (GelStep new stack #f (List empty) 0 #f))
(define chosen (step handle-key "b"))
(((chosen stack) tos) subject)
(((chosen handle-key "escape") stack) tos)
((GelKey new "q") item-index)
((GelKey new "u") item-index)
```

Expected menu:

```text
a  "alpha"
b  "beta"
c  "gamma"
```

The chosen subject is `"beta"`. The final TOS is the original List mirror.
Both reserved command strings have item index `0`.

### Physical-TTY hand check

When `tui-term` and a physical TTY are available:

```sh
racket host/racket/gel-run.rkt examples/gel-list.aloe
```

The menu shows `a`, `b`, `c`. Press `b` to push `"beta"`, Escape to return to
the List, then `q` to leave and restore the terminal. Pressing `2` or `u` on
the List is a no-op.

The scripted equivalent is required; this physical check is informative when
the optional dependency or a real terminal is unavailable.

## CHECKPOINTS.md and handoff

Append only:

```text
## 111. [Collision-free Gel item keys](docs/checkpoints/0111-gel-item-keys.md)

- Authored value rows use a fixed position-bound lowercase item-key pool with
  `q`, Escape, and `u` excluded; reflected messages and pending input retain
  digits. A List exposes at most the pool's 24 values. Directory behavior and
  filesystem injection remain deferred.
```

Update `docs/handoff.md` to say tests are green through 111 on
`experiment/gel-directory-surface`; generic launch, back/pop, List value rows,
and collision-free item keys are complete; and the live Directory surface is
the next pressure. Do not claim `u` acts yet or that `fs-host` is injected.

Update the current key/List paragraphs in `docs/gel.md`. After the checkpoint
is green, `docs/gel-directory-surface.md` may mark progression item 4 complete,
record the exact alphabet, and identify progression item 5 as next. Keep its
paging/search and stack-level questions open.

## Acceptance

This checkpoint is complete when authored List value rows use the exact
position-bound letter pool, active/reserved command keys cannot become item
keys, up to 24 values render and select by those letters, derived and pending
surfaces retain digits, and no Directory, filesystem, paging, search, or
kernel work has begun.

Run:

```sh
raco test tests/checkpoint-111.rkt
raco test tests/*.rkt
git diff --check
```

The checkpoint test and full suite must pass. Run both hand checks where the
optional TTY is available. Stop for review without committing and without
starting checkpoint 112.

## Explicit non-goals

- No Directory presentation, `Directory.entries` adapter, `u`/`parent`
  action, `fs-host` injection, directory-aware runner, live start value, or
  filesystem load.
- No paging, next/previous commands, search, refresh, overflow marker, prefix
  tree, two-key addressing, multi-column layout, or selection beyond the first
  24 values.
- No general authored-surface protocol, keymap/configuration system,
  plugin/hook/extension API, GelFS package, pane, or workspace framework.
- No change from digits to letters for reflected method rows, pending picks,
  or pending Int entry.
- No permanent key derived from item names or values, mnemonic item matching,
  sorting, filtering, caching, or snapshot state.
- No File surface, reading, size, enter, `(here entries)`, Git, process,
  editor, shell, copy, move, or mutation.
- No stack storage/pop change, extra stack-level rendering, argument-builder
  change, Point behavior change, or application/runner change.
- No kernel List/Mirror primitive, host crossing type, host method, default
  capability, new Aloe syntax, special form, dispatch rule, inheritance,
  macro, or implicit numeric coercion.
- Do not implement checkpoint 112 in the same change.
