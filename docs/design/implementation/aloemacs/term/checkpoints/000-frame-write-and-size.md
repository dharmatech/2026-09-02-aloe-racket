# aloemacs-term 000 — Frame write and terminal size

**Status.** Ready to implement.

## Goal

Complete the aloemacs Term layer by extending the existing optional injected
`Term` receiver with an exact, flushing, no-newline `write` message and the
positive `columns` and `rows` queries. Keep `read-key` and `write-line`
compatible, wire production size discovery through the existing `tui-term`
lifetime, and prove the whole five-row interface through a checked no-TTY
driver.

This one vertical slice completes the aloemacs Term specification. Stop when
it is green. Do not begin the editor loop, frame construction, Text
integration, files, or a runnable aloemacs program.

The implementer receives only this document. Every rule needed for the slice
is below.

## Depends on, authority, and identity

- Identity is `(aloemacs-term, 000)`, spoken **aloemacs-term 000**. This is a
  local project checkpoint, not a global Aloe checkpoint. Do not edit
  `CHECKPOINTS.md` or add a document under `docs/checkpoints/`.
- [`../../../../../../SPEC.md`](../../../../../../SPEC.md), especially section
  14, is language law. A host capability is an explicitly injected receiver;
  its one ordered descriptor drives checking, runtime dispatch, and
  reflection. Crossing remains exactly `Int`, `Bool`, `String`, and
  `(List String)`.
- [`../spec.md`](../spec.md) is the complete local design authority. This
  checkpoint implements that specification without extending it.
- Existing checked host injection, guarded crossing, and descriptor-derived
  `Mirror` behavior are predecessors. Do not add another checking, dispatch,
  reflection, or evaluation path.
- Existing Term behavior is a predecessor: `read-key : () -> String` and
  `write-line : (String) -> String`. Gel and the terminal runners already use
  the production receiver.

Evaluation is send, not apply. The head of a list is the receiver and its
second element is a literal selector. `(f x)` does not call `f`; a function
object runs only through `(f call x ...)`. Do not add a special form, ambient
binding, mutation, inheritance, macro, or implicit `Int`/`Float` coercion.

## Starting point

[`../../../../../../host/racket/term.rkt`](../../../../../../host/racket/term.rkt)
currently owns all Term production behavior and its in-memory receiver
factory. Its descriptor has the ordered prefix:

```text
read-key  : ()       -> String
write-line: (String) -> String
```

`term-state` currently holds an output port and key-reader thunk.
`make-term-receiver` accepts those as zero, one, or two positional arguments.
`call-with-tty-term-receiver` already owns a `tui-term` with
`with-term (make-tty-term)`; inside that extent, `current-term-size` is an
exported zero-argument procedure that returns two values, width then height.

`read-next-key` ignores mouse and `tsizemsg` values while waiting for a key.
That behavior does not change. The default Aloe driver has no runtime or type
binding named `term`.

## Exact file scope

### May edit

- `host/racket/term.rkt`
- `tests/aloemacs/term-capability.rkt` (new)
- `tests/checkpoint-53.rkt`, only to update the exact production Term selector
  list for the three appended rows
- `tests/checkpoint-84.rkt`, only to update the exact production Term
  descriptor expectations for the three appended rows; retain its guarded
  crossing and `write-line` tests
- `tests/checkpoint-87.rkt`, only to update the exact reflected production
  Term rows for the three appended rows; retain all original two-row behavior
  and unrelated reflection coverage
- `docs/gel.md`, only the factual Term method catalog and the statement of
  which methods Gel uses
- `docs/decisions.md`, only the existing Term decision needed to record the
  enlarged interface and its contracts

The historical test edits repair fixtures whose exact descriptor length or
rows are intentionally changed. Do not weaken unrelated assertions.

### Must not edit

- `SPEC.md`, `CHECKPOINTS.md`, or any global checkpoint document
- any file under `aloe/`, `lib/`, `examples/aloemacs/`, `docs/editor/`, or
  `docs/checkpoints/`
- `host/racket/term-run.rkt`, `host/racket/gel-run.rkt`, `tui-term`, package
  metadata, or another host module
- `tests/checkpoint-98.rkt` or any test not listed under **May edit**
- the aloemacs maps, charter, specification, text files, or earlier local
  checkpoint documents
- any file not listed under **May edit**

If another file appears necessary, stop and send the checkpoint back for
correction rather than widening the slice.

## The complete Term descriptor

Append exactly three methods to the existing descriptor. Its complete source
order, parameter lists, and return types become:

| Order | Selector | Parameters | Return |
|---:|---|---|---|
| 1 | `read-key` | `()` | `String` |
| 2 | `write-line` | `(String)` | `String` |
| 3 | `write` | `(String)` | `String` |
| 4 | `columns` | `()` | `Int` |
| 5 | `rows` | `()` | `Int` |

