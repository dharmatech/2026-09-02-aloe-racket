# aloemacs-runner-check 000 — check the loop once

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Make holding Down keep up again, and make the suite fail if that
cost comes back.

The editor loop submits the same expressions through `driver-eval!`
on every key. That entry typechecks, then runs. `AloemacsSession`
is generic in its host, so one check of `handle-key` walks
`execute-command` and every command arm. The concrete host does not
change between keys, so the later checks repeat the first one.

Check a loop expression when its datum is first used. Run the
checked expression after that. Columns, rows, `handle-key`, and
`quit` keep that one preparation. Fit and frame are prepared for
the current terminal size only. A different size prepares those two
datums again before they run, and so does a return to a size
already seen. Size A, then B, then A prepares A a second time.
Steady size does not prepare them again.

On this machine, before the repair, one Down cycle at 80×24 measured
about 46 ms. About 41 ms of that was checking the key expression.
Running it was about 0.2 ms. Drawing the frame was about 5 ms. The
same cycle before the keymap commit was about 22 ms. Checking the
loop expressions once brought the cycle to about 5 ms. At about 30
repeats per second, 46 ms falls behind and 5 ms keeps up.

Do not change the keymap, the session, or the checker. Do not skip
the check. Do not cache inside `driver-eval!`.

## Why the runner is the repair

Loading the editor checks that file once. Running a send does not
check it again. A session method waits until a send sees a concrete
host, because at definition that host is still a parameter. The
first check of `handle-key` is that walk. It accepts every command
arm. Key repeat does not need the walk again.

`driver-eval!` stays check-then-run. The REPL and the tests hand it
new text. The editor loop is a fixed program. It needs a driver
procedure that checks one datum and hands back a way to run that
checked datum again. The runner uses that procedure. It still does
not call the parser, the checker, or the evaluator itself.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. It is the design
and the slice. `SPEC.md` governs Aloe sends and types. The keymap
contract stays
[`../../keymap/spec.md`](../../keymap/spec.md). The loop's observable
order stays the accepted runner: each drawn iteration queries size,
fits, writes one frame, flushes, then reads one key. Quit stops
without another frame.

- Identity is **aloemacs-runner-check 000**. No predecessor in this
  folder. This is not keymap 002, not loop 004, and not a global
  checkpoint.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Today `driver-eval!` in `aloe/driver.rkt` parses the datum,
  typechecks it, then evaluates it. Every call typechecks.
- Today `run-aloemacs-with-hosts` in
  `host/racket/aloemacs-run.rkt` calls `driver-eval!` for startup
  visit and, on every iteration, for `(term columns)`,
  `(term rows)`, `ensure-visible`, `term write` of `frame`,
  `handle-key` of `(term read-key)`, and `quit`. The fit and frame
  datums splice the queried integers in as Aloe `Int` literals.
- `tests/aloemacs/viewport-runner.rkt` requires these source phrases
  to appear **once each**, in this order: `(term columns)`,
  `(term rows)`, `aloemacs-editor ensure-visible`, `(term write`,
  `aloemacs-editor frame`, `(term read-key)`.
- `tests/aloemacs/runner.rkt` and `tests/aloemacs/file-runner.rkt`
  require `driver-eval!` in the runner source and forbid
  `eval-expr`, `parse-datum`, and the other evaluator names already
  listed there.

## Exact file scope

### May edit

- `aloe/driver.rkt` — add `driver-prepare!` and
  `current-driver-prepare-counter`, and provide them.
  `driver-eval!` stays check-then-run on every call.
- `host/racket/aloemacs-run.rkt` — prepare the stable loop datums
  once; prepare fit and frame again when the current size pair
  differs, including a return to an earlier size; run the prepared
  procedures in the existing order.
  Startup visit stays on `driver-eval!`.
- `tests/aloemacs/runner.rkt` — add `driver-prepare!` to the
  thin-skin required-name list. Leave the forbidden names and the
  behavior tests as they are.
