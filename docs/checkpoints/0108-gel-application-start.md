# Checkpoint 108 — Application-supplied Gel start value

**Branch.** Continue on `experiment/gel-directory-surface`.

**Depends on.** Checkpoint 107 (`Directory.entries`) and the existing Gel
machine through checkpoint 88.

**Status.** Complete (reviewed 2026-09-09 on
`experiment/gel-directory-surface`).

## Goal

Remove the hard-coded `Point` application from the Gel TTY runner. Give
`GelMain` one generic entry message that starts a one-item stack from an
ordinary Aloe value, and make the runner load an Aloe application file whose
top-level `gel-start-value` binding supplies that value.

Preserve the current Point experience as a tiny Aloe application, not as
knowledge in the Racket runner:

```sh
racket host/racket/gel-run.rkt examples/gel-point.aloe
```

This checkpoint changes launch only. Do not add directory presentation,
`fs-host`, pop, value-item rows, new key assignments, or stack rendering.

## Depends on

- Parent: `experiment/gel-directory-surface` at the working design commit,
  stacked directly on `experiment/filesystem` through checkpoint 107.
- Design authority: `docs/gel-directory-surface.md` §4 architecture, §6
  disposable Point assumptions, and the first item in §7 progression.
- Gel authority until amended by this experiment: `docs/gel.md`.
- Aloe law: `SPEC.md`. Evaluation remains send; `(f x)` is not function
  application, and this checkpoint adds no special form or dispatch rule.
- The checked driver and Term boundary from checkpoints 83–88 remain the
  only runner boundary.
- `GelStack.push` already wraps an ordinary value in one `Mirror`, and
  `GelMain.call` already runs a caller-supplied `GelStack`.

The implementer will not have a separate checkpoint-manager brief. Every
rule needed for this slice is in this document.

## Authority / starting point

Facts before this checkpoint (do not redesign them):

- `gel/main.aloe` loads `gel/loop.aloe` and defines `GelMain.call` over an
  already-built `GelStack`.
- `gel-empty-stack` is immutable. `(gel-empty-stack push value)` creates a
  one-item stack whose TOS mirror holds `value`.
- `host/racket/gel-run.rkt` creates one driver, injects only `term`, loads
  `gel/main.aloe`, loads `examples/point.aloe`, constructs two Points in a
  quoted entry send, and discards the returned stack.
- The runner has no Gel key policy or rendering logic. Keep it that way.
- `driver-load-file!` checks a whole file before evaluating its first
  expression. Use it for both Gel and application source.
- `driver-eval!` checks the launch send before evaluating it. Keep using the
  same driver for injection, both loads, and launch.
- Default drivers and `bin/aloe` contain neither `term` nor `fs-host`.
- `lib/disk.aloe` is complete through live `Directory.entries`, but this
  checkpoint does not load it or inject filesystem authority.

## Exact file scope

**May edit during implementation:**

- `gel/main.aloe` (add `GelMain.start` only)
- `host/racket/gel-run.rkt` (take one application path and remove Point
  knowledge)
- `examples/gel-point.aloe` (new, minimal launch application)
- `tests/checkpoint-108.rkt` (new)
- `CHECKPOINTS.md` (append checkpoint 108 only)
- `docs/gel.md` (launch/current-scope text only: the runner takes an Aloe
  application and no longer owns Point)
- `docs/handoff.md` (current state and next pressure only)
- `docs/gel-directory-surface.md` status/progression notes only after the
  checkpoint is green; do not change its locked screen or deferred scope
- `docs/decisions.md` (optional short dated launch-contract addendum only)

**Do not edit:**

- `aloe/`
- `host/racket/term.rkt`, `host/racket/term-run.rkt`, or
  `host/racket/fs.rkt`
- `gel/menu.aloe`, `gel/stack.aloe`, or `gel/loop.aloe`
- `lib/`, including `lib/disk.aloe` and `lib/fs.aloe`
- `bin/aloe`
- `SPEC.md`
- historical checkpoint documents
- historical tests 1–107 unless a living source assertion proves impossible;
  no such edit is expected by this specification
- Boids, MPL, `examples/point.aloe`, or unrelated examples

Do not add a shared runner framework, plugin API, capability registry, new
host method, or filesystem runner in this checkpoint.

## Required behavior

### Generic Gel entry

Add one method to `GelMain` while preserving its existing `call` and `loop`
methods byte-for-byte:

```aloe
(start (type T)
  (value T)
  GelStack
  (self call
    (gel-empty-stack push value)))
```

The complete public relationship is:

```aloe
(gel-main start value) ; constructs a one-item stack, then enters Gel
(gel-main call stack)  ; existing lower-level entry for an assembled stack
```

