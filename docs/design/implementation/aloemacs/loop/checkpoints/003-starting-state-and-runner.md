# aloemacs-loop 003 — Starting state and iterative runner

**Status.** Ready to implement.

## Goal

Complete the first running aloemacs program with the exact empty Aloe starting
binding and a thin Racket-owned iterative session loop. The runner creates one
checked driver, injects one supplied Term receiver, loads the Aloe main file,
writes one complete frame, reads one key, rebinds the immutable editor, and
stops immediately when that transition requests quit.

This checkpoint implements the remaining aloemacs-loop specification. Stop
when it is green. Do not add another application feature, move editor policy
into Racket, or begin files, buffers, windows, or prefix keymaps.

The implementer receives only this document. Every rule needed for this slice
is below.

## Depends on, authority, and identity

- Identity is `(aloemacs-loop, 003)`, spoken **aloemacs-loop 003**. This is a
  local project checkpoint, not a global Aloe checkpoint. Do not edit
  `CHECKPOINTS.md` or add a document under `docs/checkpoints/`.
- [`../../../../../../SPEC.md`](../../../../../../SPEC.md), especially
  evaluation as send, `define`, `load`, immutable classes, and section 14's
  typed host boundary, is language law. The head of a list is the receiver and
  its second element is the literal selector. A function object runs only
  through `(f call ...)`.
- [`../spec.md`](../spec.md), especially sections 1.1, 2, 7, 8.5, 9, and 10,
  is the local design authority. This checkpoint implements the exact
  starting state and iterative runner.
- **aloemacs-loop 000–002** are implemented and reviewed. Preserve the
  immutable editor transitions, pure frame bytes, exact key normalization,
  focused tests, and every established invariant.
- **aloemacs-text 000–003** and **aloemacs-term 000** remain reviewed
  predecessors. The runner composes the existing checked driver and existing
  five-row Term receiver without extending either.

Do not add a special form, language feature, host method, crossing type,
ambient capability, direct evaluator path, or second runtime environment.

## Starting point

The implemented application surface currently consists of:

- `examples/aloemacs/editor.aloe`, which source-relatively loads Text and
  defines all editor transitions plus pure frame construction;
- `host/racket/term.rkt`, whose five-row Term interface supplies `read-key`,
  `write-line`, `write`, `columns`, and `rows`; and
- focused no-TTY tests for Text, Term, editor keys, frames, and key mapping.

There is no `examples/aloemacs/main.aloe`,
`host/racket/aloemacs-run.rkt`, or `tests/aloemacs/runner.rkt`.

Top-level Aloe `define` may rebind an existing name in a driver's runtime and
type environments. Rebinding `aloemacs-editor` to another
`AloemacsEditor` is the runner's session bookkeeping; it is not mutation of
the old editor, its Text, or its Position.

## Exact file scope

### May edit

- `examples/aloemacs/main.aloe` (new)
- `host/racket/aloemacs-run.rkt` (new)
- `tests/aloemacs/runner.rkt` (new)

### Must not edit

- `SPEC.md`, `CHECKPOINTS.md`, any global checkpoint document, or any file
  under `docs/editor/`
- `examples/aloemacs/editor.aloe`, any other example, or any file under
  `lib/`, `aloe/`, `gel/`, or `bin/`
- `host/racket/term.rkt`, `host/racket/gel-run.rkt`,
  `host/racket/term-run.rkt`, another host module, package metadata, or
  `tui-term`
- any existing test, including every prior `tests/aloemacs/` file
- the aloemacs maps, charters, specifications, or earlier checkpoint
  documents
- any file not listed under **May edit**

If another file appears necessary, stop and send the checkpoint back for
correction rather than widening the slice.

## Exact Aloe main file

Create `examples/aloemacs/main.aloe` with exactly these two top-level forms:

```aloe
(load "editor.aloe")

(define aloemacs-editor
  (AloemacsEditor new
    (Text from-string "")
    (Position new 0 0)
    #f))
```

The load is relative to `main.aloe`. The one application binding has:

- empty exact Text source `""`;
- point line 0, column 0;
- `quit = #f`; and
- checked type `AloemacsEditor`.

Do not add a scratch banner, path, dirty state, Term reference, application
class, `main` function, recursive loop, frame call, key read, output send, or
another top-level binding.

Loading `main.aloe` into one ordinary checked driver brings in the editor and
Text dependencies only in that driver. It does not require or inject Term and
does not produce output because both forms evaluate to `void`.

## Runner module surface

Create `host/racket/aloemacs-run.rkt`. It provides exactly:

```racket
run-aloemacs
run-aloemacs-with-term
```

Use `define-runtime-path` for:

```text
../../examples/aloemacs/main.aloe
```

Require only `racket/runtime-path`, the needed public procedures from
`aloe/driver.rkt`, and the existing local `term.rkt`. The required driver
procedures are:

- `make-driver`;
- `driver-inject-host!`;
- `driver-load-file!`; and
- `driver-eval!`.