Keep this one descriptor as the source for guarded runtime sends, checker
typing after injection, and `Mirror`. Do not add a synthetic checker facade,
host-specific reflection code, a second receiver, or a source-written `Term`
type.

`read-key` and `write-line` remain the first two rows in their existing order
and retain their current implementations and contracts. The appended order is
observable and exact.

## Exact frame write

Implement:

```text
(term write string) : String
```

For each successful call, in this order:

1. display the crossed String to the receiver's output port;
2. append nothing;
3. flush that port once; and
4. return the same String value through the guarded host boundary.

The bytes/characters written are exactly what Racket `display` writes for the
String. Do not append LF, CR, CRLF, a delimiter, padding, terminal control
data, or an implicit frame marker. `(term write "")` follows the same rule:
it writes no content, flushes, and returns `""`.

Do not add a `flush` selector and do not use `(term write-line "")` as a flush
protocol. `write-line` continues to display its String, append exactly
`"\r\n"`, flush, and return its String. Do not implement either method by
changing the other's observable behavior.

ANSI sequences are ordinary String content. This layer neither constructs
them nor adds terminal-control selectors.

## Size source and normalization

Grow the receiver state to output port, key-reader thunk, and size-reader
thunk. Preserve the factory's positional compatibility exactly:

```racket
(make-term-receiver [output (current-output-port)]
                    [reader read-next-key]
                    [size-reader default-size-reader])
```

Existing calls with zero, one, or two arguments keep their meanings. A size
reader accepts no arguments and returns two Racket values in this order:
columns, then rows. The default size reader returns `(values 80 24)`. No new
export is required for that default helper.

Both `(term columns)` and `(term rows)` invoke the receiver's size-reader at
the time of that send. Each invocation obtains and normalizes the whole pair,
then selects its requested component. The two separate sends do not promise
an atomic snapshot across a resize and must not cache a size.

A pair is valid only when both components are exact integers greater than
zero. Normalize the whole pair to `(values 80 24)` if any of these occurs:

- the size reader raises an ordinary `exn:fail?`;
- it returns other than exactly two values;
- either value is not an exact integer; or
- either value is zero or negative.

One bad component replaces both components. Never return a mixed
reported/fallback pair. Catch only ordinary failures needed by this contract;
breaks must pass through unchanged. The descriptor's guarded `Int` result
boundary remains in force after normalization.

The size queries do not read a key or write output. `write` and `write-line`
do not call the key thunk or size thunk. `read-key` continues to call only the
key thunk.

## Production TTY wiring

Keep `call-with-tty-term-receiver` inside its existing
`with-term (make-tty-term)` dynamic extent. Within that extent, construct the
receiver with all three production dependencies:

- the current `tui-term` output port;
- the existing `read-next-key` thunk; and
- `current-term-size` as the size-reader thunk.

`current-term-size` returns width then height from the live current `tterm`;
the existing `tui-term` resize handling updates that state. Apply the same
receiver normalization before either value crosses into Aloe.

Do not add an ioctl, FFI, signal handler, package, polling loop, or resize
event channel. `read-next-key` continues to discard `tsizemsg` values; resize
does not become a key String or result variant. The two existing runner files
need no change because both already call `call-with-tty-term-receiver`.

## Focused no-TTY tests

Add `tests/aloemacs/term-capability.rkt`. Exercise all production behavior
through `make-term-receiver`, an ordinary checked driver, string/custom output
ports, and injected thunks. Do not open a physical TTY, invoke `with-term`, or
call `call-with-tty-term-receiver` in this suite.

Cover all of the following:

1. The descriptor has exactly the five selectors, parameter lists, and return
   types in the table above, in that order.
2. After injection, checker results are `String` for `write` and `write-line`
   and `Int` for `columns` and `rows`. A fresh default driver still has no
   `term` runtime or type binding.
3. On one receiver and output string port, `(term write "ab")` returns
   `"ab"`, `(term write "c")` returns `"c"`, and the port contains exactly
   `"abc"`.
4. On a fresh port, `(term write-line "sealed")` returns `"sealed"` and the
   port contains exactly `"sealed\r\n"`.
5. A tracked output port proves that `write` flushes after display, including
   for an empty String. Preserve the existing `write-line` flush proof.
6. A receiver using the default size source reports `columns = 80` and
   `rows = 24` through checked Aloe sends.
7. An injected `(lambda () (values 132 43))` reports `columns = 132` and
   `rows = 43`. Track calls closely enough to prove that each selector queries
   the source once at the time of its send and that the component order is not
   reversed.