- `tests/aloemacs/runner-check.rkt` (new) — the driver procedure,
  the partial type bindings, the prepare counts, and the Down-cycle
  timing bar. Checks at module top level so `raco test` runs them.

### Must leave untouched

- `aloe/type.rkt`, `aloe/eval.rkt`, `aloe/parse.rkt`, `aloe/env.rkt`,
  `SPEC.md`, `CHECKPOINTS.md`
- `examples/aloemacs/`, including the keymap and `execute-command`
- `host/racket/gel-run.rkt`, Term, Fs
- `tests/aloemacs/viewport-runner.rkt`,
  `tests/aloemacs/keymap-runner.rkt`,
  `tests/aloemacs/file-runner.rkt`, and every other existing test
- This folder's `README.md`, the parent aloemacs map, and this
  checkpoint
- Every file not listed under **May edit**

If another file is necessary, stop and send this checkpoint back
to the high-level discussion. Do not widen the slice.

## Required behavior

### `driver-prepare!`

```racket
(driver-prepare! state datum) -> (-> any)
```

`state` is a driver. `datum` is the same kind of value
`driver-eval!` accepts.

The call parses and typechecks `datum` immediately, against the
driver's type environment as it is now. It does not evaluate. It
does not read a key, query a size, send `write`, or call any other
host method. On a type error it raises the same `typecheck:`
failure `driver-eval!` would raise and returns no procedure. It
installs no runtime binding. Checker bindings follow the current
checker, including a type binding it already installed before a
later part of the datum failed. Do not add rollback. With `Option`
defined, `(define n (Option None))` fails and leaves `n` unbound.
`(define n (if #t (Option None) (Option None)))` fails with the
same message and leaves `n` type-bound only. A rejected class can
leave its type binding in place.

The returned procedure has arity 0. Each call evaluates that one
checked expression in the driver's **current** runtime environment
and returns the value. A later call evaluates it again. A `define`
installs its type binding at prepare time and its runtime binding
when the procedure runs. It does not typecheck again.

The procedure stays valid while every name it uses still has a type
compatible with that check, and the classes and methods the check
used are unchanged. Rebinding a name to a new value of that same
type is valid, and the run sees the new value. Rebinding a name to
a different type, or changing a class or method the check used,
invalidates the procedure. `driver-prepare!` does not detect that.
A `load` stays valid only while that file and every nested load
stay unchanged. Checking reads them, and each run reads them
again. `driver-prepare!` does not detect an edit and does not
snapshot the files. The editor runner stays inside the valid case:
`aloemacs-editor` is rebound only to another session of the same
host, and `term` stays the injected receiver. The six loop datums
do not use `load`.

`driver-eval!` still typechecks every call. The same datum twice
is checked twice. This procedure does not memoize other datums,
and nothing in `type.rkt` remembers a generic method body.

### Runner loop

Keep the exports and arities of `run-aloemacs`,
`run-aloemacs-with-term`, and `run-aloemacs-with-hosts`. Keep
startup visit on `driver-eval!`, once, before the loop. A rejected
visit still performs no size query, fit, write, or key read.

After a pathless load, or after a successful visit rebind, prepare
these four datums once:

```aloe
(term columns)

(term rows)

(define aloemacs-editor
  (aloemacs-editor handle-key (term read-key)))

(aloemacs-editor quit)
```

Then enter the Racket loop. Each iteration:

1. Run the prepared columns procedure once.
2. Run the prepared rows procedure once.
3. If this is the first iteration, or either integer differs from
   the pair used for the current fit and frame procedures, prepare
   these two datums with those integers as Aloe `Int` literals:

   ```aloe
   (define aloemacs-editor
     (aloemacs-editor ensure-visible columns rows))

   (term write
     (aloemacs-editor frame columns rows))
   ```

4. Run the prepared fit procedure once.
5. Run the prepared frame procedure once. Term's existing write
   still flushes once.