Do not require `aloe/eval.rkt`, `aloe/env.rkt`, `aloe/parse.rkt`,
`aloe/type.rkt`, or another implementation module. Do not call
`env-define!`, `eval-expr`, `parse-datum`, `read-program`,
`make-top-level-env`, or any evaluator/checker internal directly.

## Checked setup

`run-aloemacs-with-term` accepts exactly one supplied validated Term receiver.
It performs this setup once and in this order:

1. construct one driver with `make-driver`;
2. inject the supplied receiver under the exact name `term` using
   `driver-inject-host!`; and
3. load `examples/aloemacs/main.aloe` with `driver-load-file!`.

There is no second driver, runtime environment, checker environment, Term
receiver, or editor construction in Racket. Injection happens before loading,
even though the main file itself does not send to Term.

Let normal driver and host-boundary failures propagate from
`run-aloemacs-with-term`; do not catch, translate, retry, or downgrade them
inside this testable function.

## Iterative session

After setup, `run-aloemacs-with-term` uses an ordinary Racket named `let` loop.
It does not recurse in Aloe.

Each iteration evaluates these three Aloe datums through `driver-eval!`, in
this exact order:

```aloe
(term write
  (aloemacs-editor frame (term columns) (term rows)))

(define aloemacs-editor
  (aloemacs-editor handle-key (term read-key)))

(aloemacs-editor quit)
```

The first expression:

- queries `columns` exactly once;
- queries `rows` exactly once;
- passes those checked `Int` results to the Aloe `frame` method;
- sends the one complete returned frame String to `term write` exactly once;
- relies on Term's existing flush; and
- never sends `write-line`.

The second expression:

- reads exactly one checked key String;
- sends that String to the current editor's Aloe `handle-key`; and
- rebinds the driver name `aloemacs-editor` to the returned immutable editor.

The third expression reads the new editor's quit field. If it is `#t`, return
from the Racket loop immediately. If it is `#f`, perform the next iteration.

The initial editor is known to be non-quit. A transition to quit ends without
drawing a second frame after that key. Do not add a pre-read, post-quit redraw,
key echo, sleep, polling step, frame delimiter, cleanup write, or final
newline.

The Racket return value of `run-aloemacs-with-term` is not application data
and is not part of the Aloe surface; tests do not depend on it. The observable
contract is the ordered Term interaction and completion described here.

## Thin-skin boundary

The runner contains no:

- key name or key dispatch table;
- `Text`, `Position`, `Span`, `EditResult`, or `AloemacsEditor`
  construction;
- edit, delete, movement, quit, viewport, clipping, row, cursor, or ANSI
  calculation;
- ANSI escape literal;
- `write-line` send;
- reflection, `Mirror`, dynamic selector, or evaluator bypass; or
- mutable application state separate from the driver's top-level binding.

The loop may use ordinary Racket control flow only to repeat the three checked
Aloe evaluations. Every application decision remains in `editor.aloe`.

## Production entry point

`run-aloemacs` takes no arguments. It calls
`call-with-tty-term-receiver` and passes the supplied receiver directly to
`run-aloemacs-with-term`.

The module's `main` submodule calls `run-aloemacs` for:

```sh
racket host/racket/aloemacs-run.rkt
```

It may match `gel-run.rkt`'s ordinary `exn:fail?` handling, using the
diagnostic prefix `aloemacs`, CRLF, and exit status 1. Breaks must not be
converted to ordinary failures. The main submodule adds no arguments, usage
mode, alternate receiver, or editor policy.

No automated test invokes `run-aloemacs`, its main submodule, or a physical
TTY. Production lifetime and cooked-mode restoration remain owned by the
reviewed `call-with-tty-term-receiver`.

## Exact no-TTY frames

The runner tests use 8 columns by 4 rows. The initial empty editor frame is:

```racket
(define empty-frame
  "\u001b[?25l\u001b[2J\u001b[H\r\n\r\n\r\n\u001b[1;1H\u001b[?25h")
```

After the key `"x"`, the editor contains text `"x"` at point `(0, 1)`, so its
next frame is:

```racket
(define x-frame
  "\u001b[?25l\u001b[2J\u001b[Hx\r\n\r\n\r\n\u001b[1;2H\u001b[?25h")
```

These expected Strings are test data only. Neither literal appears in the
runner source.

## Required tests

Add `tests/aloemacs/runner.rkt`. It requires the public checked driver, Term
receiver factory, and new runner module. It opens no physical TTY.

Cover all of the following:

1. `main.aloe` contains exactly the two source datums in **Exact Aloe main
   file**. It has no Term send, runner, extra binding, or initial content.
2. A fresh driver has no `AloemacsEditor`, `Text`, or `aloemacs-editor`.
   Loading `main.aloe` without injecting Term succeeds with no load output,
   binds those names only in that driver, gives `aloemacs-editor` checked type
   `AloemacsEditor`, and exposes exact empty text, `(0, 0)` point, and false
   quit. A second fresh driver remains unaffected.
