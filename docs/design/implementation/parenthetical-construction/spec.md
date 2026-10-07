# Parenthetical construction specification

**Status: Accepted (2026-10-07) after checkpoint-manager review, under the
user's instruction to proceed if the review found no blocking issues.**

This effort adds fully labeled construction of a class declared with
`(fields ...)`, using `(receiver new* (name expr) ...)`. Positional `new`
continues to build the same constructor. Labels make the field attached to
each value visible, especially in the fourteen-field Aloemacs startup
session. They introduce no second constructor or runtime message.

This file is the complete design input for the checkpoint manager and the
implementers. They do not need the charter or the discussion. Once accepted,
it authorizes only the language amendments in §5.5 and the consumer edit in
§6. For every other language rule, `SPEC.md` remains law. `docs/workflow.md`
governs the process. The colon experiment on
`experiment/2026-10-05-labeled-construction` is not authority here.

## 1. Checkpoint series

- **Identity:** `parenthetical-construction`. Speak the first checkpoint
  **parenthetical-construction 000**. File it under
  `docs/design/implementation/parenthetical-construction/checkpoints/`
  as `000-<slug>.md`. Numbers have three digits, start at 000, and are never
  renumbered; slugs use lowercase words separated by hyphens.
- **Project root:** `/home/dharmatech/journal/2026-09-02-aloe-racket`.
  Product code and tests go there, not in this design folder.
- **Branch:** `experiment/2026-10-06-parenthetical-construction`, created
  from `main` at `987cbd0`. Keep the series on this branch until a human
  merges it.
- **Order:** grammar (§4), checking and evaluation (§5), then the session
  definition (§6). Each is independently testable and sized as one
  implementer conversation. The grammar layer includes AST traversal and
  source-location verification, so it is a meaningful parser-only slice.
  Keep the closing consumer edit separate from the language work.
- A manager may split a layer if it would exceed one implementer context,
  preserving this order and adding no features. A split must be testable
  without its successor. Do not add a fourth feature layer.
- After human acceptance of this draft, the checkpoint manager writes
  **one** next missing checkpoint, then stops. Each implementer handles
  one approved checkpoint, adds its tests in the same change, runs its
  verification, and stops when green. Human review separates the stages.
- Number this series locally. Do not edit `CHECKPOINTS.md` or put checkpoints
  under `docs/checkpoints/` unless a human later promotes the series.

## 2. Product boundary

A `(fields ...)` class has one constructor, `new`. A programmer may choose
either spelling independently at each construction site:

```aloe
(Point new 10 20)
(Point new* (x 10) (y 20))
(Point new* (y 20) (x 10))
```

All three store `10` in `x` and `20` in `y`. The labeled form is syntax in
the second position, like `case`. It is not a send, method, message, or
second constructor. Construction still records constructor identity `new`.
It adds no `new*` row to class or instance reflection, and no label query
to `Mirror` or `Signature`.

Every field is supplied exactly once. Labels are the fields' declared
source names, not separate initialization names. Only the immediate tail
elements are binding pairs. Their values are ordinary expressions in the
surrounding environment. The names neither evaluate nor introduce bindings.

The receiver is an expression, not necessarily a class name. A class alias
and a computed expression that has that same class-object type are legal.
For example, with `also-point` bound to `Point`,
`((if #t Point also-point) new* (x 1) (y 2))` is eligible. The ordinary
checker still rejects an `if` whose arms are different class-object types.

This series adds no defaults, mixed positional/labeled tail, labels on
ordinary methods, protocol sends, numeric sends, host messages, `List`, or
explicit constructors. `(Option Some ...)`, `(AloemacsCommand FindFile)`,
`(AloemacsWindowTree Leaf ...)`, and `case` payload binders stay positional.
`(List of ...)`, `(List empty)`, `(Symbol intern ...)`, and
`(Text from-string ...)` keep their existing meanings. An ordinary send
containing a two-element expression does not acquire label semantics.

