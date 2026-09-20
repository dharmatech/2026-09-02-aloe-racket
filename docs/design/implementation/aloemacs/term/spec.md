# aloemacs Term specification

**Status.** Design for the local **aloemacs-term** project. This is not
Aloe language law, a checkpoint, or an implementation assignment. A later
checkpoint-manager conversation will slice `aloemacs-term 000`, `001`, …
under `checkpoints/`. The authority for typed host capabilities and crossing
values remains [`SPEC.md`](../../../../../SPEC.md), especially section 14.

This project extends the existing optional, injected `Term` receiver with the
small surface a later full-screen Aloe program needs: write one complete frame
without an appended newline, and query the current terminal dimensions. It
does not define that program or its loop.

## 1. Scope and invariants

`Term` remains one descriptor-defined host capability. It is installed only
by explicit driver injection and is absent from default environments. This
project adds no special form, ambient binding, kernel printing operation, or
second evaluation path.

The complete ordered `Term` interface after this project is:

| Order | Send | Type | Effect and result |
|---:|---|---|---|
| 1 | `(term read-key)` | `() -> String` | Return the next key string; mouse and resize events remain ignored. |
| 2 | `(term write-line s)` | `(String) -> String` | Display `s`, display `"\r\n"`, flush, and return `s`. |
| 3 | `(term write s)` | `(String) -> String` | Display exactly `s`, append nothing, flush, and return `s`. |
| 4 | `(term columns)` | `() -> Int` | Return the current positive terminal column count. |
| 5 | `(term rows)` | `() -> Int` | Return the current positive terminal row count. |

The first two rows and their behavior are unchanged. The three new rows are
appended so the existing descriptor order remains a stable prefix. The same
ordered descriptor remains the single source of checking, runtime dispatch,
and descriptor-derived reflection.

Only existing crossing types are used. This project does not add `(List Int)`,
a host `Size`, `Void`, a delimiter-encoded `String`, or any other crossing
type, and it does not change `SPEC.md`.

### 1.1 Project boundary

- The production implementation and in-memory receiver factory remain in
  [`host/racket/term.rkt`](../../../../../host/racket/term.rkt).
- New behavior tests live in `tests/aloemacs/term-capability.rkt` and use a
  checked driver, `make-term-receiver`, a string output port, and injected
  thunks. They never require a TTY. This name does not reuse the aloemacs Text
  test numbers `000` through `003`.
- Existing `tests/checkpoint-53.rkt`, `tests/checkpoint-84.rkt`, and
  `tests/checkpoint-87.rkt` assertions about the exact production `Term`
  descriptor length or selector list may be updated only to reflect the three
  appended methods. Existing assertions about the original two rows retain
  their meaning. No other historical test should need semantic revision.
- [`docs/gel.md`](../../../../gel.md) section 6 and the Term decision in
  [`docs/decisions.md`](../../../../decisions.md) are updated in this local
  series so their factual method catalog is not stale. They must also say that
  Gel continues to use only `read-key` and `write-line`.
- `host/racket/term-run.rkt` and `host/racket/gel-run.rkt` require no change:
  both already inject the receiver made by `call-with-tty-term-receiver`.
- Nothing in this project belongs in `examples/aloemacs/`, `lib/`,
  `docs/editor/`, `docs/checkpoints/`, `CHECKPOINTS.md`, or an `aloe/` kernel
  module.

## 2. Frame write

`(term write s)` is the no-newline frame primitive. Its byte/character content
is exactly what Racket `display` of the crossed `String` writes to the Term
output port. It does not append LF, CR, CRLF, a separator, padding, or terminal
control data. It calls `flush-output` after displaying `s` and returns that
same `String` through the guarded host boundary.

A later full-screen loop constructs one frame, including any ANSI sequences,
as one Aloe `String` and sends `write` once. Thus one frame produces one flush;
there is no separate `flush` selector. `(term write "")` follows the same
contract—it writes no content, flushes, and returns `""`—but it is not a
second framing protocol.

