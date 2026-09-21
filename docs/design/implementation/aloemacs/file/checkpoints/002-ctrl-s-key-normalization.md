# aloemacs-file 002 — Ctrl-S key normalization

**Status.** Ready to implement.

## Goal

Make the existing Term key boundary normalize the exact plain Ctrl-S message
emitted by `tui-term` to the named Aloe command String `"save"`. Preserve
printable `s`, Ctrl-Shift-S, Alt-S, every existing Return, Escape, Backspace,
and arrow mapping, unknown named keys, unsupported-key errors, and the
five-row Term capability unchanged.

This checkpoint is the physical-key bridge to the reviewed
`AloemacsSession.handle-key "save"` behavior. Stop when it is green. Do not
change the session, starting value, runner, command-line handling, or
filesystem behavior.

The implementer receives only this document. Every rule needed for this slice
is below.

## Depends on, authority, and identity

- Identity is `(aloemacs-file, 002)`, spoken **aloemacs-file 002**. This is a
  local project checkpoint, not a global Aloe checkpoint. Do not edit
  `CHECKPOINTS.md` or add a document under `docs/checkpoints/`.
- [`../../../../../../SPEC.md`](../../../../../../SPEC.md), especially section
  14's typed host boundary, is language law. Term remains an optional,
  explicitly injected host capability; this checkpoint does not change host
  types, checking, dispatch, reflection, or injection.
- [`../spec.md`](../spec.md), especially sections 1, 6, 8.3, 9, and 10, is the
  local design authority. This checkpoint implements only the one exact
  Ctrl-S normalization in section 6.
- **aloemacs-file 000–001** are implemented and reviewed. The immutable
  `AloemacsSession` already recognizes the complete String `"save"`, performs
  explicit save before quit, preserves ordinary printable `"s"`, and absorbs
  every key after quit. Do not reopen that application policy.
- **aloemacs-loop 002** is implemented and reviewed. It established the
  current key-normalization decision tree and exact Backspace handling in
  `host/racket/term.rkt`.
- **aloemacs-term 000** is implemented and reviewed. Preserve its exact
  five-row descriptor, receiver factory, output behavior, size normalization,
  and TTY lifetime.

Do not add a language feature, host method, crossing type, event variant,
second key path, key class, or application policy to Racket.

## Starting point

`host/racket/term.rkt` exports the pure `tkeymsg->aloe-key` conversion. Its
current precedence is:

1. reject a non-`tkeymsg` argument;
2. normalize Return;
3. normalize Escape;
4. normalize the reviewed Backspace shapes;
5. prefer a printable decoded character;
6. otherwise accept a printable key character;
7. turn a symbolic key into its name; and
8. reject every remaining unsupported key.

Because modifiers are otherwise ignored for printable key characters, the
message below currently reaches the printable-key branch and returns `"s"`:

```racket
(make-tkeymsg #\s '(ctrl) #f)
```

`examples/aloemacs/file.aloe` already handles the named String `"save"`
directly. `examples/aloemacs/main.aloe` and the current runner still use the
pre-file-layer starting value and are intentionally unchanged in this slice.

The existing Term interface remains exactly:

| Order | Selector | Parameters | Return |
|---:|---|---|---|
| 1 | `read-key` | `()` | `String` |
| 2 | `write-line` | `(String)` | `String` |
| 3 | `write` | `(String)` | `String` |
| 4 | `columns` | `()` | `Int` |
| 5 | `rows` | `()` | `Int` |

Neither this table nor `make-term-receiver` changes.

## Exact file scope

### May edit

- `host/racket/term.rkt`
- `tests/aloemacs/file-key-mapping.rkt` (new)

### Must not edit

- `SPEC.md`, `CHECKPOINTS.md`, any global checkpoint document, or any file
  under `docs/editor/`
- any file under `aloe/`, `lib/`, `examples/`, `gel/`, or `bin/`
- `host/racket/fs.rkt`, `host/racket/aloemacs-run.rkt`, another host module,
  package metadata, or `tui-term`
- any existing test, including `tests/aloemacs/key-mapping.rkt`,
  `tests/aloemacs/file-session.rkt`, Term tests, runner tests, and historical
  global checkpoint tests
- the aloemacs maps, charter, specification, or predecessor checkpoint
  documents
- any file not listed under **May edit**

If another file appears necessary, stop and send the checkpoint back for
correction rather than widening the slice.

## Exact Ctrl-S form

Before both printable-character cases in `tkeymsg->aloe-key`, map exactly:

```racket
(make-tkeymsg #\s '(ctrl) #f)
```

to:

```racket
"save"
```

All three message components are normative:

- key is the lowercase character `#\s`;
- modifiers are exactly the list `'(ctrl)`; and
- the separate decoded-character field is exactly `#f`.

This is the plain Ctrl-S shape emitted by the current `tui-term` VT decoder.
A small private Racket predicate is permitted. Do not export it, change the
module's `provide` surface, or expose `tkeymsg` structure to Aloe.

## Decision-tree preservation

The resulting precedence is exactly:

1. validate that the input is a `tkeymsg`;
2. Return detection;
3. Escape detection;
4. existing exact Backspace detection;
5. exact plain Ctrl-S detection;
6. printable decoded character;
7. printable key character;
8. symbolic key via `symbol->string`; and
9. unsupported-key error.

The Ctrl-S clause must precede the printable branches; otherwise its key
character remains `"s"`. It does not replace, broaden, or reorder Return,
Escape, or Backspace recognition.

The following messages are deliberately not save commands and continue
through the old conversion rules:

```racket
(make-tkeymsg #\s)                    ; => "s"
(make-tkeymsg #\s '(ctrl shift) #f)  ; => "s"
(make-tkeymsg #\s '(alt) #f)         ; => "s"
(make-tkeymsg #\s '(ctrl) #\s)       ; => "s"
```

The exact ordering and membership of the modifier list matter. Do not map
every message containing `ctrl`, every key whose printed form is `s`, the
uppercase character `#\S`, or a decoded printable `s` to `"save"`.

`tkeymsg->aloe-key` remains a pure conversion. It performs no input read,
output write, flush, size query, driver mutation, filesystem operation,
session dispatch, or editor transition.

## Behavior that remains exact

The implementation must leave all existing behavior untouched:

- the named, BS, DEL/rubout, and exact control-H Backspace forms return
  `"backspace"`;
- Return spellings return `"return"`;
- Escape spellings return `"escape"`;
- arrow symbols return `"up"`, `"down"`, `"left"`, or `"right"`, including
  the existing representative modified-arrow behavior;
- printable letters and space return one-character Strings;
- decoded printable characters retain precedence over an unrelated key;
- an unknown symbol such as `'home` returns `"home"`;
- an unsupported non-printable, non-symbolic key raises the existing
  `unsupported key` error; and
- a non-`tkeymsg` argument raises the existing argument-contract error.

There is no general modifier vocabulary or modifier-aware dispatch. The one
Ctrl-S shape is a closed application normalization, like the reviewed
Backspace compatibility forms.

## Required focused tests

Create `tests/aloemacs/file-key-mapping.rkt`. Require only `rackunit`, the
`make-tkeymsg` constructor from `tui/term/messages`, and the existing local
Term module. Do not construct an Aloe driver, host receiver, session,
filesystem, or physical TTY.

Prove all of the following:

1. `(make-tkeymsg #\s '(ctrl) #f)` returns exactly `"save"`.
2. Plain printable `s` returns `"s"`.
3. Ctrl-Shift-S and Alt-S each return `"s"`, not `"save"`.
4. A Ctrl-S-shaped message with decoded character `#\s` returns `"s"`,
   proving the required `#f` field is part of the match.
5. A representative neighboring printable key such as `#\q` retains its
   one-character result.
6. At least one existing Backspace shape still returns `"backspace"`, proving
   the new clause did not preempt that earlier normalization.
7. Repeated conversion of the exact Ctrl-S message is stable and has no
   observable state.

Do not duplicate the complete mapping matrix from
`tests/aloemacs/key-mapping.rkt`; that reviewed file must remain unchanged and
green. `tests/aloemacs/file-session.rkt` already proves that the resulting
named `"save"` command has the correct application behavior and also remains
unchanged.

## Verification and hand check

Run the focused test first:

```sh
TMPDIR=/tmp raco test tests/aloemacs/file-key-mapping.rkt
```

Run the directly affected reviewed tests unchanged:

```sh
TMPDIR=/tmp raco test tests/aloemacs/key-mapping.rkt
TMPDIR=/tmp raco test tests/aloemacs/term-capability.rkt
TMPDIR=/tmp raco test tests/aloemacs/file-session.rkt
```

Run the complete recursive suite:

```sh
TMPDIR=/tmp raco test tests
```

Then run this pure no-TTY hand exercise from the repository root:

```racket
(require (only-in tui/term/messages make-tkeymsg)
         "host/racket/term.rkt")

(map tkeymsg->aloe-key
     (list
      (make-tkeymsg #\s '(ctrl) #f)
      (make-tkeymsg #\s)
      (make-tkeymsg #\s '(ctrl shift) #f)
      (make-tkeymsg #\s '(alt) #f)
      (make-tkeymsg #\s '(ctrl) #\s)))
```

The exact result is:

```racket
'("save" "s" "s" "s" "s")
```

No physical-TTY hand check is required.

## Acceptance

- The exact plain Ctrl-S `tkeymsg` becomes the one String `"save"` before
  printable handling.
- Plain `s`, Ctrl-Shift-S, Alt-S, decoded-character Ctrl-S, and every existing
  mapping retain their stated behavior.
- `tkeymsg->aloe-key` remains pure and its public module surface is unchanged.
- The Term descriptor, receiver factory, TTY lifetime, Aloe session, editor,
  filesystem, starting value, runner, and every existing test are unchanged.
- The focused test, directly affected predecessor tests, and full recursive
  suite are green; the hand check returns the exact stated list; and
  `git diff --check` is clean.
- Stop for human review. Do not start aloemacs-file 003, main/runner
  integration, or another editor feature.

## Explicit non-goals

- changing `AloemacsSession.handle-key`, `AloemacsEditor`, Text, Fs, or any
  Aloe source
- changing `examples/aloemacs/main.aloe`, injecting `fs-host` in the runner,
  accepting command-line paths, or adding runner tests
- a new Term selector, descriptor row, receiver field, host interface,
  crossing type, reflection special case, event class, or error protocol
- a general modifier representation, configurable keymap, prefix map,
  `C-x C-s`, `C-x C-f`, `M-x`, or another control/alt binding
- raw terminal bytes, escape-sequence parsing, CSI/OSC decoding, mouse, paste,
  resize events, polling, alternate screen, PTY, or a `tui-term` change
- a minibuffer, prompt, save-as, find-file, status line, dirty bit, autosave,
  backup, lock, save-on-quit, second buffer, window, split, or dired
- changing language law, adding a global checkpoint, changing Gel, or
  implementing any later aloemacs-file slice
