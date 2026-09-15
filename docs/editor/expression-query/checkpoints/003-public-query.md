# Editor expression query 003 — Public path query

**Status.** Implemented and reviewed. The focused 18-test suite and the
135-test editor predecessor suite are green, and the exact Point hand check
matches the required public result and location. The recursive suite passes
1,897 of 1,899 tests; its only failures are the two pre-existing
`tests/gel/presentations/003-doc-law.rkt` wording contradictions. This
checkpoint introduces no additional failure.

## Goal

Complete the expression-query experiment with its public, path-based Racket
operation. Read and select from one complete normalized source file, create a
fresh standard checker environment, run the contextual observation completed
by checkpoints 001–002, and return the selected type, ordered signatures, and
source location as plain Racket data.

This is the final implementation slice for the Expression Query
specification. It integrates accepted components; it does not redesign
selection, checking, signature discovery, loading, evaluation, or Aloe.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law for reading, checking, source order,
  sends, classes, methods, protocols, and `load`.
- `docs/editor/expression-query/spec.md` is the local design authority. This
  checkpoint completes its public result, path reading, default environment,
  complete-file failure, and integration requirements.
- Editor-expression-query 000 is implemented and reviewed. Its private
  `select-expression-at-position` is the only source-position selector.
- Editor-expression-query 001–002 are implemented and reviewed. The private
  `typecheck-program/observe` checks the real program, observes by identity,
  materializes at the selected root's end, handles one selected deferred
  generic body rigidly, continues through later roots and protocol
  conformance, and returns an `expression-type-observation` or `#f`.
- Editor-signatures-of-type 000–002 are implemented and reviewed. The
  existing shared transparent `signature-spec` and `type-signature-specs`
  remain the only signature representation and row source.
- `aloe/main.rkt` already exports the static `make-type-environment` that
  creates a fresh checker environment and installs List followed by String.

Identity is `(editor-expression-query, 003)`, spoken
**editor-expression-query 003**. This is a local editor checkpoint, not a
global checkpoint and not part of either predecessor series. Do not edit
`CHECKPOINTS.md` or add a file under `docs/checkpoints/`.

## Exact public module and surface

Add `aloe/expression-query.rkt` with this exact public surface:

```racket
(struct expression-query-result (type signatures location) #:transparent)

(query-expression-at source-path position)
  ; source-path : path-string?
  ; position    : exact-positive-integer?
  ; -> (or/c expression-query-result? #f)
```

Also re-export `(struct-out signature-spec)` from
`aloe/signature-catalog.rkt`. This must be the existing structure binding,
not a wrapper, copy, or look-alike structure. A consumer requiring only
`aloe/expression-query.rkt` can therefore construct, recognize, and inspect
both the result and every signature row.

The result fields contain:

- `type`: the already materialized type datum from
  `expression-type-observation-type`;
- `signatures`: the already materialized fresh proper list from
  `expression-type-observation-signatures`; and
- `location`: the selected AST node's existing `expression-loc` `srcloc`.

Do not convert these values to strings or Aloe runtime values. Do not copy or
rebuild a signature list in the public layer. The observation layer already
obtains the rows from `type-signature-specs` in the selected lexical
environment.

Do not export the private selection helpers, observation structure,
`typecheck-program/observe`, a checker environment, or any additional public
binding. Do not re-export the query or result from `aloe/main.rkt` or
`aloe/driver.rkt` and do not add an Aloe runtime message.

## Validate and normalize the request

`query-expression-at` has exactly two required arguments and no optional or
keyword arguments.

Validate before filesystem access:

- `source-path` must satisfy `path-string?`; otherwise raise a Racket argument
  error whose `who` is `query-expression-at` and whose expected contract is
  `path-string?`.
- `position` must satisfy `exact-positive-integer?`; otherwise raise a Racket
  argument error whose `who` is `query-expression-at` and whose expected
  contract is `exact-positive-integer?`.

