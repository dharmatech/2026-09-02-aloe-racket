# aloemacs-file 003 — File-aware main and runner

**Status.** Ready to implement.

## Goal

Complete the aloemacs file layer by making the Aloe starting value an empty
untitled `AloemacsSession` and extending the thin Racket runner with one
explicit filesystem host plus an optional startup path. Existing files are
visited before the first frame, missing paths begin as empty bound new-file
sessions, the session handles named `"save"` keys, and quit still stops
without an implicit save or redraw.

This checkpoint integrates the reviewed file substrate, session, key mapping,
and Loop runner. Stop when it is green. Do not add another editor feature,
move file policy into Racket, or begin buffers, windows, prompts, prefix
keymaps, or dirty state.

The implementer receives only this document. Every rule needed for this slice
is below.

## Depends on, authority, and identity

- Identity is `(aloemacs-file, 003)`, spoken **aloemacs-file 003**. This is a
  local project checkpoint, not a global Aloe checkpoint. Do not edit
  `CHECKPOINTS.md` or add a document under `docs/checkpoints/`.
- [`../../../../../../SPEC.md`](../../../../../../SPEC.md), especially send
  evaluation, `define`, immutable generic classes, exhaustive `case`, `if`,
  `load`, sections 5.3 and 9's generic-`None` rule, and section 14's typed
  host boundary, is language law. The head of a list is the receiver and its
  second element is the literal selector. A function object runs only through
  `(f call ...)`.
- [`../spec.md`](../spec.md), especially sections 1, 4, 6–8.5, 9, and 10, is
  the local design authority. This checkpoint implements its exact starting
  state, host injection, optional visit, loop, and command-line surface.
- **aloemacs-file 000–002** are implemented and reviewed. Preserve the exact
  ten-row `FsHost`, strict content rules, thin `Fs`, immutable
  `AloemacsSession`, visit/save policy, named-`"save"` dispatch, and exact
  plain Ctrl-S normalization.
- **aloemacs-loop 000–003** are implemented and reviewed. Preserve the
  three-field nested `AloemacsEditor`, pure frame, all Loop keys, and the
  established three-expression iterative runner sequence.
- **aloemacs-text 000–003** and **aloemacs-term 000** remain reviewed
  predecessors. The runner composes their public surfaces without extending
  them.

Do not add a special form, language feature, host method, crossing type,
ambient capability, evaluator bypass, second runtime environment, or second
application state path.

## Starting point

The reviewed application now contains:

- `examples/aloemacs/editor.aloe`, the unchanged pure three-field Loop editor;
- `examples/aloemacs/file.aloe`, the generic three-field session with editor
  forwarding, visit, save, and named-save dispatch;
- `host/racket/fs.rkt`, with production and stateful-double `FsHost`
  receivers;
- `host/racket/term.rkt`, whose unchanged five-row Term descriptor now maps
  exact plain Ctrl-S to `"save"`; and
- focused no-TTY tests for all those layers.

`examples/aloemacs/main.aloe` still loads `editor.aloe` and binds a bare
empty `AloemacsEditor`. `host/racket/aloemacs-run.rkt` still injects only Term,
exports only its zero-path Loop-era procedures, accepts no command-line path,
and knows nothing about `FsHost` or visit.

Top-level Aloe `define` may rebind `aloemacs-editor` in one driver's runtime
and type environments. That remains runner bookkeeping around immutable Aloe
values; it is not mutation of a session, editor, Text, Position, Fs, or Path.

## Exact file scope

### May edit

- `examples/aloemacs/main.aloe`
- `host/racket/aloemacs-run.rkt`
- `tests/aloemacs/file-runner.rkt` (new)
- `tests/aloemacs/runner.rkt`, only for the intentionally changed main value,
  required `fs-host` injection, third runner procedure, expanded arities, and
  corresponding thin-skin assertions; retain all existing frame/call-count
  coverage

