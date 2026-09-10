# Checkpoint 109 — Gel back / pop

**Branch.** Continue on `experiment/gel-directory-surface`.

**Depends on.** Checkpoint 108 (application-supplied Gel start value)

**Status.** Complete (reviewed 2026-09-10 on
`experiment/gel-directory-surface`).

## Goal

Add non-destructive back navigation to Gel's immutable stack.

- `(stack pop)` removes exactly one TOS mirror when history exists.
- Pop on a zero- or one-item stack is a no-op, so a Gel session never falls
  through to an empty TOS.
- Idle `"escape"` pops.
- Pending `"escape"` cancels the pending send without popping.
- `"q"` requests quit whether the state is idle or pending.

This checkpoint changes stack/key transitions only. Do not add directory
objects, item rows, authored menus, `u`, `fs-host`, or extra stack rendering.

## Depends on

- Parent: `experiment/gel-directory-surface` after reviewed checkpoint 108.
- Design authority: `docs/gel-directory-surface.md` §3 reserved command
  keys, §4 stack/history semantics, and progression item 2 in §7.
- Current Gel behavior and structure: `docs/gel.md`, `gel/stack.aloe`, and
  `gel/loop.aloe`.
- Aloe law: `SPEC.md`. Pop and key handling are ordinary Aloe messages and
  immutable reconstruction; this checkpoint adds no syntax or dispatch rule.
- Host key mapping is already fixed: the Term boundary maps Escape to the
  Aloe `String` `"escape"` (checkpoint 53 / `host/racket/term.rkt`). Do not
  change the host spelling to `"esc"`.
- `GelMain.start` from checkpoint 108 makes a one-item floor; `GelMain.call`
  still permits tests and applications to supply a stack with history.

The implementer will not have a separate checkpoint-manager brief. Every
rule needed for this slice is in this document.

## Authority / starting point

Facts before this checkpoint (do not redesign them):

- `GelStack.items` is a `(List Mirror)` with `first` as TOS. `push` conses a
  mirror at the front, so the next item is `((items rest) first)`.
- `gel-empty-stack` is a shared immutable `GelStack` whose list is empty.
- Gel never consumes arguments from history during normal invocation; this
  pop is explicit UI navigation, not Forth evaluation.
- `GelStep.pending` is an empty-or-singleton `(List GelRow)`. An idle state
  has an empty pending list.
- Pending Int input is held in `int-input` plus `has-digits`; pending typed
  picks use the same `pending` row with no separate mutable state.
- `GelKey` currently supplies `digit-value`, `menu-index`, `quit?`, and
  `return?` from its `text` field.
- `GelStep.handle-key` accepts a `String`, constructs one `GelKey`, and routes
  to `handle-idle` or `handle-pending` according to the pending list.
- Before this checkpoint, pending `"q"` cancels. That behavior is deliberately
  replaced: Escape cancels, while `q` keeps its reserved meaning of quit.
- `gel-main` echoes every key before stepping. If a step does not quit, it
  redraws from the returned stack/state.

## Exact file scope

**May edit during implementation:**

- `gel/stack.aloe` (add `GelStack.pop` only)
- `gel/loop.aloe` (add `GelKey.escape?` and the back/cancel/quit transitions)
- `tests/checkpoint-109.rkt` (new)
- `tests/checkpoint-69.rkt`, `tests/checkpoint-70.rkt`,
  `tests/checkpoint-75.rkt`, and `tests/checkpoint-76.rkt` only for the living
  pending-cancel assertions specified below
- `CHECKPOINTS.md` (append checkpoint 109 only)
- `docs/gel.md` (current stack/key behavior only)
- `docs/handoff.md` (current state and next pressure only)
- `docs/gel-directory-surface.md` status/progression notes only after the
  checkpoint is green; do not change the locked screen or deferred scope
- `docs/decisions.md` (optional short dated note that Escape is back/cancel
  and `q` always quits)

**Do not edit:**

- `aloe/`
- `host/`, including Term mapping and both runners
- `gel/main.aloe` and `gel/menu.aloe`
- `lib/`, including `lib/disk.aloe` and `lib/fs.aloe`
- `examples/`, including the checkpoint-108 Point application
- `bin/aloe`
- `SPEC.md`
- historical checkpoint documents
- historical tests other than the four narrow living-test changes named
  above
- Boids, MPL, filesystem tests, or unrelated documentation

Do not begin value-item rows or the directory-aware runner in this change.

## Required behavior

### `GelStack.pop`

Add this method to `GelStack` without changing its fields or existing
methods:

```aloe
(pop () GelStack
  (if (((self items) len) <= 1)
      self
      (GelStack new ((self items) rest))))
```

Lock:

- Length greater than one: return a new `GelStack` over the existing list
  tail. Exactly one mirror is removed.
- Length one: return `self` by identity. Do not create an empty stack.
- Length zero: return `self` by identity. `gel-empty-stack` remains safe to
  inspect through `pop`, even though an interactive session does not use it
  as TOS.
- Do not unwrap, re-reflect, copy, reorder, or invoke any mirror while
  popping. The new TOS is the exact mirror that was immediately below the old
  TOS.
