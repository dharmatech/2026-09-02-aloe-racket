# Checkpoint 118 — The evaluator under the compile limit

**Branch.** Continue on `experiment/2026-10-16-host-queries` at `812bc84`,
or at a later commit that leaves `aloe/` and `tests/` as they are. Before
starting, `git diff --stat 812bc84 HEAD -- aloe tests` must print nothing. If
it prints anything, stop and report: the cut below is written against that
tree.

**Depends on.** Nothing new. `aloe/eval.rkt` last changed at `87c0844`. Line
numbers below are that file as of `812bc84`.

**Status.** Ready to implement.

The implementer receives only this document.

## Goal

Racket CS compiles a module body to machine code as one unit only when it is
smaller than `PLT_CS_COMPILE_LIMIT`, 10,000 terms by default. A larger body
is compiled in interpretable mode. Each procedure is still machine code, but
calls between the module's own procedures go through variables, and nothing
is inlined across them.

`aloe/eval.rkt` crossed that line at `0e20fae` (14 October 2026). It is about
10,170 terms now. Every Aloe program has run about 20 percent slower since:
`List rest` of 971 Strings went from 26 to 42 µs, and the deep medians of
`tests/aloemacs/window-pictures.rkt` went from about 22.8 and 14.1 ms to 27.6
and 17.6 ms. The evidence is section 1 of
[`archive/design-sketches/2026-10-18-aloemacs-frame-time/summary.md`](../../archive/design-sketches/2026-10-18-aloemacs-frame-time/summary.md).

This checkpoint moves the evaluator's cold code out of `aloe/eval.rkt` into
three new modules beside it. Afterwards every evaluator module compiles whole
at a limit of 8,000. That is 20 percent under Racket's default. A new test
fails when an evaluator module crosses 8,000 again. The hot path stays
together in `aloe/eval.rkt`. Aloe behavior does not change.

## Locks

- **No behavior change.** Every Aloe result, error message, printed value, and
  test outcome stays the same. `SPEC.md` does not change. No message, form,
  or type is added or removed.
- **Move, do not rewrite.** Each moved definition keeps its body, its comments,
  and its order relative to the other definitions that go to the same module,
  byte for byte. The one exception is the two extra spaces of indentation
  inside `make-reflection-sends` (see "The one indirection"). Nothing is
  renamed. No procedure is merged, split, or reworded.
- **The surface stays.** `aloe/eval.rkt` is still the module other code
  requires. Its `provide` list is unchanged, and so is its `method-records`
  submodule. `aloe/driver.rkt`, `aloe/main.rkt`, and every test keep their
  `require` forms.
- **The hot path stays in `aloe/eval.rkt`.** Moving it apart loses the inlining
  this checkpoint exists to recover. The hot path is:
  - `eval-expr` and the forms it evaluates: `eval-case`, `eval-new-star`,
    `eval-with`, `eval-load!`, `construct-instance` and its type inference
  - `lookup-message`
  - every `send-to-…` table except the three reflection tables: instances,
    functions, List and the List class, Int, Float, Bool, String (with
    `split-lines`, `joined-with`, and `find`), Symbol and the Symbol class.
    `send-to-mirror-class`, `send-to-mirror`, and `send-to-signature` belong
    to Mirror and signature support. An ordinary send does not reach them, so
    they are cold and they move.
  - `make-list-value`, `runtime-type-of`, and `same-runtime-type?`
  - method selection and application: `select-runtime-method`, the
    specificity procedures, `apply-method`, `apply-list-method`,
    `apply-int-method`, `apply-string-method`, and the generic-argument checks

  None of these moves. If the cut below does not bring `aloe/eval.rkt` under
  8,000, stop and report. Do not move any of them to make the number.
- **No raised limit.** Bytecode built by an ordinary `raco make` or
  `raco test -y` must be the fast bytecode. Do not set `PLT_CS_COMPILE_LIMIT`
  in a launcher, an environment file, `info.rkt`, or a build flag.

## The cut

The manager applied exactly this cut to a scratch copy of `812bc84` and
bisected each module body's size with `PLT_LINKLET_SHOW_POST_INTERP` (method
under "The guard"):

| Module | Terms, approximately |
|---|---:|
| `aloe/eval.rkt` today | 10,160 to 10,200 |
| `aloe/eval.rkt` after | 7,130 to 7,170 |
| `aloe/eval-value.rkt` (new) | 930 to 960 |
| `aloe/eval-load.rkt` (new) | 590 to 615 |
| `aloe/eval-mirror.rkt` (new) | 1,505 to 1,535 |