Accept both Racket path values and strings. Do not require `.aloe` or any
other suffix.

Before opening the file, convert the accepted path to the equivalent of:

```racket
(simplify-path (path->complete-path source-path) #f)
```

Use that one complete, simplified path for the root-file check, file opening,
and `read-program`'s `#:source-path`. The selected result's
`srcloc-source` must consequently be equal to that normalized path, including
when the caller supplied a relative string containing `.` or `..`.

The normalized root must name a regular file. A missing path or a directory
must raise an error that names the path; opening errors for an unreadable file
may propagate normally. Do not silently return `#f` for a filesystem error
and do not infer file type from its suffix.

## Read the complete file, then select

Open the normalized root and read it to EOF with exactly the existing
`read-program` operation and the normalized path supplied as
`#:source-path`. `read-program` must return the complete root expression list
before selection or checking begins.

Do not use `read`, `parse-datum`, `parse-program`, `syntax->datum` on whole
forms, a text scan, or a second parser. Reader and Aloe parser failures must
propagate before any checker failure from an earlier well-formed root can be
reported. There is no incomplete-buffer or well-formed-prefix mode.

Pass the complete root list and requested position once to
`select-expression-at-position`. The exact returned object, or `#f`, is the
only target supplied to the observer. Do not infer a node from its location,
reparse the source, or detach a nested node for separate checking.

Checkpoint 000's rules remain final: the smallest containing expression
wins, preorder breaks equal-span ties, selectors belong to sends, syntax-only
declaration parts are not expressions, and top-level gaps select nothing.
The root coordinate never addresses expressions parsed from a loaded file.

## Fresh static environment and one checker pass

After successful root reading and selection, call the existing static
`make-type-environment` from `aloe/main.rkt` once for every query. Require only
that binding from `main.rkt`; do not call `make-driver` or create either a
driver or runtime environment.

That helper creates the raw checker environment and checks the standard List
library followed by the standard String library. Do not duplicate that
bootstrap, load those libraries from the queried source, cache an environment,
or retain an environment between calls.

Call `typecheck-program/observe` exactly once with:

1. the complete root expression list;
2. that fresh default checker environment; and
3. the exact selected expression object or `#f`.

If the observer returns `#f`, return `#f`. This is the valid top-level-gap
case and happens only after strict complete checking succeeds. If it returns
an observation, construct one `expression-query-result` from the observation
fields and the selected expression's location.

Do not call `type-of` on the selected node, call `type-signature-specs` again,
walk a declaration table, or perform a second checker pass. Do not add
query-specific checking behavior to this public module.

## Source order, loads, and strict failure

All complete-program behavior comes from the accepted reader and observer:

- earlier declarations and method installations are visible to the selected
  expression;
- all rows installed by the selected root itself are visible at that root's
  successful end;
- a later `define-methods` form does not retroactively change an already
  materialized answer;
- all later roots and final protocol conformance are still checked;
- checking stops at the first error in normal checker order; and
- any later checker failure suppresses an earlier answer by raising.

`load` keeps its existing behavior. Paths resolve relative to the file
containing the `load`; each loaded file is read with source locations and
checked in the same environment; earlier loaded bindings, classes, and
installed methods are visible afterward. Missing loaded files and load cycles
retain their existing checker failures and exact text. Do not prewalk,
flatten, or separately query a load graph.

A matched expression and a gap have the same strict complete-file policy.
Reader/parser errors, missing files, checker errors, and final conformance
errors are never converted to `#f` or wrapped in a result.

Every successful and failed call is isolated. It must retain no bindings,
classes, method rows, inference constraints, load-cycle state, selected node,
or observation for a later call. Repeated default-library queries contain one
copy of every installed List or String extension row.

## Static-only and catalog boundaries

The public operation performs no Aloe evaluation. It must not:

- create a runtime environment or driver;
- call `eval-expr`, `eval-exprs`, `eval-source`, or a driver evaluation
  operation;
