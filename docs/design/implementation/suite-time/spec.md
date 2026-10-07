# Specification — suite time

**Status: Accepted.** This specification resolves the suite-time
charter. Implementation proceeds one approved checkpoint at a time.

Session comparisons must evaluate each supplied Aloe datum once per
side and inspect the resulting values. After that repair, an optional
Racket command reports the duration and outcome of every test file and
compares them with the previous local report run.

This file carries the complete design input for the checkpoint manager
and implementers. The charter and this conversation are not required
context. A checkpoint narrows this specification to one implementable
slice; it does not revise the design.

## 1. Series and authority

- Series identity: `suite-time`. The first checkpoint is spoken
  **suite-time 000**, lives at `checkpoints/000-slug.md` beside this
  file, and uses a lowercase, hyphen-separated slug. Numbers have three
  digits, begin at 000, and are never renumbered.
- The manager writes one checkpoint and stops. Human review separates
  design, checkpoint writing, implementation, and the next checkpoint.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
  Source and tests belong in that tree, outside this design folder.
- Starting point: `main` at `9af2f39`. The human chooses the branch.
  This series does not enter `CHECKPOINTS.md` or `docs/checkpoints/`.
- After human acceptance, this file is the series design authority.
  [`docs/workflow.md`](../../../workflow.md) governs process and host
  verification. [`SPEC.md`](../../../../SPEC.md) remains Aloe law.

The layers, in order, are:

1. Bind each side once in the three helpers named in §4, prove their
   effects and observations, and record warm before-and-after evidence.
2. Add the optional per-file timing report specified in §5.
3. Repair the remaining `point` helper in `keymap-session.rkt`, as
   specified in §6, after the report exists.

The suite inventory in §6 supplies the charter's conditional third
layer. The manager may split a layer that exceeds one implementer
conversation, preserving this order and adding no features. It must
not write the remainder of the series in advance.

## 2. Starting behavior and boundary

[`aloe/driver.rkt`](../../../../aloe/driver.rkt) implements
`driver-eval!` by parsing, typechecking, and evaluating every call.
`driver-prepare!` checks once and returns an evaluation procedure.
The interactive runner already uses preparation; the implemented
[`runner-check`](../aloemacs/runner-check/README.md) repair is a
predecessor, not work to reopen here.

In [`aloe/type.rkt`](../../../../aloe/type.rkt),
`infer-instance-send` checks the selected method body again for legacy
generic `(fields ...)` instances. This rule explains why splicing a
session operation into many assertions is expensive. The
[`checker-recursion`](../checker-recursion/README.md) proposal is
withdrawn. Neither it nor a method-body cache is a prerequisite.

The charter's measurement on 2026-10-07 was a warm, serial
`TMPDIR=/tmp raco test -y tests`: 2,650 tests passed in 592.59 seconds
(569.88 user, 22.16 system). Median file duration was 0.424 seconds;
about 90% of elapsed time was in `tests/aloemacs/`. The two keymap files
accounted for about 56%:

| File | Recorded duration |
|---|---:|
| `tests/aloemacs/keymap-session.rkt` | 249.7 s |
| `tests/aloemacs/keymap-prefix.rkt` | 84.6 s |
| `tests/aloemacs/minibuffer-session.rkt` | 22.3 s |
| `tests/aloemacs/completion-page-session.rkt` | 16.1 s |
| `tests/aloemacs/buffer-value.rkt` | 5.3 s |

These are historical evidence, not deadlines. Fresh implementation
measurements supplement them. They do not replace the starting record
or establish a required speedup ratio.

This series leaves unchanged `SPEC.md`, all of `aloe/`, `host/`,
`examples/`, and `lib/`, and the existing `bin/aloe` command. It adds
no parser or evaluator behavior, generic checking cache, deferred-body
rule, rebinding rule, or generic instantiation rule. It does not use
`driver-prepare!` in comparisons.

Helpers already binding once keep their current names and shape.
Assertions are not removed to reduce cost. No new Rackunit timeout,
median limit, performance ratio assertion, or failing duration
threshold belongs in either layer. Existing runner-check and
string-load-save timing tests remain untouched.

The standing suite command remains serial and keeps `-y`. Neither
`-j`, `--jobs`, `--drdr`, parallel test execution, nor a change to the
standing command's process count belongs in this series. Any later
parallel trial or checker change requires its own exploration.