About 850 terms of growth fit in `aloe/eval.rkt` before the guard fails. When
it fails, the next split is a new checkpoint. Raising the number is not the fix.

### `aloe/eval-value.rkt` (new): runtime values

These are the structs and small helpers that both `aloe/eval.rkt` and
`aloe/eval-mirror.rkt` use, plus the printer and structural equality. Printing
and equality are cold: only `check`, `:raw`, `Mirror raw`, and the REPL reach
them.

The file is exactly this header, then the definitions below in the order
listed:

```racket
#lang racket/base

;; The evaluator's runtime values: the structs dispatch and reflection share,
;; the small helpers both call, the printer, and structural equality.
(require racket/string
         "env.rkt"
         "host.rkt"
         "mirror.rkt"
         "signature.rkt"
         "symbol.rkt")

(provide (struct-out class-value)
         (struct-out instance-value)
         (struct-out function-value)
         (struct-out list-value)
         (struct-out runtime-class-type)
         (struct-out runtime-list-type)
         (struct-out protocol-value)
         class-value-protocol-name
         string-class-for
         int-class-for
         option-class-for
         arity-error
         unknown-message
         aloe-value->string
         aloe-values-equal?)
```

| Lines | Definitions |
|---|---|
| 32–43 | structs `class-value`, `instance-value`, `function-value`, `list-value`, `runtime-class-type`, `runtime-list-type` |
| 46–49 | the comment and struct `protocol-value` |
| 283–286 | the comment and `class-value-protocol-name` |
| 442–449 | `string-class-for`, `int-class-for`, `option-class-for` |
| 1759–1767 | `arity-error`, `unknown-message` |
| 1774–1832 | `aloe-value->string` |
| 1852–1877 | `value-vectors-equal?`, `aloe-values-equal?` |

`value-vectors-equal?` is not provided.

The five helpers here (`class-value-protocol-name`, the three `…-class-for`
procedures, `arity-error`, and `unknown-message`) are one- and two-line
procedures. Hot code and reflection both call them. Keeping them in
`aloe/eval.rkt` would mean passing them through the indirection too. Racket CS
inlines another module's struct predicates and accessors, as it already does
for `env.rkt`'s class objects and `mirror.rkt`'s Mirror values. In the
manager's prototype of this cut, the speed check below measured the same
speed as the whole-compiled reference.

### `aloe/eval-load.rkt` (new): the load cache

The file is exactly this header, then the definitions below in the order
listed:

```racket
#lang racket/base

;; The evaluator's load cache: each resolved path runs once per base, and a
;; completed run's exports are copied into each loader.
(require racket/match
         "env.rkt"
         (only-in "library.rkt"
                  list-library-resolved-path
                  string-library-resolved-path
                  int-library-resolved-path
                  option-library-resolved-path
                  resolved-source-path)
         "parse.rkt")

(provide current-eval-load-paths
         eval-once!
         eval-keyed-root
         record-evaluated-libraries!
         record-evaluated-option-class!)
```

| Lines | Definitions |
|---|---|
| 50–53 | the comment and struct `evaluator-load-entry` |
| 55 | `current-eval-load-paths` |
| 76–94 | the comment and `eval-keyed-root` |
| 96–128 | the comment and `eval-once!` |
| 130–144 | the comment and `file-exports` |
| 146–149 | the comment and `copy-exports!` |
| 151–163 | the comment and `record-evaluated-libraries!` |
| 165–167 | the comment and `record-evaluated-option-class!` |

`eval-load!` (lines 57–74) stays in `aloe/eval.rkt`, because it runs
`eval-exprs`. It reaches the cache only through `eval-once!` and
`current-eval-load-paths`. `eval-once!` already takes the run procedure as an
argument, so this module needs nothing from `aloe/eval.rkt`.

### `aloe/eval-mirror.rkt` (new): reflection

The file is exactly this header, then the module-level definitions below in
the order listed, then `make-reflection-sends`:

```racket
#lang racket/base

;; Reflection: sends to the Mirror class, Mirror values, and Signature values,
;; and the signature rows they read.
(require racket/list
         "env.rkt"
         "eval-value.rkt"
         "host.rkt"
         "mirror.rkt"
         "parse.rkt"
         "signature-catalog.rkt"
         "signature.rkt"
         "symbol.rkt")

(provide send-to-mirror-class
         value-signature-specs
         make-reflection-sends)
```

