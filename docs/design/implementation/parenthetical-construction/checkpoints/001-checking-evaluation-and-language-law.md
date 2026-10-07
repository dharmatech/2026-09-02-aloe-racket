# parenthetical-construction 001 — Checking, evaluation, and language law

**Status: Implemented in the working tree and checkpoint-manager reviewed
(2026-10-07).** Issued on 2026-10-07 after review of the accepted spec and
the grammar/traversal predecessor. Its requirements below are unchanged.

The implementation review passes the focused verification command
with **72 tests** and the full suite with **2,646 tests**.
`git diff --check` is green. The consumer rewrite remains the next slice.

## Goal

Check and evaluate the existing `new-star-expr` so fully labeled `new*`
builds the same generated `new` constructor as positional construction.
Check values in field declaration order with the existing expected-type
context; evaluate the receiver once, then values once in written order.
Prove diagnostics, generic and reflection parity, and editor continuity,
and make the language-document amendments authorized by the spec.

Stop when this language slice, its documents, and regression tests are
green. The Aloemacs session rewrite belongs to the next checkpoint.

If you have been told to read this file, this is the whole assignment.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **parenthetical-construction 001**. File:
  `checkpoints/001-checking-evaluation-and-language-law.md`. Number this
  locally; do not add a global checkpoint or a `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Branch: `experiment/2026-10-06-parenthetical-construction`, created
  from `main` at `987cbd0`. Continue on this branch; a human merges it.
- Read [`docs/workflow.md`](../../../../workflow.md),
  [`SPEC.md`](../../../../../SPEC.md), and
  [`CHECKPOINTS.md`](../../../../../CHECKPOINTS.md) before writing code.
  `SPEC.md` remains law except for the specific new-form rules and document
  amendments authorized by the accepted feature spec.
- Accepted [../spec.md](../spec.md) §§1–3 govern the series, boundaries,
  tools, and exhaustive scopes. All of §5 governs this slice; §§7–8 supply
  its verification and acceptance obligations. §4 defines the completed
  parser interface. §6 describes later work, not this assignment. The
  charter, sketches, earlier conversation, and colon experiment are not
  additional authority.
- Predecessor: **parenthetical-construction 000 — Grammar and AST
  traversal** is implemented in the working tree and reviewed against its
  written checkpoint. Its focused verification passes **399 tests**.
  Keep that existing work. It supplies the exported transparent structures
  `(construction-binding name value)` and
  `(new-star-expr receiver bindings loc)`, whole-tail shape validation,
  source spans, and all required expression/completion traversal.
  The checker and evaluator do not yet handle the node.

The manager also ran `TMPDIR=/tmp raco test -y tests`: **2,630 tests
passed**. The whitespace check is green. This verifies the predecessor;
it is not acceptance of an implementation of this checkpoint.

Evaluation remains send; selectors are literal; functions execute through
`call`; `let` expands to `fn` plus `call`. Add no inheritance, Aloe mutation,
macros, implicit Int/Float coercion, or other special form.

## Exact file scope

### May create or edit

- `aloe/type.rkt`: add checking of `new-star-expr`, including eligibility,
  name validation, and declaration-order reuse of `infer-construction`.
  Preserve the normal unification and observation hooks.
- `aloe/eval.rkt`: add evaluation of `new-star-expr`, retain explicit
  constructor provenance in the private runtime class representation, and
  reuse the existing `construct-instance` path.
- `SPEC.md`: only §3.2's construction rule, a new §4.11 directly after
  `case`, removal of the `labeled make` item in §8, and the additional
  labeled Point goldens beside the preserved positional goldens in §9,
  exactly as feature-spec §5.5 directs.
- `docs/decisions.md`: only add the dated **Parenthetical construction
  (2026-10-07)** entry specified in feature-spec §5.5.
- Create `tests/parenthetical-construction/law.rkt` and
  `tests/parenthetical-construction/editor.rkt`. Keep focused helpers and
  fixture source strings in these files. Temporary query fixtures belong
  in temporary directories and must be cleaned up.

### Must leave untouched

- `aloe/parse.rkt`, both private selection walkers,
  `aloe/completion-query.rkt`, `aloe/private/checker-observation.rkt`,
  `aloe/expression-query.rkt`, and all other kernel/query modules.
- Drivers, entry points, host implementations and keyword validation,
  libraries, signature catalogs, language-server/editor APIs, and tooling.
- All existing tests and fixtures, including
  `tests/parenthetical-construction/grammar.rkt` and
  `tests/aloemacs/runner.rkt`.
- Every `.aloe` program, including `examples/aloemacs/main.aloe`,
  `file.aloe`, and `editor.aloe`.
- All other sections of `SPEC.md`, especially §1, §2.1, and §7.2;
  `CHECKPOINTS.md`, global checkpoints, this series' README/spec/charter
  and checkpoint documents, and all other design documents.
- The colon experiment, Gel, Boids, and unrelated working-tree changes.

These lists are exhaustive. If another file or a broader change is
necessary, stop and return this checkpoint to the manager instead of
widening it. If the slice cannot fit one implementer conversation, return
the size finding to the manager.

## Slice requirements

### 1. Eligibility and diagnostic precedence

The parser already validates every immediate binding-pair shape before
parsing the receiver or values. Preserve that syntax precedence. For a
well-shaped `new-star-expr`, checking proceeds in this order:

1. Infer and resolve the receiver using the existing expression rules.
   Preserve receiver errors, including unbound names and different-class
   `if` arms, before eligibility or names are considered.
2. Require a class-object type declared with `(fields ...)` and its
   generated `new` constructor. Use `class-info-explicit-constructors?`;
   a constructor named `new` alone does not establish eligibility.
   Instances, `List`, primitive class objects, and every explicit
   `(constructors ...)` class are ineligible.
3. Walk names in written order. Report the first unknown field or duplicate
   field, whichever offending pair appears first, and stop.
4. If every written name is valid and unique, report all absent fields in
   declaration order as missing fields. This is not positional arity.
5. Only when names exactly cover the fields, check their values.

Do not infer any value before eligibility and name coverage succeed.
Use `exn:fail:aloe-type` for checker failures and the existing evaluator
exception convention for runtime failures. Keep missing field, unknown
field, duplicate field, and ineligible `new*` distinguishable and name the
offending fields. Preserve positional `new` arity and unknown-message
behavior. Tests pin categories and relevant names, not whole sentences.

For fields `x`, `y`, these cases fix the ordering:

| Form | Required result |
|---|---|
| `(Point new* (z 1) (x 1) (x 2))` | Unknown field `z` |
| `(Point new* (x 1) (x 2) (z 3))` | Duplicate field `x` |
| `(Point new* (y "bad"))` | Missing field `x` before checking the value |
| `(Point new*)` | Missing fields `x`, `y`, in declaration order |
| `(Point new 1)` | Existing positional arity error |
| `(List new*)` | Ineligible `new*` |

A class alias and a computed expression with the same eligible class-object
type work. A non-generic empty `(fields)` class accepts `(Empty new*)`
and `(Empty new)` with the same empty payload. Retain existing generic
inference requirements for empty generic products.

### 2. Declaration-order checking and contextual observation

After name validation, associate each literal name with its original value
AST. Obtain argument expressions by walking the generated constructor's
fields in declaration order, and pass them to the existing
`infer-construction` with the same class, constructor, environment, and
expected type used by positional construction.

This ordered list is only a checking view. Keep the original node and
child identities for observation. The original bindings retain written
order for evaluation. Do not infer values first in source order, lower the
node to `let`, copy child nodes, or change generic inference.

Acceptance is exactly that of the positional counterpart whose arguments
are in field declaration order. Pair permutation must preserve expected
field types, expected concrete instance types, and generic consistency.
In particular, both permutations must accept a non-generic class with
fields `(items (List String))` and `(measure (-> String Int))`, supplied
with `(List empty)` and `(fn (s) (s len))`. The field supplies `s : String`.
Also cover a generic class whose expected concrete instance type supplies
its field context.

Add the `infer-expression` arm without bypassing its normal final
unification, `retain-expression-observation!`, or
`observe-selector-receiver!` calls. No field label is an expression to
observe, and no new observation API belongs here.

### 3. Source-order evaluation and runtime provenance

Add the `eval-expr` arm. Evaluate the receiver once. Before evaluating
values, enforce runtime eligibility and the same written-order unknown/
duplicate checks, followed by declaration-order missing fields. These
guards are required on raw `eval-expr`, independently of checked execution.
An invalid receiver or name set must run no value effects.

Retain an explicit-constructor flag on the private runtime class value,
initialized from `define-class-expr` before its declaration kinds are
normalized to constructor lists. Distinguish an empty `(fields)` product
from explicit constructors with empty payloads, including an explicitly
named `new`. Keep the class's reflected rows and instance payload layout.
Do not export new runtime APIs or infer eligibility from the selector alone.

Once validation succeeds, evaluate each value once in written order in
the surrounding environment. Names and `new*` do not evaluate or introduce
bindings. Associate results with declaration indices and, after all values
have run, assemble declaration-order arguments for
`construct-instance receiver 'new ordered-values`.