### Must not edit

- `SPEC.md`, `CHECKPOINTS.md`, any global checkpoint document, or any file
  under `docs/editor/`
- `examples/aloemacs/editor.aloe`, `examples/aloemacs/file.aloe`, or another
  example
- any file under `lib/`, `aloe/`, `gel/`, or `bin/`
- `host/racket/fs.rkt`, `host/racket/term.rkt`, `host/racket/gel-run.rkt`,
  `host/racket/term-run.rkt`, another host module, package metadata, or
  `tui-term`
- any existing test except the narrowly listed `tests/aloemacs/runner.rkt`
- the aloemacs maps, charter, specification, or predecessor checkpoint
  documents
- any file not listed under **May edit**

If another file appears necessary, stop and send the checkpoint back for
correction rather than widening the slice.

## Exact Aloe main file

Replace `examples/aloemacs/main.aloe` with exactly these two top-level forms:

```aloe
(load "file.aloe")

(define aloemacs-editor
  (AloemacsSession new
    (AloemacsEditor new
      (Text from-string "")
      (Position new 0 0)
      #f)
    (Fs new fs-host)
    (if #t
        (Option None)
        (Option Some (Path new "/typed-none")))))
```

The load is relative to `main.aloe`. The conditional is intentional: the
unselected `Some` branch supplies `T = Path`, so the selected `None` has type
`(Option Path)`. A bare `(Option None)` in this outer generic construction is
a type error because `T` remains unknown; do not copy the superseded form.

After explicit `fs-host` injection, the one starting binding has:

- checked type `(AloemacsSession FsHost)`;
- nested editor Text source `""`;
- point line 0, column 0;
- quit `#f`;
- one `(Fs FsHost)` carrying the injected receiver; and
- path `(Option None)` with `T = Path`.

Construction performs no filesystem send. It does not resolve a path, inspect
a node, read, write, or list a directory. The unselected `Path` expression is
only a type witness and is not evaluated.

Loading `main.aloe` now requires `fs-host` to have been injected first.
Loading it without that binding is a checked unbound-symbol failure. It still
does not require, inject, or send to `term`, and successful loading produces
no output because both top-level forms evaluate to `void`.

Do not add a scratch banner, default filename, dirty state, Term reference,
`main` function, recursive Aloe loop, frame call, key read, output send, or
another top-level binding.

## Runner module surface

`host/racket/aloemacs-run.rkt` provides exactly:

```racket
(run-aloemacs [path])
(run-aloemacs-with-term term [path])
(run-aloemacs-with-hosts term fs-host [path])
```

Brackets denote one optional positional Racket argument. The accepted
arities are therefore exactly 0/1, 1/2, and 2/3 respectively. When supplied,
`path` is a Racket String; the empty String is still a supplied path. An
internal false sentinel for omitted path is permitted because `#f` is not a
valid supplied path.

Keep the existing `define-runtime-path` for:

```text
../../examples/aloemacs/main.aloe
```

Require only `racket/runtime-path`, the needed public driver procedures, and
the existing local `term.rkt` and `fs.rkt`. The driver procedures remain:

- `make-driver`;
- `driver-inject-host!`;
- `driver-load-file!`; and
- `driver-eval!`.

Do not require `aloe/eval.rkt`, `aloe/env.rkt`, `aloe/parse.rkt`,
`aloe/type.rkt`, or another implementation module. Do not call
`env-define!`, `eval-expr`, `parse-datum`, `read-program`,
`make-top-level-env`, or any evaluator/checker internal directly.

## Three runner layers

### `run-aloemacs-with-hosts`

This is the file-layer no-TTY seam. It accepts one validated Term receiver,
one validated FsHost receiver, and an optional path String. It performs setup
once and in this order:

1. construct one checked driver with `make-driver`;
2. inject the supplied Term receiver under exact name `term`;
3. inject the supplied filesystem receiver under exact name `fs-host` in the
   same driver;
