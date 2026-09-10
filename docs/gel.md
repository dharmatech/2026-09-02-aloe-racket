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
6. A `List` presents its first 24 values as directly choosable rows. The rows
   use a fixed position-bound lowercase letter pool with `q` and `u` omitted.
   Choosing a row pushes that exact value mirror; paging and search remain
   deferred.
7. A live `Directory` presents its first 24 immediate children through the
   same keys. Labels append `/` to directories and `@` to symbolic links;
   choosing a row pushes the nested live object. `u` pushes the Directory's
   live parent, while Escape pops the existing stack history.

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
| a live `Directory` | focused filesystem browser |
| a live `File` / `SymbolicLink` / `Other` | derived Aloe image menu |
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
   explicitly injected, descriptor-defined receivers. Current runners may
   supply Term alone or Term plus the filesystem receiver.
3. **Gel.** Stack, current menu, send builder, authored value rows, printed
   history.
   Written in Aloe once the host messages exist.

Racket owns host integration only. Expose the smallest required effect through
an explicit typed receiver, then build domain objects, policy, and composition
in Aloe. That is the test of the language.

`bin/aloe` stays capability-free. The optional runners create a checked
driver, explicitly inject their required receivers, and load Aloe source
through that driver.

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
derived-message path and remain available through the lower-level `gel-rows`
service.

The user-facing menu is a `GelMenu` with either reflected `Messages` rows or
authored `Values` rows. Gel installs one private `List.gel-values` adapter in
`gel/menu.aloe`; it maps list elements to mirrors entirely in Aloe and retains
existing mirrors by identity. `GelMenus` recognizes that exact zero-argument
owned signature through `Mirror`, invokes it with a `GelListValues` expected
type, and builds at most 24 one-based `GelValueRow` values in source order.
One immutable `GelItemKeys` pool binds those row positions to `a` through `z`
with `q` and `u` omitted; `GelValueRow.key` derives its key from that pool and
its immutable `label` captures presentation text when the row is built.
Ordinary Lists use each mirror's raw text, retaining their existing bytes.

`gel/directory.aloe` adds a deliberately narrow application adapter only after
`lib/disk.aloe` has loaded. `GelMenus` first recognizes the exact reflected
zero-argument `gel-directory-values` row, which returns `GelValueRows` carrying
the nested live child mirrors rather than `Item` wrappers. The adapter labels
files and other objects by name, directories with `/`, and symbolic links with
`@`. It also supplies the exact reflected `gel-up` service used only by the
`u` command. These selectors are private seams for this one built-in surface,
not a general authored-surface protocol. Empty Directories render only
`u  up`; unfamiliar objects retain their derived menu.

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
there are no separate callable invocation helpers. `(stack pop)` removes
exactly one TOS mirror when history exists and returns the same stack by
identity at zero or one item, preserving a one-item floor for interactive
sessions.

The key step in `gel/loop.aloe` is Aloe application code on the immutable
`GelStep` state itself: `(step handle-key key)` returns the next state. `"q"`
requests quit, and digit strings select reflected rows. Zero-argument rows
invoke directly. The public transition still accepts terminal `String` text
and constructs one immutable `GelKey`; its `menu-index`, `digit-value`,
`item-index`, `quit?`, `escape?`, `up?`, and `return?` messages carry the
meanings Gel assigns to that text. `item-index` looks up only the fixed authored-value
letter pool. Idle `"escape"` pops one stack item when history exists and stops
at the one-item floor.
Selecting an arity-one row stores it as an empty-or-singleton `(List GelRow)`
in `GelStep.pending`; no send runs yet. The pending menu numbers only stack
mirrors accepted by `(row accepts? candidate)`, in stack order, and the next
digit invokes with that mirror's subject. `(stack matching-picks row)` filters
the stack's mirrors and returns an immutable `GelPicks`; it wraps the ordered
`(List GelPick)` and owns its `len` and valid one-based `select`.
`GelRow.expected-text` presents the first parameter type, and `int-hole?`
identifies the exact `Int` case. A mismatching or missing pick is a no-op that
stays pending. While pending, `"escape"` cancels the row, clears any integer
input, and returns to the ordinary Gel menu without popping; a second Escape
then follows the idle pop behavior. `"q"` requests quit from both idle and
pending states without invoking or popping. An exact `Int` hole temporarily
pauses stack-pick digits: `"0"` through `"9"` accumulate an integer with
`acc * 10 + digit`, and `"return"` invokes only after at least one digit. The
pending line shows the accumulator. Non-Int holes keep the typed stack-pick
behavior. On an idle Directory, exact lowercase `"u"` invokes its private
adapter and pushes a returned live parent; at root it is a no-op. On every
other object and during pending input it remains a no-op. A TTY only supplies
the key-shaped `String`; terminal handling remains a host skin around this pure
step. On an idle List, a valid visible item letter pushes the selected row's
exact mirror immediately, leaves the List beneath it as history, and never
enters the pending-send path. Digits remain reserved for reflected message
rows, pending picks, and pending Int entry; they do not select List values.
`q` and Escape retain command precedence before `u`,
and invalid or out-of-range keys are no-ops.