- reflect an Aloe runtime value or construct Aloe `List`, `Mirror`, or
  `Signature` values;
- accept or install a host receiver;
- invoke a host implementation; or
- print source-program output.

The two-argument surface has no host-injection escape hatch. A queried source
that refers to an otherwise optional host name such as `term` fails through
the ordinary unbound-symbol checker error.

Production expression-query code must not name Point selectors, List/String
library selectors, kernel selectors, or use `class-info-methods` or another
declaration-table accessor. It must not construct `signature-spec` rows. The
only permitted reason to require `aloe/signature-catalog.rkt` is to re-export
the accepted `signature-spec` binding.

## Normative Point result

Use the unchanged exact 178-byte fixture at
`tests/editor/expression-query/fixtures/point.aloe`. Position 170 is inside
the literal `new` selector of the final send. Checkpoint 000 therefore selects
the entire `(Point new 1 2)` send.

The exact public result has:

```text
type: (Point Int)
location: normalized fixture path, line 10, column 0, position 163, span 15
signatures, in order:
  x     : ()          -> Int
  y     : ()          -> Int
  +     : (Point Int) -> (Point Int)
  dist2 : (Point Int) -> Int
```

These are four exact shared `signature-spec` values. The `+` row's
`parameters` field is `'((Point Int))`. The location belongs to the selected
send, not its selector token.

Position 108 in the same fixture must also work through the public operation
and retain checkpoint 002's exact `(Point T)` declaration-context result with
the four rows parameterized by `T`. The later concrete construction must not
specialize that answer.

## Relative-load fixture

Add exactly this small fixture pair below a dedicated directory. Every shown
line ends in LF.

`tests/editor/expression-query/fixtures/003-public-query/support.aloe`:

```aloe
(define-class Loaded
  (fields
    (value Int))
  (methods))
```

`tests/editor/expression-query/fixtures/003-public-query/root.aloe`:

```aloe
(load "support.aloe")
(Loaded new 7)
```

Querying the `new` selector in `root.aloe` must return type `Loaded` and the
single row `(value () Int)`. This proves that the load resolves from the
containing file and contributes its class to the same checker environment.
The returned location source remains the normalized `root.aloe` path; loaded
expressions are not grafted into the root tree.

Use temporary files or directories created by the test for extensionless
roots, malformed inputs, missing-load cases, later-error cases, independence,
and other one-off programs. Do not add a fixture for every assertion.

## Exact file scope

Implementation may add only:

- `aloe/expression-query.rkt`
- `tests/editor/expression-query/003-public-query.rkt`
- `tests/editor/expression-query/fixtures/003-public-query/root.aloe`
- `tests/editor/expression-query/fixtures/003-public-query/support.aloe`

Do not edit:

- `aloe/type.rkt`, `aloe/private/expression-selection.rkt`, `aloe/parse.rkt`,
  `aloe/signature-catalog.rkt`, `aloe/main.rkt`, `aloe/driver.rkt`,
  `aloe/eval.rkt`, `aloe/library.rkt`, `aloe/env.rkt`, or `aloe/host.rkt`
- checkpoint 000–002 tests or any existing fixture
- signatures-of-type tests
- `SPEC.md`, `CHECKPOINTS.md`, or anything under `docs/checkpoints/`
- the expression-query specification, charter, README, or checkpoint
  documents except for status/index updates made by the checkpoint manager
- `gel/`, `lib/`, `host/`, or another editor project

The accepted private APIs and canonical static environment helper are
sufficient for this adapter. If implementing the public operation requires
changing selection, observation, checking, signature discovery, bootstrap,
or load behavior, stop and return the checkpoint for design review.

## Required tests

Add `tests/editor/expression-query/003-public-query.rkt`. It is three
directories below the repository root, so use `../../../aloe/...` in
`require` and `define-runtime-path` paths. Exercise the public module for all
observable query behavior; private modules may be required only for explicit
parity or non-export assertions.