## 3. Host, layout, and verification command

Use the repository's installed Racket and Rackunit. No new package,
Python environment, build system, or long-lived test service is needed.
Run commands from the project root. Agent test runs are always:

```sh
TMPDIR=/tmp raco test -y <paths>
```

`-y` refreshes bytecode for changed modules and their dependents.
`compiled/` remains gitignored and uncommitted. Leave existing cache
directories in place. A report run must also refresh bytecode; an
untimed compilation pass must not hide compilation work inside a
reported run.

The first layer edits only the three test files in §4. The second may
create `bin/suite-time.rkt` and `tests/suite-time/report.rkt`, add
`/.suite-time/` to the root `.gitignore`, and document its invocation in
the root `README.md` Bytecode section. Keep the existing `compiled/`
ignore rule and standing test and launch commands. Do not change
`AGENTS.md`, `docs/workflow.md`, or unrelated test helpers.
The third edits only `point` and its regression coverage in
`tests/aloemacs/keymap-session.rkt`.

The report stays outside `tests/` so directory testing cannot start a
recursive suite run. Its module must be safe to require: the command
executes only through `module+ main`. Report tests belong under the
local project identity, `tests/suite-time/`, and temporary fixture
projects belong under `/tmp`.

## 4. Layer one: bind once

### 4.1 Helper contract and file scope

Edit `same-session` in:

- `tests/aloemacs/keymap-session.rkt`
- `tests/aloemacs/keymap-prefix.rkt`
- `tests/aloemacs/buffer-value.rkt`

Use the existing `def!` in each file, in this order:

```racket
(def! st 'comparison-actual actual)
(def! st 'comparison-expected expected)
```

Both names are currently free in these files. They are private scratch
bindings owned by the helper; call sites must not use them as fixtures
or supplied arguments. Every subsequent comparison refers to these
stored names, including whole-value equality. The caller's datum is
never spliced into a later assertion.

Actual is evaluated before expected. Each successful helper call
evaluates each supplied datum once. A symbol argument performs one
lookup and stores that value. An expression argument computes and
stores its result. Each `define` still goes through `driver-eval!` and
is checked normally. Subsequent observations are also checked normally;
only the original operation disappears from their receiver expressions.
The contract concerns evaluating the supplied datum, not deduplicating
subexpressions within independently constructed expected datums.

Do not bind or rebind fixture names `actual`, `expected`, `result`, or
`saved`. An existing name denotes the value its call site already
computed. Two executions require two sends at the call site. The
comparison loop is an observation mechanism.

Keep the complete assertion inventory:

| Observation | Files |
|---|---|
| Whole-session structural equality, including constructor payloads and UndoFrames | All three |
| `buffers fs echo searching query origin wrapped failing kill-ring pending prompt last-submission waiting-command windows`, then `current-buffer editor path` | All three |
| Editor `text point quit scroll-row scroll-col history mark text-rows` | Both keymap files |
| Text `to-string` equality | `keymap-session.rkt` |
| Frames `(8 1)` and `(12 6)` | `keymap-session.rkt` |
| Frames `(8 1)` and `(20 4)` | `keymap-prefix.rkt` |
| Actual buffers' `before` and `after` are empty | `buffer-value.rkt` |

Retain other assertions outside these helpers. Do not add a missing
observation to another helper merely for uniformity. Preserve independent
expected-value constructors and existing type-error tests.

### 4.2 Completed effect inventory

Every existing `same-session` call in these three files was inspected,
including loop-generated arguments and the `expected` builder in
`keymap-session.rkt`. The relevant cases are below. Test-case names
identify call sites independently of line-number changes.