At module level:

| Lines | Definitions |
|---|---|
| 44 | struct `runtime-class-object-type` |
| 373–378 | `send-to-mirror-class` |
| 380–398 | `runtime-type->datum` |
| 400–440 | `instance-signature-specs`, `class-instance-type-datum`, `class-signature-specs`, `list-signature-specs` |
| 451–502 | `value-signature-specs` |
| 504–508 | `value-selector-names` |
| 510–511 | `make-type-data-list` |
| 513–523 | `type-datum->aloe-value` |
| 525–569 | `signature-type-parameters` |
| 651–665 | `runtime-named-type-matches?` |

Inside `make-reflection-sends`, in this order:

| Lines | Definitions |
|---|---|
| 571–578 | `runtime-owner-type` |
| 580–589 | `same-runtime-owner-type?` |
| 591–604 | `signature-spec->value` |
| 606–641 | `send-to-mirror` |
| 643–649 | `bind-runtime-type-parameter!` |
| 667–702 | `runtime-type-matches-datum?` |
| 704–754 | `invoke-with-signature` |
| 838–860 | `send-to-signature` |

### The one indirection

`aloe/eval.rkt` requires `aloe/eval-mirror.rkt`. Racket modules cannot
require each other in a cycle, so `aloe/eval-mirror.rkt` cannot require
`aloe/eval.rkt`. The eight definitions in the second table call four
evaluator procedures: `make-list-value`, `runtime-type-of`,
`same-runtime-type?`, and `invoke-signature-row`. One procedure takes those
four as arguments and builds the eight. It is the last form of
`aloe/eval-mirror.rkt`:

```racket
;; eval.rkt requires this module, so this module cannot require eval.rkt.
;; These sends call four evaluator procedures; eval.rkt passes them in once
;; and binds the two sends this returns.
(define (make-reflection-sends make-list-value
                               runtime-type-of
                               same-runtime-type?
                               invoke-signature-row)
  ;; the eight definitions, each indented two more spaces
  (values send-to-mirror send-to-signature))
```

Leave out the placeholder comment line. The eight definitions go where it
stands, in the table's order, each line indented by two more spaces and
otherwise unchanged. Blank lines between them stay empty. An indented blank
line is trailing whitespace, and `git diff --check` reports it. The parameter
names are the evaluator's own names, so the bodies need no edits.

`aloe/eval.rkt` binds the two sends as the last form of its module body.
That means after every definition and before the `method-records` submodule,
because the four procedures must be defined when it runs:

```racket
;; Reflection lives in eval-mirror.rkt, which cannot require this module; its
;; Mirror and Signature sends are built from these four procedures.
(define-values (send-to-mirror send-to-signature)
  (make-reflection-sends make-list-value
                         runtime-type-of
                         same-runtime-type?
                         invoke-signature-row))
```

There is no other indirection: no parameter, box, `set!`, callback table,
`lazy-require`, or `dynamic-require`. `invoke-signature-row` stays in
`aloe/eval.rkt`. It dispatches exact rows to `apply-method`, `send-to-list`,
`apply-list-method`, the Int and String method appliers, and every other
`send-to-…` table, and moving it would require passing all of them in.

### What stays in `aloe/eval.rkt`

Everything not listed above stays, in its current order. The file begins:

```racket
#lang racket/base

;; The evaluator's hot path: eval-expr and the forms it evaluates, message
;; lookup, every kernel send table, List construction, runtime types, and
;; method selection and application. Racket CS inlines within this module only
;; while its body compiles whole; tests/checkpoint-118.rkt checks that at a
;; limit of 8,000 terms. Cold code is in eval-value.rkt, eval-load.rkt, and
;; eval-mirror.rkt.
(require racket/match
         "env.rkt"
         "eval-load.rkt"
         "eval-mirror.rkt"
         "eval-value.rkt"
         "host.rkt"
         (only-in (submod "host.rkt" evaluator-exact-host-method)
                  host-receiver-invoke-method)
         "mirror.rkt"
         "parse.rkt"
         "signature-catalog.rkt"
         "signature.rkt"
         "symbol.rkt")
```