Compare complete type datums, complete `signature-spec` structures in order,
and complete `srcloc` fields. Cover at least:

1. The public procedure has arity exactly two. The transparent result has
   fields in `type`, `signatures`, `location` order. The public
   `signature-spec` constructor, predicate, and accessors are the same
   bindings exported by `aloe/signature-catalog.rkt`.
2. The public module does not export the private selector, containment helper,
   observation structure, observer, checker operations, environment helper,
   driver operations, or additional query variants. `main.rkt` and
   `driver.rkt` do not export `query-expression-at`.
3. Position 170 in the exact Point fixture returns `(Point Int)`, all four
   exact ordered rows, and an `srcloc` whose source is the normalized fixture
   path and whose line, column, position, and span are `10`, `0`, `163`, and
   `15`.
4. Position 108 in that fixture returns exact symbolic `(Point T)` and all
   four symbolic rows from checkpoint 002, proving public rigid-body
   integration.
5. Through the public operation, retain representative selection locks from
   checkpoint 000: a nested atom, a nested send parenthesis, selector text,
   inner whitespace, top-level whitespace, and an equal-span `let` or `if`
   sugar position. Do not duplicate all 82 private-helper assertions.
6. Through the public operation, retain representative lexical observations
   from 001: at least one nested `self` or method parameter and one `fn`,
   `let`, or case-payload binding must succeed in its real context.
7. A file containing `(List of 1)` reports `(List Int)` with the five kernel
   rows followed by `fold`, `reverse`, and `map`; a String literal reports
   the four kernel rows followed by `starts-with?`. Pin all row structures and
   order. No source `load` is used.
8. Compare at least one public List or String signature result directly with
   `type-signature-specs` for the same top-level checker type in a fresh
   `make-type-environment`; the lists must be equal. Repeating each public
   query returns an equal but fresh proper list with no duplicated selector.
9. The fixed relative-load fixture returns `Loaded` and exactly
   `(signature-spec 'value '() 'Int)` at its root send. The same test proves
   that its result location names normalized `root.aloe`, not
   `support.aloe`.
10. An extensionless temporary regular file is accepted. A relative string
    path containing `.` or `..` and an equivalent Racket path value produce
    equal answers whose `srcloc-source` is the same complete simplified path.
11. A later valid `define-methods` form is fully checked but its installed row
    is absent from an earlier selected value's already materialized rows. A
    variant with an error in that later form raises and returns no earlier
    answer.
12. A checker-valid but runtime-failing program such as `(1 / 0)` returns its
    static result without division. Capture output and prove the query emits
    nothing. A source reference to an unprovided host name such as `term`
    raises the unchanged unbound-symbol `exn:fail:aloe-type?`.
13. Non-path values and positions including zero, a negative integer, an
    inexact positive number, an exact non-integer, and a non-number raise
    Racket argument errors naming `query-expression-at` and the required
    contract. Neither validation case touches the filesystem.
14. A missing root and a directory root raise filesystem/query errors naming
    their paths. A missing relative loaded file raises the existing
    `exn:fail:aloe-type?` load error with unchanged text.
15. An unclosed form and a malformed send propagate reader/parser failures,
    never `#f`. Put an earlier well-formed but checker-invalid root before a
    later malformed form and prove reading/parsing the entire root wins before
    checking begins.
16. Two checker-invalid roots report only the first ordinary checker error
    with its unchanged text. A checker error after an otherwise observable
    selected root suppresses the result. A valid top-level gap, trailing
    newline, comment gap, and position one character beyond EOF return `#f`
    only after the complete program succeeds; the same gaps still raise for
    an invalid complete program.
17. A successful query that installs a class or method, and a failed query
    that installs one before a later error, do not affect a following query.
    Repeated successful and failed calls remain independent.
