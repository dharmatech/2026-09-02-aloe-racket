# End-state sketch: running Aloemacs after the host runner series

Companion to [`summary.md`](summary.md), the record of the 2026-10-17
host runner discussion. This file draws what the tree would look like
if both series in that record's recommendation were implemented: a
manifest-driven `bin/aloe` on the language spine, then the Aloemacs
loop moved into Aloe. It answers the user's question "what would it
look like practically: would we still have a file like
`aloemacs-run.rkt`, shorter, longer, or none at all?"

This is a sketch, not a spec and not a checkpoint. Every spelling below
is a candidate: the fifth manifest element, the names `run.aloe`,
`args`, `call-with-aloemacs-term`, and the module split. A designer
settles them. Where a choice is open, this file says so.

Revised 2026-10-17 after Grok's review ([`grok-review.md`](grok-review.md);
`summary.md`, "Review, 2026-10-17"): the second `load` in `run.aloe`, the
failed-visit arm marked open, the `args` double in the test shim, the
small runners kept, and the REPL rule. The revised order keeps
`aloemacs-run.rkt` owning the loop until two spine gates land, so the
Aloemacs end state here is the later of the two steps.

## The command

Today:

```bash
racket host/racket/aloemacs-run.rkt notes.txt
```

After:

```bash
./bin/aloe examples/aloemacs/run.aloe notes.txt
```

What happens. `run-cli` looks for `aloe-hosts.rktd` in the folder that
contains `run.aloe` and finds the row keyed `"run.aloe"`. It loads each
row's host module by `dynamic-require`, as `aloe/host-manifest.rkt`
already does for the language server, and calls the row's factories
nested in row order. Inside the innermost extent it makes a driver,
injects the receivers on the base with `driver-inject-host!`, and loads
`run.aloe`. The whole file is typechecked before anything runs, as
today. The last form of `run.aloe` starts the loop. On quit the extents
unwind in reverse: the mouse and alternate-screen modes are turned off,
tui-term restores the terminal, the process exits 0. A folder with no
manifest, or no row for the file, gets today's behavior unchanged:
`aloe: typecheck: unbound symbol: fs-host`, exit 1. `make-driver` and
the file-less REPL stay capability-free.

## The files, side by side

| Today | Lines | After | Lines |
|---|---|---|---|
| `host/racket/aloemacs-run.rkt`: wiring, visit, loop, TTY bracket, CLI, in Racket | 126 | `host/racket/aloemacs-run.rkt`: TTY bracket only, in Racket | about 15 |
| `examples/aloemacs/main.aloe` | 86 | `examples/aloemacs/main.aloe`, unchanged | 86 |
| `examples/aloemacs/aloe-hosts.rktd`: one row, read by the editor only | 4 | `examples/aloemacs/aloe-hosts.rktd`: two rows, read by editor and runner | about 12 |
| | | `examples/aloemacs/run.aloe`: visit, loop, entry, in Aloe; new | about 35 |
| `host/racket/gel-run.rkt` | 42 | deleted; `gel/run.aloe` new | about 8 |
| `host/racket/term-run.rkt`, `host/racket/fs-repl.rkt` | 34, 28 | kept until a scratch-file convention exists, then deleted (review) | 34, 28 |
| | | `host/racket/args.rkt`: new, shared by every program | about 25 |
| | | `aloe/driver.rkt` run-cli grows; `aloe/host-manifest.rkt` admits the factory element | about 50, about 20 |

So Aloemacs does not end with no Racket file. It ends with a much
smaller one that holds only terminal lifecycle, and the application
logic that is Racket today becomes Aloe. Gel, and any program that
needs only a plain terminal or disk, ends with no Racket file at all.

## The manifest

The one place that says which program gets which host and how the
production receiver is built. The editor keeps reading the first three
elements of an entry for the host's type and ignores the fourth. One
candidate spelling:

```racket
;; examples/aloemacs/aloe-hosts.rktd
((file "main.aloe"
   (host fs-host host/racket/fs fs-interface))
 (file "run.aloe"
   (host fs-host host/racket/fs      fs-interface   (with host/racket/fs           call-with-fs-receiver))
   (host term    host/racket/term    term-interface (with host/racket/aloemacs-run call-with-aloemacs-term))
   (host args    host/racket/args    args-interface (with host/racket/args         call-with-args-receiver))))
```