| File and test case | Argument or class | Observation after one evaluation; call-site disposition |
|---|---|---|
| `keymap-session.rkt`: “successful existing and missing visits reset pending; rejection retains source” | Inline `((armed visit (Path new "dir")) case (None () armed) (Some (session) session))` | One refused visit performs resolve/kind inspection and selects `armed`. No read or write. Keep the preceding separate `present?` send: the test explicitly attempts the visit twice. No rewrite. |
| `keymap-session.rkt`: “armed ordinary rebuilds, direct wrappers, search, kill, and save preserve pending” | Inline `(untitled save-key)` | The absent path causes no host call and yields the untitled payload with `"failed"` echo. One observation suffices. No rewrite. |
| `keymap-session.rkt`: table dispatch, save outcomes, search dispatch including Save, armed direct saves, fitting before Save, and successful visits | Already-bound `actual`, `expected`, `direct`, `saved`, `save-key`, or `result` | Save, save-key, handle-key, and visit effects have occurred in the preceding `def!`. In the table/search Save rows, the expected builder can itself save; that happens before the existing call-log reset. Comparison only reads the supplied values. Keep all bindings and resets. |
| `keymap-prefix.rkt`: plain/prefix save outcomes, exact text saves, search then Save, and prompt commands | Already-bound `result`, `plain`, `started`, or other fixture names | Saves write once per explicit send when eligible; refusals write zero times. Prompt prefill queries are already performed: FindFile queries `root?` and `parent`, SaveAs uses the bound path, and SelectBuffer has no filesystem query. Comparison introduces no query or write. Keep the existing call sites. |
| `buffer-value.rkt`: “refused and vanished visits preserve every source field, including pending” | Inline `((source visit (Path new path)) case (None () source) (Some (session) session))`, for `dir`, `link`, `pipe` | One refused visit inspects the target and selects `source`; reads and writes stay empty. The preceding separate `present?` send is a second explicit attempt, and remains. The vanished-file and failing-read branches do not pass a visit expression to the helper. No rewrite. |
| `buffer-value.rkt`: successful visits, direct saves, and plain/prefix save echoes | `visited`, `plain`, `prefixed`, or `(saved case (None () bound) (Some (session) session))` | Visit and save effects happen before comparison. Matching the stored Option `saved` performs no save. The direct-save loop explicitly sends twice and expects two writes. The plain/prefix case has two explicit sends and expects two eligible writes. Keep both forms. |
| Both keymap files: quit absorption, search-owned keys, prefix consumption/default suppression; all three files: remaining constructions, editing, movement, fitting, and field-derived expectations | Inline pure operations or lookups | One result has the same payload expected by existing assertions. Quit absorbs Save before host calls. Ignored pending-map defaults do not invoke Save. Search-owned keys perform their search operation, with no filesystem effect. No result relies on repeated evaluation. |

**No existing call site requires a rewrite into an explicit second
send.** Existing repetitions are already explicit, or are separate
assertions whose sends remain. Do not collapse them into one send.
The first layer's call-site scope therefore consists only of the new
regressions below, not unrelated fixture cleanup.

### 4.3 Regression proof

Add focused Rackunit coverage in each of the three in-scope files,
using its existing fresh driver and counted filesystem double:

1. Compare two inline eligible save-key expressions on a suitable
   bound session with an existing regular path. Both yield matching
   sessions; the full helper must produce exactly two writes, one per
   supplied side, with the expected path and text. This fails with the
   old splicing helper. Count after all fields/text/frames/empty-list
   observations, not before them.
2. Bind the result of one effectful expression, then compare that
   bound name with itself. Comparison adds no host calls. Existing
   equivalent coverage may satisfy this requirement if it checks the
   call log after the helper.
3. Prove the helper does not overwrite `actual`, `expected`, `result`,
   and `saved`, using distinct existing bindings and checking their
   values after comparison. These may be fixtures in the same focused
   regression; do not introduce a driver mock or production counter.

The original assertion inventory and test cases remain. Retain exact
write, read, failure propagation, and immutable-source checks.
Leave the separate `point` helper unchanged in this first layer; its
repair follows the report in §6.

### 4.4 Warm evidence procedure

Before editing, run an untimed serial warm-up of the two keymap files:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/keymap-session.rkt tests/aloemacs/keymap-prefix.rkt
```

Then measure each separately, in this order:

```sh
TMPDIR=/tmp /usr/bin/time -f 'keymap-session wall=%e user=%U sys=%S' raco test -y tests/aloemacs/keymap-session.rkt
TMPDIR=/tmp /usr/bin/time -f 'keymap-prefix wall=%e user=%U sys=%S' raco test -y tests/aloemacs/keymap-prefix.rkt
```

After editing and adding regressions, run the focused verification:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/keymap-session.rkt tests/aloemacs/keymap-prefix.rkt tests/aloemacs/buffer-value.rkt
```

That also warms the changed modules. Repeat the same two separate
timed commands on the same machine, Racket installation, and serial
configuration. If compilation occurred during a timed sample, warm
that file and repeat the sample. Do not delete caches to manufacture a
cold comparison. Record pass counts and wall/user/system times for
each file before and after, and note machine or load differences.