- The original stack and shared list tail remain immutable.
- `pop` takes no argument and does not mean drop, argument consumption,
  `parent`, or process-wide `cd`.
- Do not add `peek`, `drop`, `swap`, a return stack, an empty-stack sentinel,
  or a new stack wrapper.

Place `pop` with the core `GelStack` operations. Do not implement it as a
top-level callable helper or as a `GelStep` list manipulation.

### `GelKey.escape?`

Add one method to `GelKey`:

```aloe
(escape? () Bool
  ((self text) = "escape"))
```

Lock:

- True exactly for the terminal boundary's lowercase string `"escape"`.
- `"esc"`, `"Escape"`, `"q"`, `"return"`, digits, and all other strings are
  false.
- Preserve `digit-value`, `menu-index`, `quit?`, and `return?` byte-for-byte.
- Keep `(step handle-key text)` as the public String-taking transition. Do not
  pass raw host key objects or make selectors computed.

### Idle Escape

In `GelStep.handle-idle`, preserve the existing `quit?` branch first. If the
key is not quit but `(key escape?)` is true, return an idle `GelStep` with:

```aloe
(GelStep new
  ((self stack) pop)
  #f
  (List empty)
  0
  #f)
```

All other keys continue through the existing reflected-row selection logic
unchanged.

Consequences:

- On a stack with history, idle Escape pops exactly one slot.
- On a one-item stack, the returned state's stack is the exact original
  stack because `GelStack.pop` returns `self`.
- Escape does not request quit.
- Escape does not invoke a row, reflect a new value, or call any subject
  message such as `parent`.
- Repeated idle Escape stops at one item. It never gives `GelText` an empty
  TOS.
- Idle `q` still returns a quit-requesting state over the unchanged stack.
  It does not pop.

Do not reserve or implement `u` in this checkpoint. `u` remains an ordinary
non-digit no-op under the current derived-menu key logic.

### Pending Escape and universal quit

Change `GelStep.handle-pending` so its branch order is:

1. `(key quit?)` → request quit;
2. `(key escape?)` → cancel the pending send;
3. otherwise preserve the existing Int-hole or typed-pick handling.

Pending quit returns:

```aloe
(GelStep new (self stack) #t (List empty) 0 #f)
```

Pending Escape returns:

```aloe
(GelStep new (self stack) #f (List empty) 0 #f)
```

Lock:

- Pending `q` now has the same reserved meaning as idle `q`: leave Gel. It
  preserves the stack, invokes nothing, and clears pending/Int-entry state in
  the returned terminal state.
- Pending Escape cancels without quitting and without popping. The stack is
  returned by identity, the pending row is removed, and `int-input` /
  `has-digits` reset to `0` / `#f`.
- This applies both before and after digits have been accumulated for an
  exact-`Int` hole and while a non-Int typed-pick row is pending.
- A second Escape after cancellation is idle and therefore pops, subject to
  the one-item floor. This is the meaning of "cancels a pending send first."
- `return`, digit accumulation, valid typed picks, invalid-pick no-ops,
  arity-zero invocation, and row selection remain unchanged.
- Do not introduce a global mode flag or mutate the existing state.

`handle-int`, `handle-pick`, and the public shape of `handle-key` remain
byte-for-byte. Do not add a general command table in this checkpoint.

### Gel main-loop behavior

`gel/main.aloe` does not change. Its existing loop supplies the required
observable behavior:

- every Escape is echoed as `key escape\r\n`;
- after idle Escape with history, the next redraw uses the revealed TOS;
- after pending Escape, the next redraw shows the same TOS with its ordinary
  menu; and
- after `q`, no further TOS/menu redraw occurs and the current stack returns.

Do not move echoing, pop, cancellation, or quit policy into Racket.

## Living historical tests

Checkpoints 69, 70, 75, and 76 contain assertions that pending `"q"`
cancels. That old assertion conflicts with the now-locked command-key policy.
Edit only those cancellation blocks:

1. Replace the pending cancellation input `"q"` with `"escape"`.
2. Update the adjacent comment/name only as needed to say Escape cancels.
3. Preserve the existing assertions: quit remains false, stack identity is
   unchanged where checked, pending becomes empty, and accumulated Int state
   resets where checked.
4. Do not add universal-q assertions to historical tests; those belong in
   checkpoint 109.
5. Do not otherwise reformat or modernize those files.

Do not edit the historical checkpoint documents. They remain records of the
behavior introduced at their own checkpoints; current behavior is recorded
in 109 and `docs/gel.md`.

## Tests and hand checks

Add `tests/checkpoint-109.rkt`. Use ordinary Aloe evaluation plus scripted
production Term receivers. Automated tests must not need a physical TTY.

Cover at least:

1. `GelStack.pop` typechecks as `GelStack`; `GelKey.escape?` typechecks as
   `Bool`.
2. Popping a three-item stack returns length two, reveals the former second
   mirror as TOS by identity, preserves the remaining order, and leaves the
   original stack unchanged.