The require list drops `racket/list`, `racket/string`, and `library.rkt`,
which only moved code used. The `provide` form (lines 21–29) follows,
unchanged. `aloe-value->string`, `instance-value?`, and
`instance-value-constructor` are now imports from `aloe/eval-value.rkt`, and
`aloe/eval.rkt` re-exports them by the same names.

What remains, in order:

- struct `runtime-method-match` (45)
- `eval-load!` and its comment (57–74)
- `eval-expr` through `recorded-method-environment` (169–281)
- `eval-case`, `aloe-value->host-argument`, `host-result->aloe-value`,
  `lookup-message` (288–371)
- `invoke-signature-row` (756–836)
- `send-to-symbol-class` through `number-argument` (862–1757)
- `eval-exprs` (1769–1772)
- `instance-has-zero-argument-method?` and `aloe-value->display-string`
  (1834–1850). `aloe-value->display-string` sends `show` through
  `lookup-message`, so it stays.
- the new `define-values` form above
- the `method-records` submodule and its comment (1879–1910), unchanged. It
  still sees the struct accessors and `protocol-value-environment` through
  this module's require of `aloe/eval-value.rkt`.

## The guard: `tests/checkpoint-118.rkt`

The guard proves each evaluator module compiles whole at 8,000. It runs in a
subprocess, in a temporary copy, so it neither reads nor writes the
repository's `compiled/` directories.

1. Name the guarded modules `eval`, `eval-load`, `eval-mirror`, and
   `eval-value`, the files `aloe/<name>.rkt`, as one list constant. Name the
   limit 8,000 and the detector limit 100 as constants.
2. Check that `(system-type 'vm)` is `'chez-scheme`. Fail if not; do not skip.
   The variables below are Racket CS debugging aids, observed on Racket 9.3 CS.
3. Check that the files directly in `aloe/` whose names match
   `^eval.*[.]rkt$` are exactly the four guarded files. A later evaluator
   module is named `aloe/eval-<part>.rkt` and joins the list.
4. Create a directory with `make-temporary-directory`. Copy every file under
   `aloe/`, except anything inside a `compiled/` directory, into `<tmp>/aloe/`
   at the same relative paths. Delete `<tmp>` in a `dynamic-wind` post thunk,
   so it is removed even when a check raises.
5. Run a subprocess with `system*` from `racket/system`: the executable is
   `(find-exe)` from `compiler/find-exe`, and the arguments are `-l- raco make`
   followed by the four files as `aloe/<name>.rkt`. Set its working directory
   to `<tmp>`. Give it a copy of the current environment variables with
   `PLT_CS_COMPILE_LIMIT=8000` and `PLT_LINKLET_SHOW_POST_INTERP=1` added.
   Capture its standard output and standard error together. Require a
   successful exit. When it fails, the check message carries the start of the
   output.
6. Parse the output's lines that start with `;; compile-linklet: `. Keep the
   latest value seen for `module:`, `phase:`, and `name:`. Each
   `step: <step>` line belongs to the linklet those three values describe.
   Racket prints `phase:` before `module:`; do not depend on their order. A
   guarded module's body is the linklet whose module is the bare name (`eval`,
   `eval-mirror`, …), whose phase is `0`, and whose name is `module`.
   Submodules print as `(eval method-records)` and are not bodies.
7. For each guarded module, check that its body has a `compiled` step, which
   proves it was compiled in this run. Then check that it has no `post-interp`
   step. Each message names the module and the limit.
8. Prove the detector works in the same run. Delete
   `<tmp>/aloe/compiled/eval_rkt.zo` and `eval_rkt.dep`, then run step 5 again
   with only `aloe/eval.rkt` and `PLT_CS_COMPILE_LIMIT=100`. Its dependencies
   are already compiled, so only `eval.rkt` compiles. Check that body `eval`
   has a `post-interp` step. A change in Racket's output shape must fail the
   test, not pass it.

The manager's prototype of this guard ran in 4.7 seconds on the cut tree. A
one-module version of it fails on the current tree with
`eval interpretable at 8000`.

## The speed check

The guard proves the compile mode. It does not prove the hot path stayed in
one module: a cut that separated the hot path would pass the guard and stay
slow. This check shows the inlining came back. It is required for acceptance.
A note in a summary is not enough.

Run it after the suite is green. Build three trees outside the repository:

- *before*: `HEAD` as committed, which is the tree before this checkpoint's
  edits. The implementer does not commit.