Lock:

- `T` is method-local and fresh at every send. Starting separate sessions
  from unrelated Aloe types must typecheck without a common source type.
- `start` accepts an ordinary Aloe value, not an expression string, Racket
  value, thunk, function, or new wrapper class.
- It performs exactly one `push` from `gel-empty-stack`; it does not accept or
  construct history below the supplied value.
- `GelStack.push` remains responsible for reflection. Do not call
  `(Mirror of value)` in `GelMain.start`.
- `GelMain.call` remains the entry for tests or applications that deliberately
  assemble a stack. Do not change its selector, parameter type, return type,
  initial `GelStep`, loop, output order, or result.
- Do not rename `gel-main`, `GelMain`, `call`, or `loop`.
- Do not add a top-level `gel-start` helper. Checkpoint 74 removed the old
  callable start wrappers; they stay absent.

### Aloe application contract

Add `examples/gel-point.aloe` with exactly the application-level ownership
needed by the runner:

```aloe
(load "point.aloe")

(define gel-start-value
  (Point new 10 20))
```

The application file owns the concrete class and value. It does not load
Gel, mention `term`, build a `GelStack`, call `gel-main`, define key policy,
or perform output. The runner preloads Gel and launches the conventional
binding after the application file has been checked and evaluated.

`gel-start-value` is a runner/application convention, not an Aloe special
form, default binding, Gel library global, host capability, or required class.
An application may bind it to any well-typed Aloe value. A missing binding is
an ordinary checked `unbound symbol: gel-start-value` launch failure.

Do not add a general application manifest, command registry, callback, or
module system around this convention.

### TTY runner

Change the public command shape to require exactly one Aloe application file:

```text
racket host/racket/gel-run.rkt path/to/application.aloe
```

Within the existing `call-with-tty-term-receiver` extent, in this order:

1. create one `make-driver` state;
2. inject the supplied production Term receiver as `term`;
3. load `gel/main.aloe` with `driver-load-file!`;
4. load the supplied application path with `driver-load-file!`; and
5. evaluate and discard the result of:

   ```aloe
   (gel-main start gel-start-value)
   ```

The two loads and entry send use that same driver. Keep the application path
as supplied so Aloe `load` inside it resolves relative to the application
file. Do not read the application with Racket `read`, extract its last value,
splice a host value into source, or create a second evaluator/checker pair.

Remove from `host/racket/gel-run.rkt`:

- the runtime path for `examples/point.aloe`;
- the direct load of `examples/point.aloe`;
- every `Point` constructor expression; and
- the hard-coded two-Point stack.

The source file must not contain the token `Point` after this change. It may
know `gel-start-value` and the generic Gel entry send; it must not know what
class that binding has.

Keep the runner thin:

- inject only `term`; do not require `fs.rkt` or inject `fs-host`;
- retain `driver-inject-host!`, `driver-load-file!`, `driver-eval!`, and
  `make-driver` rather than reaching into checker/runtime environments;
- retain the `gel: ` failure prefix, CRLF, and status 1 for handled failures;
- evaluate no Gel key, menu, stack-operation, or rendering policy in Racket;
- discard the final `GelStack` as before; and
- keep all checked loading and evaluation inside the TTY extent so the
  terminal is restored on success, failure, or break.

Argument validation occurs before opening a TTY. With anything other than one
argument, print exactly:

```text
usage: racket host/racket/gel-run.rkt path.aloe
```

to the current error port with LF and exit status 2. Do not attempt to create
a terminal or driver on that path.

This checkpoint may restrict the Gel runner to the `.aloe` / `.sexpr` source
paths already accepted by `driver-load-file!`; do not add a second extension
validator in the runner.

### Observable Point application behavior

With a scripted Term that returns only `"q"`, launching
`examples/gel-point.aloe`:

- checks as a complete Gel and application load before entering the loop;
- prints the existing Point TOS and derived menu beginning with
  `TOS: #<Point 10 20>\r\n` and `1  x  0\r\n`;
- echoes `key q\r\n`;
- returns a `GelStack` of length 1 whose TOS subject is the original Point;
  and
- produces no application-load result text.

The former second Point was runner-owned demo state and is deliberately not
preserved. Typed stack-pick behavior remains covered by the lower-level Gel
tests and by `GelMain.call`; do not add another Point merely to recreate that
runner fixture.

## Tests and hand checks

Add `tests/checkpoint-108.rkt`. Use scripted production Term receivers; the
automated suite must not require a physical TTY or the optional terminal
package.

Cover at least:

1. A fresh ordinary driver has no `term`, `fs-host`, `gel-start-value`, or
   `GelMain` binding.