There is no `make`, copy-and-replace `with`, keyword value, computed field
name, dictionary payload, macro system, or macro replacement proof. Do not
implement labels as Racket keyword arguments. Required and optional keyword
host implementations remain rejected under checkpoint 83a.

The reader and identifiers are unchanged. `new*` is reserved only in the
second-position syntax seat; elsewhere it is an ordinary source name. A
field named `x:` is labeled `(x: expr)`, with that exact symbol. A source
definition `(define x: 123)` remains legal. There is no colon label token,
colon reservation, or `x::` spelling. Do not import or test the colon
experiment's spelling. Square brackets gain no meaning, and the parser
need not retain delimiter shape. Use parentheses in goldens and the closing
edit.

No field-name completion, field-name highlighting, editor feature, Boids
feature, Gel change, or rewrite of other call sites belongs in this series.
Do not change generic inference or `if` to make an uncontextualized
`(define n (Option None))` legal.

## 3. Host, layout, and verification commands

Use the repository's existing Racket definitional interpreter and checker:
reader → `aloe/parse.rkt` → `aloe/type.rkt` → `aloe/eval.rkt`. Tests use
`rackunit`. No new toolchain, dependency, project setup, elaboration IR, or
host API is needed.

The existing seams are:

| File | Seam |
|---|---|
| `aloe/parse.rkt` | AST definitions, `expression-loc`, and second-position `case` recognition in `parse-syntax-expression` |
| `aloe/type.rkt` | `infer-expression`, `class-info-explicit-constructors?`, `class-constructor`, and `infer-construction` |
| `aloe/eval.rkt` | `eval-expr`, runtime class values, `find-constructor`, and `construct-instance` |
| `aloe/private/expression-selection.rkt` | Expression selection and containment traversal used by checker observation |
| `aloe/private/completion-selection.rkt` | Traversal when recovering a nested ordinary send's selector |
| `aloe/completion-query.rkt` | Traversal used to find `load` nodes before a completion query |
| `tests/editor/source-locations/000-spans.rkt` | Location-free AST traversal that must recognize the new node |

New series tests live under `tests/parenthetical-construction/`. The scoped
updates to the existing source-location helper and the closing runner
snapshot are the only exceptions. Test support and fixtures, if needed,
also stay under that series test directory.

All commands run from the project root. The focused commands are specified
in each layer. Follow each focused run with:

```sh
TMPDIR=/tmp raco test -y tests
git diff --check
```

`TMPDIR=/tmp` and `-y` are required for agent test runs. Do not commit
`compiled/`. After changing `.rkt` files, rebuild with the test command or
`raco make host/racket/aloemacs-run.rkt bin/aloe` before launching an entry
point. `./bin/aloe` and `racket host/racket/aloemacs-run.rkt` load bytecode
without rebuilding it. Changes only to `.aloe` files need no rebuild.

Layer scopes below are exhaustive. Leave host keyword validation, library
implementations, signature catalogs, the identifier sections of `SPEC.md`,
and the colon experiment untouched. If implementing a checkpoint needs a
file outside its scope, return that checkpoint to the manager instead of
widening it.

## 4. Layer — Grammar and AST traversal

**Allowed files:** `aloe/parse.rkt`,
`aloe/private/expression-selection.rkt`,
`aloe/private/completion-selection.rkt`, `aloe/completion-query.rkt`,
`tests/editor/source-locations/000-spans.rkt` (only the new-node arm in its
location-free walker), and new tests in
`tests/parenthetical-construction/grammar.rkt`.

This layer parses the new syntax and makes it traversable. It does not
typecheck or evaluate labeled construction, amend language law, or change
an Aloe program. Existing positional programs still parse, check, and run.

### 4.1 Syntax and validation

Recognize a proper combination whose second source element is `new*` before
the ordinary-send fallback, beside the existing `case` recognition. Keep
the existing treatment of head-position special forms.

The form is:

```text
(receiver-expr new* (field-name value-expr) ...)
```