6. Run the prepared `handle-key` procedure once.
7. Run the prepared `quit` procedure once. `#t` returns from the
   Racket loop immediately. `#f` repeats.

The same two integers reuse the fit and frame procedures. A resize
is seen on the next iteration's size queries and prepares those two
datums again before fit and frame run. A return to an earlier size
prepares them again. The runner does not keep a procedure for every
size it has seen. Steady size does not prepare them again. The
`handle-key` datum contains `(term read-key)`, not the key text, so
one prepare covers every key. Fit, frame, `handle-key`, and `quit`
stay valid across editor rebinds because each new session has the
same type. A new size is a new datum, not a change of that type.

Host callback order stays: one columns read, one rows read, one
frame write, one flush, one key read, per drawn iteration. The quit
key's iteration still draws its frame before the key, then stops.
No second frame, size query, or key read follows quit.

The runner source still contains each of these phrases once, in
this order, so `tests/aloemacs/viewport-runner.rkt` stays green:
`(term columns)`, `(term rows)`, `aloemacs-editor ensure-visible`,
`(term write`, `aloemacs-editor frame`, `(term read-key)`. The fit
and frame datum text appears before the `handle-key` datum. Prepare
`handle-key` before entering the loop anyway. Do not copy any of
these phrases into a comment.

Require `driver-prepare!` from `aloe/driver.rkt` only. Do not
require `aloe/eval.rkt`, `aloe/parse.rkt`, `aloe/type.rkt`, or
`aloe/env.rkt`. The runner source must not contain `eval-expr` or
`parse-datum`.

## Tests

New `tests/aloemacs/runner-check.rkt`. No `module+ main`. The
checks run when `raco test` loads the file.

### The procedure evaluates again and `driver-eval!` still checks

On a fresh `make-driver`, with no editor loaded:

- `driver-prepare!` of `(define n 1)` returns an arity-0 procedure.
  Run it once. `driver-eval!` of `n` returns `1`.
- `driver-prepare!` of `(define n (n + 1))`, then run that
  procedure twice. `driver-eval!` of `n` returns `3`.
- `driver-prepare!` of `(1 + "a")` raises `exn:fail?` whose message
  matches `#rx"^typecheck:"` and returns no procedure. A following
  `driver-eval!` of `(define ok 1)` still returns, and
  `driver-eval!` of `ok` returns `1`.
- `driver-eval!` of `(define n 1)`, then of `(n + 1)`, returns `2`.
  `driver-eval!` of `(define n "a")` rebinds `n`. The next
  `driver-eval!` of `(n + 1)` raises `exn:fail?` whose message
  matches `#rx"^typecheck:"`. A cached check of that datum would
  miss this failure.
- `driver-eval!` of `(define n 1)`. `driver-prepare!` of `(n + 1)`.
  One run returns `2`. `driver-eval!` of `(define n 10)` rebinds
  `n` to another `Int`. The next run of that same procedure returns
  `11`.
- Inject one host under `probe`. Its only method is `tick`, with
  no parameters and return type `Int`. The implementation accepts
  the host state, adds one to a counter, and returns the new count.
  `driver-prepare!` of `(probe tick)` leaves the counter at `0`.
  The first run returns `1`. The second run returns `2`.

### A rejected value can leave a type binding

On a fresh `make-driver`, define `Option` with `driver-eval!`:

```aloe
(define-class (Option T)
  (constructors
    (None (fields))
    (Some (fields (value T))))
  (methods))
```

`driver-prepare!` of `(define n (Option None))` raises `exn:fail?`
whose message matches
`#rx"^typecheck: cannot infer type parameter T for Option"` and
returns no procedure. `n` is unbound in the type environment and
unbound in the runtime environment. `driver-prepare!` of
`(define n (if #t (Option None) (Option None)))` raises `exn:fail?`
whose message matches that same pattern and returns no procedure.
`n` is bound in the type environment and unbound in the runtime
environment. Use `type-environment-bound?` and `env-bound?`. This
test file may require `aloe/type.rkt` and `aloe/env.rkt` for those
predicates. The runner still must not.