8. Separate bad fixtures cover a wrong value count, a non-exact-integer
   component, a zero or negative component, and an ordinary raised
   `exn:fail?`. Each reports the whole `80` by `24` fallback through checked
   sends; no ordinary discovery failure escapes as a host failure.
9. An injected key thunk returns the exact named String `"left"`. Track key
   calls to prove that output and size sends do not call it, while `read-key`
   still does. Also prove size queries do not write output.
10. Existing zero-, one-, and two-argument `make-term-receiver` call sites
    remain valid; do not rewrite unrelated tests merely to supply a size
    thunk.

Do not make tests depend on execution order or simulate an OS resize. The
focused suite is the first consumer; there is no aloemacs program in this
checkpoint.

## Historical fixtures and documentation

Make only these compatibility updates:

- `tests/checkpoint-53.rkt`: the production receiver selector list is now
  `(read-key write-line write columns rows)`.
- `tests/checkpoint-84.rkt`: the production declaration has those selectors,
  parameter lists `(() (String) (String) () ())`, and return types
  `(String String String Int Int)`. Its guarded crossing and exact
  `write-line` CRLF/flush assertions retain their meaning.
- `tests/checkpoint-87.rkt`: descriptor-derived messages and signatures expose
  all five rows in that exact order, with the exact parameter and return
  types. Reflection itself causes no key, output, or size effect. Preserve
  reflected invocation coverage for the original rows.

Do not revise checkpoint 98: its existing `write-line` case must pass
unchanged.

Update the two factual catalogs:

- `docs/gel.md` section 6 lists all five Term methods and explicitly says Gel
  still sends only `read-key` and `write-line`.
- `docs/decisions.md` records `write : (String) -> String`, exact no-newline
  display plus flush, and positive `columns` / `rows : () -> Int` with whole
  pair fallback `80` by `24`. Keep Term optional and injected.

These are catalog updates, not language-law or Gel behavior changes.

## Verification and hand check

Run the focused and directly affected suites first:

```sh
raco test tests/aloemacs/term-capability.rkt
raco test tests/checkpoint-53.rkt tests/checkpoint-84.rkt tests/checkpoint-87.rkt
raco test tests/checkpoint-98.rkt
```

Then run the recursive suite; `tests/*.rkt` is not an acceptable substitute
because it skips nested aloemacs and editor tests:

```sh
raco test tests
```

Run one checked no-TTY expression by hand from the repository root:

```racket
(require "aloe/driver.rkt"
         "host/racket/term.rkt")

(define output (open-output-string))
(define state (make-driver))
(driver-inject-host!
 state
 'term
 (make-term-receiver
  output
  (lambda () "left")
  (lambda () (values 132 43))))

(list (driver-eval! state '(term write "frame"))
      (driver-eval! state '(term columns))
      (driver-eval! state '(term rows))
      (get-output-string output))
```

Expected:

```racket
'("frame" 132 43 "frame")
```

No physical-TTY hand check is required.

## Acceptance

The checkpoint is complete only when:

1. The single ordered Term descriptor contains exactly the five locked rows
   and drives checking, runtime dispatch, and reflection.
2. `write` displays exactly its String, appends nothing, flushes, and returns
   the String; `write-line` retains exact CRLF, flush, and return behavior.
3. `columns` and `rows` return positive checked `Int` values from a fresh
   per-send whole-pair query, with exact `80` by `24` default and failure
   fallback behavior.
4. The production TTY receiver supplies `current-term-size` inside the
   existing `with-term` lifetime without a new dependency or native layer.
5. `read-key`, key mapping, and ignored mouse/resize-event behavior remain
   unchanged, and default drivers remain free of Term authority.
6. The focused no-TTY suite, affected historical tests, checkpoint 98, Gel
   tests, and the full recursive suite are green; the hand check returns the
   expected value.
7. Both documentation catalogs are current.

## Explicit non-goals

- An editor, loop, keymap, buffer, `Text`, paint function, frame builder, mode
  line, or runnable file under `examples/aloemacs/`
- A `flush` selector or empty-`write-line` flush convention
- An Aloe `Size` class, `(List Int)`, size String, `Void`, crossing-vocabulary
  change, or `SPEC.md` edit
- Resize events in `read-key`, `SIGWINCH` values, event variants, polling, or
  `key-pending?`
- Alternate-screen, clear, cursor, raw/cooked, or mouse host messages; ANSI is
  String data and the runner continues to own terminal lifetime
- Mouse input, paste, CSI/OSC decoding, PTYs, subprocesses, Unicode display
  width, grapheme layout, wrapping, or tabs
- A `tui-term` change, new Racket package, ioctl, C FFI, runner protocol, or
  kernel printing operation
- Gel behavior, menus, or reflection machinery beyond descriptor-derived
  rows for the enlarged existing receiver