Report the evidence in the implementation handoff. Timing records and
transcripts may stay under `/tmp`; do not commit them. Improvement is
evidence, not an automated acceptance threshold. After the focused
checks, run `TMPDIR=/tmp raco test -y tests` and `git diff --check`,
then stop when green.

## 5. Layer two: observational report

### 5.1 Command and suite membership

The explicit command, from the project root, is:

```sh
TMPDIR=/tmp racket bin/suite-time.rkt
```

It reports the complete `tests/` suite. It has no path selection,
parallelism, deadline, or threshold options in this series. The
ordinary `TMPDIR=/tmp raco test -y tests` invocation remains sufficient
to run everything without reporting or updating timing history.

Discover modules recursively in `tests/` in Racket's directory traversal
order, using the installed `compiler/module-suffix` recognition and
excluding dot-prefixed file basenames as directory-mode `raco test`
does. Include modules with top-level tests, modules with a `test`
submodule, and modules that log zero tests. Do not select files by
grepping for Rackunit forms or by a committed manifest. At this starting
point all suite modules are `.rkt` and there is no `info.rkt` beneath
`tests/` governing discovery.

For this small wrapper, discovery does not implement `info.rkt`
inclusion/omission configuration. If one is present under the selected
suite tree, stop before running files with a clear unsupported-discovery
error; do not silently report a different suite. Existing module
submodule configuration remains handled by `raco test`. This is an
operational error, not a timing failure or a change to ordinary testing.

Run each discovered file once, waiting for completion before starting
the next, with this effective child invocation:

```sh
TMPDIR=/tmp raco test -y --process -- <file>
```