3. Popping a two-item stack leaves one item. Popping that one-item result
   returns the same stack by identity. Popping `gel-empty-stack` returns that
   same empty stack by identity and does not error.
4. `GelKey.escape?` is true only for `"escape"`. Existing digit, quit, and
   return mappings still give their established results.
5. Idle Escape over a multi-item `GelStep` pops exactly once, stays idle, and
   does not request quit. Repeating Escape stops at a one-item stack.
6. Idle `q` requests quit with the stack unchanged; idle `u` remains a no-op.
7. Pending typed-pick Escape cancels without popping or quitting. Pending Int
   Escape after accumulated digits also cancels and resets the accumulator.
8. Pending `q`, for both typed-pick and Int rows, requests quit, preserves the
   stack, clears pending state, and never invokes the selected signature.
9. A pending Escape followed by another Escape first cancels and only then
   pops one history item.
10. Scripted `gel-main call` with a two-item stack and keys
    `("escape" "q")` echoes both keys, redraws the newly revealed TOS after
    Escape, and returns the one-item stack.
11. Scripted Point application behavior through `GelMain.start` remains
    valid. A useful path is `("1" "escape" "q")`: `x` pushes `10`, Escape
    returns to the Point, and `q` returns the original one-item stack by
    observable contents.
12. A scripted pending path such as `("3" "escape" "q")` shows the pending
    line, cancels back to the same Point menu, then quits without invocation.
13. The runner remains application-supplied and Term-only. Default drivers
    remain free of `term`, `fs-host`, and Gel bindings.
14. The four living historical tests and the full suite remain green.

Keep transcript assertions exact enough to prove redraw ordering:

```text
... current TOS/menu ...
key escape
... revealed or unchanged TOS/menu ...
key q
```

Do not create a Racket pop helper or expose list internals to the runner for
test convenience.

### Pure hand check

From the project directory, load `gel/loop.aloe` into the existing Aloe REPL
or a driver and evaluate the equivalent of:

```aloe
(define stack
  ((gel-empty-stack push 1) push "two"))
(define popped (stack pop))
((popped tos) subject)
((popped items) len)
((stack items) len)
```

Expected values: `1`, `1`, and `2`.

### Physical-TTY hand check

When `tui-term` and a physical TTY are available:

```sh
racket host/racket/gel-run.rkt examples/gel-point.aloe
```

Press the displayed key for `x` (currently `1`), then Escape. Gel must return
from TOS `10` to TOS `#<Point 10 20>`. Press the displayed `+` key (currently
`3`), then Escape; the pending send must cancel without popping the Point.
Press `q` to leave and restore the terminal.

The scripted equivalents are required; the physical-TTY check is informative
when the optional dependency or a real terminal is unavailable.

## CHECKPOINTS.md and handoff

Append only:

```text
## 109. [Gel back / pop](docs/checkpoints/0109-gel-back-pop.md)

- `GelStack.pop` preserves a one-item floor. Idle Escape pops, pending Escape
  cancels first, and `q` quits from idle or pending state. No value-item rows
  or filesystem-aware Gel behavior yet.
```

Update `docs/handoff.md` to say tests are green through 109 on
`experiment/gel-directory-surface`; application-supplied launch and back/pop
are complete; and value-item rows are the next pressure. Do not claim an
authored Directory surface, key-pool policy, `u`, `fs-host` injection, or a
live directory start.

Update current stack/key paragraphs in `docs/gel.md`, especially the obsolete
statement that pending `q` cancels. After the checkpoint is green,
`docs/gel-directory-surface.md` may mark progression item 2 complete and item
3 next without resolving later open choices.

## Acceptance

This checkpoint is complete when Gel has an immutable one-level pop with a
one-item floor, Escape is context-sensitive back/cancel, `q` always quits,
the Aloe main loop exhibits the correct redraw order without changes, and no
directory or value-row work has begun.

Run:

```sh
raco test tests/checkpoint-109.rkt
raco test
git diff --check
```

The checkpoint test, four living historical tests, and full suite must pass.
Run both hand checks where the optional TTY is available. Stop for review
without committing and without starting checkpoint 110.

## Explicit non-goals

- No value-item rows, list selector page, authored `Directory` surface, or
  child selection.
- No item-key alphabet, collision-free pool, `u`, paging, search, prefix key,
  or two-key addressing.
- No `fs-host` import/injection, directory runner, live `Directory` start, or
  process-wide `chdir`.
- No change to `Disk`, `Location`, `Directory`, `File`, `Item`, or either
  filesystem library.
- No extra stack levels in text, stack-editing mode, `drop`, `swap`, return
  stack, or automatic argument consumption.
- No new literal-hole type, multi-argument builder, refresh, File surface,
  `read`, `size`, `enter`, `(here entries)`, Git, process, workspace, shell,
  editor, hook, plugin, pane, or GelFS framework.
- No host key remapping, Term change, runner change, default capability, host
  crossing type, or host effect.
- No new Aloe syntax, special form, dispatch rule, mutation, inheritance,
  macro, or implicit numeric coercion.
- Do not implement checkpoint 110 in the same change.