Reuse that construction path for immutable payloads, constructor identity,
runtime generic inference, field reads, equality, and reflection. Do not
reorder expressions before evaluation, cache their results across prepared
runs, or introduce an Aloe dictionary or second constructor.

For an outer `x` bound to `5`, `(Point new* (y (x + 1)) (x 10))` evaluates
the `y` value first, stores `x = 10`, and stores `y = 6`. The pair named
`x` does not shadow the outer variable.

### 4. Language-document amendments

Apply feature-spec §5.5's exact scoped amendments to `SPEC.md` and its
dated entry to `docs/decisions.md`. That subsection provides the complete
replacement/addition text; do not invent further language rules.

The documents must describe the reserved second-position syntax seat,
pair-shape and diagnostic precedence, eligible declaration kind,
declaration-order checking, source-order evaluation, and the single
reflected `new` constructor. Preserve all positional Point goldens and
add both labeled goldens. Remove the obsolete labeled-`make` exclusions
without adding a `make` selector. Record the later macro replacement
constraint without building or proving such a macro in this series.

### 5. Focused language tests

Use `rackunit` in `law.rkt` and the existing checked driver, parser,
checker, and evaluator interfaces. Test-only host methods may record
effects through explicitly injected capabilities; add no production trace
helper or Aloe mutation. Prove all of feature-spec §5.4's language cases:

- Positional/labeled parity in both pair orders: type, `new` identity,
  payload equality, and field reads. Preserve existing positional sends,
  explicit constructors, and goldens. Verify class and instance reflection
  adds neither `new*` messages nor signatures.
- Aliased and computed same-class receivers work; different-class `if`
  arms fail. An effectful receiver runs once before value effects.
  Swapping pairs swaps their recorded effects while preserving field
  storage. Preparing once and running twice reevaluates receiver and values
  on each run; preparation and failed checked calls run no effects.
- Labels need no variable bindings. Values see the outer environment,
  including outer `x` and an ordinary variable named `new*`. A colon-suffix
  field uses its exact symbol `x:`; another symbol is unknown.
- Malformed shapes remain syntax errors. Cover each name-error category,
  first-offending-pair precedence, multiple missing fields in declaration
  order, name errors before invalid/unbound values, and receiver errors
  before names. Positional count failures remain arity.
- Empty products accept both spellings. Explicit constructors remain
  ineligible, including a sole explicit `new` with empty payload. Reject
  instance, `List`, and primitive-class receivers. Raw evaluation enforces
  eligibility and the same name-error ordering without value effects.
- Generic Point accepts homogeneous Int and homogeneous Float values and
  rejects mixed values in either pair order, matching positional calls.
  Expected concrete generic instance types retain field context.
  Standalone `(define n (Option None))` still fails; the existing `if`
  witness remains legal.
