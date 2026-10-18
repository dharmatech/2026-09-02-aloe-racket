# Host runner discussion

Record of the 2026-10-17 discussion about the driver files every
host-using Aloe program needs today, and whether to replace the typed
host boundary with a traditional import of Racket modules. This is a
discussion record. It is not language law, not a charter, and not a
decision to build anything. Where it says "recommend", that is the
analysis's opinion, not the user's decision.

Three participants: the user, a first agent whose answer the user
brought for review, and Claude (in Claude Code), which checked that
answer against the tree with an eleven-agent workflow: four
fact-checkers, two experiments, a pin inventory, three design judges
with different lenses, and a critic. The probes that produced the
measurements are in this folder. Nothing in the product tree was
changed.

Tree at the time: branch `experiment/2026-10-16-host-queries` at
`85f92c4`, the last commit of editor project 9.

**Which sections are current.** The record was revised the same day
after Grok's review. The authority for any charter is the section
"Review, 2026-10-17" below, together with the revised
[`end-state-sketch.md`](end-state-sketch.md) and the "Exits" section.
"Recommendation" and "Where the reviewers differ" are the record of
what was proposed first; the review replaced parts of both, and each
carries a note saying so. Read them as history, not as instructions.

## Conclusion

Keep the typed host boundary. The awkwardness is real, but it is not
the boundary. It is a missing generic entry point: `bin/aloe` injects
nothing, so every program that needs a terminal or a disk has a Racket
runner written by hand, and Aloemacs's runner also holds its event
loop, its startup visit, and its terminal escape policy.

The fix the tree already points at: let `bin/aloe` read the folder
manifest `aloe-hosts.rktd` that editor project 9 just added, extended
with a factory clause the language server ignores, and inject
production receivers before loading. The manifest's own spec reserved
that step. The Aloemacs loop and startup visit can follow into an Aloe
entry file, but only later and as their own aloemacs charter;
`aloemacs-run.rkt` keeps the loop until then. Both changes are
measured below.

After Grok's review the same day, the agreed order is: the checker
cycle guard first, as one global checkpoint on the language spine;
then the tail-call sentence in SPEC with a language-suite test, a
second global checkpoint; then the manifest-runner charter, with the
reader amendment before any manifest grows a fifth element, Gel first,
and `term-run.rkt` and `fs-repl.rkt` kept until a scratch-file
convention exists; then the loop charter, with a sampled-peak memory
bar as its precondition. The section "Review, 2026-10-17" has the
locks.

Rejected: an FFI or `(require racket-module)`, an in-source host
declaration, an amendment to SPEC section 14, a Deno-style permission
flag, and adding tui-term to `info.rkt`.

## The question

The user: the implementation is an interpreter hosted on Racket, and
instead of a foreign function interface it has a typed host boundary.
Every application that uses a host facility needs a driver file. Most
languages let you write one file, say what you import, and run it.
Should Aloe move that way, with a file that imports a term library or a
filesystem library and loads Racket as needed? Or does the boundary
have benefits, with ergonomics that can be improved? Earlier agents
had said keep the boundary and clean up its use.

## The first answer

The first agent said: keep the boundary and fix the wiring. It split
`host/racket/aloemacs-run.rkt` into boundary wiring (a few lines), a
startup visit written as quoted datums, a Racket event loop with
prepare caching, and boilerplate. It gave four reasons to keep the
boundary: the aloemacs tests run the real editor with doubles and no
TTY; `(Fs new fs-host)` wraps the host as a value carried in a field;
one descriptor feeds checker, evaluator, and Mirror; the host surface
is small and auditable. It named four defects: `main.aloe` uses
`fs-host` as a free variable; there is no generic granting runner;
Aloemacs keeps its loop in Racket, which it called the lock "Term only
at the runner"; four runners repeat the same lines. It proposed three
changes: a capability declaration in Aloe source, checked by the
checker; `bin/aloe` reading those declarations and granting production
receivers, possibly behind a flag; and reopening the loop lock to move
the loop into Aloe. It named a language-spine charter and a separate
aloemacs decision as the exits.

## What checked out

Verified against the tree:

- The runner anatomy is right in shape. `host/racket/aloemacs-run.rkt`
  lines 24-27 are the wiring (make driver, inject `term` and `fs-host`,
  load `main.aloe`), 28-41 the startup visit as datums through
  `driver-eval!`, 42-81 the prepared loop, 94-107 the alternate-screen
  and mouse-motion bracket in a `dynamic-wind`, 109-126 the command
  line. The numbers in its table do not match any counting convention
  (the code lines are about 5 / 14 / 40 / 52), but nothing turns on
  them.
