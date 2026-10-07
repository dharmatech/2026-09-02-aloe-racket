# parenthetical-construction 000 — Grammar and AST traversal

**Status: Implemented in the working tree and checkpoint-manager reviewed
(2026-10-07).** Issued on 2026-10-07 after review and acceptance of the
parenthetical-construction spec. Its requirements below are unchanged.

## Goal

Parse `(receiver-expr new* (field-name value-expr) ...)` into its own AST
node, preserve the written order and source locations of its expressions,
and make the existing expression and selector-selection walkers traverse
that node. Prove this parser-only slice without requiring the checker or
evaluator to understand labeled construction.

Stop when grammar, source spans, traversal, and existing-program regression
checks are green. Checking, evaluation, language-law amendments, and the
Aloemacs startup rewrite belong to later checkpoints.

If you have been told to read this file, this is the whole assignment.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **parenthetical-construction 000**. File:
  `checkpoints/000-grammar-and-ast-traversal.md`. This is a local project
  number; do not add a global checkpoint or a `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Branch: `experiment/2026-10-06-parenthetical-construction`, created from
  `main` at `987cbd0`. Continue on this branch; a human merges the series.
- Read [`docs/workflow.md`](../../../../workflow.md),
  [`SPEC.md`](../../../../../SPEC.md), and
  [`CHECKPOINTS.md`](../../../../../CHECKPOINTS.md) before writing code.
  `SPEC.md` remains law except for the explicitly authorized new-form work
  in the accepted spec. This checkpoint does not amend `SPEC.md`.
- Accepted [../spec.md](../spec.md) §§1–3 govern the series, product boundary,
  file scopes, and host verification. All of §4 governs this slice;
  §§7–8 supply its applicable verification and acceptance obligations.
  §§5–6 describe later work, not this assignment. The charter, sketches,
  earlier conversation, and colon experiment supply no additional authority.
- There is no predecessor checkpoint. The starting tree has positional
  construction, second-position `case` parsing, source spans, expression
  selection/containment, and ordinary selector recovery. It has no
  `new-star-expr` or `construction-binding` structure.
- The manager ran the existing runner, source-location, expression-selection,
  and selector-recovery tests with `TMPDIR=/tmp raco test -y` before issuing
  this checkpoint: **395 tests passed**. This is baseline evidence, not
  acceptance of an implementation of `new*`.

Existing language rules continue to apply to receiver and value expressions:
evaluation is send; selectors are literal; functions execute through
`call`; `let` expands to `fn` plus `call`. Add no inheritance, Aloe mutation,
macros, implicit Int/Float coercion, or other special form.

## Exact file scope

### May create or edit

- `aloe/parse.rkt`: export the two AST structures, recognize and validate
  the new syntax, and add its `expression-loc` arm.
- `aloe/private/expression-selection.rkt`: add traversal of the receiver
  and binding values for selection and containment.
- `aloe/private/completion-selection.rkt`: add the same traversal for
  nested ordinary selector recovery; keep the reserved `new*` syntax
  token out of ordinary selector sites.
- `aloe/completion-query.rkt`: add the same traversal, and only the imports
  it needs, so the existing nested-`load` detection reaches binding values.
  Preserve its source-path policy and public interface.
- `tests/editor/source-locations/000-spans.rkt`: only a new-node arm in
  its location-free walker. Preserve all existing fixtures and assertions.
- Create `tests/parenthetical-construction/grammar.rkt`. Keep focused
  helpers and test source strings in this file.

### Must leave untouched

- `aloe/type.rkt`, `aloe/eval.rkt`, other kernel modules, drivers, host
  validation and capabilities, libraries, signature catalogs, and entry
  points.
- All `.aloe` programs, including `examples/aloemacs/main.aloe`,
  `file.aloe`, and `editor.aloe`; `tests/aloemacs/runner.rkt`.
- Every other existing test and fixture, including the expression-query
  and completion test files named in verification below.
- `SPEC.md`, `CHECKPOINTS.md`, `docs/decisions.md`, global checkpoints,
  this series' README/spec/charter, and all other design documents.
- The colon experiment, Gel, Boids, and unrelated working-tree changes.

These lists are exhaustive. If another file or a broader behavior change
is necessary, stop and send this checkpoint back to the manager instead
of widening it. If the slice cannot fit one implementer conversation,
return the size finding to the manager.

## Slice requirements

### 1. Syntax and validation precedence

Recognize a proper combination with `new*` as its second source element
before the ordinary-send fallback, beside second-position `case`.
Preserve the existing priority and treatment of head-position special forms.

```aloe
(Point new* (x 10) (y 20))
(Point new* (y 20) (x 10))
((if #t Point also-point) new* (x 1) (y 2))
(Empty new*)
```

Every immediate tail element must be a proper two-element list whose
first element is a source symbol. Validate the shapes of the **entire**
tail before parsing the receiver or any value. Reject bare values,
empty lists, one-element lists, longer lists, improper pairs, and
non-symbol first elements using the parser's existing syntax-exception
convention. An improper outer combination remains malformed.

A malformed later pair must win over otherwise invalid syntax in the
receiver or an earlier value. After all shapes pass, parse the receiver
and each value as ordinary expressions. Invalid syntax inside a value
then remains an ordinary syntax error. Only the immediate tail elements
are binding pairs; lists inside their values keep ordinary expression
rules.

An empty tail is valid grammar. Unknown and duplicate names also parse:
the parser neither knows class fields nor decides receiver eligibility,
missing fields, name coverage, types, or positional arity.

### 2. AST and source locations

Add and export these exact transparent structures from `aloe/parse.rkt`:

```racket
(struct construction-binding (name value) #:transparent)
(struct new-star-expr (receiver bindings loc) #:transparent)
```

The receiver and each binding value are parsed expressions. Each name is
the exact literal Racket source symbol. Bindings stay in written order,
including duplicates; do not sort them, deduplicate them, or lower the
node to a send or `let`. There is no expression node for the field name
or the `new*` token.

`expression-loc` returns the whole construction form's location.
`read-program` preserves the original receiver and value spans, including
the selector spans of ordinary sends nested inside them. `parse-datum`
produces location-free nodes and children. No new pair-name span API or
delimiter-shape retention is required.

### 3. Traversal and existing syntax

Every named walker visits the receiver first, then binding values in
written order. Names are not expression children. Preserve node identity,
smallest-containing-expression selection, existing ties, method-body
containment, selector replacement spans, and all public query interfaces.
The source-location helper traverses the same children.

Selector recovery must reach an ordinary send nested within a binding
value. Neither the pair itself, its name, nor the reserved `new*` token is
an ordinary selector site. Do not add field-name completion. The
`completion-query.rkt` walker must also reach a `load` within a value;
checking and public query proofs for that case come in the language layer.
Grammar acceptance uses the private recovery and selection interfaces,
without depending on checker support for the new node.

Keep the reader and identifier rules unchanged. `new*` outside its
second-position syntax seat remains an ordinary name, including in a
definition, as a receiver, and as a value. `(define x: 123)` is legal;
`(x: expr)` records the exact symbol `x:` as a pair name. Do not import or
test the colon experiment's label notation. Square brackets gain no
meaning; use parentheses in the test examples.

Positional `(Point new (source x) (source y))` remains a `send-expr` with
ordinary send arguments. `(Point new (x 10) (y 20))` still follows ordinary
expression parsing and fails its existing numeric-selector syntax check;
it is never rescued as labeled construction. Preserve ordinary sends,
`case`, `let`, explicit constructors, and existing positional programs.

### 4. Focused tests

Add `tests/parenthetical-construction/grammar.rkt` using `rackunit` and the
existing parser and private selection/recovery interfaces. Prove:

1. Normal, swapped, nested, computed-receiver, and empty-tail forms produce
   `new-star-expr` with literal names and values in written order. Unknown
   and duplicate names remain present and parse successfully.
2. Every malformed pair shape above is rejected, as is an improper outer
   form. Include malformed later pairs with an otherwise invalid receiver
   and with an otherwise invalid earlier value, proving shape-validation
   precedence. Also cover ordinary invalid value syntax after all pair
   shapes pass. Pin the syntax category, not complete error sentences.
3. Positional `new` and its valid two-element send arguments retain their
   AST shapes. Ordinary `new*` and colon-suffix names outside the syntax
   seat parse, including `(define x: 123)`; a binding name can be the exact
   symbol `x:`. Numeric-selector arguments retain their ordinary failure.
4. Read syntax retains whole-form, receiver, value, and nested selector
   spans. Pin source, line, column, one-based position, and span for a
   small explicit fixture. Datum parsing has no locations, including in
   nested values and sends, and gives equal ASTs on repeated parsing.
5. Selection and containment reach the same receiver and nested value
   nodes. A label position belongs to the enclosing construction, with
   no variable or send node for that label. Include a construction within
   a method body and nested constructions, preserving existing traversal
   rules and node identity.
6. Recovery finds nested ordinary send selectors, with their original
   replacement coordinates, in both binding orders. Pair names and the
   reserved `new*` token yield no ordinary selector site. Verify the
   recovered target remains contained in the recovered AST.

These are grammar/traversal tests. Do not add a checker or evaluator arm,
call the checked driver with `new*`, or require a public hover/completion
query on it to succeed in this checkpoint.

## Verification and completion

Run from `/home/dharmatech/journal/2026-09-02-aloe-racket`:

```sh
TMPDIR=/tmp raco test -y tests/parenthetical-construction/grammar.rkt tests/editor/source-locations/000-spans.rkt tests/editor/expression-query/000-selection.rkt tests/editor/completion/000-selector-recovery.rkt
TMPDIR=/tmp raco test -y tests
git diff --check
```

`TMPDIR=/tmp` and `-y` are required. Do not substitute a `tests/*.rkt`
glob for the recursive suite or commit `compiled/`. If launching an entry
point after `.rkt` edits, run the test command first, or rebuild with
`raco make host/racket/aloemacs-run.rkt bin/aloe`; entry points do not
rebuild bytecode themselves. No terminal or listener hand check is needed
for this parser-only slice.

The checkpoint is complete when the focused tests prove syntax precedence,
the exact AST interface, source order and spans, selection/containment,
and nested selector recovery; existing programs remain green in the full
suite; the whitespace check passes; and all changes stay within scope.
Report the changed files and verification results, then stop for human
review. Do not start or write parenthetical-construction 001, implement
checking/evaluation, amend language law, or rewrite the session definition.

## Explicit non-goals

- Eligibility, unknown/duplicate/missing-field diagnostics, declaration-order
  typechecking, generic inference, expected-type context, evaluation,
  runtime class provenance, payload construction, and reflection changes.
- `SPEC.md` amendments, a decisions entry, and consumer or snapshot rewrites.
- Defaults, mixed tails, method/protocol/numeric/host labels, labels on
  `List` or explicit constructors, a `make` selector, copying `with`,
  computed labels, dictionaries, keywords, macros, or colon label tokens.
- New editor APIs, field-name completion/highlighting, language-server work,
  new tooling or dependencies, Boids, Gel, committing, or merging.