### Preparation counts

`current-driver-prepare-counter` is a parameter. Its default is
`#f`. When it holds a box of an exact integer, `driver-prepare!`
adds one to that box at entry, before parsing. A prepare that later
raises still counts. The runner does not read or set the parameter.

Around `run-aloemacs-with-hosts`, set the parameter to a box of `0`.

On the steady six-key 20×8 run below, the box holds **6** when the
run returns. Columns, rows, `handle-key`, and `quit` are prepared
once each. Fit and frame are prepared once each.

On a separate pathless three-key run, keys are `"down"`, `"down"`,
`"escape"`. The size reader is called twice per iteration, once
from columns and once from rows, and both calls in an iteration
return the same pair: 20×8, then 21×8, then 20×8. The box holds
**10** when the run returns. Fit and frame are prepared for 20×8,
again for 21×8, and again for the return to 20×8. Visit stays on
`driver-eval!` and does not add to either count. This run asserts
the count. It does not rebuild frame goldens.

The 20 ms bar does not prove these counts. Repeated checks of the
cheaper expressions can stay under that bar.

### Down cycles stay under 20 ms

Drive `run-aloemacs-with-hosts`. No TTY. Fs double rooted at
`"/cwd"` with `"/cwd/a.txt"` holding `"a\nb\nc\nd\ne\nf\ng\nh"`.
Visit `"a.txt"`. Term size is 20 columns by 8 rows on every query.
Keys are five `"down"` then `"escape"`.

Build each expected frame the way
`tests/aloemacs/keymap-runner.rkt` builds a session frame. Body
`"a\r\nb\r\nc\r\nd\r\ne\r\nf\r\ng"`, column `1`, terminal rows `8`,
label `"/cwd/a.txt"`. The six frames use cursor rows `1` through
`6` in key order. Assert the observed order: columns `20`, rows
`8`, that frame's write, flush, that key, for each of the six keys.
No write, flush, size read, or key read follows Escape. Six keys
mean twelve size reads.

Time the five gaps from the return of one `read-key` until the next
`read-key` call. Use `current-inexact-monotonic-milliseconds`. The
median is the third value after sorting those five durations
ascending. It is strictly under **20** ms. On failure, the Rackunit
message includes the median in milliseconds. Also `printf` the
median when the check passes.

The 20 ms bar is the regression check. The current loop is about
46 ms per Down and fails it. One prepare of `handle-key` is allowed
before the timed gaps. Do not raise the bar. If the repaired median
is 20 ms or more, stop and report the number.

Leave the existing runner, viewport, keymap, and file behavior
tests in place. They are the proof that visit, resize, save, and
quit still follow the old order.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/runner-check.rkt
TMPDIR=/tmp raco test -y tests/aloemacs/runner.rkt tests/aloemacs/viewport-runner.rkt tests/aloemacs/keymap-runner.rkt tests/aloemacs/file-runner.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
```

If those are green, `TMPDIR=/tmp raco test -y tests`.
`git diff --check` clean.

The timing file's printed median is part of the result. Record it.

Stop. Do not issue 001. Do not issue keymap 002.

## Non-goals

- Rolling back a type binding that the current checker already
  installed before a later part of the same datum failed
- A table of fit and frame procedures for every terminal size
  already seen. Only the current pair is retained
- A cache inside `driver-eval!`, `type-of`, or `check-method-body!`
- A checker change so a generic method body is walked once per
  instantiation for every caller
- A language form for abstract host methods, or any `SPEC.md` edit
- Moving the loop into an Aloe method
- Rewriting `execute-command`, special-casing Down, or shrinking
  the keymap so the checker sees fewer arms
- Changing what a frame paints, or the safe-cell walk
- `raco demod`, a resident process, or a change to launch commands