- `./bin/aloe --quit examples/aloemacs/main.aloe` prints
  `aloe: typecheck: unbound symbol: fs-host` and exits 1. `gel/main.aloe`
  fails the same way on `term`. It is a checker error, not a runtime
  one.
- The doubles claim is nearly right. Of 81 files under `tests/aloemacs/`,
  26 drive the real runner loop over `main.aloe` with a scripted Term
  and (in 25) an fs double, 13 more load `main.aloe` into a driver with
  only an fs double, and no test needs a TTY. "Every" is too strong:
  `fs-contents.rkt` touches a real temp directory, and 34 files need the
  optional tui-term package to load `term.rkt`.
- One descriptor for checker, evaluator, and Mirror, and checkpoints
  83-88 as the anti-drift design: `docs/decisions.md` "Typed host
  capabilities (2026-09-06)" says exactly that.
- `lib/fs.aloe` and `lib/disk.aloe` are single-field generic classes
  over an injected receiver, and `AloemacsSession` carries `(Fs H)` as a
  field. The raw receiver is still a driver-base global named `fs-host`,
  wrapped once in `main.aloe` line 74. "Rooted at one directory" holds
  for the test double only; `make-fs-receiver` follows the process cwd.
- There is no runner that grants both a terminal and a disk to an
  arbitrary file. `term-run.rkt` already is a generic Term runner for
  any file, and `fs-repl.rkt` is a REPL with `fs-host` that can `load` a
  file from its prompt, so "a terminal or a disk needs its own Racket
  file" overstates it.

## What did not check out

- **Term has six methods, not five.** `host/racket/term.rkt` lines
  243-253: `read-key`, `write-line`, `write`, `columns`, `rows`,
  `read-event`. The mouse series added the sixth. FsHost has ten
  (`host/racket/fs.rkt` lines 217-230).
- **The Racket loop is not a lock.** "Term only at the runner" is in the
  aloemacs README's "Why this program" paragraph, not its "Locks" list.
  The loop charter, section 4.9 "Who iterates (resolve this)", offered
  Aloe recursion or a Racket loop. The loop spec, section 7 line 348,
  chose Racket for one stated reason: "This avoids making stack
  overflow the normal lifetime limit of an editor session." The first
  answer never engaged that reason. The measurement below does.
- **The per-key typecheck cost.** The runner-check checkpoint names the
  cause as `driver-eval!` being check-then-run on every submission,
  compounded by the session being generic in its host. Driving the loop
  from Racket is the mechanism that resubmitted the datum. An Aloe-side
  loop would not have paid it, because a method body is checked at its
  send site once, and the evaluator never calls the checker.
- **Philosophy's `require` is a module-system item**, listed with
  `#lang aloe` and macros. The modules series then filled the module
  hole with `load` and recorded `import` as rejected
  (`docs/decisions.md` "File modules and the copy rule (2026-10-14)").
  An in-source host declaration is deferred, not anticipated: decisions
  2026-09-06 deferred "source-written host types" pending application
  pressure, and project 9 put "An Aloe declaration for hosts, a SPEC.md
  amendment, or host names in annotations" in its non-goals.
- **Networking is not "a third descriptor"** in today's shape. Crossing
  types are `Int`, `Bool`, `String`, `(List String)` (`aloe/host.rkt` line
  28). A socket is a handle; opaque handles, bytes, and `Result` are all
  explicitly deferred. A narrow host with a fixed endpoint in receiver
  state and text payloads would fit; a general one is a SPEC section 14
  extension of its own.

## What the first answer missed

**The manifest already exists.** Editor project 9, host-configured
queries, closed on 2026-10-17 (commits `7a93158`, `042e451`, `85f92c4`).
A manifest beside a program names its hosts:

```racket
;; examples/aloemacs/aloe-hosts.rktd
((file "main.aloe"
   (host fs-host host/racket/fs fs-interface)))
```

The language server reads it through `aloe/host-manifest.rkt` as data,
never evaluated, admits only modules matching
`^host/racket/[a-z0-9_-]+$`, loads them with `dynamic-require`, and
binds each host's type only. Its charter locked, section 4.3: "It is
not a new Aloe declaration, and SPEC.md is not amended." Line 219:
"Leave room for runners. A later project may let the runners read the
same manifest. A runner would also need a way to build a receiver,
such as a factory." Its spec, section 6.9 "Room for runners", reserves
a fifth element or a new entry head. Its non-goals (spec section 14,
lines 1117 and 1125) list both "Runners reading the manifest, a factory
element" and "An Aloe declaration for hosts". So the first answer's
proposal 1 re-derives, in Aloe source, a declaration the tree already
keeps one file over, creating two sources of truth, and proposal 2
ignores that the reader is already two thirds of a generic runner.