`write-line` is not implemented in terms of a changed meaning for `write` if
doing so would alter its observable contract. It continues to display its
argument, append exactly `"\r\n"`, flush, and return the argument. In
particular, Gel output and the existing checkpoint-98 Term case remain
unchanged.

ANSI clear, cursor-address, cursor-visibility, and alternate-screen sequences
are ordinary content passed to `write`. Their construction and policy are not
part of this layer.

## 3. Terminal size

Terminal size crosses the host boundary as two scalar queries:

```aloe
(term columns) ; Int
(term rows)    ; Int
```

Both results are exact positive integers. `columns` means terminal width in
cells and `rows` means terminal height in cells as reported by the host. This
layer does not define text width, character width, layout, or a source-written
`Size` class.

Each send queries the size source at the time of that send and selects one
component from the resulting `(columns, rows)` pair. The two sends do not
promise an atomic snapshot across a resize. A later loop may send both once
per frame and compose an Aloe value if it needs one.

### 3.1 Receiver size source

`term-state` grows from output plus key reader to output, key reader, and a
size-reader thunk. The receiver factory has this compatible shape:

```racket
(make-term-receiver [output (current-output-port)]
                    [reader read-next-key]
                    [size-reader default-size-reader])
```

Existing calls with zero, one, or two positional arguments keep their current
meaning. A size reader takes no arguments and returns two Racket values in
this order: columns, then rows. The factory's `default-size-reader` returns
`80` and `24`; therefore an in-memory receiver with no injected size source
has the documented size **80 columns by 24 rows**.

Before either component crosses into Aloe, the receiver obtains and normalizes
the whole pair. If the size reader raises an ordinary `exn:fail?`, produces
the wrong number of values, produces a non-exact-integer component, or
produces a component less than or equal to zero, the normalized pair is
`80` and `24`. A failure or invalidity in either component replaces the whole
pair; a mixed reported/fallback size is not returned. Breaks are not caught.
Consequently neither size selector can return zero or a negative integer, and
ordinary size discovery failure does not escape as an Aloe host failure.

Tests may inject a size reader directly. The required non-default fixture
returns **132 columns and 43 rows** so a test proves both component order and
the thunk wiring rather than merely observing the default.

### 3.2 Physical TTY source

`call-with-tty-term-receiver` continues to own the `tui-term` lifetime through
`with-term (make-tty-term)`. Inside that dynamic extent it constructs the
receiver with:

- the current `tui-term` output port;
- the existing `read-next-key` thunk; and
- `tui-term`'s existing `current-term-size` procedure as the size reader.

`current-term-size` returns width then height from the current `tterm`; its
resize handler updates that state. The normalization in section 3.1 supplies
the same `80` by `24` fallback if that query fails or reports an invalid
dimension. No ioctl, C FFI, package addition, `tui-term` change, or separate
resize-event channel is introduced.

`read-next-key` continues to discard `tsizemsg` values while waiting for a
key. Size is observed only through `columns` and `rows`; resize does not become
a key `String` or a new `read-key` result variant.

## 4. Required tests

The first consumer is the focused Racket test
`tests/aloemacs/term-capability.rkt`, which injects `Term` into an ordinary
checked driver. It uses no physical TTY, `with-term`,
`call-with-tty-term-receiver`, or alternate terminal package.

The following are normative:

### 4.1 Descriptor and types

- The exact selector order is
  `(read-key write-line write columns rows)`.
- Their parameter lists are `(() (String) (String) () ())`.
- Their return types are `(String String String Int Int)`.
- Through the checker, `write` and `write-line` have result type `String`, and
  `columns` and `rows` have result type `Int`.
- Default drivers still have no `term` runtime or type binding.

### 4.2 Output and flush

With one string output port and one receiver:

```aloe
(term write "ab") ; => "ab"
(term write "c")  ; => "c"
```

The port then contains exactly `"abc"`, not `"ab\r\nc"` or any other
suffix. On a fresh port:

```aloe
(term write-line "sealed") ; => "sealed"
```

the port contains exactly `"sealed\r\n"`.

A tracked output port also proves that `write` flushes after its display. The
existing flush assertion for `write-line` remains green. No test treats a call
to `write-line ""` as the frame flush.

### 4.3 Size double and fallback

- A default `make-term-receiver` reports `(term columns) => 80` and
  `(term rows) => 24`.
- A receiver whose size reader returns `(values 132 43)` reports
  `columns => 132` and `rows => 43` through Aloe sends.
- At least one invalid pair, including a zero or negative component, reports
  the whole fallback `80` by `24`.
- An ordinary size-reader failure also reports `80` by `24` rather than
  surfacing a host exception.

These tests exercise the double and normalization; they do not simulate an
OS terminal resize or inspect a real terminal.

### 4.4 Input compatibility

An injected key thunk supplies a named `String` such as `"left"`, and
`(term read-key)` returns that exact string. Output and size sends do not call
the key thunk. Existing key mapping tests and the rule that mouse and resize
messages are ignored remain unchanged.

### 4.5 Regression

The existing Gel tests, checkpoint-98 Term case, descriptor/reflection tests
adjusted for the appended rows, and the full non-aloemacs test suite remain
green. New tests must not depend on their execution order.

## 5. Documentation contract

The implementation series updates the factual Term catalog in two places:

1. `docs/gel.md` section 6 lists all five descriptor methods and says Gel still
   sends only `read-key` and `write-line`.
2. `docs/decisions.md` records `write : (String) -> String`, its exact-write
   and flush behavior, and the positive `columns`/`rows : () -> Int` queries
   with the `80` by `24` fallback.

Those edits describe the existing optional capability; they do not turn this
local project into Gel work or Aloe language law. `SPEC.md` and
`docs/philosophy.md` remain unchanged.

## 6. Acceptance

The design is implemented when all of the following are true:

1. The ordered `Term` descriptor has exactly the five methods and types in
   section 1, still backed by one checked host interface.
2. `write` displays exactly its `String`, appends nothing, flushes once per
   call, and returns the `String`; `write-line` retains its exact CRLF, flush,
   and return contract.
3. `columns` and `rows` return positive `Int` values from an injectable size
   source, with the exact default and failure behavior in section 3.
4. The production TTY path reads size through `current-term-size` inside the
   existing `with-term` lifetime, with no new dependency or native layer.
5. `read-key`, its key thunk, and its treatment of mouse and resize messages
   are unchanged.
6. The no-TTY tests in section 4 pass, both documentation catalogs are
   current, and the existing suite remains green.
7. No crossing type, kernel operation, runner protocol, or Aloe `Size` class
   has been added.

## 7. Explicit non-goals

- An editor, event loop, `handle-key`, keymap, buffer, `Text`, paint function,
  frame builder, mode line, or runnable `examples/aloemacs/` program
- A `flush` selector or using `write-line ""` as a flush convention
- An Aloe `Size` class or library, `(List Int)`, a size `String`, or any
  crossing-vocabulary change
- Resize events in `read-key`, `SIGWINCH` as an Aloe value, event variants,
  polling, or `key-pending?`
- Alternate-screen, cursor, clear, raw/cooked, or mouse operations as host
  methods; ANSI remains string data and the runner retains terminal lifetime
- Mouse input, bracketed paste, CSI/OSC decoding, PTYs, subprocesses, or a VT
  emulator
- Unicode display width, grapheme clusters, tabs, wrapping, or layout policy
- Changing `tui-term`, adding a Racket package, writing an ioctl, or opening a
  C FFI project
- Changing Gel behavior, Gel menus, `Mirror`, `Signature`, or reflection
  beyond the rows already derived from the enlarged descriptor
- Loading `lib/text.aloe`, changing aloemacs Text work, global checkpoint
  numbers, or edits to `CHECKPOINTS.md`