- Exercise both empty-list/function permutations from requirement 2.
  Also wrap each value in an `if` whose test is an injected host send
  returning `Bool` and recording a distinct marker. Both list branches
  are `(List empty)`; both function branches are `(fn (s) (s len))`.
  Prove the expected list element type through checking, written-order
  effects, empty stored list observations, and that the stored function
  called on `"abc"` returns `3`. Compare field observations rather than
  identity of separately created functions.
- Use independent class fixtures to reorder equal-typed fields: labeled
  values stay attached to their names while an unchanged positional call
  remains accepted with changed field associations. Reordering distinct-
  typed fields rejects the unchanged positional call. Renaming rejects
  the old label; adding or removing a field rejects unchanged old calls
  of either spelling.

### 6. Editor continuity tests

In `editor.rkt`, use the existing `query-expression-at` and
`query-selector-completions` public interfaces. Use temporary source files
when their interfaces or source-relative loads require them.

Cover both pair orders and a construction inside a method body. Hover must
reach an ordinary value expression and the function parameter checked
against its field type. Selector completion inside that function's
`(s ...)` must receive the existing String signatures from the same field
context. Retain source locations and replacement coordinates.

Cover `load` nested in a binding value: completion traversal must reach it
and retain the existing source-path policy, including no completion when
a load is present without a source path. A field-name position yields no
field-name completion. Add no field-name API, highlighting, or language-
server changes.

## Verification and completion

Run from `/home/dharmatech/journal/2026-09-02-aloe-racket`:

```sh
TMPDIR=/tmp raco test -y tests/parenthetical-construction/law.rkt tests/parenthetical-construction/editor.rkt tests/checkpoint-83.rkt
TMPDIR=/tmp raco test -y tests
git diff --check
```

`TMPDIR=/tmp` and `-y` are required. The full command is recursive; do not
replace it with `tests/*.rkt`. The existing host test must keep rejecting
required and optional keyword implementations. Do not commit `compiled/`.

An optional hand check, after the tests rebuild bytecode, is:

```sh
./bin/aloe examples/point.aloe
```

At the prompt, `(check (Point new* (y 2) (x 1)) (Point new 1 2))` succeeds
and `((Point new* (y 2) (x 1)) x)` returns `1`. End with `(exit)`. This
does not replace automated verification. Entry points do not rebuild
bytecode; use the test command or
`raco make host/racket/aloemacs-run.rkt bin/aloe` before launching after
`.rkt` edits. No Aloemacs terminal check is needed in this slice.

Complete when the focused tests prove the language and editor obligations,
the scoped law and decisions amendments match feature-spec §5.5, the full
suite and whitespace check pass, and every change stays within scope.
Report changed files and verification results, then stop for human review.
Do not start or write parenthetical-construction 002 or rewrite the session.

## Explicit non-goals

- Parser or AST redesign, walker changes, a new elaboration IR, public
  diagnostic or observation frameworks, and reflection API additions.
- Defaults, mixed tails, labels on methods/protocols/numbers/host messages,
  `List`, or explicit constructors; a `make` selector, copying `with`,
  computed labels, dictionaries, keywords, macros, or colon label tokens.
- Reader or identifier changes, implicit numeric coercion, expanded generic
  inference, field-name completion/highlighting, language-server work,
  new dependencies, Boids, Gel, committing, or merging.
- Any consumer source rewrite or existing test snapshot update. Those
  belong only to the closing session-definition checkpoint.
