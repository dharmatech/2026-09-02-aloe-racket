# suite-time 000 — Evaluate each comparison side once

**Status: Ready to implement.**

## Goal and stop

Repair `same-session` in the three named Aloemacs test files so each
supplied Aloe datum is evaluated once per side, then every existing
assertion observes the stored values. Prove the effect contract with
the existing counted filesystem doubles and record warm serial
before-and-after evidence for both keymap files.

Stop after this slice is green and its evidence is reported. Do not
add the timing report or repair the separate `point` helper.

## Authority, dependencies, and identity

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: `(suite-time, 000)`, spoken **suite-time 000**. Local
  numbering; do not edit `CHECKPOINTS.md` or `docs/checkpoints/`.
- Design authority: [`../spec.md`](../spec.md), §§1–3, §4 in full,
  and the first-layer acceptance conditions in §7. §§5–6 describe
  later work and are not this assignment.
- Process and host verification: [`docs/workflow.md`](../../../../workflow.md).
  Read the project-root `AGENTS.md`, `SPEC.md`, and `CHECKPOINTS.md`
  before writing code. `SPEC.md` remains Aloe language law.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
  Run all commands there. Use installed Racket and Rackunit; add no
  package or tool dependency.
- Starting point: `main` at `9af2f39`. The human chooses the branch;
  this checkpoint does not assign a new one. No preceding suite-time
  checkpoint exists.
- The implemented `aloemacs/runner-check` repair is a predecessor.
  Its preparation behavior stays unchanged. `driver-eval!` still
  parses, typechecks, and evaluates every call; legacy generic method
  bodies still receive their existing checking. Neither withdrawn
  checker-recursion work nor a checker cache is a prerequisite.

If you have been told to read this file, this is the whole assignment,
together with the authority named above.

## Exact file scope

May edit only:

- `tests/aloemacs/keymap-session.rkt`: `same-session` and focused
  regression coverage for its contract;
- `tests/aloemacs/keymap-prefix.rkt`: `same-session` and focused
  regression coverage for its contract;
- `tests/aloemacs/buffer-value.rkt`: `same-session` and focused
  regression coverage for its contract.

There are no new source or test files in this checkpoint. Existing
call sites require no rewrite. Keep their fixtures, independent
expected-value constructors, log resets, and assertions.

Must leave untouched:

- all other tests and helpers, including `point` and `history-len`
  in `keymap-session.rkt`;
- `SPEC.md`, `CHECKPOINTS.md`, `AGENTS.md`, all design/workflow
  documents, the root `README.md`, and `.gitignore`;
- all of `aloe/`, `host/`, `examples/`, `lib/`, and the existing
  `bin/aloe` command;
- the future `bin/suite-time.rkt`, `tests/suite-time/`, and
  `.suite-time/` report/history surface.

If another repository file is necessary, stop and return the
checkpoint to the manager rather than widening its scope. Timing
records and transcripts may stay under `/tmp`; do not commit them.
Leave existing bytecode caches in place; `compiled/` stays uncommitted.

## Required helper behavior

At the beginning of each `same-session`, use that file's existing
`def!`, in exactly this order:

```racket
(def! st 'comparison-actual actual)
(def! st 'comparison-expected expected)
```

Actual is evaluated before expected. Each successful call evaluates
each supplied datum once. A symbol argument performs one lookup and
stores that value; an expression argument computes and stores its
result. These names are currently free and become helper-owned scratch
bindings. Neither existing nor new call sites may use them as fixtures
or supplied arguments.

After those definitions, use `comparison-actual` and
`comparison-expected` in every assertion, including whole-value
equality. Never splice the original `actual` or `expected` datum into
a later field, editor, text, frame, or empty-list check. Each definition
and observation still goes through `driver-eval!` and normal checking.
Do not switch to `driver-prepare!` or add a driver mock or production
instrumentation.

The helper must not bind or rebind fixture names `actual`, `expected`,
`result`, or `saved`. A bound name retains the value its call site
already computed. This contract does not deduplicate subexpressions
inside an independently constructed expected datum.

### Preserve every observation

Keep the helpers' complete current inventory:

| Observation | Files |
|---|---|
| Whole-session structural equality, including constructor payloads and UndoFrames | All three |
| `buffers fs echo searching query origin wrapped failing kill-ring pending prompt last-submission waiting-command windows`, then `current-buffer editor path` | All three |
| Editor `text point quit scroll-row scroll-col history mark text-rows` | Both keymap files |
| Text `to-string` equality | `keymap-session.rkt` |
| Frames `(8 1)` and `(12 6)` | `keymap-session.rkt` |
| Frames `(8 1)` and `(20 4)` | `keymap-prefix.rkt` |
| Actual buffers' `before` and `after` are empty | `buffer-value.rkt` |

Preserve other assertions, existing type-error tests, exact host-call
checks, failure propagation, and immutable-source checks. Do not add
another file's observations merely to make the helpers uniform.

### Existing call sites and effects

The accepted spec §4.2 completed the call-site inventory. **No
existing call site needs an explicit second send added.** Existing
repetitions are already explicit or belong to separate assertions;
keep them as written.

- In `keymap-session.rkt`, the inline refused visit in “successful
  existing and missing visits reset pending; rejection retains source”
  inspects `dir` and selects `armed`. Keep the separate preceding
  `present?` send: those are two explicit visit attempts. The inline
  `(untitled save-key)` in “armed ordinary rebuilds, direct wrappers,
  search, kill, and save preserve pending” has no path, performs no
  host call, and yields the failed-echo payload once.