Every immediate tail element must be a proper list of exactly two elements
whose first element is a source symbol. Validate the shapes of the entire
tail before parsing its receiver or any value expression. A bare value,
empty list, one-element list, longer list, improper pair, or non-symbol
first element is a syntax error. The existing malformed-combination rule
also rejects an improper outer list. Class eligibility and name validation
are later checks, not parser decisions.

An empty tail, `(Empty new*)`, is valid syntax. Unknown and duplicate names
also parse; the parser knows no class fields. Once pair shapes are valid,
parse the receiver and each value as ordinary expressions. Invalid syntax
inside a value remains an ordinary syntax error. Do not recursively treat
the lists inside a value as labels.

`(Point new (source x) (source y))` remains a `send-expr` with ordinary send
arguments. `(Point new (x 10) (y 20))` also receives the existing ordinary
expression rules, including their invalid numeric-selector syntax; it is
never rescued by treating its arguments as labels.

### 4.2 AST interface and source order

Add and export these transparent AST structures from `aloe/parse.rkt`:

```racket
(struct construction-binding (name value) #:transparent)
(struct new-star-expr (receiver bindings loc) #:transparent)
```

`name` is the literal Racket symbol from the pair's first element. `value`
is its parsed expression. `bindings` is a list in written order, including
duplicates. No node represents evaluating a field name or the `new*` token.
Do not lower the node to a send or to `let`.

`expression-loc` returns the whole form's location. `read-program` preserves
the receiver's and each value's original source spans, including nested
sends' selector spans. `parse-datum` produces location-free nodes, as it
does for other expressions. Pair names need no new editor span API.

Teach each named expression walker to visit the receiver followed by the
binding values in written order. Field-name symbols are not children. Keep
existing selection rules, checker observation, and completion query APIs.
The source-location test helper gains the same traversal arm; do not revise
its existing fixtures or assertions. No field-name completion is added.

### 4.3 Focused tests and stop

`grammar.rkt` must prove:

- Normal, swapped, nested, computed-receiver, and empty-tail forms retain
  their source order and literal names in `new-star-expr`.
- Every malformed pair shape is rejected, including a malformed later pair
  combined with an otherwise invalid receiver or value. Pair-shape syntax
  takes precedence. Well-shaped unknown and duplicate names still parse.
- Positional `new` stays a send. Ordinary `new*` and colon-suffix source
  names outside the syntax seat still parse, including `(define x: 123)`.
  A pair can carry the exact field-name symbol `x:`.
- Read syntax retains whole-form and child spans; datum parsing is
  location-free. Expression selection and containment reach the receiver
  and nested value expressions without visiting names as expressions.
- Selector recovery finds an ordinary nested send inside a value without
  mistaking the pair itself for a send or proposing field-name completion.

Run:

```sh
TMPDIR=/tmp raco test -y tests/parenthetical-construction/grammar.rkt tests/editor/source-locations/000-spans.rkt tests/editor/expression-query/000-selection.rkt tests/editor/completion/000-selector-recovery.rkt
```

Then run the full suite and whitespace check in §3. Stop after grammar and
traversal are green. Checking the new form begins in the next layer.

## 5. Layer — Checking, evaluation, and language law

**Predecessor:** the grammar layer is implemented, green, and reviewed.

**Allowed files:** `aloe/type.rkt`, `aloe/eval.rkt`, `SPEC.md` only as §5.5
allows, `docs/decisions.md` only for §5.5's entry, and new tests in
`tests/parenthetical-construction/law.rkt` and
`tests/parenthetical-construction/editor.rkt`. The parser and walker
interfaces are the completed predecessor; do not redesign them here.

### 5.1 Eligibility and error precedence

For a syntactically valid `new-star-expr`, perform these checks in order:

1. Infer the receiver under the existing rules. Preserve an existing
   receiver failure, such as an unbound name or incompatible `if` arms.
2. Require its resolved type to be a class object declared with
   `(fields ...)`, whose constructor is the generated `new`. Otherwise
   report ineligible `new*`. This includes instances, built-in `List`,
   other primitive class objects, and every explicit `(constructors ...)`
   class, even one explicitly declaring a constructor named `new`.