4. load `examples/aloemacs/main.aloe` through `driver-load-file!`; and
5. when a path was supplied, perform the one startup visit below.

There is no second driver, runtime environment, checker environment, Term
receiver, FsHost receiver, or application value constructed in Racket.
Injection precedes loading because the new main value evaluates
`(Fs new fs-host)`.

Normal driver, checker, and guarded host failures propagate from this testable
function. Do not catch, retry, downgrade, or translate them inside the seam.
The only deliberate runner error is the specified observed visit refusal.

### `run-aloemacs-with-term`

This compatible Loop-era test seam accepts a supplied Term receiver and an
optional path. It constructs exactly one production `make-fs-receiver` and
delegates to `run-aloemacs-with-hosts`, preserving whether the optional path
was omitted or supplied.

With no path, constructing the receiver performs no disk operation and the
empty untitled session performs none. Existing pathless scripted-Term tests
continue to use this procedure and retain their exact frame, read, size, and
flush counts.

### `run-aloemacs`

This production entry accepts an optional path. It obtains one physical Term
receiver through the existing `call-with-tty-term-receiver`, constructs one
production filesystem receiver through the delegation above, and runs the
same checked seam. It does not create another driver or add policy around the
result.

No automated test invokes `run-aloemacs` or opens a physical TTY. Production
TTY lifetime and cooked-mode restoration remain owned by the reviewed
`call-with-tty-term-receiver`.

## Optional startup visit

When `run-aloemacs-with-hosts` receives a path String, it obtains a resolved
thin Path through the session's own Fs and sends one visit through checked
Aloe evaluation. The logical expression is:

```aloe
(aloemacs-editor visit
  ((aloemacs-editor fs) path supplied-string))
```

`AloemacsSession.visit` resolves again by its reviewed contract; no Racket
path normalization or filesystem classification is added.

Evaluate `visit` exactly once. The runner may bind the resulting
`(Option (AloemacsSession FsHost))` under one private top-level setup name so
it can:

1. inspect the Option through a checked Aloe `case` or `present?` expression;
2. on `Some(session)`, exhaustively extract and rebind `aloemacs-editor` to
   that session; or
3. on `None`, raise a deliberate Racket `aloemacs` visit error that includes
   the exact supplied argument.

The temporary Option binding is setup bookkeeping, not a second mutable
application state or a public Aloe API. Its `None` branch in any extracting
`case` remains exhaustive even when a preceding check proved it unreachable.

A missing supplied path returns `Some` from the session: it starts as an empty
bound new-file session and is not created during setup. An existing regular
file is loaded before the first frame at point `(0, 0)` with quit false. An
observed directory, symbolic link, or other node returns `None` and is
rejected before any dimension query, frame write, flush, or key read.

Do not send raw `fs-host` messages, call `Fs.inspect/read/write` in Racket,
construct `Path`, Text, editor, or session values in Racket, perform a second
visit, or fall back to the untitled session after refusal.

## Iterative session

After setup, `run-aloemacs-with-hosts` retains the Loop runner's ordinary
Racket named-`let` iteration. Every iteration evaluates exactly these three
Aloe datums through `driver-eval!`, in this order and unchanged in shape:

```aloe
(term write
  (aloemacs-editor frame (term columns) (term rows)))

(define aloemacs-editor
  (aloemacs-editor handle-key (term read-key)))

(aloemacs-editor quit)
```

The first expression queries columns and rows exactly once each, obtains the
complete frame from the session's forwarding method, sends it once to
`term write`, and relies on Term's existing flush. It never sends
`write-line`.

The second expression reads one checked key String, sends it to the current
session, and rebinds the one immutable application value. The session—not the
runner—handles `"save"`, ordinary editing keys, and quit.

The third expression reads the new session's forwarded quit fact. True exits
immediately; false begins the next iteration. A quit transition ends without
a second frame after that key and without an implicit save.

