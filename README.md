
# ALOE

Scheme is a small gem. Aloe is a similar gem with two new facets.

1. **Send, not apply.** A list is `(receiver selector arg …)`. The selector is a
   symbol; it is not evaluated. Functions are objects that understand `call`.
2. **Types, inferred where you do not write them.** Classes declare fields and
   methods. The rest of the program should not repeat those types.

In the 1970s Steele and Sussman studied Hewitt’s actor model and found that
message send and function application could express each other. Scheme took
application as the primitive. Aloe takes the other branch: a Lisp whose kernel
is sending a message.

The core stays small on purpose. Libraries and programs grow the rest
([lib/list.aloe](lib/list.aloe), [examples/](examples/)). See
[docs/philosophy.md](docs/philosophy.md) and [SPEC.md](SPEC.md).

`ALOE = Scheme + Smalltalk + Types`

Demo of code completion in vscode:

https://www.youtube.com/watch?v=YuIjug7elPY

## Status

Aloe remains an exploratory prototype. Local `main` includes the language and
filesystem work through checkpoint 107, String checkpoints 114–115, and the
local editor/LSP projects; this is not a finished public release.
The implementation is a definitional interpreter
plus a type checker,
written in Racket.
There is no bytecode VM and no native compiler.
Types are checked before evaluation;
inference fills in what you do not write.

## Layout

- [SPEC.md](SPEC.md) — language law, including constructors, receiver-anchored
  `case`, and typed host capabilities
- [CHECKPOINTS.md](CHECKPOINTS.md) — implementation order
- [docs/workflow.md](docs/workflow.md) — conversation pipeline for new work
- [AGENTS.md](AGENTS.md) — rules for a coding agent
- [lib/list.aloe](lib/list.aloe) — Aloe implementations of `fold`, `reverse`, and `map`
- [lib/string.aloe](lib/string.aloe) — Aloe implementation of `starts-with?`
- [lib/option.aloe](lib/option.aloe) — loadable `Option` with `None` and `Some`
- [lib/fs.aloe](lib/fs.aloe) — thin `Path`, `Entry`, and `Fs` filesystem API
- [lib/disk.aloe](lib/disk.aloe) — live `Disk`, `Location`, and `Item` filesystem API
- [examples/boids.aloe](examples/boids.aloe) — target program
- [examples/mpl/](examples/mpl/) — 0.2 computer algebra fragment
- [docs/editor/](docs/editor/) — source-query and LSP local-project documentation
- [editors/vscode/](editors/vscode/) — VS Code hover/completion client
- [docs/journal/](docs/journal/) — release notes

## Driver

From the project directory, after loading the Racket path from your profile:

```sh
./bin/aloe
./bin/aloe examples/boids.aloe
./bin/aloe --quit examples/boids.aloe
```

The first command starts the REPL. Loading a file without `--quit` evaluates it
and then opens the REPL with its definitions and classes still available.

## Bytecode

Racket bytecode is written under `compiled/` next to the sources and
is gitignored. Refresh it before a launch when `.rkt` files have
changed and you are not about to run the tests:

```sh
raco make host/racket/aloemacs-run.rkt bin/aloe
```

Tests refresh bytecode for the modules they load, including test-only
modules the command above does not reach:

```sh
TMPDIR=/tmp raco test -j 4 -y tests
```

The command runs up to four test files at once, each in its own
process. A narrower path works the same way:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs
```

For an optional per-file timing report of the complete suite, run:

```sh
TMPDIR=/tmp racket bin/suite-time.rkt
```

While the ordinary command runs four files at once, the report
runs files serially with `raco test -y --process`, streams test
diagnostics, and lists elapsed seconds, outcomes, and observed
bytecode work, slowest first. `rebuilt` means compilation, recompilation,
or timestamp update work was observed; `warm` means no such work was
observed; `unknown` means observation was incomplete or unfamiliar.
Durations include each child's startup, bytecode updates, and testing.
The command rejects `info.rkt` under `tests/` because it does not support
that discovery configuration.

Each completed report, including one with test failures, atomically
replaces the gitignored `.suite-time/previous.rktd`. The next report
compares matching files with that record, showing previous outcomes
and bytecode labels beside duration deltas. Interrupted or operationally
aborted reports preserve the previous record. Timing differences do not
fail tests. The ordinary test commands above do not update this history.

`./bin/aloe` and `racket host/racket/aloemacs-run.rkt` load that
bytecode and do not rebuild it. A launch, or a test run that omits
`-y`, can load an old `.zo` of a module that was not itself edited,
so the run does not match the sources.

## 0.1 goal

Typecheck [examples/boids.aloe](examples/boids.aloe) and evaluate `(demo step)`.

Interpreter + type checker in Racket only. No compiler.

Legal now: Aloe 0.1 typechecks and evaluates the complete [examples/boids.aloe](examples/boids.aloe) program, including both trailing `step` sends.

## 0.2 additions

Aloe 0.2 adds protocols and method overloads. [examples/mpl/](examples/mpl/) is a
Cohen-style CAS fragment built around the `Math` protocol: primitive `Int` is
not `Math`, so algebraic constants use `Num`. The default printer sends `show`
when an object provides it, while the REPL command `:raw` prints the structural
`#<…>` form. To try it, load the MPL core and bind a symbol:

```lisp
(load "examples/mpl/core.aloe")
(define x (Sym new "x"))
```