**The runner and the manifest already disagree.** `aloemacs-run.rkt`
injects `term` and `fs-host`; the manifest lists `fs-host` only. Spec
section 12 item 5 says why: `term.rkt` line 9 requires `tui/term` at
module level, so listing `term` would make hover in `main.aloe` depend
on the optional package. Making `bin/aloe` read the manifest reduces the
sources of truth from two to one plus a runner-only column, and splitting
`term.rkt` into a tui-free interface module and a TTY module removes the
reason for the omission.

**`bin/aloe` cannot statically require `term.rkt`.** `tests/checkpoint-53.rkt`
lines 41-54 pin that `bin/aloe` and the core never contain `tui/term`
and that `info.rkt` never names `tui-term`; `tests/checkpoint-88.rkt`
line 110 pins that `aloe/driver.rkt`, `aloe/main.rkt`, and `bin/aloe`
never match `host/racket/term.rkt`, `tui/term`, `term-interface`, or
`make-term-receiver`, not even in a comment. A granting `bin/aloe` must
load host modules dynamically, by data, as the manifest reader does.
`docs/checkpoints/0086` line 112, "Do not make either runner part of
ordinary bin/aloe", and `docs/gel.md` line 111, "bin/aloe stays
term-free", are the sentences a charter must reopen, under the
condition that a run with no manifest row injects nothing and loads no
host module.

**The factory is not a constructor.** `make-fs-receiver` is one.
The production Term receiver is handed to a continuation by
`call-with-tty-term-receiver` (`term.rkt` lines 262-268) inside
tui-term's `with-term`, which swaps the current ports to the TTY, puts
it in raw mode, and restores it on normal return, errors, and breaks.
Aloemacs wraps that in a `dynamic-wind` that writes
`\e[?1049h\e[?1002h\e[?1006h` before and the reverse after
(`aloemacs-run.rkt` lines 94-107). A data-driven runner therefore needs
one call-with shape for every host, nesting in row order with the load
innermost, and a home for per-application terminal policy with its
error-path teardown intact. The same fact is the strongest argument
against an import: an import binds a value, and cannot wrap the rest of
the program in a dynamic extent without a second evaluation rule, which
SPEC section 14 forbids.

**The cost of deleting runners.** Five test files read `gel-run.rkt`
and `term-run.rkt` as text or spawn them (`checkpoint-65`,
`checkpoint-86`, `alternate-screen`, `mouse`, `split-drag-motion`);
`tests/fs-repl.rkt` requires `fs-repl.rkt`; 27 files require
`aloemacs-run.rkt`. "Deletes two runners outright" is a migration.

## Measurements

Run on Racket v9.3 [cs], one 16-core laptop. Probes in this folder.

**Stack safety of a recursive Aloe loop** (`loop-stack.rkt`). A
Gel-shaped method: read a key, write a line, nested `let`, `if`,
tail self-send.

| N iterations | wall ms | per iteration | max RSS | heap after GC vs before |
|---|---|---|---|---|
| 1,000 | 7.0 | 7.0 us | 133.2 MB | +0.06 MB |
| 10,000 | 62.6 | 6.3 us | 131.5 MB | +0.02 MB |
| 100,000 | 648.4 | 6.5 us | 133.0 MB | +0.07 MB |
| 1,000,000 | 6507.1 | 6.5 us | 133.1 MB | +0.01 MB |

Time linear, memory flat. The deliberately non-tail control,
`((self loop-nontail (n + 1)) + 0)`, still completes at 1,000,000
iterations because Racket CS grows continuations on the heap: it holds
about 1.4 GB (1.4 KB per pending iteration) and spends half its time in
GC. There is no stack limit on the tail path. The code explains it: the
send clause of `eval-expr` (`aloe/eval.rkt` line 255) ends in
`lookup-message`; `send-to-instance` (1115) ends in `apply-method`
(1327), which ends in `eval-expr` of the body; `send-to-function`
(1406) likewise; `send-to-bool` (1570) tail-calls the chosen thunk.
`let` is `fn` plus `call`; `if` is a Bool send to two thunks. The only
`parameterize` and `dynamic-wind` in `eval.rkt` are on the `load` path.
The loop spec's reason for a Racket loop does not hold. The one design
constraint it leaves: the recursive send must stay in tail position, or
the session leaks about 1.4 KB per keystroke without an error.