The loop contains no key-name branch, path classification, text extraction,
filesystem send, save call, ANSI calculation, status output, prompt, retry,
sleep, polling, cleanup write, or final newline. Racket control flow only
repeats the three checked evaluations.

## Command line and failure reporting

The main submodule accepts exactly:

```text
racket host/racket/aloemacs-run.rkt
racket host/racket/aloemacs-run.rkt path
```

- Zero arguments call `run-aloemacs` with no path.
- One argument calls `run-aloemacs` with that exact Racket String.
- More than one argument reports a usage diagnostic containing `usage` and
  exits with status 2 before opening a TTY, constructing a driver, injecting
  a host, loading Aloe, drawing, or reading a key.

For the zero- and one-argument forms, retain the existing ordinary
`exn:fail?` handler: diagnostics use prefix `aloemacs`, go to the current
error port, and exit with status 1. Breaks are not converted to ordinary
failures. A refused startup path and a host failure therefore reach this same
production diagnostic boundary.

There is no `--help`, option parser, default path, prompt, stdin path, later
interactive visit command, or more-than-one-file mode.

## Thin-skin boundary

The runner may contain only:

- construction/injection/loading through the public driver API;
- the optional-path setup and checked `visit` Option unwrapping above;
- construction of the production receivers through their public factories;
- the exact three-expression iteration; and
- command-line arity/error handling.

It contains no:

- `AloemacsSession`, `AloemacsEditor`, `Text`, `Position`, `Span`, or
  `EditResult` construction;
- raw filesystem send or filesystem selector such as `kind`, `inspect`,
  `read`, or `write`; Text `to-string`; or a save branch;
- key String literal such as `"save"`, `"escape"`, `"backspace"`, or an
  arrow name;
- editor transition, frame, viewport, clipping, cursor, newline, encoding, or
  ANSI implementation;
- `write-line`, ANSI escape literal, reflection, `Mirror`, dynamic selector,
  evaluator/checker internal, or second environment; or
- mutable application state separate from the driver's top-level binding.

The supplied path String may be inserted as a literal argument in one checked
Aloe datum. That is data crossing into the already-typed `Fs.path` method, not
Racket implementation of path semantics.

## Exact no-TTY frames

All runner tests use 8 columns by 4 rows. The empty session frame is:

```racket
(define empty-frame
  "\u001b[?25l\u001b[2J\u001b[H\r\n\r\n\r\n\u001b[1;1H\u001b[?25h")
```

An existing file containing `"x"` is visited at point `(0, 0)`, so its first
frame is:

```racket
(define loaded-x-frame
  "\u001b[?25l\u001b[2J\u001b[Hx\r\n\r\n\r\n\u001b[1;1H\u001b[?25h")
```

After inserting `"x"` into an empty session, point is `(0, 1)`, so the frame
is instead:

```racket
(define inserted-x-frame
  "\u001b[?25l\u001b[2J\u001b[Hx\r\n\r\n\r\n\u001b[1;2H\u001b[?25h")
```

These are test data only. None of the ANSI literals appears in production
runner source.

## Required test updates — existing Loop runner

Update `tests/aloemacs/runner.rkt` only where the intentionally enlarged main
and runner surface makes old assertions stale:

1. Its exact `main.aloe` datums become the two forms in **Exact Aloe main
   file**, including the typed-`None` conditional.
2. Its main-loading test injects a `make-fs-double` before load, expects
   `AloemacsSession`, `Fs`, `Path`, and `Option` bindings, checks type
   `(AloemacsSession FsHost)`, and proves empty Text, point `(0, 0)`, quit
   false, and absent path. No Term injection is needed.
3. It proves loading main without `fs-host` is rejected and successful loading
   performs no filesystem content change or output.
4. Its exported-procedure assertions cover exactly the three names and
   arities 0/1, 1/2, and 2/3.
