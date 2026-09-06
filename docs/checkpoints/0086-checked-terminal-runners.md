# Checkpoint 0086 — Checked terminal runners

Status: Proposed

Depends on checkpoint 0085, typed atomic host injection.

## Goal

Move Aloe's two optional terminal entry points onto the checked driver path
established by checkpoint 0085.

`host/racket/gel-run.rkt` and `host/racket/term-run.rkt` must each create one
driver, explicitly inject the production Term receiver with
`driver-inject-host!`, and use that same driver for checking and evaluation.
They must no longer assemble a runtime-only environment or call the evaluator
directly.

This is an integration checkpoint.  It adds no new capability mechanism or
terminal behavior.

## Common runner structure

Within the dynamic extent of `call-with-tty-term-receiver`, each runner must:

1. inject the supplied receiver as `term` into a fresh driver;
2. load source through a checked driver operation; and
3. evaluate any runner-owned entry expression through `driver-eval!`.

The same driver instance must own both environments throughout a run.  Do not
recover its component environments for manual binding, parsing, typechecking,
or evaluation.

Consequently, the runners should no longer depend directly on:

- `env-define!`;
- `eval-expr`;
- `make-top-level-env`;
- `parse-datum`; or
- `read-program` for evaluation outside the driver.

Do not introduce a shared runner framework for two small files.  Keeping each
entry point direct and locally readable is preferable here.

## Gel runner

Preserve the existing Gel sequence:

1. open the TTY-managed Term receiver;
2. inject it as `term`;
3. load `gel/main.aloe`;
4. load `examples/point.aloe`; and
5. evaluate the unchanged `gel-main` entry send with the same two-Point demo
   stack and ordering.

Use `driver-load-file!` for the two known `.aloe` files and `driver-eval!` for
the entry send.  Definitions loaded from those files must not add runner
output, and the entry result remains discarded by the command-line wrapper.

The runner remains only the host lifecycle and launch skin.  Gel key policy,
menus, stack operations, recursion, and domain behavior stay in Aloe.

## General Term runner

Preserve the command:

```text
racket host/racket/term-run.rkt path/to/program.aloe
```

The supplied file must be checked as a complete program before its first
expression is evaluated.  Successful non-`Void` expression results continue
to use the driver's ordinary result printer in source order.

The current runner accepts any readable path even though its usage text says
`path.aloe`.  Do not accidentally introduce an extension restriction merely
by choosing a driver helper.  `driver-load-port!` may be used inside
`call-with-input-file`, with the path supplied as its source path, to preserve
that behavior.

Update the runner's stale comment about two key shapes.  The production Term
descriptor now has one checked `read-key` result shape: `String`.

## Checking and effects

For each loaded file, parsing and full-file typechecking precede evaluation.
An ill-typed later expression therefore prevents earlier expressions in that
file from performing terminal or other Aloe effects.

This checkpoint does not add a transaction spanning multiple files.  The Gel
runner continues to load its two files in order; successful completion of the
first load is not rolled back if the second load fails.

Runtime host guards from checkpoint 0084 remain the final defense against a
bad Racket implementation or value.  Runner migration must not bypass or
duplicate those guards.

## TTY lifecycle and command behavior

Keep all injection, checking, loading, and evaluation inside
`call-with-tty-term-receiver`.  Thus normal completion, static errors, runtime
errors, and breaks all leave through the existing `with-term` extent so the
terminal is restored.

Preserve the current command behavior:

- `term-run.rkt` requires exactly one argument;
- its usage failure exits with status 2 and retains the existing usage text;
- its handled failures retain the `aloe-term: ` prefix and exit status 1;
- Gel failures retain the `gel: ` prefix, CRLF, and exit status 1; and
- successful runs retain their current exit behavior.

Do not make either runner part of ordinary `bin/aloe`.  Loading the default
driver must not load `tui-term`, create a terminal, or inject `term`.

## Tests

Add `tests/checkpoint-86.rkt` and adjust the existing Gel runner coverage to
exercise the checked path.

Cover at least:

- a scripted Term receiver injected into a driver can load and run a valid
  Term-using file with the existing terminal transcript and result printing;
- an ill-typed later expression in such a file prevents an earlier
  `read-key` or `write-line` effect;
- the scripted quit-only Gel run retains its original stack and transcript;
- the scripted digit-then-quit Gel run retains its stack result and
  transcript;
- the scripted Gel runs use `driver-inject-host!`, checked file loading, and
  `driver-eval!` rather than separate runtime and checker setups;
- both runner sources use `driver-inject-host!` and contain no direct
  environment binding or evaluator calls;
- the Gel runner still contains no Gel domain helpers or key policy;
- the Term runner's no-argument command preserves its usage text and exit
  status without attempting to open a TTY;
- a fresh ordinary driver remains free of `term`; and
- the existing checkpoint 0084 and 0085 host-boundary tests remain green.

Automated tests must not require a physical TTY.  Use scripted production Term
receivers for behavior and narrow source/dependency assertions for the thin
TTY wrappers.  Do not add a public runner abstraction solely to make the
wrappers mockable.

## Hand checks

From the project directory, the usage path must remain:

```sh
racket host/racket/term-run.rkt
```

It should print:

```text
usage: racket host/racket/term-run.rkt path.aloe
```

and exit with status 2 without opening the terminal.

When an interactive TTY and the optional `tui-term` package are available,
this command should retain the current Gel behavior:

```sh
racket host/racket/gel-run.rkt
```

The physical-TTY check is informative rather than a CI requirement; the
scripted tests are the reproducible acceptance evidence.

## Acceptance

This checkpoint is complete when both optional terminal runners use one
checked driver and the production Term descriptor from injection through
evaluation, while their valid observable behavior and failure wrappers remain
unchanged.

The resulting runner files should be shorter or comparably small, with no
local loader/evaluator machinery that duplicates the driver.

Run the checkpoint test, the full suite, the non-TTY usage hand check, and
`git diff --check`.  All must pass.  Stop for review without committing.

## Explicit non-goals

- Do not change the Term interface or its `read-key`/`write-line` behavior.
- Do not add crossing types, host handles, optional methods, or new effects.
- Do not add host reflection or source-written host type annotations.
- Do not design or implement a filesystem capability.
- Do not add a general capability registry, plugin system, or FFI.
- Do not add a second dispatch, evaluator, checker, or environment pair.
- Do not move Gel application behavior into Racket.
- Do not inject Term into `bin/aloe` or any default environment.
- Do not require a real TTY during the automated suite.
- Do not redesign CLI argument parsing, output formatting, or error wording.
- Do not change Boids, MPL, or unrelated examples.