3. Walk the binding names in written order. At each pair, an undeclared
   name is unknown field; a name already seen is duplicate field. Report
   the first such offending pair and stop. Do not collect both categories.
4. If names so far are valid and unique, report every missing field in
   declaration order. Missing field is not positional arity.
5. Only after the names exactly cover the fields, check the value
   expressions under §5.2.

The parser's malformed-tail syntax errors precede all of these checks.
No value is typechecked before eligibility and name validation succeed.
Use the existing parser exception convention for syntax and
`exn:fail:aloe-type` for checker failures. Name diagnostics must distinguish
missing field, unknown field, and duplicate field, and identify the names
involved. Ineligible `new*` is distinguishable from unknown message or
positional arity. Do not introduce a public diagnostic framework or pin
whole sentences in tests; test the category and relevant names.

For fields `x`, `y`, examples include:

| Form | Required failure or result |
|---|---|
| `(Point new* (z 1) (x 1) (x 2))` | Unknown field `z` |
| `(Point new* (x 1) (x 2) (z 3))` | Duplicate field `x` |
| `(Point new* (y "bad"))` | Missing field `x`, before checking `"bad"` |
| `(Point new*)` | Missing fields `x`, `y`, in that order |
| `(Point new 1)` | Existing positional arity error |
| `(List new*)` | Ineligible `new*` |
| `(Empty new*)` for a non-generic empty `(fields)` class | Same empty payload as `(Empty new)` |

Use `class-info-explicit-constructors?` to distinguish the two declaration
kinds in the checker. A constructor merely being named `new` is insufficient.

### 5.2 Declaration-order checking

After name validation, create a field-name-to-expression association from
the original bindings. Walk the generated constructor's fields in
declaration order to obtain its argument-expression list. Pass that list,
the same constructor, environment, and expected type to the existing
`infer-construction` walk. Keep the original AST node and child identities
for observation; the ordered argument list is only a checking view.

This reuse defines acceptance: a labeled call is accepted exactly when the
positional call with its values in declaration order is accepted. Permuting
pairs changes neither this checking walk nor generic inference. Preserve
expected field types, expected result types, consistency checks, and the
existing generic construction obligations. Do not first infer the values
in source order, and do not lower the form to parallel `let` before checking.
That lowering loses field context needed by some empty lists and functions.

A non-generic class with fields `(items (List String))` and
`(measure (-> String Int))` must accept both orders of `(items (List empty))`
and `(measure (fn (s) (s len)))`. The function's `s : String` comes from
its field. The same rule applies when an expected concrete instance type
supplies a generic class's field types. Cases that positional construction
already rejects remain rejected, including inconsistent Int/Float generic
arguments and an uncontextualized `(define n (Option None))`.

Add an `infer-expression` arm for the node and retain the normal
post-inference unification and observation hooks. Consequently hover and
ordinary selector completion inside a value see the field's type context.
There is no observation of the label as an expression.

### 5.3 Source-order evaluation and positional payload

Add an `eval-expr` arm for the node. Evaluate the receiver exactly once,
then evaluate each value expression exactly once in written order, in the
same surrounding environment. Do not evaluate `new*` or the field names.
One value cannot refer to another pair as a new binding.

Retain declaration provenance in the runtime class representation, using
an explicit-constructor flag initialized from `define-class-expr`.
Currently runtime normalization turns both declaration kinds into a
constructor list and can erase that distinction. The flag must distinguish
empty `(fields)` from explicit empty constructors, including an explicitly
named `new`, without changing reflection or instance payload layout.

After evaluating the receiver, reject an ineligible runtime receiver before
evaluating values. The raw `eval-expr` path must also validate names before
running values, using the same unknown/duplicate/missing ordering as §5.1.
Its errors follow the evaluator's existing exception convention and carry
the same categories and names. These runtime checks do not replace the
checker or add a runtime type system.