5. Its existing `run-aloemacs-with-term` pathless Escape and edit-then-Escape
   cases remain otherwise unchanged: the same frames, one flush per frame,
   key counts, size counts, and stop-without-redraw assertions must hold.
6. Its source-boundary check adds the production filesystem factory and
   host-aware seam to the required public surface while retaining every
   evaluator-internal, constructor, ANSI, `write-line`, and key-policy
   prohibition.

Do not replace the reviewed pathless frame tests with new file tests, loosen
their exact byte/count assertions, or move them into the new file.

## Required new tests — `file-runner.rkt`

Create `tests/aloemacs/file-runner.rkt`. Use scripted Term receivers and
shared `make-fs-double` receivers. Tests open no physical TTY and use no
production filesystem scratch file.

### Pathless double

Run `run-aloemacs-with-hosts` with no path and one `"escape"` key. Prove:

- the empty frame is written and flushed exactly once;
- exactly one key is read and terminal size is queried exactly twice;
- no redraw occurs after quit;
- planted filesystem contents and names remain unchanged; and
- no file is chosen or created.

### Existing relative file

With double cwd `"/cwd"`, plant `"/cwd/a.txt"` as a regular file containing
`"x"`. Run with supplied path `"a.txt"` and one `"escape"` key. Prove:

- the relative spelling is resolved through thin Fs;
- the file is loaded before the first frame;
- the first and only frame is exact `loaded-x-frame`, with cursor at terminal
  coordinate `(1, 1)` because visit starts point at `(0, 0)`;
- exactly one key is read and two size queries occur; and
- Escape quits without changing the file.

### Missing bound path and save

First run a missing supplied path with immediate Escape and prove it remains
missing, establishing that visit alone does not create it.

With a fresh shared double, run the same missing relative path with scripted
keys `"x"`, `"save"`, and `"escape"`. Prove:

- three frames are written and flushed: the initial empty frame, then the
  exact `inserted-x-frame` before save, then the same `inserted-x-frame`
  before Escape;
- exactly three keys and six size queries occur;
- save creates `"/cwd/new.txt"` as a regular file containing exactly `"x"`;
- the runner adds no newline or other bytes; and
- Escape performs no second write or post-quit redraw.

The scripted String `"save"` models the output of checkpoint 002's separately
tested physical-key normalization. This runner does not construct or inspect
a `tkeymsg`.

### Refused startup nodes

For a directory, symbolic link, and other node, call the host-aware seam with
that relative path and prove each:

- raises the deliberate visit error naming the supplied argument;
- does so before any frame bytes, flush, size query, or key read;
- leaves the key script untouched; and
- leaves filesystem nodes and contents unchanged.

Use a fresh scripted Term fixture per refusal so observations cannot leak
between cases.

### Save remains Aloe policy

Inspect the runner source narrowly enough to prove:

- the setup uses the public driver and receiver factories;
- the path is passed through `(aloemacs-editor fs)`, thin `path`, and one
  checked `visit`;
- the iteration still contains only frame/write, read/handle-key/rebind, and
  quit checking; and
- there is no `"save"` key literal, raw `fs-host` content send, `Fs.write`,
  `(aloemacs-editor save)`, Text extraction, path-kind branch, editor/session
  constructor, ANSI literal, or evaluator/checker bypass.

The missing-path creation test is the behavioral proof that a save key reaches
the Aloe session rather than a Racket key branch.

### Command-line over-arity

Load the runner's `main` submodule in an isolated namespace with more than one
command-line argument, captured current ports, and a recording `exit-handler`
(or an equivalent no-TTY subprocess). Prove:

- status 2 is requested;
- the error output contains `usage`;
- standard output is empty; and
- no TTY is opened and no key/input is consumed.

Do not invoke the zero- or one-argument production main path in an automated
test because those forms intentionally request a physical TTY.

## Verification and hand check

Run the two directly affected runner suites first:

```sh
TMPDIR=/tmp raco test tests/aloemacs/runner.rkt
TMPDIR=/tmp raco test tests/aloemacs/file-runner.rkt
```

Run all aloemacs tests:

```sh
TMPDIR=/tmp raco test tests/aloemacs
```

Run the complete recursive suite:

```sh
TMPDIR=/tmp raco test tests
```

Then run this checked no-TTY hand exercise from the repository root:

```racket
(require "aloe/host.rkt"
         "host/racket/aloemacs-run.rkt"
         "host/racket/fs.rkt"
         "host/racket/term.rkt")

(define output (open-output-string))
(define keys (box '("x" "save" "escape")))
(define key-calls 0)
(define size-calls 0)

(define term
  (make-term-receiver
   output
   (lambda ()
     (define key (car (unbox keys)))
     (set-box! keys (cdr (unbox keys)))
     (set! key-calls (add1 key-calls))
     key)
   (lambda ()
     (set! size-calls (add1 size-calls))
     (values 8 4))))

(define fs-host
  (make-fs-double "/cwd" (hash "/cwd" 'directory)))

(run-aloemacs-with-hosts term fs-host "new.txt")

(list
 (host-receiver-send fs-host 'kind '("/cwd/new.txt"))
 (host-receiver-send fs-host 'read '("/cwd/new.txt"))
 key-calls
 size-calls
 (positive? (string-length (get-output-string output))))
```

The exact result is:

```racket
'("file" "x" 3 6 #t)
```

No physical-TTY hand check is required.

## Acceptance

- `main.aloe` contains exactly the session load and typed empty-untitled
  starting construction, requires explicit `fs-host`, requires no Term, and
  performs no filesystem operation.
- The runner provides exactly the three optional-path procedures at arities
  0/1, 1/2, and 2/3; production wrappers each construct the one receiver they
  own and delegate to the checked host-aware seam.
- The host-aware seam injects both supplied receivers into one driver, loads
  main, evaluates one optional visit, deliberately refuses non-file paths
  before terminal activity, and otherwise runs the unchanged three-expression
  iteration.
- Zero-path startup is empty and untitled; existing relative paths load before
  the first frame; missing paths remain absent until save and are then created
  with exact current Text.
- Save policy remains in `AloemacsSession`; quit never saves; the runner has
  no key branch, raw file operation, editor logic, frame logic, ANSI, prompt,
  status output, or evaluator bypass.
- Zero or one command-line path is accepted, over-arity reports usage before
  TTY setup, and production failures retain the existing diagnostic boundary.
- Updated Loop runner assertions, the new file-runner suite, all aloemacs
  tests, and the full recursive suite are green; the hand check yields the
  exact result above; and `git diff --check` is clean.
- Stop for human review. Do not issue aloemacs-file 004 or begin another
  editor layer.

## Explicit non-goals

- a minibuffer, interactive find-file, save-as, path prompt/completion,
  prefix map, `C-x C-s`, `C-x C-f`, or additional key binding
- a second buffer, buffer list, windows, splits, dired, directory UI,
  `*scratch*`, status line, mode line, or workspace
- dirty state, saved snapshots, external-change detection, merge, revert,
  insert-file, recent files, autosave, backup, lock, or save-on-quit
- backup/atomic-replace/fsync policy, permission repair, mkdir, delete,
  rename, chmod, changing cwd, globbing, recursive traversal, or remote files
- binary editing, encoding selection, replacement decoding, BOM stripping,
  CRLF conversion, platform text mode, final-newline insertion, or metadata
- following symbolic links for contents or accepting a non-file startup node
- another Term or FsHost method, crossing type, host capability, keymap
  abstraction, terminal parser, mouse, paste, PTY test, or TTY automation
- changing `AloemacsSession`, `AloemacsEditor`, Text, Fs, Disk, Term mapping,
  Gel, the driver, language law, or the global checkpoint spine
