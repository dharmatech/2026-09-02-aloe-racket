# Charter — aloemacs term

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md).

**Your job.** Turn this charter into a specification for the **Term
surface a full-screen Aloe program needs**: write a frame without a
forced newline, and read the terminal size. Then **stop**. Do not
write checkpoints. Do not implement. Do not specify the editor
loop, keymaps, Text, paint, files, or a CSI decoder.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, the parent map, and the authority in §5.
2. Record the locked decisions in §4. Resolve the open questions
   in §4.6–§4.9.
3. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-term 000**, `001`, … under
   `docs/design/implementation/aloemacs/term/checkpoints/` (not
   `docs/checkpoints/0116`, not `docs/editor/`).
4. Stop. The human reviews it. Do not write those checkpoint files.

The checkpoint manager and implementers will not have this charter.
Put every rule they need in the specification.

Keep the spec **small enough to slice**. An editor, a keymap, mouse,
paste, PTY, alternate-screen as a host method, and a rewrite of
`tui-term` are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| Production Term | [`host/racket/term.rkt`](../../../../../host/racket/term.rkt): `read-key` → `String`, `write-line` → `String` (writes the string, then `"\r\n"`, flushes, returns the string) |
| Injection | Checked driver `driver-inject-host!`; `make-term-receiver` already accepts an output port and a key thunk (the in-memory double) |
| Crossing vocabulary | `SPEC.md` §14: `Int`, `Bool`, `String`, `(List String)` only |
| Gel | Still uses `(term write-line …)` and `(term read-key)` |

aloemacs-text 000–003 are **siblings**, not predecessors. This layer
must not load `lib/text.aloe` or mention `Position` / `Span` /
`replace`. A later Loop layer composes Term with Text.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. An Aloe program with an injected Term can emit an arbitrary
   `String` **without** a host-appended newline. That is the frame
   primitive. Today's `write-line` is not that primitive.
2. The same program can read the terminal's column and row counts
   as `Int` values (or an Aloe value built only from those `Int`s).
   Host crossing stays inside `SPEC.md` §14. Do not add
   `(List Int)`, a host `Size` type, or a delimiter-encoded size
   `String`.
3. **Tests are the first consumer**, using `make-term-receiver` (or
   an equivalent double) and a string output port. They must not
   require a real TTY, `tui-term`, or `call-with-tty-term-receiver`.
   At least:
   - `write` (or the named no-newline send) of `"ab"` then `"c"`
     yields `"abc"` on the port, not `"ab\r\nc"`;
   - `write-line` still yields `"sealed\r\n"` for `"sealed"`, as
     [`tests/checkpoint-98.rkt`](../../../../../tests/checkpoint-98.rkt)
     already asserts;
   - size on the double is a documented pair of `Int`s (the spec
     names the numbers the double returns);
   - `read-key` is unchanged: the existing thunk still supplies
     the next `String`.
4. Gel remains a valid Term client. Do not remove or change
   `write-line`'s `"\r\n"` and flush behavior. Do not change
   `read-key`'s result type. Existing Gel tests and the
   checkpoint-98 Term case stay green.
5. No editor loop, no `examples/aloemacs/` program required in
   this layer, no mouse, paste, PTY, or Unicode width.

## 4. Locked decisions (record these; do not reopen 4.1–4.5)

### 4.1 Capability, not kernel

Term stays an injected host receiver. Do not add a printing special
form, an ambient `term`, or a kernel `display`. ANSI (clear, cursor
address, hide cursor, alternate screen) is an **Aloe string**, not
a new host method, unless a named test proves a byte cannot be
written through the write primitive.

### 4.2 Keep the Gel contract

| Send | Stays |
|---|---|
| `(term read-key)` | `String`; mouse and resize events remain ignored at this read |
| `(term write-line s)` | display `s`, then `"\r\n"`, flush, return `s` |

Add methods. Do not overload `write-line` into two meanings.

### 4.3 Resize is not an event yet

`term.rkt` already drops `tsizemsg`. Keep that for `read-key`.
Size is a **query** the program sends when it wants dimensions,
typically once per frame in a later loop. Do not invent a resize
key string or a variant return type for `read-key`.

### 4.4 Where code lives