Build a field-name-to-index association from the generated constructor's
declaration. As source-order evaluation produces each result, remember it
at that field's index. Once every expression has run, assemble the values
in declaration order and call the existing
`construct-instance receiver 'new ordered-values` path. This preserves the
constructor identity, immutable payload vector, runtime generic inference,
field reads, equality, and reflection used by positional construction.
The temporary association is host bookkeeping, not an Aloe dictionary or
a new stored payload. Do not reorder expressions and then evaluate them.

For example, with an outer `x` bound to `5`:

```aloe
(Point new* (y (x + 1)) (x 10))
```

evaluates `(x + 1)` and then `10`, storing `10` in field `x` and `6` in
field `y`. This has the evaluation correspondence of a parallel `let`
followed by positional construction. It is not the definition of checking.

### 5.4 Focused tests and editor continuity

`law.rkt` must prove:

- Labeled and positional construction have the same type, constructor
  identity `new`, and payload for both field orders. Existing positional
  sends, field reads, goldens, and explicit constructors remain legal.
- Class aliases and a computed same-class receiver work. Different-class
  `if` arms fail under the existing rule. A receiver with a recorded host
  effect runs once and before values.
- A test-only injected host method records the source order of value
  effects. A reversed pair order reverses those effects while values still
  occupy their declaration-order fields. A prepared expression run twice
  reevaluates the receiver and values; it does not cache their results.
- Labels are literal and do not need variable bindings. Values use outer
  variables; a pair named `x` does not shadow outer `x`. Exact colon-suffix
  field names work and a different symbol is unknown. `new*` still works
  as an ordinary variable name in a value expression.
- Each malformed shape, missing field, unknown field, duplicate field,
  positional arity, and ineligible `new*` has the correct category.
  Mixed unknown/duplicate examples above select the first offending pair.
  Multiple missing names appear in declaration order. Name errors win over
  invalid value types or unbound value variables; receiver errors win over
  name checks for a well-shaped tail. Failed checked calls run no effects.
- Empty `(fields)` accepts both spellings. Explicit `(constructors ...)`
  classes remain ineligible even when their sole constructor is named `new`.
  Instances and `(List new*)` are ineligible. Raw evaluation enforces
  eligibility and name errors without running values.
- Generic Point succeeds with homogeneous Int or Float values and rejects
  mixed values in both pair orders, exactly like positional construction.
  A generic class with expected concrete instance type retains the same
  field context as its positional spelling. Standalone Option None is
  still rejected; the existing `if` witness remains accepted.
- Swap two pairs containing an empty list and a context-dependent function.
  Use the class described in §5.2. Also wrap each field value in an `if`
  whose test is a test-only host send returning `Bool` and recording a
  distinct marker. The list branches are `(List empty)`; the function
  branches are `(fn (s) (s len))`. Both permutations typecheck, the markers
  run in written order, the stored list has the expected element type, and
  calling the stored function on `"abc"` returns `3`. Compare field
  observations rather than requiring separately created functions to have
  equal identity.
- Reflection of a class and instances adds neither `new*` messages nor
  signatures; the generated constructor row remains `new`.
- Reordering equal-typed declared fields in independent class fixtures
  leaves a labeled call's name-to-value association unchanged, while the
  corresponding positional call remains accepted with values in different
  fields. Reordering distinct-typed fields rejects the unchanged positional
  call. Renaming a field rejects its old label, and adding or removing a
  field rejects an unchanged old call of either spelling.

`editor.rkt` uses the existing `query-expression-at` and
`query-selector-completions` interfaces, with temporary source files where
required. It must prove hover reaches an ordinary value expression and the
parameter of a function checked against its field type; selector completion
inside `(s ...)` receives `String` signatures from that same expected
function type. Cover both pair orders and a value within a method body, so
method-body containment cannot skip the new node. Completion traversal must
still detect a `load` nested in a labeled value and retain the existing
source-path policy. A field-name position produces no field-name completion.
No language-server, hover, or completion API change belongs in this layer.

Run:

```sh
TMPDIR=/tmp raco test -y tests/parenthetical-construction/law.rkt tests/parenthetical-construction/editor.rkt tests/checkpoint-83.rkt
```