2. After injecting scripted Term and loading `gel/main.aloe`,
   `(gel-main start 10)` typechecks as `GelStack`. A quit-only run returns a
   one-item stack with TOS subject `10`, preserves `gel-empty-stack` at length
   zero, and has the unchanged Int transcript followed by `key q\r\n`.
3. A separate driver can use `(gel-main start "hello")`; the generic entry is
   not accidentally monomorphic.
4. Existing `(gel-main call assembled-stack)` behavior remains available. A
   quit-only two-item stack is returned by identity and keeps its order.
5. Loading `examples/gel-point.aloe` binds `gel-start-value` to
   `(Point Int)`. Launching it through `(gel-main start gel-start-value)` has
   the Point behavior above and returns a one-item stack.
6. `examples/gel-point.aloe` contains no `term`, `GelStack`, `gel-empty-stack`,
   `gel-main`, or host language form.
7. `host/racket/gel-run.rkt` uses one checked driver, loads Gel before the
   supplied application path, and evaluates exactly the generic launch send.
   Its source contains no `Point`, `point-path`, direct environment binding,
   evaluator, parser, reader-based source loading, Gel domain helper, or
   `fs-host` injection.
8. Running the Gel runner with no arguments exits 2 and prints the exact usage
   line without opening a TTY. Also cover more than one argument if the test
   stays narrow.
9. A missing `gel-start-value` in an otherwise valid application reaches the
   ordinary Aloe unbound-symbol failure when the launch send is checked; do
   not add a Racket-side preflight or custom error.
10. `term-run.rkt`, the Term descriptor, the filesystem host, and default
    drivers remain unchanged. The full existing suite remains green.

For scripted runs, mirror the runner's checked order with one driver rather
than introducing a public runner abstraction solely for tests.

### Non-TTY hand check

From the project directory:

```sh
racket host/racket/gel-run.rkt
```

Expected stderr and status:

```text
usage: racket host/racket/gel-run.rkt path.aloe
```

Exit status: `2`.

### Physical-TTY hand check

When `tui-term` and a physical TTY are available:

```sh
racket host/racket/gel-run.rkt examples/gel-point.aloe
```

The first screen shows `#<Point 10 20>` and its existing derived rows. Press
`q`; Gel echoes the key, exits, and restores the terminal. This check is
informative when no physical TTY is available, but the scripted equivalent is
required.

## CHECKPOINTS.md and handoff

Append only:

```text
## 108. [Application-supplied Gel start value](docs/checkpoints/0108-gel-application-start.md)

- `GelMain.start` creates a one-item stack from any Aloe value; the TTY runner
  loads an application-provided `gel-start-value` and contains no `Point`
  knowledge. No filesystem capability or directory surface yet.
```

Update `docs/handoff.md` to say tests are green through 108 on
`experiment/gel-directory-surface`; Gel launch is application-supplied; the
Point sample is an Aloe application; and the next approved pressure is back /
pop, not value rows or filesystem injection yet.

Update only the corresponding current-launch paragraphs in `docs/gel.md`.
After the checkpoint is green, `docs/gel-directory-surface.md` may mark the
first progression item complete without resolving its open item-key,
stack-rendering, snapshot, runner-shape, or File-surface questions.

## Acceptance

This checkpoint is complete when the checked TTY runner has no concrete Aloe
class knowledge, an Aloe application supplies one generic start value, the
Point sample launches with the preserved menu through that contract, and the
existing lower-level stack entry remains unchanged.

Run:

```sh
raco test tests/checkpoint-108.rkt
raco test
racket host/racket/gel-run.rkt
git diff --check
```

The checkpoint test and full suite must pass. The no-argument command must
print the exact usage line and exit 2. Run the physical-TTY check when the
optional dependency and a real terminal are available. Stop for review
without committing and without starting checkpoint 109.

## Explicit non-goals

- No live `Directory` start and no directory-aware runner yet.
- No `fs-host` import or injection in ordinary Gel.
- No changes to `Disk`, `Location`, `Directory`, `File`, or `Item`.
- No pop, Escape handling, pending-send cancellation change, or one-item
  stack floor rule.
- No value-item rows, list selection, authored Directory menu, item-key pool,
  reserved `u`, paging, search, or multi-column rendering.
- No extra stack levels, stack editing, drop, swap, or return stack.
- No `read`, `size`, `enter`, `(here entries)`, Git, processes, editor, shell,
  workspace, hook, plugin, pane, or GelFS framework.
- No new Aloe syntax, special form, dispatch rule, mutation, inheritance,
  macro, numeric coercion, host crossing type, or host capability.
- No general launcher framework, manifest, application registry, or dynamic
  Racket callback exposed to Aloe.
- Do not implement checkpoint 109 in the same change.