Menu and TOS text share the Aloe `GelText` service. `(gel-text menu value)`
emits one indexed selector/arity line per reflected row, with overloads for
ordinary values, exact mirrors, and `GelStep` state. `(gel-text tos stack)`
emits `"TOS: "` plus the top mirror's raw subject text unless an exact private
zero-argument `gel-tos-text` signature is present. The Directory adapter adds
that signature to live `Directory`, `File`, `SymbolicLink`, and `Other`
objects; `GelText` invokes the owned row through the same mirror with an exact
`String` result, rendering the class and escaped existing path while keeping
the selector out of the derived menu. From the project directory, launch the
Point application through the thin TTY skin with
`racket host/racket/gel-run.rkt examples/gel-point.aloe` (after installing the
optional `tui-term` package). Press the displayed digit for `x` to push its
value, and `q` to leave with the terminal restored.

The interactive recursion now lives in `gel/main.aloe`: it writes a TOS line
from `(gel-text tos stack)`, then `(gel-text menu state)`, reads a `String` key,
steps or ignores it, and recurses. Immediately after reading, it writes `key `
followed by the key before handling it, so the transcript records digits,
no-ops, `return`, and quit alike. TOS text uses the structural printer exposed
through the TOS mirror; it does not select a subject's optional `show` method.
The Racket runner is only the host lifecycle skin that opens the TTY, injects
`term` into one checked driver, loads Gel and one supplied Aloe application,
then sends `(gel-main start gel-start-value)`. `GelMain.start` accepts any
ordinary Aloe value and performs one push from `gel-empty-stack`; the existing
`GelMain.call` remains the lower-level entry for an application that assembles
its own stack. `examples/gel-point.aloe` owns the Point class load and binds
its one `(Point new 10 20)` start value. The runner has no Point knowledge. A
separate Gel `show` choice remains later work.
Launch the live directory application from the project directory with
`racket host/racket/gel-directory-run.rkt examples/gel-directory.aloe`. This
separate runner injects both `term` and production `fs-host`; the application
loads the disk vocabulary and Gel adapter, then supplies the process's current
live Directory as `gel-start-value`. It does not change process cwd.

---

## 6. Current host boundary (2026-09-10)

- `tui-term` remains an optional dependency for physical terminal use. Core
  Aloe, Boids, and MPL do not load it.
- Term is the first optional typed capability. One ordered descriptor defines
  `read-key : () -> String` and `write-line : (String) -> String` for both the
  evaluator and checker.
- `host/racket/term-run.rkt` and `host/racket/gel-run.rkt` each create one
  checked driver, explicitly inject Term, and use that driver for loading and
  evaluation. The Gel runner requires one Aloe application path, loads Gel
  before that application, and launches its `gel-start-value` convention.
- `host/racket/gel-directory-run.rkt` follows the same checked application
  launch, but explicitly injects both `term` and production `fs-host`. Its
  Aloe application owns all Directory construction and navigation policy.
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

- Explicitly inject `term` in checked runners and `fs-host` only in the
  filesystem-capable Directory runner
- Object stack, printed TOS, printed menu with keys
- Menu rows from `Mirror` and `Signature`
- Up to 24 letter-keyed, directly choosable value rows when a List is TOS
- A live Directory application with labeled immediate children and `u` parent
  pushes through a separate filesystem-capable runner
- Typed pending sends for one-argument methods
- Push the result
- Back with idle Escape; cancel pending sends with Escape before popping
- Quit with `q` from idle or pending state
- Generic one-value application entry through `GelMain.start`
- Point retained as the tiny `examples/gel-point.aloe` application

No file reading, processes, git, mouse, Listener REPL, or
cursor-addressed full screen unless `read-key` plus line printing is
genuinely unusable.

### Current focused Directory application

The focused browser in `examples/gel-directory.aloe` starts on a live current
Directory, lists its immediate children, and distinguishes a computed parent
push from stack back. [`docs/gel-directory-surface.md`](gel-directory-surface.md)
records the completed first progression and deferred pressure. The current
listing is immutable within one menu construction, but later redraws or key
steps may observe the host again. Paging/search, persistent snapshots and
refresh, file reading, and extra visible stack levels remain later work.

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
- One stack. Menus from the TOS type. Lists expose the first 24 values through
  a fixed position-bound letter pool that excludes `q` and `u`; paging and
  search remain later work.
- Directory rows reuse the same Values menu and item-key pool. The adapter
  lives in Gel application code; reusable disk vocabulary remains unaware of
  Gel.
- Escape means stack back. Directory `u` computes and pushes a live parent;
  it does not pop, replace TOS, or change process cwd.
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

- Overflow command assignment for paging and search; any later command key
  must first leave the item-key pool.
- How non-`Int` literal holes should be filled.
- Which named key strings Gel should eventually handle beyond the current
  Escape and Return paths.
- Whether a printed history line is only text, or a named value (`$1`)
  that can be pushed again. `$1` is Listener-shaped; Gel can wait.
- Whether Directory rows need a persistent per-TOS snapshot and explicit
  refresh rather than observation on each menu construction.
- How many stack levels to display so back versus up is visible before a key.

---

## 10. How to work

Same split as the language.

- This conversation designs. This file is the spec.
- One checkpoint at a time. Tests in the same change.
- Implementer stops when `raco test` is green and one keystroke path
  has been run by hand on a real TTY.
- Do not grow the Aloe kernel for Gel unless a Gel golden cannot be
  expressed as a host method plus Aloe classes.