Then run the full suite and whitespace check in §3. The existing host test
must continue rejecting required and optional keyword implementations.
Stop when the language, editor continuity, and documents are green. Do not
rewrite Aloemacs yet.

### 5.5 Language-document amendments

Edit only the construction rule in `SPEC.md` §3.2, the special-form section
by adding §4.11 directly after `case`, the `labeled make` item in §8, and
the goldens in §9. Leave §1, §2.1, §7.2, and all other language rules as
they stand. In §3.2 delete “Labeled construction (`make`) is out of scope.”
and add:

> For a class declared with `(fields ...)`, positional `(receiver new arg
> ...)` and fully labeled `(receiver new* (name expr) ...)` build the same
> singleton `new` constructor. The latter is syntax, not a send; see
> section 4.11. It adds no constructor or reflected message.

The new subsection is titled **4.11 `new*`** and states this law:

> `(receiver-expr new* (field-name value-expr) ...)` is syntax in the second
> position, where `new*` is reserved. The tail is a list of binding pairs
> in the `let` shape. Each pair is a proper list of two elements whose first
> element is the field's exact source symbol. Pair shapes are validated
> before the receiver or values are checked; a malformed pair is a syntax
> error. An empty tail is well formed.
>
> The receiver is checked by the existing expression rules. Its type must
> be a class object declared with `(fields ...)`; otherwise the form is
> ineligible `new*`. Explicit `(constructors ...)` classes are ineligible,
> even if a declared constructor is named `new`. Computed receivers with
> the eligible class-object type are allowed.
>
> Names are checked in written order. The first unknown or duplicate field
> is reported, whichever occurs first. If all written names are valid and
> unique, every absent field is reported in declaration order as missing
> field, not arity. These checks precede value checking. Positional `new`
> retains its arity rule.
>
> When the names exactly cover the fields, values are checked in field
> declaration order with the same expected types and generic inference as
> positional construction. A labeled call is accepted exactly when its
> positional counterpart in declaration order is accepted. Checking does
> not expand the form into `let`.
>
> The receiver is evaluated once, then the value expressions once each in
> written order, in the surrounding environment. The `new*` token and names
> are not evaluated. Pair names introduce no bindings. After evaluation,
> results form the existing `new` constructor's immutable payload in field
> declaration order. An empty `(fields)` class accepts an empty tail under
> the existing generic inference rules.
>
> Reader and identifier rules are unchanged. A field named `x:` uses
> `(x: expr)`; the colon is part of its ordinary source name. Elsewhere
> `new*` remains an ordinary source name. Square brackets gain no meaning.
> There are no defaults, mixed tails, or labels on other sends or explicit
> constructors. Reflection exposes the existing `new` row, not `new*`.

Remove only the `labeled make` item from §8; do not introduce a `make`
selector. Keep every existing positional Point golden and add alongside
them:

```text
(Point new* (x 1) (y 2)) → a (Point Int), equal to (Point new 1 2)
((Point new* (y 2) (x 1)) x) → 1
```

Add one dated entry to `docs/decisions.md`, headed
**Parenthetical construction (2026-10-07)**, with this content:

> Decided: labeled construction is the `new*` form in the selector position.
> Each label is a binding pair `(name expr)`, in the shape already used by
> `let`. Its car is the exact field source name and is not evaluated. The
> value expressions run in source order; afterward their stored payload is
> the positional `new` constructor's declaration-ordered payload. Checking
> walks declaration order with the existing field context, not a `let`
> expansion.
>
> A positional call whose equal-typed fields trade places still typechecks
> and changes meaning. The labeled spelling keeps values attached to their
> names. A field rename breaks its old label; a separate initialization name
> is not introduced.
>
> The colon experiment on `experiment/2026-10-05-labeled-construction` is a
> separate experiment, not this series. Square brackets were given no new
> meaning. Rejected: defaults, mixed calls, method labels,
> explicit-constructor labels, and a `make` selector.
>
> A later macro may replace this form only after its expansion is shown to
> preserve source-order evaluation and declaration-order checking, including
> the expected type a function expression receives from its field. This
> series builds no macro and does not have to prove that replacement.