- Production implementation: `host/racket/term.rkt` (and a test
  double in the same spirit as today's `make-term-receiver`)
- Tests under `tests/aloemacs/`, with names that do not reuse
  `000-string-prerequisite.rkt` … `003-text-edits.rkt`
- Runners (`term-run.rkt`, `gel-run.rkt`) change only if the spec
  proves they must; a dedicated `aloemacs-run.rkt` is the Loop
  layer
- `examples/aloemacs/` is still empty in this layer
- Do not invent `docs/checkpoints/0116-…`. If a host-interface
  change later belongs on the language spine, the human promotes
  it after review

### 4.5 Out of this layer

- Editor state, `handle-key`, paint of `Text`, keymaps
- Alternate screen, raw/cooked, cursor hide as **host** methods
- Mouse, bracketed paste, CSI/OSC decode, `key-pending?`
- PTY, subprocesses, SIGWINCH as an Aloe value
- Changing `tui-term` itself
- `Mirror` rows for the new methods beyond whatever the existing
  descriptor-derived catalog already does (do not specify a
  Mirror project)
- Loading `lib/text.aloe`

### 4.6 Write and flush (resolve this)

Name the no-newline send and its flush rule.

Today `write-line` flushes every call. A full-screen frame wants
one large `String` then one flush.

Pick a closed set. Candidates (or a tighter variant):

1. `(term write s)` displays `s` and flushes; no separate `flush`.
2. `(term write s)` displays `s` without flush; `(term flush)`
   flushes and returns a documented value (`s`, `#t`, or `Void`
   — pick one that already exists as a crossing or method
   result).
3. `(term write s)` displays `s` without flush; the later loop
   is allowed to call `write-line` of `""` to flush — **reject
   this** unless you can show it does not emit an extra line.

State the return type. `write-line` returns the `String`; match
that unless there is a smaller choice.

### 4.7 Size shape (resolve this)

The program needs two `Int`s: columns and rows. Crossing law
forbids returning `(List Int)` from the host.

Pick one:

1. Two methods, e.g. `(term columns)` and `(term rows)`, each
   `() -> Int`.
2. One Aloe `Size` class **not** produced by the host: two host
   `Int` methods plus `(Size new columns rows)` in Aloe. If you
   choose this, say whether `Size` lives in `lib/` or only in a
   later loop file — this layer should not grow a library nobody
   sends.

Do not return a `String`. Do not extend §14.

Document what the in-memory double returns when no TTY exists
(fixed 80×24 is acceptable if named). Document what the
production receiver does on a real TTY (and if `term/size` is
unavailable, the same fallback, not a host exception into Aloe
unless you specify that failure).

Fallback `80` and `24` must be positive; a zero or negative size
is not a legal result.

### 4.8 Production size source (resolve this)

`term-state` today is output port plus key reader. Size has to
come from somewhere.

- Prefer a size thunk on `make-term-receiver` so tests inject
  numbers without ioctl.
- Production `call-with-tty-term-receiver` may read size from
  `tui-term` if it already exposes it, or from a small Racket
  ioctl in `term.rkt`. Do not add a new Racket package.
- Name the exact files. Do not open a C FFI project.

### 4.9 Documentation of the capability (resolve this)

Gel's host-boundary notes (`docs/gel.md` §6, `docs/decisions.md`
Term paragraph) describe two methods. This layer adds methods to
the same interface.

Say whether those two documents are updated in this series (a
factual list of Term methods) or left until promotion. `SPEC.md`
§14 changes **only** if you add a crossing type — which §4.7
forbids. Do not rewrite Gel's object model.

## 5. Authority

- [`../README.md`](../README.md) — locks, paths, non-goals
- `SPEC.md` §14 — typed host capabilities and crossing vocabulary
- `docs/philosophy.md` — keep the host small; ANSI as data
- `docs/decisions.md` — Term is injected; `write-line` contract
- `docs/gel.md` §6 — current Term methods; mouse/resize ignored
- [`host/racket/term.rkt`](../../../../../host/racket/term.rkt)
- [`tests/checkpoint-98.rkt`](../../../../../tests/checkpoint-98.rkt)
  “Term remains scalar-only and optional”
- Legmacs `term/write`, `term/size`, `term/flush` and Chez Emacs
  `sys` — seam catalogs, not law

`SPEC.md` remains Aloe language law. This spec is not language
law. It may extend the production Term **interface descriptor**
the way filesystem extended Fs, without becoming a kernel
feature.

## 6. Non-goals

- A runnable editor or `handle-key` loop
- Painting `Text`, a frame builder, or a mode line
- Key chord decoding beyond today's `read-key` strings
- Alternate screen / raw mode as Aloe-visible methods (the
  runner's `with-term` already owns cooked/raw)
- Files, Fs, load/save
- Mouse, paste, PTY, subprocesses
- Unicode cell width
- Changing Gel menus, `Mirror`, or `GelStep`
- Porting `tty.sls` or let-go `term.go`