The `main.aloe` row stays fs-only, so hover there never depends on the
optional tui-term package, which is the reason host-queries spec
section 12 item 5 gave for omitting `term`. The `run.aloe` row is the
one the runner uses. Every module named must be in the `host/racket`
collection, the trust rule the editor already applies. The factory
module may differ from the interface module; that is what lets the
Aloemacs bracket live beside the generic Term.

## `run.aloe`

Today's Racket loop and startup visit, written as Aloe. With the
checker cycle guard in place (see the record's "The checker hangs on
the natural encodings"), the natural shape is:

```aloe
(load "main.aloe")
(load "file.aloe")

(define-class (AloemacsRun H)
  (fields (session (AloemacsSession H)))
  (methods
    (loop () (AloemacsSession H)
      (let ((columns (term columns)))
        (let ((rows (term rows)))
          (let ((fitted ((self session) ensure-visible columns rows)))
            (let ((recorded (fitted record-pictures columns rows)))
              (let ((written (term write (recorded frame columns rows))))
                (let ((next (recorded handle-event (term read-event))))
                  (if (next quit)
                      next
                      ((AloemacsRun new next) loop)))))))))))

(define aloemacs-start
  (let ((paths (args list)))
    (if (paths empty?)
        aloemacs-editor
        ((aloemacs-editor visit ((aloemacs-editor fs) path (paths first))) case
          (None () aloemacs-editor)   ;; open: see the note on a failed visit
          (Some (session) session)))))

(define aloemacs-final ((AloemacsRun new aloemacs-start) loop))
```

Notes:

- The second `load` is required. SPEC section 11's copy rule copies out
  of a loaded file only the names that file itself defines, and
  `main.aloe` defines only `aloemacs-editor`; `AloemacsSession` is
  defined in `file.aloe`. Without the line, `run.aloe` fails with
  `typecheck: unbound symbol: AloemacsSession` (verified 2026-10-17,
  `retention.rkt`). With it, the same path and bytes as the load inside
  `main.aloe` copy the definitions without running the file.
- The per-iteration order is today's exactly: columns, rows,
  `ensure-visible`, `record-pictures`, one flushing `write`,
  `read-event`, quit. The scripted runner tests pin that order and
  those selectors, so the loop must keep it.
- The visit is today's quasiquoted Racket datums
  (`aloemacs-run.rkt` lines 28-41) moved over, not new code.
- The recursive `((AloemacsRun new next) loop)` is the encoding that
  hangs today's checker; the cycle guard is a precondition.
  `loop-cost.rkt` in this folder shows a working but uglier encoding
  through an explicit-constructors class and a step function, if the
  fix were skipped.
- The last form is a `define`, so nothing prints to the restored
  terminal when the loop returns. `driver-load-port!` prints non-void
  results.
- A failed visit is open, and the `None` arm above shows one of the two
  answers only because the other has no Aloe spelling yet. As drawn, a
  bad path becomes an untitled session and the loop does call Term.
  Today Racket exits 1 with "cannot visit path" before any Term call,
  and `tests/aloemacs/file-runner.rkt` pins the zero Term calls. Both
  are coherent. The refusing answer needs a channel Aloe lacks: `check`,
  a host method that raises, or an exit host. The charter chooses; this
  sketch does not.
- The loop lives in `run.aloe`, never in `main.aloe`: 35 tests load
  `main.aloe` with only an fs double and expect definitions only, and
  `tests/aloemacs/runner.rkt` pins its exact datums.

## `aloemacs-run.rkt`, shrunk

Keeps its name, because 27 tests require it and may keep
`run-aloemacs-with-hosts` as a test shim. Shrinks to the one thing Aloe
cannot do, terminal lifecycle with teardown on error:

```racket
#lang racket/base
(require "term.rkt")
(provide call-with-aloemacs-term)

;; Alternate screen, then button-motion reporting in SGR form; undone in
;; reverse on normal return and when an exception leaves the editor.
(define (call-with-aloemacs-term receive)
  (call-with-tty-term-receiver
   (lambda (term)
     (dynamic-wind
      (lambda () (write-string "\e[?1049h\e[?1002h\e[?1006h" (current-output-port))
                 (flush-output (current-output-port)))
      (lambda () (receive term))
      (lambda () (write-string "\e[?1002l\e[?1006l\e[?1049l" (current-output-port))
                 (flush-output (current-output-port)))))))
```

That is the honest residue: terminal policy, not editor logic. The
record's "Where the reviewers differ" has the alternative, enables
written by Aloe as strings and a generic reset in the TTY module, which
takes this file to zero lines. The record leans against it because the
scripted tests assert no enable bytes in the frame output, but it is a
live option, and a third option is modes as data in the manifest entry.

## Shared infrastructure, written once

- `host/racket/term.rkt` splits: the interface, state, and
  `make-term-receiver` stay and load without tui-term; a new TTY module
  holds the tui-term require, the key and mouse mapping, and
  `call-with-tty-term-receiver`.
- `host/racket/fs.rkt` gains a three-line `call-with-fs-receiver` that
  calls its continuation with `(make-fs-receiver)`.
- `host/racket/args.rkt` is new: a host with one method, `list`
  returning `(List String)`, over the arguments left after the program
  path; a production receiver and a double. `(List String)` is already a
  crossing type, so this adds no vocabulary.
- `run-cli` in `aloe/driver.rkt` reads the row, loads the factories,
  nests them, checks that each receiver's interface is `eq?` to the
  row's export, injects, loads, and prints the reader's failure reason
  on a bad row instead of running hostless.
- `aloe/host-manifest.rkt` admits the fourth element and hands it to the
  runner; the server keeps ignoring it and never calls a factory.

None of this is per program.

## Where the boundary information lives afterwards

The declaration of what Racket offers does not move: the six Term
methods and ten FsHost methods with their crossing types stay in
`host/racket/term.rkt` and `host/racket/fs.rkt`, once per host, feeding
the checker, evaluator, and Mirror as today. That layer is the part
that resembles an FFI declaration, and it belongs on the Racket side.
What changes is the per-program glue:

| Information | Today | After |
|---|---|---|
| Which program gets which host | the runner's `driver-inject-host!` calls | the manifest row beside the program |
| How a production receiver is built | the runner, by hand | the factory named in the row |
| Lifecycle policy needing `dynamic-wind` | the runner | a 15-line Racket factory, or nothing |
| Loop, startup visit, entry | the runner, in Racket | `run.aloe`, in Aloe |
| What the program needs, as a type | `(AloemacsSession H)`, `(Fs new fs-host)` | unchanged |

The Aloe source still names `term`, `fs-host`, and `args` as free names
bound on the base. Nothing Racket-shaped appears in `.aloe` files.

Tests do not change in kind. They keep calling `driver-inject-host!`
with a scripted term and an fs double, and an `args` double whenever
the test passes a startup path, since `run.aloe` reads `(args list)`.
Then they load `run.aloe` or `main.aloe`. The manifest is production
wiring only. To stop the two grant paths drifting again, the review
proposes that the test shim read the entry file's manifest row and
inject the test's doubles under exactly those binding names, failing
when the sets differ; it reads names only and never calls a factory or
loads the TTY module.

## Gel, for comparison

`gel/run.aloe`, about eight lines: load `main.aloe`,
`../examples/point.aloe`, and `stack.aloe`, then today's entry send from
`gel-run.rkt` lines 28-33 as the last form, bound with `define`.
`gel/aloe-hosts.rktd` gains a `run.aloe` row with a `term` factory
pointing at the generic `call-with-tty-term-receiver`. `gel-run.rkt` is
deleted. Gel's loop is already Aloe, which is why the record makes it
the first consumer.

## Decide early

`bin/aloe file` without `--quit` drops into the REPL after loading.
Inside a TTY factory's extent that would read tui-term key structs.
The review's rule, which both reviewers accept: a row whose factory
holds the TTY runs the file and exits; a row of plain constructors and
no terminal extent may enter the REPL. One `--quit` rule for both would
make one of them feel broken. That keeps `fs-repl.rkt`'s use case, a
REPL with a disk, alive as a constructor-only row.