3. The runner module exports procedures named `run-aloemacs` and
   `run-aloemacs-with-term` with arities zero and one respectively.
4. Build a no-TTY Term receiver with:
   - an output string port;
   - a tracked key reader whose only key is `"escape"`; and
   - a tracked size reader that returns `(values 8 4)`.

   Calling `run-aloemacs-with-term` on it:
   - returns without exhausting the key script;
   - reads exactly one key;
   - calls the size reader exactly twice, once for `columns` and once for
     `rows`;
   - writes exactly `empty-frame`;
   - performs exactly one frame write; and
   - does not append CRLF, echo the key, or draw after quit.
5. A second scripted run with keys `"x"` then `"escape"` proves iteration and
   rebinding. It reads exactly two keys, calls the size reader exactly four
   times, and writes exactly `empty-frame` followed immediately by `x-frame`.
   There is no third frame after the quit transition.
6. Use a tracked output port or another exact observation to prove one
   flushing `write` per rendered frame. Do not change Term or duplicate its
   implementation; the runner merely sends `term write`.
7. Inspect the runner source closely enough to prove it uses
   `make-driver`, `driver-inject-host!`, `driver-load-file!`, `driver-eval!`,
   and `call-with-tty-term-receiver`; does not use evaluator/checker
   internals; contains no `write-line`, ANSI literal, editor constructor,
   Text operation, key-name table, or extra policy; and leaves both existing
   runner files unchanged.
8. Every earlier aloemacs Text, Term, editor, frame, and key-mapping test
   remains green.

Test counters and scripted input are Racket test-fixture state, not
application state. Production editor state remains the one immutable Aloe
binding.

## Verification and hand check

Run the focused runner suite first:

```sh
TMPDIR=/tmp raco test tests/aloemacs/runner.rkt
```

Then run the complete local aloemacs suites:

```sh
TMPDIR=/tmp raco test tests/aloemacs
```

Run the recursive suite; `tests/*.rkt` is not an acceptable substitute
because it skips nested aloemacs and editor tests:

```sh
TMPDIR=/tmp raco test tests
```

Run this checked no-TTY hand exercise from the repository root:

```racket
(require "host/racket/aloemacs-run.rkt"
         "host/racket/term.rkt")

(define output (open-output-string))
(define key-calls 0)
(define size-calls 0)

(define term
  (make-term-receiver
   output
   (lambda ()
     (set! key-calls (add1 key-calls))
     "escape")
   (lambda ()
     (set! size-calls (add1 size-calls))
     (values 8 4))))

(run-aloemacs-with-term term)

(list
 (equal?
  (get-output-string output)
  "\u001b[?25l\u001b[2J\u001b[H\r\n\r\n\r\n\u001b[1;1H\u001b[?25h")
 key-calls
 size-calls)
```

The result is:

```racket
'(#t 1 2)
```

No physical-TTY hand check is required.

## Acceptance

This checkpoint is complete only when:

1. `main.aloe` has exactly the source-relative editor load and empty immutable
   starting binding specified here.
2. `run-aloemacs-with-term` performs one checked setup and only the exact
   frame/write, read/transition/rebind, and quit-check sequence in an
   iterative Racket loop.
3. Each visible iteration queries both dimensions afresh, writes and flushes
   one complete Aloe-built frame, reads one key, and stops without redrawing
   after a quit transition.
4. `run-aloemacs` supplies the production receiver through the existing
   `call-with-tty-term-receiver`, and the module provides exactly the two
   specified entry procedures.
5. The runner contains no editor, frame, ANSI, keymap, or language policy and
   uses no evaluator/checker internals or second environment.
6. The immediate-quit and edit-then-quit no-TTY runs have the exact outputs
   and call counts specified here.
7. The focused runner, complete local, and full recursive suites are green,
   and the hand check returns the exact stated result.
8. No file, buffer, window, prefix map, search, live evaluation, language
   feature, host-interface change, or other out-of-scope behavior has been
   added.

After implementation and human review, aloemacs-loop 000–003 satisfy the
complete loop specification. Do not issue aloemacs-loop 004.

## Explicit non-goals

- files, paths, visiting, loading buffer contents, saving, dirty state,
  encodings, CRLF file conversion, final-newline policy, or filesystem
  authority
- multiple buffers, windows, splits, scratch banner, status line, mode line,
  viewport persistence, resize events, polling, or alternate-screen policy
- prefix keys, configurable keymaps, `C-x`, `M-x`, minibuffer, search,
  replace, undo, marks, selection, kill ring, indentation, syntax, or modes
- mouse, paste, PTY, subprocesses, terminal emulation, Unicode display width,
  graphemes, combining characters, tabs-as-columns, or wrapping
- `Mirror`, eval of buffer text, live eval, hot reload, or a Legmacs/Chez
  Emacs source port
- changes to Text, Term, editor transitions, frame rendering, key mapping,
  Gel, either existing runner, the checked driver, or Aloe language law