**Per-key cost of an Aloe-side Aloemacs loop** (`loop-cost.rkt`). Same
scripted Term (20 by 8, 50 "down" keys then "escape"), same fs double
with `/cwd/a.txt`, same startup visit of `a.txt`, three rounds. Gaps
are measured from one key read returning to the next being called, as
`tests/aloemacs/runner-check.rkt` does.

| Variant | median gap | first gap | max gap |
|---|---|---|---|
| A. Today's runner, Racket loop with `driver-prepare!` | 0.94-0.96 ms | 1.01-1.08 ms | 2.84-3.07 ms |
| B. Aloe loop, one `driver-eval!`, no `driver-prepare!` | 0.94-1.14 ms | 1.02-1.24 ms | 2.87-2.98 ms |
| C. Per-key `driver-eval!`, no prepare (the pre-runner-check shape) | 128-134 ms | 132-137 ms | 134-139 ms |

A and B write byte-identical frames in the same host-call order.
B's one-time check of the loop send costs about 134 ms, the same walk
today's seven prepares cost (130-137 ms), nearly all of it the
`handle-event` walk over the generic session, which has grown from the
41 ms the runner-check checkpoint recorded. B needs no `driver-prepare!`
and no per-size re-preparation: columns and rows are values inside the
loop. The 20 ms Down-cycle bar holds with a wide margin.

**The checker hangs on the natural encodings** (`recursion-hang.rkt`).
This is new and bears on sequencing. Two encodings of the Aloe loop,
a `define-methods AloemacsSession` adding a recursive `run`, and a
generic `(fields ...)` wrapper class recursing through a new wrapper,
both typecheck at definition and then never return from the send that
starts the loop. `aloe/type.rkt` line 1949: every instance send on a
generic class without explicit constructors re-checks the method body
under the instantiated substitution (`check-method-body!`, line 1429),
and nothing records that a body is already being checked, so a
recursive send is an infinite walk. The five-line reproduction:

```aloe
(define-class (Loop H)
  (fields (h H))
  (methods
    (run (n Int) Int
      (if (n = 0) 0 (self run (n - 1))))))
((Loop new 1) run 3)
```

Gel never hit this because `GelMain` is not generic. A class with
explicit `constructors` checks its bodies once at definition and is
immune, but under rigid `H` a body cannot send host messages
(`typecheck: unknown message: kind`). Variant B above used a third
encoding: an explicit-constructors loop class whose `run` takes the
session and a step function `(-> (AloemacsSession H) (AloemacsSession
H))` returned by a session method, whose body is deferred to the send
that sees the concrete host. It works, and it is contorted. The honest
fix is an in-progress set or memo in `check-method-body!`, with a test
that a recursive method on a generic `(fields ...)` class checks and
runs. That is a language-spine checkpoint and a precondition of any
loop series.

## What pins the current shape

From the inventory, for the two changes: (G) `bin/aloe` reads the
manifest and the three small runners go; (L) the Aloemacs loop and
startup visit move into Aloe.

| Count | What |
|---|---|
| 27 | test files require `host/racket/aloemacs-run.rkt`; keep the file name, shrink it |
| 35 | test files load `examples/aloemacs/main.aloe` with only an fs double; the loop must live in a new file |
| 22 | test files pin `file.aloe`'s define-class list; no loop class there |
| 12 | test files break across G and L: 8 mechanical pin edits, 4 behavior changes |
| 5 | test files read or spawn `gel-run.rkt` and `term-run.rkt` |

The behavior changes: `runner-check.rkt`'s prepare counts and 20 ms
bar; `fs-repl.rkt`'s REPL round trip; `checkpoint-86.rkt`'s usage and
exit-2 pins on `term-run.rkt`; `file-runner.rkt`'s main-submodule usage
test and its Racket-raised "cannot visit path" refusal with zero Term
calls. The twenty-odd scripted runner tests keep passing under L only
if `run-aloemacs-with-hosts` keeps its signature as a test shim and the
Aloe loop preserves, per iteration, exactly one `columns`, one `rows`,
one flushing `write`, one `read-event`, never `read-key` or
`write-line`, no Term call after quit, and the startup visit's `kind`
then `read` before the first frame. Several doubles are four-method
interfaces, and one raises on `write-line`.

