# aloemacs-loop 002 — Backspace key normalization

**Status.** Ready to implement.

## Goal

Make the existing Term key boundary normalize every specified decoded
Backspace shape to the one Aloe command String `"backspace"`. Preserve Return,
Escape, printable characters, arrows, other named keys, unsupported-key
errors, the five-row Term capability, and every editor behavior unchanged.

This checkpoint is a small host-boundary compatibility slice. Stop when it is
green. Do not add the starting `aloemacs-editor` binding, create the iterative
runner, open a TTY in tests, or change editor commands.

The implementer receives only this document. Every rule needed for this slice
is below.

## Depends on, authority, and identity

- Identity is `(aloemacs-loop, 002)`, spoken **aloemacs-loop 002**. This is a
  local project checkpoint, not a global Aloe checkpoint. Do not edit
  `CHECKPOINTS.md` or add a document under `docs/checkpoints/`.
- [`../../../../../../SPEC.md`](../../../../../../SPEC.md), especially section
  14, is language law. Term remains an optional explicitly injected typed host
  capability; this checkpoint does not alter its descriptor, crossing
  vocabulary, checking, dispatch, reflection, or injection.
- [`../spec.md`](../spec.md), especially sections 3, 5, 8.5, and 9, is the
  local design authority. This checkpoint implements only the exact key
  normalization in section 5.
- **aloemacs-loop 000–001** are implemented and reviewed. The editor already
  handles the normalized Strings `"backspace"`, `"return"`, `"escape"`,
  `"up"`, `"down"`, `"left"`, and `"right"`. Preserve all editor transition
  and frame behavior.
- **aloemacs-term 000** is implemented and reviewed. Preserve its exact
  five-row descriptor, receiver factory compatibility, output behavior, size
  normalization, TTY lifetime, and focused tests.

Do not add a language feature, host method, crossing type, event variant,
second key path, or application policy to Racket.

## Starting point

`host/racket/term.rkt` exports `tkeymsg->aloe-key`. It currently:

1. rejects non-`tkeymsg` arguments;
2. maps Return forms to `"return"`;
3. maps Escape forms to `"escape"`;
4. prefers a printable decoded character;
5. otherwise accepts a printable key character;
6. converts a symbolic key with `symbol->string`; and
7. raises `term: unsupported key` for every remaining non-printable,
   non-symbolic key.

This already maps the named symbol `'backspace` through the generic symbol
case, but direct BS, DEL/rubout, and decoded control-H are non-symbolic forms
that do not all reach `"backspace"`.

The existing Term interface is exactly:

| Order | Selector | Parameters | Return |
|---:|---|---|---|
| 1 | `read-key` | `()` | `String` |
| 2 | `write-line` | `(String)` | `String` |
| 3 | `write` | `(String)` | `String` |
| 4 | `columns` | `()` | `Int` |
| 5 | `rows` | `()` | `Int` |

Neither that table nor `make-term-receiver` changes.

## Exact file scope

### May edit

- `host/racket/term.rkt`
- `tests/aloemacs/key-mapping.rkt` (new)

### Must not edit

- `SPEC.md`, `CHECKPOINTS.md`, any global checkpoint document, or any file
  under `docs/editor/`
- any file under `aloe/`, `lib/`, `examples/`, `gel/`, or `bin/`
- `host/racket/aloemacs-run.rkt`, either existing runner, another host module,
  package metadata, or `tui-term`
- any existing test, including `tests/checkpoint-53.rkt`,
  `tests/aloemacs/term-capability.rkt`, editor tests, and frame tests
- the aloemacs maps, charters, specifications, or earlier checkpoint
  documents
- any file not listed under **May edit**

If another file appears necessary, stop and send the checkpoint back for
correction rather than widening the slice.

## Exact Backspace forms

Before either printable-character case in `tkeymsg->aloe-key`, map each of
these `tui-term` messages to exactly `"backspace"`:

```racket
(make-tkeymsg 'backspace)
(make-tkeymsg #\backspace)
(make-tkeymsg #\rubout)
(make-tkeymsg #\h '(ctrl) #f)
```

Their meanings are:

- `'backspace` — a named decoder result;
- `#\backspace` — the direct BS control character U+0008;
- `#\rubout` — the direct DEL control character U+007F; and
- key `#\h`, exact modifiers `'(ctrl)`, and no decoded character — the
  control-H shape emitted by `tui-term`.

The control-H mapping is exact. Plain `#\h`, shifted `#\h`, or another
modifier list continues through the existing printable-key behavior. Do not
turn every message whose key happens to be `#\h` into Backspace.

A small private Racket predicate is permitted. Do not export another helper,
change `provide`, add a host method, or expose key-message structure to Aloe.

## Decision-tree preservation

The complete precedence remains:

1. validate that the input is a `tkeymsg`;
2. Return detection;
3. Escape detection;
4. the exact Backspace detection above;
5. printable decoded character;
6. printable key character;
7. symbolic key via `symbol->string`; and
8. unsupported-key error.

The Backspace clause must occur before the printable cases so decoded
control-H cannot become `"h"`. Keeping Return and Escape first ensures their
existing aliases retain precedence.

No other modifier policy changes:

- symbolic arrow messages still become their symbol names even when a
  modifier is present;
- a non-Backspace printable key continues to become its one-character
  String under the existing rules; and
- `tkeymsg->aloe-key` remains a pure conversion with no input read, output
  write, flush, size query, driver mutation, or editor dispatch.