## 6. Layer — The session definition

**Predecessor:** the checking/evaluation layer and its language amendments
are implemented, green, and reviewed.

**Allowed files:** `examples/aloemacs/main.aloe` (only `aloemacs-editor`),
`tests/aloemacs/runner.rkt` (only the value of `expected-main-datums`), and
new tests in `tests/parenthetical-construction/session.rkt`. No kernel,
language-law, host, other existing test, `file.aloe`, or `editor.aloe` edit
belongs here.

Keep the source-relative `(load "file.aloe")` unchanged. Rewrite the one
definition to the following two-`let` structure. This incorporates the
chosen sketch's binding names and nesting, with the small-constructor
exceptions already resolved. It is the complete target definition; no
prose or Markdown fence goes into the source file.

```aloe
(define aloemacs-editor
  (let ((initial-buffer
          (AloemacsBuffer new*
            (editor
              (AloemacsEditor new*
                (text       (Text from-string ""))
                (point      (Position new 0 0))
                (quit       #f)
                (scroll-row 0)
                (scroll-col 0)
                (history    (List empty))
                (mark
                  (if #t
                      (Option None)
                      (Option Some (Position new 0 0))))
                (text-rows  0)))
            (path
              (if #t
                  (Option None)
                  (Option Some (Path new "/typed-none"))))
            (id 0)))

        (inactive-prompt
          (if #t
              (Option None)
              (Option Some
                (AloemacsPrompt new*
                  (label              "")
                  (text               "")
                  (column             0)
                  (completion-note    "")
                  (completion-lines   (List empty))
                  (completion-matches (List empty))
                  (completion-start   0)))))

        (initial-windows
          (AloemacsWindows new*
            (tree
              (AloemacsWindowTree Leaf (AloemacsView new 0 0 0 0 #f)))
            (selected 0)
            (columns  0)
            (rows     0))))

    (let ((initial-buffers
            (AloemacsBuffers new*
              (before         (List empty))
              (current-buffer initial-buffer)
              (after          (List empty))))

          (initial-pending
            (if #t
                (Option None)
                (Option Some aloemacs-global-keymap)))

          (initial-last-submission
            (if #t
                (Option None)
                (Option Some "")))

          (initial-waiting-command
            (if #t
                (Option None)
                (Option Some (AloemacsCommand FindFile)))))

      (AloemacsSession new*
        (buffers         initial-buffers)
        (fs              (Fs new fs-host))
        (echo            "")
        (searching       #f)
        (query           "")
        (origin          (Position new 0 0))
        (wrapped         #f)
        (failing         #f)
        (kill-ring       (List empty))
        (pending         initial-pending)
        (prompt          inactive-prompt)
        (last-submission initial-last-submission)
        (waiting-command initial-waiting-command)
        (windows         initial-windows)))))
```

The inner `let` is the outer `let`'s body and sees `initial-buffer`. Bindings
within either `let` remain parallel. All original values and all `if`
witnesses remain, including the inactive Option alternatives. Alignment is
optional and has no language meaning.

These are the only constructors relabeled, with their exact field order:

| Class | Fields in declaration order |
|---|---|
| `AloemacsSession` | `buffers fs echo searching query origin wrapped failing kill-ring pending prompt last-submission waiting-command windows` |
| `AloemacsBuffers` | `before current-buffer after` |
| `AloemacsBuffer` | `editor path id` |
| `AloemacsEditor` | `text point quit scroll-row scroll-col history mark text-rows` |
| `AloemacsPrompt` | `label text column completion-note completion-lines completion-matches completion-start` |
| `AloemacsWindows` | `tree selected columns rows` |

`Position`, `Path`, `Fs`, and `AloemacsView` remain positional throughout
this definition, as shown. Explicit constructors and ordinary sends also
retain their spelling. Do not relabel any other source call site.