Use a subprocess argument vector, not shell interpolation, with the
project root as invocation directory. Preserve `TMPDIR=/tmp` in the
child environment. `--process` preserves the standing directory run's
isolated test process even though each invocation names one file.
There is only one active test file at a time. Preserve default `test`
submodule selection and run-if-absent behavior. Add no timeout flag.
The [Racket test manual](https://docs.racket-lang.org/raco/test.html)
defines this discovery and process behavior and the `-y` update mode.

### 5.2 Duration, outcome, and compiler observation

For each file, measure elapsed wall time with a monotonic clock from
immediately before launching its child through child termination and
output draining. Seconds include that invocation's startup, bytecode
updates, and testing. They do not claim to isolate Aloe evaluation or
match the standing suite's aggregate time exactly: the optional
wrapper adds a `raco` launcher per file.

Drain stdout and stderr concurrently so neither pipe can block a test.
Stream test stdout and ordinary stderr without loss. Finish draining
one invocation before moving to another. Auxiliary I/O threads are
allowed; concurrent test files are not. A zero child exit code means
`PASS`; any nonzero code means `FAIL`. Keep the exact exit code in the
record. Do not infer success from a printed test-count string.

Observe compilation during the timed invocation, rather than labeling
the first run cold and every later run warm. Enable `info` logging for
the `compiler/cm` topic in each child's `PLTSTDERR` configuration,
including its spawned test process, while retaining existing logging
settings for other topics. Recognized compiler event lines can be
consumed by the report instead of repeated in ordinary stderr.
Unrecognized output is forwarded, never discarded as test noise.

The [compilation manager API](https://docs.racket-lang.org/raco/API_for_Making_Bytecode.html)
documents its `compiler/cm` events. The installed implementation also
emits recompile and touch events. Classify each invocation as:

- `rebuilt`: a `start-compile`, `start-recompile`, or `start-touch`
  event occurred. This includes generation, recompilation, and cache
  timestamp updates, for the test or any dependency, including shared
  modules outside `tests/`. On a failed file it means update work was
  attempted; it does not promise a completed build.
- `warm`: observation completed and no such event occurred. This means
  no compilation-manager update was observed, not warm disk caches or
  stable machine load. Existing `.zo` files alone cannot establish it.
- `unknown`: compiler telemetry could not be classified or observed
  reliably. Forward unfamiliar compiler messages, print the limitation,
  and do not claim the invocation was warm. Unknown observation does
  not make a passing test fail.

The run summary is `rebuilt` if any file is rebuilt, otherwise
`unknown` if any file is unknown, otherwise `warm`. Observation never
precompiles, changes a source, removes a cache, adds errortrace, or
alters driver/checker behavior.

### 5.3 Table and previous run

After all files finish, print one row per discovered file, sorted by
unrounded elapsed seconds descending, with repository-relative path
ascending to break ties. The output columns are:

| Column | Meaning |
|---|---|
| `Seconds` | Current wall seconds, displayed to three decimals |
| `Result` | Current `PASS` or `FAIL` |
| `Bytecode` | Current `rebuilt`, `warm`, or `unknown` |
| `Previous(s)` | Prior duration for the same path |
| `Previous result` | Prior pass/fail result |
| `Previous bytecode` | Prior update classification |
| `Delta(s)` | Current minus prior seconds; positive is slower |
| `File` | Complete repository-relative path, without truncation |

Keep unrounded durations in the record. Missing previous rows display
`—` in previous and delta columns. A missing record produces a normal
first-run report. If the record schema or Racket version differs, or
the record is malformed, explain why comparisons are unavailable and
show no fabricated previous values. Compiler labels and outcomes remain
visible even when numeric deltas exist; a delta is descriptive and
never gates success. An `unknown` label remains explicit.

Print run metadata above the table: current run's UTC timestamp, Racket
version, serial command, and overall bytecode classification. When
comparison is available, also print the previous timestamp and bytecode
classification. The footer gives files passed/failed, sum of file
durations, and total report wall time. These sums may differ because
discovery, formatting, and persistence are outside per-file timing.

The previous-run record is `/.suite-time/previous.rktd` relative to the
project root. Gitignore the entire root `.suite-time/` directory. Read
the old record before testing; after a completed run, replace it
atomically with the current run using a temporary sibling and rename.
The completed current run becomes the next run's previous record,
including when test files failed. An interrupted or operationally
aborted run must not overwrite it. Do not retain a committed timing
log or introduce a history database.

Use a versioned Racket datum containing run timestamp, Racket version,
overall bytecode classification, ordered suite membership, and per-file
path, unrounded seconds, exact child exit code, result, and bytecode
classification. Read it as data, validate its shape, and never evaluate
it. The command does not require Git, a commit lookup, or network access.

Continue after a failed file so the report remains complete. Return 0
only if every file passes and the report finishes; return nonzero if a
file fails or an operational error prevents discovery, execution, or
persistence. Keep ordinary child failure diagnostics. Timing differences
and unknown bytecode observation never change test success or produce
a new deadline. A completed failed test run is still saved.

### 5.4 Report proof

`tests/suite-time/report.rkt` must exercise report operations with a
temporary fixture root, record path, and small test set; importing the
report cannot start the real suite. Internal test seams may supply
deterministic durations and fake child outcomes. They are not additional
command-line features. Prove:

- Discovery includes nested modules and both top-level/submodule tests,
  ignores nonmodules/dot-prefixed module basenames, covers zero-test
  modules, and rejects unsupported `info.rkt` discovery before testing.
- Commands preserve `-y`, `--process`, and `/tmp`, use separate argument
  values, and never run two files at once. A failure does not skip a
  later file. Real temporary passing and failing Rackunit files produce
  the expected outcomes; ample stdout and stderr are drained intact.
- Sorting, tie-breaking, column values, signed deltas, missing prior
  files, first runs, and incompatible/malformed records are correct.
  Use deterministic durations; do not assert a wall-time limit.
- Real `-y` fixture invocations with absent bytecode are rebuilt, a
  repeat with unchanged sources is warm, and editing a dependency
  causes a later update to be reported. This tests telemetry through
  both launcher and test process. Also cover recompile/touch and
  unfamiliar-event classification using representative event input.
- Only a completed run replaces history, including completed test
  failures. Aborts preserve it. Requiring the module has no run or
  record-writing effect.

Run focused report tests with
`TMPDIR=/tmp raco test -y tests/suite-time/report.rkt`. Then run the
report twice from the real project root to inspect full membership,
pass/fail rows, compiler labels, and previous-run columns. The first
may rebuild; the second must identify actual observed updates rather
than assuming warmth. These report invocations are the full-suite
verification for this layer; do not add a redundant ordinary full run
after they pass unless a change or failure calls for it. Check
`git check-ignore .suite-time/previous.rktd`, `git status --short`,
and `git diff --check`. Stop when green.

## 6. Layer three: the remaining point helper

The suite scan inspected multi-observation helpers, their argument
construction, and their call sites, rather than treating every
quasiquote as the same defect.

It found another instance in `tests/aloemacs/keymap-session.rkt`:

```racket
(define (point st s)
  (list (ev st `((,s point) line)) (ev st `((,s point) column))))
```

In “fitted page commands use remembered rows and all six motions keep
history,” three calls supply `(base handle-key "page-up")`,
`(base handle-key "page-down")`, and
`(one-row handle-key "page-down")`. Each supplied operation is checked
and evaluated twice, once for each coordinate. Their expected results
are respectively `(1 3)`, `(3 3)`, and `(1 1)`. These are pure sends and
require no call-site second execution. The helper's other two calls,
on bound `query` and `next` in the search test, remain lookups of those
stored values.

After the report layer, repair only this helper using its existing
`def!` to bind the supplied session datum once as
`comparison-point-source`. That name is currently free and becomes
helper-owned scratch space. Both coordinate reads then inspect that
stored session. Preserve the returned Racket list in line/column order,
all five existing call sites, and both coordinate observations.
`driver-eval!` still checks every call. Do not change `history-len`, the
completed `same-session` repair, or pure helper forms elsewhere.

Add a focused regression in the same file that passes an inline
eligible `(base handle-key "save")` to `point` on a suitable idle
fixture. Verify the returned coordinates and exactly one write after
both reads. Compare a previously bound effectful result as well and
prove there are no additional calls. Preserve the fixture bindings
`actual`, `expected`, `result`, and `saved`. This regression proves the
same defect and repair as the first layer without a clock limit or a
production instrumentation change.

Run `TMPDIR=/tmp raco test -y tests/aloemacs/keymap-session.rkt`, then
the now-existing report command for full-suite verification and
`git diff --check`. Report the test results and observational duration;
no speedup is required to make this small repair correct. Stop when
green. This is the only later helper layer.

The rest of the search establishes why its scope remains one file:

`completion-page-session.rkt` has `same`, which sends one `check`, and
`expect-page`, which calls it once. `snapshot!` binds the Tab result as
`listed`. Later page changes bind `middle`, `tail`, `next`, `fresh`, or
other results; `ended!` binds Return as `done` before inspecting it.
Its remaining cost comes from distinct scanner, paging, gate, and
submission checks. There is no helper multiplying an expensive supplied
session expression across field assertions.

The minibuffer, buffer-session, buffer-collection, and windows
comparison helpers already store their supplied sides once. In
`echo-session.rkt`, `same-payload` receives bound names at every call.
In `file-session.rkt`, `check-session` and `check-key-save` also receive
bound names. Leave those forms alone. Snapshot/paint helpers in the
mode-line and idle-echo tests inspect bound sessions; explicit repeated
frame sends are the assertions they intend to make.

Small position, Text/edit, next-lines, and editor observation helpers
can repeat concrete pure expressions. They do not reproduce the
expensive generic session-operation defect identified here and do not
justify a general helper rewrite layer. The similarly named `point`
helpers in `search-session.rkt` and `kill-session.rkt` receive bound
names at their existing call sites and remain untouched.
Remaining suite cost becomes evidence for a later exploration after
the report exists; it does not authorize a checker change in this one.

## 7. Acceptance and stop

The series is accepted only when:

1. Each of the three repaired helpers evaluates each supplied side once,
   preserves fixture names, and performs every existing observation on
   the stored values. The later `point` repair also stores its argument
   once before both coordinate reads. Focused effect regressions and
   existing tests pass.
2. Explicit repeated sends and already-bound arguments retain their
   meaning. No call site derives required behavior from helper repetition.
3. Warm serial before-and-after evidence for both keymap files is
   reported using §4.4 on the same machine, without a new deadline.
4. The optional report covers the standing suite, reports each file's
   actual duration and outcome slowest first, observes bytecode updates,
   and compares with a validated previous local record when available.
5. Ordinary suite execution remains available unchanged; timing history
   and bytecode are gitignored and uncommitted. The report adds no
   duration-based failure condition or test parallelism.
6. Language law, checker, evaluator, driver, production Aloe, and host
   runners are unchanged. There is no extra checker or parallel layer.

The designer stops at this draft. After human acceptance, a manager
receives this file to write **suite-time 000** only, then stops. Each
implementer completes only its approved checkpoint, verifies it, and
stops for review before another number is issued.

If you have been told to read this file, this is the whole assignment.
