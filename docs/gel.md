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

The same machine later talks to the file system, processes, and git:
those are more classes, not a second UI.

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
| a `Dir` | shell listing, `cd`, `up` |
| a `File` | name, size, copy, open-as-print |
| a `Process` / process list | later |
| a `GitRepo` | later; appears because this dir answers git, not because a minor mode was turned on |

Adding a capability means adding an Aloe class or method (plus host
primitives when the OS must be touched). Gel itself does not grow a new
framework per personality.

---

## 5. Three layers

Keep them separate.

1. **Aloe.** Classes, sends, types. Portable as far as the types go.
2. **Host prelude.** Keys, later `list-dir`, `stat`, `kill-pid`. Racket
   first, then a thin bridge so Aloe can send those messages. Not
   `SPEC.md`.
3. **Gel.** Stack, current menu, send builder, pager, printed history.
   Written in Aloe once the host messages exist.

Racket owns FFI only. Bind a C library in Racket if needed, then expose
a small Aloe receiver. After that, build in Aloe. That is the test of
the language.

`bin/aloe` stays term-free. A separate host runner binds `term` and
loads Gel.

The reflection hatch is `Mirror`, not a `perform` message on every object.

Gel v0 menu rows now live in `gel/menu.aloe`. `(gel-rows call value)` builds
ordered `GelRow` values from the subject's reflected signatures, including a
one-based index, selector, arity, and signature. The stack loop and key input
come later.

The Gel stack in `gel/stack.aloe` is an ordinary `(List Mirror)`, with `first`
as TOS and `cons` as push. Ordinary values are wrapped once on push; an
existing mirror is stored unchanged. A zero-argument row invokes against the
TOS mirror and pushes the result as another mirror. A one-argument row accepts
either an ordinary value or a mirror; the latter is unwrapped with `subject`
before invoking the row's exact signature. The result is pushed as a mirror.

The key step in `gel/loop.aloe` is Aloe application code: `"q"` requests quit,
and digit strings select reflected zero-argument rows. A TTY only supplies the
key-shaped `String`; terminal handling remains a host skin around this pure
step.

---

## 6. What already exists (2026-09-04)

Not Gel. Only the key door.

- Package: `tui-term` (`raco pkg install tui-term`). Not `#%terminal`,
  not a project C FFI. See `docs/decisions.md`.
- Spike: `host/racket/read-key-spike.rkt`
- Optional runner: `host/racket/term-run.rkt`
- Bridge: `host/racket/term.rkt`, `aloe/host.rkt`
- Eval will send to an injected `host-receiver`
- Tests: `tests/checkpoint-53.rkt`
- Core Aloe, Boids, and MPL do not load `tui-term`

Key mapping, v0:

- printable character → Aloe `String`
- return, escape, and other named keys → host `Key` with `(key name)`
- mouse and resize events are ignored

`(term read-key)` is the intended Aloe spelling. The current runner
injects the receiver; it is not a kernel special form.

The two runtime shapes (`String` and `Key`) are a host fact. Do not
weaken the type language to paper over them in this slice.

---

## 7. Scope

### v0 — the Gel machine

Prove the loop on objects that already live in the Aloe image.

- Bind `term` in the host runner
- Object stack, printed TOS, printed menu with keys
- Menu from the checker / class method table (no kernel ask-API)
- Send builder for a method that needs arguments
- Push the result
- Quit on a reserved key
- One in-image vocabulary: `Point` (and the `Point` class) is enough

No files, no processes, no git, no mouse, no Listener REPL, no
cursor-addressed full screen unless `read-key` plus line printing is
genuinely unusable.

### v1 — shell vocabulary

Host objects `Dir` and `File`. Listing is a `List`. Pager keys. `cd` /
`up` push directories. A few file sends (`name`, `size`, open as print).
This is the first daily-use personality.

Strings already exist in Aloe. Paths are a host type, not a reason to
add mutation to every object. `cwd` is an app handle.

### Later, same machine

Processes, git, class picker over the whole image, nested field rebuild
for Boids, presentations / mouse as a skin on the same command table,
the reserved Listener / Inspector / Browser apps.

Do not add N-ary `+`, macros, `#lang aloe`, or graphics because Gel
would like them. Gel pressures keys, host objects, and (only if a golden
blocks) a reflective “messages of this value” API. v0 can use the
checker table instead.

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
- How the builder picks an argument from the stack without fighting the
  menu keys.
- Whether `Key` becomes a real Aloe class or stays a host receiver.
- Whether a printed history line is only text, or a named value (`$1`)
  that can be pushed again. `$1` is Listener-shaped; Gel can wait.
- Ask-API (`messages` on a value) when the checker table is no longer
  enough. Not v0.

---

## 10. How to work

Same split as the language.

- This conversation designs. This file is the spec.
- One checkpoint at a time. Tests in the same change.
- Implementer stops when `raco test` is green and one keystroke path
  has been run by hand on a real TTY.
- Do not grow the Aloe kernel for Gel unless a Gel golden cannot be
  expressed as a host method plus Aloe classes.