Do not recognize terminal byte sequences, inspect ports, parse CSI, add a
general modifier vocabulary, or introduce a key class.

## Behavior that must remain exact

### Return

Each existing Return spelling remains `"return"`:

```racket
(make-tkeymsg 'return)
(make-tkeymsg #\return)
(make-tkeymsg #\newline)
```

### Escape

Each existing Escape spelling remains `"escape"`:

```racket
(make-tkeymsg 'escape)
(make-tkeymsg 'esc)
(make-tkeymsg #\u1b)
```

### Arrows and named keys

Each arrow symbol maps through `symbol->string`:

```text
up    -> "up"
down  -> "down"
left  -> "left"
right -> "right"
```

A representative modified arrow still collapses to the same name. An unknown
symbol such as `'home` remains `"home"` rather than an error.

### Printable and unsupported keys

Printable letters and space remain one-character Strings. Plain `#\h`
remains `"h"`; the exact control-H form alone becomes `"backspace"`.

A non-printable, non-symbolic key that is not one of the Backspace forms
continues to raise an error matching `unsupported key`. Passing a value that
is not a `tkeymsg` continues to raise the existing argument error.

## Required focused tests

Add `tests/aloemacs/key-mapping.rkt`. Require only the Racket modules needed
to construct `tkeymsg` values, call `tkeymsg->aloe-key`, and assert results.
Use `tui/term/messages` rather than opening a terminal. Do not construct an
Aloe driver or physical TTY for this pure boundary test.

Cover all of the following:

1. The four exact Backspace forms each return `"backspace"`.
2. Plain `#\h` still returns `"h"`. At least one non-control modifier shape
   also retains the old printable result, proving control-H matching is
   narrow.
3. `'up`, `'down`, `'left`, and `'right` return the four exact command
   Strings. A representative arrow with modifiers returns the same name.
4. All three Return forms return `"return"`.
5. All three Escape forms return `"escape"`.
6. Representative printable letter and space messages retain their exact
   one-character Strings. Cover both the ordinary key-character route and a
   message whose separate decoded character supplies the printable result.
7. An unknown named key such as `'home` returns `"home"`.
8. A representative unsupported non-printable, non-symbolic key still raises
   an error matching `unsupported key`.
9. A non-`tkeymsg` argument still raises an argument-contract error.
10. Repeated conversions have no observable state and do not require a
    driver, injected Term receiver, TTY, input port, or output port.

The historical checkpoint-53 mapping tests and the aloemacs Term capability
tests must pass unchanged. Do not move old assertions into the new file or
weaken their coverage.

## Verification and hand check

Run the focused mapping suite first:

```sh
TMPDIR=/tmp raco test tests/aloemacs/key-mapping.rkt
```

Then run the directly affected predecessor suites unchanged:

```sh
TMPDIR=/tmp raco test tests/checkpoint-53.rkt
TMPDIR=/tmp raco test tests/aloemacs/term-capability.rkt
```

Run the recursive suite; `tests/*.rkt` is not an acceptable substitute
because it skips nested aloemacs and editor tests:

```sh
TMPDIR=/tmp raco test tests
```

Run this pure no-TTY hand exercise from the repository root:

```racket
(require (only-in tui/term/messages make-tkeymsg)
         "host/racket/term.rkt")

(map tkeymsg->aloe-key
     (list
      (make-tkeymsg 'backspace)
      (make-tkeymsg #\backspace)
      (make-tkeymsg #\rubout)
      (make-tkeymsg #\h '(ctrl) #f)
      (make-tkeymsg 'up)
      (make-tkeymsg 'down)
      (make-tkeymsg 'left)
      (make-tkeymsg 'right)))
```

The result is:

```racket
'("backspace" "backspace" "backspace" "backspace"
  "up" "down" "left" "right")
```

No physical-TTY hand check is required.

## Acceptance

This checkpoint is complete only when:

1. Every exact named, BS, DEL/rubout, and control-H form maps to the one Aloe
   String `"backspace"`.
2. The new detection occurs before printable handling and is narrow enough
   that ordinary printable `h` and unrelated modifier behavior stay intact.
3. Return, Escape, all arrows, printable keys, unknown symbols,
   unsupported-key errors, and non-message argument errors retain their
   existing behavior.
4. The Term descriptor, host implementations, receiver factory, size/output
   behavior, TTY lifetime, Aloe editor, and frame code are unchanged.
5. The focused mapping test, unchanged predecessor tests, and full recursive
   suite are green, and the hand check returns the exact stated list.
6. No runner, starting binding, language feature, new dependency, general
   modifier system, terminal parser, or out-of-scope editor feature has been
   added.

Stop for human review. Do not begin another aloemacs-loop checkpoint.

## Explicit non-goals

- `examples/aloemacs/main.aloe`, the `aloemacs-editor` starting binding,
  `host/racket/aloemacs-run.rkt`, iteration, Term injection by an application,
  a runnable editor, or runner tests
- changes to editor key dispatch, commands, movement, frame construction,
  ANSI, Text, Position, Span, or any Aloe source
- a new Term selector, descriptor row, receiver field, host interface,
  crossing type, reflection special case, event class, or error protocol
- raw terminal bytes, escape-sequence parsing, CSI/OSC decoding, mouse, paste,
  resize events, polling, alternate screen, PTY, or a `tui-term` change
- general modifier names, modifier-aware bindings, prefix keys, configurable
  keymaps, `C-x`, `M-x`, minibuffer, search, undo, files, buffers, windows, or
  any later editor feature
