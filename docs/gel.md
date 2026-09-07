# Gel

**Guided Exploration Layer**

You can also read the letters as **Generated Evaluation Layer**
(the menu and the send are built from the live type) or
**Growable Environment Layer** (Aloe, the OS, and the keyboard become one
surface). Those are readings, not other product names.

Gel is a keystroke object environment for Aloe. It is not a typed REPL.

This file is law for the Gel phase. Informal chat is how we amend it.
Aloe language law remains `SPEC.md`. Rejected language ideas remain
`docs/decisions.md`.

## Unified target transition

The application descriptions below retain the current checkpoint-88 keys,
state, output, and runners. [SPEC.md](../SPEC.md) defines the unified target in
the **89I ratification change submitted for review**; its acceptance completes
checkpoint 89's design/documentation arc. The corrected roadmap and handoff
are accepted. [CHECKPOINTS.md](../CHECKPOINTS.md#future-family-implementation)
governs implementation order; a planned entry still requires its own checkpoint
document and authorization.

91C introduces `invoke-mirrored`, all three [approved helper replacements](../SPEC.md#gel-invocation-through-mirrors),
and inference closure together. Existing valid calls, keys, stack results and
output are preserved, with the intentional menu addition when explicitly
browsing a Mirror object's own API. Ordinary subject menus acquire no row.
103B separately migrates Gel's nominal declarations; 105 replaces the pending
sentinel list with `(Option GelRow)` and its exhaustive consumers. Further
state restructuring is optional when it makes the application clearer.

These transitions preserve the existing host/application boundary and choose
no new keys, UI, or host capabilities. For the 89I documentation slice, the
full suite and in-memory [checkpoint-88 Term hand check](checkpoints/0088-seal-typed-host-boundary.md#hand-check)
are required; supplied readers need no live TTY session. The installed
`tui-term` package is used by Term integration. Later implementation checkpoints
retain their required live interactions. See the [family handoff](unified-nominal-adts-implementation-handoff.md)
for the current review boundary and validation evidence.

---

## 1. Job

Open Gel every day. Put an object on the stack. See what it offers. Press
one key. Fill a send if it needs arguments. The result becomes the next
object.

The same machine may later explore file-system, process, and repository
personalities without becoming a second UI. Their capability and object
shapes remain undecided until an application forces them.

Need-driven. Not Morphic-as-kit. Not a VS Code clone. Not a bash clone.

---

## 2. Reserved names

Do not spend these on Gel.

| Name | Reserved for |
|---|---|
| **Listener** | Genera-style typed REPL: expressions, commands, presentations in the history |
| **Inspector** | Smalltalk-style field-and-slot viewer |
| **Browser** | Class / source browser |

Gel is the odd one: live TOS, menus from messages, one key, send builder.

TUI names the medium (a terminal and raw keys). It is not the product.

---

## 3. The machine

One stack of values. Top of stack (TOS) is the active object.

1. The menu is the messages that object understands (fields count as
   zero-argument sends).
2. Every menu item has a key. That key runs the item. No mouse in v0.
3. Pick a selector. If it has parameters, open a **send builder**:
   receiver, selector, one typed hole per parameter.
4. Fill a hole by typing a literal, picking another stack item, or
   drilling into a field. Types come from the method signature. The
   checker rejects a hole before the send runs.
5. Submit. The send runs. The result is pushed. The menu follows the new
   TOS.
6. A long `List` is not “one key per element in the universe.” It is a
   **selector page**: visible rows get keys; `n` / `p` page; `/` searches.
   Choosing a row pushes that element.

Nested “edit” is rebuild. Aloe objects are immutable. Pushing
`(boid position)` and building a new `Point` does not mutate the boid.
A later parent send/`new` uses the new value.

Classes and instances share the stack. Putting `Point` on the stack
offers `new`. Putting a point on the stack offers `x`, `+`, and the rest.

---

## 4. Modes are TOS

There is no global mode flag if the stack can say it.

| TOS | Personality |
|---|---|
| a class (`Point`) | construct |
| a `Point` / `Sim` / `Sum` | Aloe image |
| a future filesystem-facing value | possible shell personality |
| a future process-facing value | possible process personality |
| a future repository-facing value | possible version-control personality |

Those future rows are exploratory, not accepted type, selector, handle, or
policy designs.

Adding a capability means adding an Aloe class or method (plus host
primitives when the OS must be touched). Gel itself does not grow a new
framework per personality.

---

## 5. Three layers

Keep them separate.

1. **Aloe.** Classes, sends, types. Portable as far as the types go.
2. **Host capabilities.** Racket supplies irreducible facts and effects behind
   explicitly injected, descriptor-defined receivers. Term is the first one;
   later capabilities remain application-driven and unspecified.
3. **Gel.** Stack, current menu, send builder, pager, printed history.
   Written in Aloe once the host messages exist.

Racket owns host integration only. Expose the smallest required effect through
an explicit typed receiver, then build domain objects, policy, and composition
in Aloe. That is the test of the language.

`bin/aloe` stays term-free. The optional runners create a checked driver,
explicitly inject `term`, and load their Aloe source through that driver.

The reflection hatch is `Mirror`, not a `perform` message on every object.
Injected host receivers participate in the same `Mirror` and `Signature`
protocol as ordinary values. Their rows come directly from the capability
descriptor and invoke through the ordinary guarded host boundary.

Gel v0 menu rows now live in `gel/menu.aloe`. `(gel-rows of value)` builds
ordered `GelRow` values from the subject's reflected signatures, including a
one-based index, selector, arity, and signature, while `(gel-rows select rows
index)` returns a valid indexed row. An exact `Mirror` overload uses an
existing mirror directly, while the generic overload reflects an ordinary
value and delegates to it; both routes therefore share the same row
construction and never reflect a mirror twice. Those rows drive the current
stack loop and key handling.

The Gel stack in `gel/stack.aloe` is an immutable `GelStack`. Its `items` field
holds the underlying `(List Mirror)`, `tos` reads the first item, and `push`
constructs a new stack. Ordinary values are wrapped once on push; an existing
mirror is stored unchanged. `gel-empty-stack` is the shared immutable starting
value; `(gel-empty-stack push value)` starts a one-item stack, and another
`push` adds a new TOS without changing the empty stack. `(stack invoke-zero
row)` invokes a zero-argument row against the TOS mirror and pushes the result.
`(stack invoke-one row argument)` accepts either an ordinary value or a mirror;
the latter is unwrapped with `subject` before invoking the row's exact
signature. The result is pushed as a mirror. Invocation belongs to `GelStack`;
there are no separate callable invocation helpers.

The key step in `gel/loop.aloe` is Aloe application code on the immutable
`GelStep` state itself: `(step handle-key key)` returns the next state. `"q"`
requests quit, and digit strings select reflected rows. Zero-argument rows
invoke directly. The public transition still accepts terminal `String` text
and constructs one immutable `GelKey`; its `menu-index`, `digit-value`,
`quit?`, and `return?` messages carry the meanings Gel assigns to that text.
Selecting an arity-one row stores it as an empty-or-singleton `(List GelRow)`
in `GelStep.pending`; no send runs yet. The pending menu numbers only stack
mirrors accepted by `(row accepts? candidate)`, in stack order, and the next
digit invokes with that mirror's subject. `(stack matching-picks row)` filters
the stack's mirrors and returns an immutable `GelPicks`; it wraps the ordered
`(List GelPick)` and owns its `len` and valid one-based `select`.
`GelRow.expected-text` presents the first parameter type, and `int-hole?`
identifies the exact `Int` case. A mismatching or missing pick is a no-op that
stays pending. While pending, `q` cancels the row and returns to the ordinary
Gel menu rather than quitting. An exact `Int` hole temporarily pauses those
stack-pick digits: `"0"` through `"9"` accumulate an integer with
`acc * 10 + digit`, and `"return"` invokes only after at least one digit. The
pending line shows the accumulator. Canceling drops it. Non-Int holes keep the
typed stack-pick behavior. A TTY only supplies the key-shaped `String`;
terminal handling remains a host skin around this pure step.

Menu and TOS text share the Aloe `GelText` service. `(gel-text menu value)`
emits one indexed selector/arity line per reflected row, with overloads for
ordinary values, exact mirrors, and `GelStep` state. `(gel-text tos stack)`
emits `"TOS: "` plus the top mirror's raw subject text. From the project
directory, launch the thin TTY skin with `racket host/racket/gel-run.rkt`
(after installing the optional `tui-term` package). Press the displayed digit
for `x` to push its value, and `q` to leave with the terminal restored.

The interactive recursion now lives in `gel/main.aloe`: it writes a TOS line
from `(gel-text tos stack)`, then `(gel-text menu state)`, reads a `String` key,
steps or ignores it, and recurses. Immediately after reading, it writes `key `
followed by the key before handling it, so the transcript records digits,
no-ops, `return`, and quit alike. TOS text uses the structural printer exposed
through the TOS mirror; it does not select a subject's optional `show` method.
The Racket runner is only the host lifecycle skin that opens the TTY, injects
`term` into one checked driver, loads Gel and `Point`, and starts `gel-main`.
Its demo stack puts `(Point new 1 2)` under `(Point new 10 20)`, so selecting
`+` produces `(Point new 11 22)`. A separate Gel `show` choice remains later
work.

---

## 6. Current host boundary (2026-09-06)

- `tui-term` remains an optional dependency for physical terminal use. Core
  Aloe, Boids, and MPL do not load it.
- Term is the first optional typed capability. One ordered descriptor defines
  `read-key : () -> String` and `write-line : (String) -> String` for both the
  evaluator and checker.
- `host/racket/term-run.rkt` and `host/racket/gel-run.rkt` each create one
  checked driver, explicitly inject Term, and use that driver for loading and
  evaluation.
- `Mirror` exposes descriptor-derived messages and `Signature` rows for an
  injected receiver. Owned rows invoke exactly through the guarded host
  boundary; no dynamic selector send or host-specific reflection API exists.
- `host/racket/read-key-spike.rkt` remains the original terminal-input spike.

Key mapping, v0:

- printable character → Aloe `String`
- return, escape, and other named keys → Aloe `String` names
- mouse and resize events are ignored

`(term read-key)` is the Aloe spelling. The checked runners inject the
receiver explicitly; it is not a kernel special form or ambient capability.

---

## 7. Scope

### v0 — the current Gel machine

The loop is implemented on objects that already live in the Aloe image.

- Explicitly inject `term` in the checked host runner
- Object stack, printed TOS, printed menu with keys
- Menu rows from `Mirror` and `Signature`
- Typed pending sends for one-argument methods
- Push the result
- Quit on a reserved key
- One in-image vocabulary: `Point`

No files, no processes, no git, no mouse, no Listener REPL, no
cursor-addressed full screen unless `read-key` plus line printing is
genuinely unusable.

### Possible next vocabulary — exploratory

A future application may pressure Gel toward file-system or shell-like work.
No capability split, selectors, crossing types, handles, object boundaries,
navigation policy, or presentation policy has been accepted. Those decisions
wait for concrete operations and tests.

### Later, same machine

Processes, repository work, a class picker over the whole image, nested field
rebuild for Boids, presentations or mouse as a skin on the same command table,
and the reserved Listener / Inspector / Browser apps are possible directions,
not current designs.

Do not add N-ary `+`, macros, `#lang aloe`, or graphics because Gel
would like them. Gel pressures keys and host boundaries; any new kernel work
still requires a blocked golden. The current menu needs are already served by
`Mirror` and `Signature`.

---

## 8. Decisions

- Text first. Mouse is a skin on the command table.
- One stack. Menus from the TOS type. Lists have a pager.
- TOS is the **receiver**. Arguments fill from the builder (typed
  literals or other stack items). Not Forth “TOS is last argument.”
- Most specific method wins, same as Aloe 0.2 overloading. Gel does not
  invent a second lookup rule.
- No implicit `Int` → `Math` lift. No implicit `Int` / `Float` mix.
- Do not put Gel in `lib/` until a second application wants the same
  code. Keep it beside the host runner (`host/` and a Gel Aloe tree).
- Do not one-shot files + processes + git + the Point builder.

---

## 9. Open

- Exact key assignment: digits, letters, reserved keys for quit / pop /
  page / search / submit.
- How non-`Int` literal holes should be filled.
- Which named key strings Gel should eventually handle beyond digits and quit.
- Whether a printed history line is only text, or a named value (`$1`)
  that can be pushed again. `$1` is Listener-shaped; Gel can wait.
- What concrete application, if any, should drive the next host capability;
  its shape remains open.

---

## 10. How to work

Same split as the language.

- This conversation designs. This file is the spec.
- One checkpoint at a time. Tests in the same change.
- Implementer stops when `raco test` is green and one keystroke path
  has been run by hand on a real TTY.
- Do not grow the Aloe kernel for Gel unless a Gel golden cannot be
  expressed as a host method plus Aloe classes.