Documents G contradicts or dates: `docs/gel.md` sections 5-6,
`docs/handoff.md` ("injected only by the optional checked terminal
runners"), `docs/decisions.md` 2026-09-04, checkpoints 0086 and 0088
(historical, dated not rewritten), host-queries spec sections 1, 6.3,
8.2, 12.5, 13, 14. Documents L contradicts: loop spec section 7,
runner-check 000's non-goal at line 378 ("Moving the loop into an Aloe
method"), the aloemacs README's "Term only at the runner" and its
alternate-screen and motion sentences, and the mouse and
alternate-screen placement of the bracket bytes "in the runner, as
terminal setup, outside any Aloe send". SPEC section 14,
`docs/philosophy.md`, and the README lock "Host stays a typed injected
capability" are compatible with both, provided `make-driver` and the
file-less REPL stay capability-free; "Default environments contain no
optional capability" wants one clarifying sentence.

## Recommendation

**Superseded in part.** This is the first proposal, kept as written.
The review below replaced four of its points: `bin/aloe` is not the
only runner, `term-run.rkt` and `fs-repl.rkt` stay until a scratch-file
convention exists, the cycle guard is its own checkpoint ahead of the
runner series rather than second inside it, and the loop is pinned by
a sampled-peak test rather than a custodian ceiling. The current order
is "Revised order, after review" at the end of this section.

Keep the boundary. Make `bin/aloe` the only runner, in this order.

1. **Language spine: manifest-driven `bin/aloe`.** A call-with factory
   clause in the manifest grammar, which the language server ignores by
   rule and never loads. Split `term.rkt` so `term-interface` loads
   without tui-term. `run-cli` reads the row keyed by the file it is
   given, in that file's folder only, nests the factories in row order,
   injects on the base, loads, and refuses when the factory's receiver
   interface is not `eq?` to the row's export. It prints the reader's
   failure reason instead of the editor's silent miss, so a missing
   tui-term is an error, never a hostless run. A small `args` host, one
   method returning `(List String)`, carries the program's arguments;
   the crossing type already exists. Gel is the first consumer: a
   `gel/run.aloe` whose last form is today's entry send, because tests
   load `gel/main.aloe` expecting definitions only. Delete `term-run.rkt`,
   `fs-repl.rkt`, and `gel-run.rkt` in the last checkpoint, after a hand
   check, with every disappearing pin listed. `make-driver` and the bare
   REPL stay capability-free. SPEC section 14 needs at most one
   clarifying sentence. This is a charter, not a brief: factory shape,
   grant policy, REPL interplay, and the failure surface are open.
2. **Language spine: checker cycle guard.** The recursion hang above,
   with its test. Small and local.
3. **Aloemacs: loop into Aloe.** A new `examples/aloemacs/run.aloe`
   holds the loop and the startup visit; `main.aloe` keeps its exact
   datums and its fs-only manifest row; `run.aloe` gets a row naming
   `fs-host`, `term`, and `args`. The alternate-screen and mouse bracket
   stays in Racket as a per-application call-with factory in a shrunken
   `aloemacs-run.rkt`, because Aloe has no `dynamic-wind` and the
   scripted tests assert no enable bytes in the output.
   `run-aloemacs-with-hosts` keeps its arity as the test shim. The 20 ms
   bar transfers through the scripted term's timestamps; a memory bar
   under a custodian limit pins the tail shape. This reopens loop spec
   section 7 and runner-check 000's non-goal, so it is a charter under
   the aloemacs map.

Do not: add an in-source declaration (the file would grant itself
authority, Racket module paths would appear in Aloe source, and the
inject-a-double-then-load test idiom would need an "already satisfied"
rule); open an FFI; add a Deno-style flag (the program's author writes
the manifest, and the trust boundary is the `host/racket` collection,
as project 9 already accepted); add tui-term to `info.rkt`; make terminal
modes Term methods; search parent folders for a manifest; design
networking or concurrency hosts here.

The program already declares its need as a type: `(AloemacsSession H)`
and `(Fs new fs-host)`. The manifest is the grant. Keeping the two apart
is what makes doubles free.

### Revised order, after review

Grok's review the same day (next section) moved the order to this, which
Claude accepts:

1. The checker cycle guard, on its own spine checkpoint, first. The bug
   is under `Fs` and `AloemacsSession` today.
2. The tail-call sentence in SPEC and a language-suite test, a second
   small spine checkpoint.
3. The manifest runner charter, with the reader amendment before any
   manifest in the tree grows a fifth element, Gel first,
   `term-run.rkt` and `fs-repl.rkt` kept until a scratch-file
   convention exists (`gel-run.rkt` goes when Gel moves to
   `gel/run.aloe`), and `aloemacs-run.rkt` still owning the loop.
4. The Aloemacs loop charter after those, with the memory bar as a
   precondition.

## Where the reviewers differ

**Superseded in part.** The REPL and the deletion order were settled by
the review below: a row whose factory holds the TTY runs the file and
exits while a constructor-only row may enter the REPL, and
`term-run.rkt` and `fs-repl.rkt` are kept. The bracket placement stands
as agreed here.

The three judges and the critic converged on the conclusion and the
order. They differed on three points.

- **Where the alternate-screen and mouse-motion bytes live.** The
  language-design judge: the enables are program policy, so Aloe writes
  them once before the first frame as strings (the term charter already
  calls ANSI an Aloe string), and the disables are lifetime, so the TTY
  module owns a generic reset of every mode on normal and exceptional
  exit. The ergonomics and cost judges: keep both halves in a Racket
  call-with factory, per application or selected by factory options in
  the manifest row, because Aloe has no exception path and tui-term's
  own cleanup never writes `1049l`. Claude sides with the factory,
  first as a per-application module, generalizing to manifest options
  only if a second application wants the same modes.
- **Whether a configured run enters the REPL.** `bin/aloe file` without
  `--quit` opens the REPL after loading. Inside a TTY factory's extent,
  `read` would see tui-term key structs. Options: a configured run
  implies `--quit`; the REPL runs after the extents exit, with hosts
  gone; the REPL is allowed only when no factory holds the TTY. The
  same answer decides whether `fs-repl.rkt`'s use case survives.
  Unresolved.
- **When to delete the small runners.** The first answer: outright.
  The cost judge: last, after the manifest path has a hand check, in a
  checkpoint that names every pin that disappears, because those files
  are the only interactive proof points besides Aloemacs. Claude agrees
  with the latter.

One judge also disagreed with the Deno instinct in the first answer:
flags exist there because the code is third-party; here the sandbox the
project relies on is inside the program, the Newspeak or OCaml-functor
shape of `(AloemacsSession H)`, and the outer grant can be folder
configuration bounded by the collection rule.

## Review, 2026-10-17

Later the same day the user brought Grok's review of this record and of
the sketch, then Grok's answer to Claude's reply. Both are verbatim in
[`grok-review.md`](grok-review.md). This section records where the
review moved the position and what the two now agree to lock.

### Agreed without change

Keep the boundary; the awkwardness is the missing entry point; the
manifest is already the declaration and an Aloe-source declaration
would be a second source of truth that fights the inject-then-load test
idiom; no FFI, no `(require ...)`, no Deno-style flag; the checker hang
is a language bug whether or not any loop moves; the tail-call shape in
`eval.rkt` is as described. Grok re-ran `recursion-hang.rkt` and the
stack probe and reproduced both.

### Objections, and what happened to them

- **Only the toy had been shown flat; the editor loop was never measured
  for retention.** Claude ran the real session, encoding (c), for 20,000
  keys in tail and non-tail form (`retention.rkt`); Grok re-ran it and
  withdrew the objection.

  | Form | Heap after GC | Peak while running | Median gap, first and last thousand |
  |---|---|---|---|
  | Tail (Claude) | +0.32 MB | +8.5 MB | 0.96 ms, 0.96 ms |
  | Non-tail (Claude) | +0.27 MB | +44.8 MB, about 2.2 KB per pending key | 0.96 ms, 0.96 ms |
  | Tail (Grok) | +0.28 MB | +8.42 MB | 0.94 ms, 0.94 ms |
  | Non-tail (Grok) | +0.36 MB | +44.75 MB, about 2.3 KB per pending key | 0.95 ms, 0.95 ms |

  The non-tail form returns to the same heap and the same per-key time,
  so a latency bar cannot see it and a heap check after the loop
  returns cannot either. Only a peak measurement while the loop runs
  can. The natural spelling still cannot be run until the cycle guard
  lands; its steady state cannot differ, because the receiver it
  allocates before the tail send does not accumulate.
- **Tail calls are an accident of the interpreter, unstated in SPEC.**
  Agreed. Gel's loop already relies on it. It becomes a gate, below.
- **"A set or a memo" is not yet a cycle-guard fix.** Agreed; the rule
  is locked below.
- **The sketch's `run.aloe` did not typecheck**: `AloemacsSession` is
  not in scope after loading only `main.aloe`. Confirmed by probe;
  the sketch now loads `file.aloe` too.
- **The sketch decided the failed-visit question while calling it
  open.** The sketch now marks the arm open and names both answers.
- **The test shim was one host short**: a test that passes a path must
  inject an `args` double. The sketch now says so.
- **A factory clause breaks the editor until the reader changes**, since
  a fifth element makes the whole manifest broken today and a broken
  manifest counts as absent for every document in the folder. Locked:
  the reader amendment lands before any manifest in the tree grows a
  clause, in the same change as the spec amendment, and the server is
  forbidden by test to call a factory.
- **`bin/aloe` does not become the only runner.** Agreed; the chat
  overstated it. Aloemacs keeps a small Racket factory for the
  alternate-screen and mouse bracket, whose bytes must stay out of the
  scripted frame stream; a generic reset in the TTY module is the wrong
  home while Gel and Aloemacs want different modes.
- **Deleting `term-run.rkt` hurts one-off files**, which would then need
  a manifest row to run at all. Agreed: keep `term-run.rkt` and
  `fs-repl.rkt` until a scratch-file convention exists. `gel-run.rkt`
  still goes when Gel moves to `gel/run.aloe`, as the sketch's table
  says.
- **One `--quit` rule breaks one REPL case.** Agreed: a row whose
  factory holds the TTY runs and exits; a constructor-only row may
  enter the REPL.
- **The `args` host is a costume**, argv being data. Grok conceded after
  Claude's point that binding a `(List String)` by hand is a second
  injection mechanism and section 14 has one. Only the spelling is
  open.
- **Two grant paths remain** (manifest for production, injected doubles
  for tests) and can drift as they already have with `term`. Agreed
  tie: the shim reads the entry file's manifest row and injects the
  test's doubles under exactly those names, failing when the sets
  differ, reading names only.

### Locks agreed for the two gates

1. **The cycle guard.** While a method is being checked at one
   instantiation, a send of that method at the same instantiation
   assumes the annotated return type and the outer body goes on being
   checked against its annotation; a finished check can be reused at
   that instantiation; a send of a method currently being checked at a
   *different* instantiation is a type error naming both
   instantiations. The error, not a depth bound: Grok ran
   `(Loop new (List of (self h)))` and it diverges through the same
   walk, and a bound would walk several growing types and then report
   an arbitrary limit. Claude's addition, as Grok restated it: the
   in-progress set covers indirect cycles. If `run` sends `step` and
   `step` sends `run` at the same instantiation, the second `run` is a
   re-entry and assumes its annotation; `step` itself is checked in
   full. Only the re-entry of a method already in progress assumes a
   return type; no method in the middle is skipped. The rule knowingly
   rejects a finite jump to
   another instantiation, such as a method on `(Box Int)` that sends
   the same method once on `(Box String)`; no program in the tree does
   that, and a more precise rule can come when one does. Explicit
   constructors are the tempting wrong fix: under a rigid `H`,
   `handle-event` fails with `unknown message: kind`. Tests: the
   five-line `Loop` program, the `run` and `step` program above, and
   one program that recurses at a second instantiation and is refused.
2. **The tail-call test.** Not a fixed custodian ceiling: both forms
   finish within a third of a megabyte of where they started, and a
   ceiling tight enough to separate them moves with the baseline.
   Sample the peak while the loop runs; assert the tail peak stays
   within a small bound and the non-tail peak grows by at least a low
   per-iteration amount (Claude suggests 256 bytes, well under the
   1.4 to 2.3 KB observed, since the frame size is an evaluator
   internal). Keep a custodian limit only as a rail. Claude's
   cross-check: `vector-set-performance-stats!` slot 11, peak memory
   before a GC, separated the forms deterministically in the toy run
   (89.6 MB tail at every N; 217 MB and 1421 MB non-tail at 100,000
   and 1,000,000). The program under test is a non-generic class with
   no host, so the test depends on neither tui-term nor the cycle
   guard.
3. **The SPEC sentence.** A send is in tail position when it is the
   body of a method, the body of a `fn` sent `call` (and so the body of
   a `let`), the taken arm of `if`, or the taken arm of `case`;
   evaluating a receiver or an argument is not; `cond` follows `if`,
   and `if` is sugar for the `Bool` send, so the explicit form is
   covered. Verified against the evaluator on 2026-10-17: `eval-case`
   (`aloe/eval.rkt` line 288) evaluates the matching clause body and
   the else body as its last expression, and `cond` desugars in
   `aloe/parse.rkt` (`desugar-cond-syntax`, line 561).

### Not opened

Neither reviewer treats this exchange as a reason to open either
charter yet. The user's order of 2026-10-16 still has the
window-pictures performance item next.

## Open questions for a charter

The review settled several of these; where it did, the bullet now
points at the agreed rule rather than at an earlier paragraph. The
rest stay as the charter's checklist.

- Factory clause spelling: a fifth element naming an export, or a
  `(receiver MODULE EXPORT)` pair; call-with shape for every host, or
  constructors wrapped by `run-cli`. May the factory module differ from
  the interface module (needed for the term/tty split)?
- Grant policy: the folder manifest unconditionally, or behind a flag;
  an opt-out such as `--no-hosts`; the manifest read beside the program
  file, never beside the cwd.
- Failure surface of `run-cli`: messages and exit codes for a broken
  manifest, a row for another file only, a bad module path, a missing
  export, a factory that raises inside its extent, and the checker's
  unbound-symbol error when the folder has a manifest but no row.
- The `args` host, a host and not a hand-bound value (review): interface name, methods beyond a list, how `run-cli`
  splits its own flags from the program's remainder, its double.
- Which file is the program: `run.aloe` beside `main.aloe` for Gel and
  Aloemacs, with its own row; does only the entry file's row apply, as
  the queried-document rule does for the server.
- The REPL: settled by the review. A row whose factory holds the TTY
  runs the file and exits; a constructor-only row may enter the REPL.
  The charter writes it down.
- The refusal channel for a failed startup visit: Aloe has no `raise`;
  `check` prints an ugly message; a host method that raises, an exit
  host, or opening untitled with the message on the echo row.
- The loop's last form and return value, since `driver-load-port!`
  prints non-void results after the screen is restored.
- The no-growth bar: shape settled by lock 2 of the review (sampled
  peak, slot-11 cross-check, a custodian rail, a host-free non-generic
  program). The charter picks the iteration count and the bounds, and
  whether the tail shape of `run.aloe` is also pinned by source text.
- Whether `driver-prepare!` stays as test-facing API or retires with the
  runner (other tests use it today).
- Which closed documents get dated notes versus edits, and in which
  checkpoint; the spine checkpoint numbers (117 was the last, 118
  declared nonexistent); the aloemacs folder name and spoken identity.
- The scratch-file convention: `term-run.rkt` and `fs-repl.rkt` stay
  until one exists (review). What it is, a manifest row for a scratch
  file or something else, is the charter's to decide.

## Exits

This conversation had no assigned role, so it wrote nothing in the
product tree. After the review, the exits are four, in this order:

- One global checkpoint on the language spine for the checker cycle
  guard, no charter, carrying the rule and the three test programs in
  lock 1 of the review. The spine shape is `docs/checkpoints/NNNN-slug.md`,
  `tests/checkpoint-N.rkt`, and a `CHECKPOINTS.md` entry at the next
  free global number; the index says 116 and 117 are Gel-directory
  work on another branch and there is no 118. Per `docs/workflow.md`,
  the discussion hands it over as a brief for a checkpoint manager, or
  writes the one checkpoint itself. The repo's "standalone checkpoint"
  is the local `docs/design/implementation/...` shape and is not this.
- A second global checkpoint, same shape, for the tail-call sentence
  in SPEC and the language-suite test, locks 2 and 3 of the review.
- An exploration charter for the manifest runner, `README.md` and
  `charter.md`, with the open questions above, written so that the
  reader amendment lands before any manifest grows a fifth element,
  Gel moves first, `term-run.rkt` and `fs-repl.rkt` stay until a
  scratch-file convention exists, and `aloemacs-run.rkt` keeps the
  loop.
- A later aloemacs charter for the loop, written after the three above
  land, with the sampled-peak memory bar as a precondition.

The review did not treat this exchange as a reason to open any of them.
The order set on 2026-10-16 still has the window-pictures performance
item next. That is the user's call.

## Also in this folder

[`end-state-sketch.md`](end-state-sketch.md) draws the tree after both
series land: the command, every file that appears, shrinks, or goes, a
candidate manifest, a candidate `run.aloe`, and where each piece of
boundary information lives afterwards. Written the same day, at the
user's request, as a sketch and not a spec. Revised after the review.

[`grok-review.md`](grok-review.md) holds Grok's two replies verbatim.

## Probes in this folder

Scratch Racket programs, not tests. Their effects are in a `main`
submodule, so `raco test` runs nothing; run them with `racket`. They
require the repo by relative path from this folder.

| File | What it measures | Run |
|---|---|---|
| `loop-stack.rkt` | memory and time of a tail-recursive Aloe loop, and a non-tail control | `racket loop-stack.rkt tail 1000 10000 100000` |
| `loop-cost.rkt` | per-key gaps of variants A, B, C above, and byte identity of their frames | `racket loop-cost.rkt` |
| `recursion-hang.rkt` | the checker hang on a recursive method of a generic class; **does not terminate** | `timeout 10 racket recursion-hang.rkt` |
| `retention.rkt` | the scope check for `run.aloe`, then the editor loop over 20,000 keys in tail and non-tail form, with sampled peak memory | `racket retention.rkt` (about 45 s) |

`loop-stack.rkt`, `loop-cost.rkt`, and `retention.rkt` need the tui-term package, because
they build the Term double with `make-term-receiver` from
`host/racket/term.rkt`.