18. Read the production module as text and prove it does not contain a
    `signature-spec` constructor call, declaration-table inspection,
    evaluator/driver/host operation, or quoted Point/List/String/kernel
    selector catalog. This is a narrow architectural assertion, not a ban on
    the required public re-export names.

Tests may create temporary directories under the system temporary directory
and remove their exact paths through a cleanup helper or `dynamic-wind`.
Never change process-wide current-directory state without restoring it.

## Baseline suite note

The current branch has two unrelated failures already present before this
checkpoint, both in `tests/gel/presentations/003-doc-law.rkt`. One assertion
expects pre-003 handoff wording, and another expects the older experiment
shape even though the checked-in Gel documents record 003 as complete.

Do not edit or weaken those tests or documents. Require the focused suites to
be completely green and the recursive suite to retain exactly those two
failures with no new failure. If the baseline contradiction has been repaired
before implementation starts, require a completely green recursive suite.

## Hand check and acceptance

After the automated tests, run this from a Racket REPL at the repository
root:

```racket
(require "aloe/expression-query.rkt")

(define point-path
  (simplify-path
   (path->complete-path
    "tests/editor/expression-query/fixtures/point.aloe")
   #f))

(define answer (query-expression-at point-path 170))

(list
 (expression-query-result-type answer)
 (for/list ([row (in-list
                  (expression-query-result-signatures answer))])
   (list (signature-spec-selector row)
         (signature-spec-parameters row)
         (signature-spec-return row)))
 (let ([location (expression-query-result-location answer)])
   (list (equal? (srcloc-source location) point-path)
         (srcloc-line location)
         (srcloc-column location)
         (srcloc-position location)
         (srcloc-span location))))
```

The exact result is:

```racket
'((Point Int)
  ((x () Int)
   (y () Int)
   (+ ((Point Int)) (Point Int))
   (dist2 ((Point Int)) Int))
  (#t 10 0 163 15))
```

Run:

```sh
raco test tests/editor/expression-query/003-public-query.rkt
raco test tests/editor/expression-query/002-rigid-generic-body.rkt
raco test tests/editor/expression-query/001-contextual-observation.rkt
raco test tests/editor/expression-query/000-selection.rkt
raco test tests/editor/signatures-of-type/000-shared-catalog.rkt
raco test tests/editor/signatures-of-type/001-kernel-query.rkt
raco test tests/editor/signatures-of-type/002-declaration-query.rkt
raco test tests
git diff --check
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directories.

The checkpoint is complete when the exact two-argument public module composes
the accepted selector and observer over a fresh standard checker environment,
the normalized path and full result shape are exact, strict whole-file and
load failures are preserved, default rows are neither missing nor duplicated,
the normative hand result matches, and no recursive-suite failure is
introduced. Stop for review without committing. Do not begin an LSP, CLI, or
another expression-query checkpoint.

## Explicit non-goals

- No change to selection, AST traversal, checker instrumentation, rigid
  generic checking, materialization, type inference, or signature discovery
- No change to Aloe syntax, sends, overloads, source order, protocols, loads,
  or error text
- No query re-export from `main.rkt` or `driver.rkt`, runtime Aloe message,
  driver integration, or serialized protocol
- No evaluation, runtime environment, runtime reflection, Aloe `Signature`
  value, host injection, ambient capability, or host implementation call
- No source-string or caller-supplied-AST query, unsaved-buffer API, or
  location fabrication for `parse-datum` and `parse-program`
- No second parser, text scanner, incomplete-buffer recovery, selector hole,
  incremental parsing, diagnostic accumulation, or checking past the first
  error
- No CLI, LSP, JSON-RPC, editor adapter, UTF-16 conversion, completion, hover,
  or VS Code/Emacs work
- No second signature catalog, hard-coded method rows, sorting,
  deduplication, cache, or direct class-method inspection
- No new special form, macro, mutation, inheritance, coercion, Gel, Boids,
  filesystem vocabulary, or unrelated cleanup