- Table/search Save expectations can themselves perform a save while
  their expected values are being bound. That occurs before the
  existing call-log reset. Keep that order; comparison only observes
  the supplied bound values.
- In `keymap-prefix.rkt`, eligible plain and prefix saves write once
  per explicit send; refusals write zero times. Prompt setup has
  already performed its permitted prefill queries before comparison.
  Keep its exact call-log expectations.
- In `buffer-value.rkt`, inline refused visits for `dir`, `link`, and
  `pipe` inspect once during comparison and select `source`, with no
  read or write. Keep the preceding separate `present?` attempts and
  the independent vanished-file/failing-read checks. Matching the
  stored Option `saved` performs no new save. The direct-save loop
  sends twice and expects two writes; the plain/prefix case also has
  two explicit sends and expects two eligible writes.
- Already-bound arguments retain their values. Remaining inline
  construction, editing, movement, fitting, quit absorption, search,
  and prefix/default behavior needs only one evaluation per supplied
  side and keeps its existing expected payloads.

## Required regression coverage

Add focused Rackunit coverage in **each** in-scope file, using its
existing fresh-driver and counted-filesystem setup. Do not alter
production counters, drivers, or filesystem doubles to prove this.

1. On a suitable bound session with the existing regular path
   `/cwd/a.txt`, compare two inline eligible save-key expressions,
   such as `(base save-key)` on each side. Both must produce matching
   sessions. After the complete helper returns, assert exactly two
   writes, one for each supplied side, with the expected path and
   exact text. Count after every helper observation, including its
   text, frames, or empty-list checks. This must fail with the old
   splicing helper.
2. Bind the result of one effectful expression, then compare the bound
   name with itself. Capture or reset the complete host-call log after
   binding, and prove comparison adds no host calls. Checking only
   writes is insufficient for this no-additional-call proof. Existing
   coverage satisfies this requirement only if it proves the contract
   after the full helper returns.
3. Establish distinct fixture bindings named `actual`, `expected`,
   `result`, and `saved`. Retain their evaluated Racket values before
   comparison and check them again afterward to prove the helper
   overwrites none. These may share the focused regression fixtures.

Choose an eligible fixture rather than a quit, untitled, or otherwise
refused save. In `buffer-value.rkt`, the existing rich fixture's bound
session is named `source`; use it or a locally constructed session
with a regular path. Session `save-key` is an Aloe send, not a Racket
function call. Independent expected-value construction in existing
tests remains independent.

## Verification and completion

### Before any edit

First run an untimed, serial warm-up of both keymap files:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/keymap-session.rkt tests/aloemacs/keymap-prefix.rkt
```

Then measure each separately, in this order:

```sh
TMPDIR=/tmp /usr/bin/time -f 'keymap-session wall=%e user=%U sys=%S' raco test -y tests/aloemacs/keymap-session.rkt
TMPDIR=/tmp /usr/bin/time -f 'keymap-prefix wall=%e user=%U sys=%S' raco test -y tests/aloemacs/keymap-prefix.rkt
```

Record each file's pass count and wall/user/system times. The spec's
2026-10-07 historical evidence remains the starting record; these
fresh measurements supplement it.

### After the helper edits and regressions

Run the focused verification, which also warms the changed modules:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/keymap-session.rkt tests/aloemacs/keymap-prefix.rkt tests/aloemacs/buffer-value.rkt
```

Repeat the same two separate timed commands:

```sh
TMPDIR=/tmp /usr/bin/time -f 'keymap-session wall=%e user=%U sys=%S' raco test -y tests/aloemacs/keymap-session.rkt
TMPDIR=/tmp /usr/bin/time -f 'keymap-prefix wall=%e user=%U sys=%S' raco test -y tests/aloemacs/keymap-prefix.rkt
```

Use the same machine, Racket installation, and serial configuration.
If compilation occurred during a timed sample, warm that file and
repeat the sample. Note machine or load differences. Do not delete
caches to manufacture a cold comparison. No speedup ratio, timeout,
median limit, or failing duration threshold is an acceptance test.

Finally run:

```sh
TMPDIR=/tmp raco test -y tests
git diff --check
```

Keep `TMPDIR=/tmp` and `-y` on every agent test run. Add no `-j`,
`--jobs`, `--drdr`, or other test-parallelism option. Do not substitute
`tests/*.rkt` for the recursive suite. Existing runner-check and
string-load-save timing tests stay untouched.

The checkpoint is complete when all three helpers evaluate each side
once in the required order, preserve every observation and fixture
binding, the effect regressions and existing focused tests pass, the
recursive suite is green, and `git diff --check` passes.

In the implementation handoff, report the three changed files, test
pass counts, and before/after wall/user/system times for each keymap
file with any measurement caveats. Timing improvement is evidence,
not a correctness gate. Stop for human review when green. Do not
start suite-time 001 or write another checkpoint.

## Explicit non-goals

- No per-file report, previous-run history, or report documentation
- No repair of `point`, `history-len`, or another comparison helper
- No existing call-site cleanup or expected-constructor rewrite
- No removed assertions or weakened effect/failure checks
- No driver preparation change, checker cache, or generic-body rule change
- No parser, evaluator, host, or production Aloe change
- No new performance deadline, committed timing transcript, or parallel trial
- No global checkpoint entry, language feature, Gel, or Boids work