- *reference*: `HEAD` with only `aloe/eval.rkt` recompiled at
  `PLT_CS_COMPILE_LIMIT=1000000`. This is the whole-compiled reference.
- *after*: the working tree with this checkpoint, as the test run built it, at
  the default limit. `PLT_CS_COMPILE_LIMIT` must be unset in the shell.

From the repository root, with nothing else running (no `raco test`, no
build, no other benchmark):

```sh
work=/tmp/checkpoint-118-speed
mkdir -p "$work/before" "$work/reference"
git archive HEAD | tar -x -C "$work/before"
git archive HEAD | tar -x -C "$work/reference"
(cd "$work/before" && TMPDIR=/tmp raco make tests/aloemacs/window-pictures.rkt)
(cd "$work/reference" && TMPDIR=/tmp raco make tests/aloemacs/window-pictures.rkt &&
  rm aloe/compiled/eval_rkt.zo aloe/compiled/eval_rkt.dep &&
  PLT_CS_COMPILE_LIMIT=1000000 TMPDIR=/tmp raco make aloe/eval.rkt)
ln -sfn "$PWD" "$work/after"
for round in 1 2 3 4 5; do
  for tree in before reference after; do
    out=$(cd "$work/$tree" && TMPDIR=/tmp racket tests/aloemacs/window-pictures.rkt 2>&1)
    pick() { printf '%s\n' "$out" | grep -oE "$1: median [0-9.]+" | head -1 | awk '{printf "%.1f", $NF}'; }
    echo "$round $tree $(pick 'first screen') $(pick 'widest leaf deep') $(pick 'one window, deep')"
  done
done
```

Each run prints three medians: four windows on the first screen, four windows
with the widest leaf deep, and one window deep. A median at or over 30 ms fails
that run's check. The failure message carries the same text, so `pick` still
finds it. Record all 15 lines in the report.

For each tree and each deep case, take the median of its five run medians:
*B* for before, *R* for reference, *A* for after.

- **Validity.** *B* − *R* is at least 2.0 ms for both deep cases. If not, the
  trees were not built as described. Stop and report; do not judge the cut.
- **Gate.** For both deep cases, *A* ≤ *R* + (*B* − *R*) / 4. A split that
  recovered only half the speed would land at *R* + (*B* − *R*) / 2 and fail.
- The first-screen median is recorded, not gated. Its gap is about 0.6 ms, too
  small to judge a split by.

The manager's five rounds on the prototype of this cut (18 October 2026,
Intel i9-10885H, Racket 9.3 CS):

| Tree | Widest leaf deep | One window deep | First screen |
|---|---:|---:|---:|
| before | 27.4 | 17.4 | 3.2 |
| reference | 22.7 | 14.0 | 2.6 |
| after | 22.5 | 14.1 | 2.6 |
| gate on this run | ≤ 23.9 | ≤ 14.9 | — |

These figures are for comparison only. Your bounds come from the formula
applied to your own five rounds, not from this table.

If the gate fails, stop and report the table. Do not move more code, do not
split the hot path, and do not change any limit.

## Pins that stay

Three tests read `aloe/eval.rkt` as text or as a module. The cut keeps what
each one looks at in `aloe/eval.rkt`, so none of them changes:

- `tests/checkpoint-17.rkt`: List dispatch has no `[(map)` or `[(fold)` case.
  `send-to-list` and `send-to-list-method` stay in `aloe/eval.rkt`, so the pin
  still reads the module that holds List dispatch.
- `tests/checkpoint-88.rkt`: `aloe/eval.rkt` does not export
  `host-receiver-invoke-method`. `invoke-signature-row` and its `require` of
  the host submodule stay. The `provide` list is unchanged.
- `tests/checkpoint-115.rkt`: `aloe/eval.rkt` contains `split-lines`
  (`send-to-string` stays) and no `starts-with?`.

`tests/modules/004-method-records.rkt` requires
`(submod "aloe/eval.rkt" method-records)`, which stays.

The manager applied this cut to a scratch copy of `812bc84` and ran
`TMPDIR=/tmp raco test -j 4 -y tests`. The result was 6/3092 test failures,
all in `tests/editor/host-queries/001-manifest-reader.rkt` and
`002-lsp-hosts.rkt`. Those load host modules by collection path, which
resolves to the original checkout from a copy. With `PLTCOLLECTS` pointed at
the copy, all 27 tests in that directory pass. No other file failed or
crashed. No existing test changes in this checkpoint. If one fails in the
real tree, the cut was not applied as written. Compare against this document
before touching any test.