Replace only the value of `expected-main-datums` in
`tests/aloemacs/runner.rkt` with the list `read` returns for the unchanged
load plus the rewritten definition. Keep it an explicit expected datum;
do not derive the expected value by reading the actual file at test time.
The comparison and every runtime assertion stay unchanged, including type,
empty text, point, and absent options. No other existing Aloemacs test
snapshots this source or needs permission to change.

`session.rkt` must load the actual `main.aloe` through the checked driver
with an explicitly injected filesystem test double from `host/racket/fs.rkt`.
Compare its startup value, using Aloe `check`, with an independent positional
construction of the original state in the same driver. Check all fourteen
session fields, the buffer/editor contents and point, empty collections,
absent options, and the initial leaf/view/windows state. The result type is
`(AloemacsSession FsHost)`. Do not introduce top-level bindings for the new
locals or inject host capabilities implicitly.

Run:

```sh
TMPDIR=/tmp raco test -y tests/parenthetical-construction/session.rkt tests/aloemacs/runner.rkt tests/aloemacs/windows-state-foundation.rkt
```

Then run the full suite and whitespace check in §3. Stop when the scoped
rewrite and snapshot update are green. No additional consumer rewrite is
part of this series.

## 7. Verification

The layer tests must prove parser shape and source spans, diagnostic
precedence, receiver eligibility, positional/labeled parity, declaration-
order checking, source-order effects, generic and expected-type parity,
reflection parity, nested editor-query continuity, and preservation of the
Aloemacs startup value. The complete test tree protects existing programs,
explicit constructors, host call shapes, and Aloemacs runtime assertions.

Implementation tests pin diagnostic categories and field names, not whole
messages. Use test-only host capabilities to observe effects; do not add
mutation to Aloe or production trace helpers. Pure payload equality tests
and effect-order tests are separate assertions of the same construction
law.

After the language layer, an optional hand check is:

```sh
./bin/aloe examples/point.aloe
```

At its prompt, `(check (Point new* (y 2) (x 1)) (Point new 1 2))` succeeds,
and `((Point new* (y 2) (x 1)) x)` returns `1`. End with `(exit)`.
After the closing layer, an optional terminal check is
`racket host/racket/aloemacs-run.rkt`: the empty editor starts as before
and Escape exits. The terminal runner uses the existing optional `tui-term`
dependency; this series does not install or change it. These hand checks
do not replace automated acceptance.

## 8. Acceptance

The series is complete only when:

1. Positional `new` and fully labeled `new*` build the same single
   constructor and declaration-ordered payload. Reflection adds no `new*`
   row or new label API.
2. Pair permutations preserve positional checking acceptance, expected
   field types, and generic inference. Receiver and value effects run once
   in receiver-then-source order, while storage follows field declaration
   order. Empty-list/function permutation tests prove both obligations.
3. Malformed tails are syntax errors. Eligibility, first unknown/duplicate
   pair, all missing fields in declaration order, and value checking occur
   in the specified precedence. Positional count failures remain arity.
4. Exact field symbols are literal only in pair-name position. Values use
   the surrounding environment. Reader and identifiers, including colon
   names and `new*` outside its reserved seat, are unchanged.
5. Only `(fields ...)` class objects are eligible, including computed
   receivers and empty products. Explicit constructors remain positional,
   standalone Option None remains uninferable, and host keyword rejection
   remains green.
6. `SPEC.md` has the scoped construction and special-form amendments, no
   obsolete labeled-`make` exclusion, and the labeled Point goldens beside
   its preserved positional ones. One decisions entry records the choices
   and the future macro constraint.
7. Hover and ordinary selector completion within values retain their
   existing context, with no field-name completion or new editor API.
8. Only `aloemacs-editor` is rewritten in the consumer source. Its two
   `let`s, names, values, witnesses, six relabeled constructors, and four
   positional exceptions match §6. Only `expected-main-datums` changes in
   the existing runner test; its behavior assertions remain intact.
9. Focused tests, the full suite, and `git diff --check` pass. All new series
   tests are under `tests/parenthetical-construction/`; code stays within
   the layer scopes. No checkpoint is started before the required human
   review, and no later feature is added.