## Exact file scope

Implementation may edit only:

- `aloe/eval.rkt`
- `aloe/eval-value.rkt` (new)
- `aloe/eval-load.rkt` (new)
- `aloe/eval-mirror.rkt` (new)
- `tests/checkpoint-118.rkt` (new)
- `CHECKPOINTS.md`: the entry and the sentence below, nothing else
- `docs/decisions.md`: the entry below, appended at the end

Do not edit `SPEC.md`, `aloe/type.rkt`, any other `aloe/` module, `lib/`,
`examples/`, `host/racket/`, `bin/`, `info.rkt`, or any existing test. Do not
commit `compiled/`, the speed-check trees, or a speed-check script.

In `CHECKPOINTS.md`, insert this entry after the checkpoint 115 entry:

```text
## 118. [The evaluator under the compile limit](docs/checkpoints/0118-evaluator-compile-limit.md)

- Cold code leaves `aloe/eval.rkt` for `eval-value.rkt`, `eval-load.rkt`, and
  `eval-mirror.rkt`; the hot path stays together. Every evaluator module
  compiles whole at `PLT_CS_COMPILE_LIMIT=8000`, and a test enforces it. No
  Aloe behavior changes.
```

In the paragraph after it, the sentence that ends `; there is no global
checkpoint 118.` becomes:

```text
Editor and LSP work is organized as local projects rather than global
checkpoints. See [docs/editor/README.md](docs/editor/README.md).
```

Append this entry to `docs/decisions.md`:

```text
## Evaluator compile limit (2026-10-18)

Decided: every evaluator module, `aloe/eval.rkt` and the `aloe/eval-*.rkt`
modules split from it, compiles whole under Racket CS's compile limit with
20 percent to spare; `tests/checkpoint-118.rkt` fails when one takes the
interpretable path at `PLT_CS_COMPILE_LIMIT=8000`. The hot path stays in
`eval.rkt`; cold code moves out. Rejected: raising the limit through the
environment, a launcher, or a build flag; splitting the hot path across
modules.
```

## Tests and acceptance

Run:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/checkpoint-118.rkt
TMPDIR=/tmp raco test -j 4 -y tests
racket -e '(require "aloe/main.rkt") (displayln (eval-source "((Mirror of \"abc\") invoke (((Mirror of \"abc\") signatures) first) \"abc\")")) (displayln (eval-source "((Mirror of (List of 1 2)) raw)"))'
git diff --check
```

Then run the speed check.

Acceptance:

1. `tests/checkpoint-118.rkt` passes.
2. The whole suite is green. The one allowance is
   `tests/aloemacs/window-pictures.rkt`'s 30 ms timing bar. If that file fails
   only under `-j 4`, run `TMPDIR=/tmp raco test -j 4 -y
   tests/aloemacs/window-pictures.rkt` alone; it must pass. Report both runs.
   Every other failure is a failure.
3. The hand check prints `#t`, then `#<List 1 2>`. The current tree prints the
   same. The first expression goes through `signatures` and `invoke` in
   `aloe/eval-mirror.rkt` and `invoke-signature-row` in `aloe/eval.rkt`. The
   second goes through `raw` to the printer in `aloe/eval-value.rkt`.
4. The speed check is valid and passes its gate. The report has the 15-line
   table, the three trees' medians for each case, and the two bounds.
5. Every moved definition is byte-identical to its original, apart from the
   indentation inside `make-reflection-sends`. `git diff --check` is clean,
   and only the files in scope changed.

Stop for review when all of this holds. Do not commit, and do not begin
checkpoint 119.

## Explicit non-goals

- No change in what Aloe means. No `SPEC.md` edit.
- `aloe/type.rkt` is over the limit too. It is the checker, and it is a
  separate item. This checkpoint does not split it, and the guard does not
  cover it.
- No cheaper `List` `cons` or `rest`. No document has opened that change.
- No raised limit through the environment, a launcher, or a build flag.
- No other refactor: no renames, rewritten bodies, merged or split procedures,
  reordering within a module, new exports from `aloe/eval.rkt`, or changed
  error messages.
- No move of `invoke-signature-row`, `aloe-value->display-string`,
  `eval-load!`, or any hot-path definition.
- No edit to any existing test, including the three pins.
- No Aloemacs or editor frame-time work.
