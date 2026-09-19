# Editor completion 002 — Public selector-completion query

**Status.** Implemented and reviewed. The five required focused and
predecessor suites pass all 228 tests, and the exact Point Float hand check
returns `dist2` then `dot` at replacement range `(744, 1)`. The recursive
suite passes 2,201 of 2,203 tests; its only failures are the two documented
pre-existing `tests/gel/presentations/003-doc-law.rkt` contradictions. This
checkpoint introduces no additional failure.

## Goal

Add the public Racket selector-completion query. Given the exact current
buffer and a one-based character boundary, compose editor-completion 000's
recovery with editor-completion 001's contextual receiver observation, create
one fresh standard checker environment, apply the exact selector filtering
rules, and return editor-only completion items with original-buffer edit
ranges.

This checkpoint completes the language-query layer and its Point, Boids,
lexical-context, load, ordering, formatting, and failure coverage. It does not
change the LSP adapter or VS Code client. `textDocument/completion`, UTF-16
conversion, JSON CompletionItems, and capability advertisement remain one
later checkpoint.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law for sends, selectors, types, source
  order, loads, and the absence of evaluation during static queries.
- `docs/editor/completion/spec.md` is the local design authority. Sections
  1–5 and the unit-test portion of section 8 define the complete public query.
  Sections 6–7 and the protocol-test portion of section 8 remain deferred to
  the LSP slice.
- Editor-completion 000 is implemented and reviewed. Its private operation is
  the only incomplete-buffer recovery and original-range mapper.
- Editor-completion 001 is implemented and reviewed. Its private checker
  operation is the only contextual receiver observer and returns the exact
  ordered `type-signature-specs` rows at the early boundary.
- `aloe/main.rkt` already owns the public `make-type-environment` that creates
  a raw checker environment and installs the standard List library followed by
  the standard String library. Use that operation once per query; do not copy
  its bootstrap.
- Editor-signatures-of-type 000–002 remain the sole catalog implementation.
  This checkpoint consumes `signature-spec` accessors but does not construct a
  second row type or inspect checker declarations.

Identity is `(editor-completion, 002)`, spoken **editor-completion 002**. This
is a local editor checkpoint, not global checkpoint 118 and not an LSP or VS
Code checkpoint. Do not edit `CHECKPOINTS.md` or add a file under
`docs/checkpoints/`.

## Public module, structure, and operation

Add `aloe/completion-query.rkt` with exactly this public surface:

```racket
(struct selector-completion-item
  (label detail insert-text replacement-start replacement-span)
  #:transparent)

(query-selector-completions source position
                            #:source-path [source-path #f])
  ; source      : string?
  ; position    : exact-positive-integer?
  ; source-path : (or/c path-string? #f)
  ; -> (listof selector-completion-item?)
```

The module exports only the structure bindings and query operation. It does
not re-export `signature-spec`, completion-selection structures, checker
observer structures, `make-type-environment`, parser structures,
`query-expression-at`, or another convenience query.

Do not re-export the query from `aloe/main.rkt`, `aloe/driver.rkt`, or
`aloe/expression-query.rkt`. The LSP adapter will import this module directly
in the next checkpoint.

Each item contains only editor data:

- `label` is the candidate selector symbol rendered as one Racket source token
  with `write`;
- `detail` is the complete parameter-list datum rendered with `write`, then
  the literal string `" -> "`, then the return datum rendered with `write`;
- `insert-text` is exactly the same string as `label`;
- `replacement-start` is checkpoint 000's one-based original-source start;
  and
- `replacement-span` is checkpoint 000's original character span.

Do not add kind, sort text, filter text, documentation, snippet syntax,
arguments, parentheses, trailing spaces, commands, or resolve data. Those are
neither fields of the Racket structure nor hidden metadata.

The query returns a fresh proper list on every call. Duplicate overload rows
produce separate item structures even when every item field is equal.

## Public argument and path contract

Validate all public argument kinds before entering source-failure recovery:

1. `source` must satisfy `string?`.
2. `position` must satisfy `exact-positive-integer?`.
3. `source-path` must be `#f` or satisfy `path-string?`.

For a wrong kind, raise a Racket argument error whose `who` is exactly
`query-selector-completions` and whose contract names the rejected kind. Do
not convert a caller contract error into an empty list.

Valid cursor boundaries are exactly 1 through
`(add1 (string-length source))`. A positive position outside that range
returns `'()` before parsing, environment creation, or filesystem access.

When `source-path` is supplied, normalize it with:

```racket
(simplify-path (path->complete-path source-path) #f)
```

Pass that normalized path to checkpoint 000 as the reader source name. Do not
require the root path to exist or open it: `source` is authoritative and may
be an unsaved buffer. The normalized path supplies the base directory for
ordinary Aloe `load` forms, whose contents continue to come from disk.

When `source-path` is `#f`, any recovered buffer containing any `load-expr`
has no result. Return `'()` without checker traversal or ambient-directory
resolution, even if that relative file happens to exist in the current
working directory and even if the load text occurs after the target.

To enforce that rule, the public module may traverse checkpoint 000's parsed
forest using the established expression-child edges solely to detect a
`load-expr`. It must not scan source text for the word `load`, parse the buffer
again, open a load, or use that traversal to build rows. Ordinary load
resolution with a supplied path remains entirely in the existing checker.

## Exact query pipeline and failure boundary

After argument validation, first return `'()` for an out-of-range positive
position. Otherwise normalize the optional path and perform this one pipeline:

1. Call `recover-selector-completion-site` exactly once with the exact source,
   position, and normalized source path.
2. If recovery returns `#f`, return `'()`.
3. If no source path was supplied and the recovered forest contains a load,
   return `'()`.
4. Create one fresh standard environment by calling the public
   `make-type-environment` from `aloe/main.rkt` exactly once.
5. Call `typecheck-program/observe-selector-receiver` exactly once with the
   recovered forest, that fresh environment, and the recovered target send.
6. Filter the returned shared rows under the rules below.
7. Format only the retained rows into fresh `selector-completion-item` values,
   all carrying checkpoint 000's same original replacement range.

Do not call `query-expression-at`: at a selector token it observes the whole
send, not the receiver. Do not call `read-program`, `type-of`,
`typecheck-program`, or `type-signature-specs` directly from the public query.
Those operations are already owned behind checkpoints 000 and 001, except for
the narrow recovered-AST load-presence check above.

After argument validation, an ineligible site, out-of-range cursor,
unrecoverable buffer, malformed reader or parser input, checker failure before
or during receiver inference, unreadable or malformed earlier load, or other
source-driven failure returns `'()`. No buffer content escapes as a Racket
exception to the caller, and expected failure writes nothing to current output
or error ports. Do not catch breaks or termination.

Errors after successful receiver inference remain irrelevant because
checkpoint 001 exits first. With a source path, an ill-typed later root or
unreadable later load is not visited and does not suppress items. Syntactically
malformed later source still prevents checkpoint 000 from recovering a parsed
forest. This is the completion early boundary, not hover's strict
complete-file policy.

The implementation may use one post-validation `exn:fail?` handler around
the source-processing pipeline because Aloe parser failures in loaded files do
not have a dedicated exception subtype. Keep all argument checks outside that
handler. Do not log, report a diagnostic, return exception prose as an item,
or alter the existing exception hierarchy.

Every call is independent. A successful or failed query retains no checker
environment, declarations, inference variables, observer, marker, or escape
for a later call.

## Fresh standard checker environment

Use the public `make-type-environment` imported narrowly from `aloe/main.rkt`.
That one call installs List then String in the established order. Do not call
the raw `make-type-environment` from `aloe/type.rkt`, invoke library helpers
yourself, name `fold`, `map`, `reverse`, or `starts-with?` in production, or
cache a bootstrapped environment between queries.

This makes environment-local standard extension rows appear naturally through
`type-signature-specs`. Earlier buffer declarations and earlier loads then
extend that fresh environment in ordinary source order. Later roots never
retroactively contribute because checkpoint 001 exits at the receiver.

There is no host-injection parameter. A buffer whose receiver depends on an
unbound optional host capability returns `'()`. The query does not create a
runtime environment, evaluate source, construct a `Mirror`, invoke a host
implementation, or inspect runtime state.

## Stable exact-selector and prefix filtering

Let `rows` be the ordered list from the receiver observation and let
`selector-text` be checkpoint 000's complete original token.

If `selector-text` is empty, retain every row.

If it is nonempty, read that exact string as one Racket datum and require a
single symbol followed by EOF. Checkpoint 000 already enforces this mapping,
but the public boundary must fail closed and return `'()` if the internal
precondition is ever violated.

For a valid nonempty selector symbol:

1. If it is `eq?` to the selector of any candidate row, this is an existing
   selector. Retain every row, regardless of whether the cursor is at the
   token's start, interior, or end.
2. Otherwise require the cursor boundary to equal:

   ```text
   replacement-start + replacement-span
   ```

   If it does not, return `'()`.
3. At that token-end boundary, treat the complete original `selector-text` as
   a literal prefix. Retain only rows whose selector, rendered as a Racket
   source token with `write`, starts with that exact string.

Filtering is stable. Never sort, rank, group, or deduplicate. Repeated
selectors remain repeated rows in catalog order. There is no case folding,
fuzzy matching, substring matching, popularity score, or recent-use rule.

The exact-selector rule is intentionally menu-wide. Completion on the valid
`+`, `dist2`, or an escaped source spelling of an existing selector returns
the receiver's entire catalog, not just overloads or rows sharing that label.

Rendering a candidate selector token for the prefix predicate is permitted;
do not construct item details or perform additional type formatting until the
row has survived filtering. No substitution, arity inference, documentation
lookup, or signature-help work occurs here.

## Exact datum rendering

Use Racket `write`, not `display`, `format "~a"`, `symbol->string`, or custom
pretty-printing, for every source token and type datum.

A helper may render one datum by writing it to an output string. For a shared
row with selector `dist2`, parameters `'((Point Float))`, and return `'Float`,
the item is:

```racket
(selector-completion-item
 "dist2"
 "((Point Float)) -> Float"
 "dist2"
 replacement-start
 replacement-span)
```

Zero parameters render as `()`. Nested List, class, and function datums retain
their ordinary written parentheses. Selectors needing Racket escaping retain
their source-token spelling, such as `|two words|`; do not strip vertical bars
or invent an Aloe-specific escaping scheme.

## Normative Point results

Use the exact declaration from `examples/point.aloe`, either by prepending its
text to the query buffer or loading it with an appropriate source path.

For receiver `(Point new 1 2)`, completion on the complete `+` selector
returns these eight items in order:

```text
label  detail
x      () -> Int
y      () -> Int
+      ((Point Int)) -> (Point Int)
-      ((Point Int)) -> (Point Int)
dist2  ((Point Int)) -> Int
dot    ((Point Int)) -> Int
*      (Int) -> (Point Int)
/      (Int) -> (Point Int)
```

Every item has `insert-text = label` and the complete one-character `+` edit
range. Because `+` is an existing selector, the result is the whole catalog.

For receiver `(Point new 1.0 2.0)`, completion on the complete `dist2`
selector returns the same selector order with every `Int` above replaced by
`Float`. This proves completion types the receiver rather than the whole
`dist2` send, whose result would be `Float`.

For that Float receiver:

- partial `d` at token end returns `dist2`, then `dot`;
- partial `dist` at token end returns only `dist2`;
- an unmatched prefix returns `'()`;
- a nonexact partial token with the cursor before its end returns `'()`;
- either boundary and an interior boundary of complete `dist2` return the
  entire eight-row catalog; and
- an empty unclosed selector hole returns all eight rows with a zero-width
  range at the cursor.

In partial cases, every item replaces the entire original partial token, not
only the text before the cursor. A selector followed by arguments retains the
same whole-token range without consuming an argument.

## Normative Boids results

Read the exact `examples/boids.aloe` string and pass that file as
`#:source-path`, so its ordinary `load "point.aloe"` resolves from disk.

At one-based position 515, the first character of `dist2` on line 20 at
zero-based column 37, return the eight Point Float items above with replacement
start 515 and span 5.

At one-based position 2261, the first character of the first `neighbors` send
to `b` on line 76 at zero-based column 30, return these eight items in order
with replacement start 2261 and span 9:

```text
position   () -> (Point Float)
velocity   () -> (Point Float)
in-view?   (Boid) -> Bool
neighbors  ((List Boid) Float) -> (List Boid)
cohere     ((List Boid)) -> (Point Float)
align      ((List Boid)) -> (Point Float)
separate   ((List Boid)) -> (Point Float)
advance    ((Point Float)) -> Boid
```

Both positions are at the start boundary of complete existing selectors, so
the exact-selector rule returns the whole receiver catalog.

## Additional required behavior

The public suite must also prove:

- a function receiver offers only its shared `call` row, and `(f x)` remains
  completion on selector `x`, not implicit function application;
- a user class object in `(Point |)` naturally offers its constructor row,
  without top-level class-name completion;
- bootstrapped List and String receivers include their environment-local
  extension rows in exact catalog order, without production knowledge of the
  extension selector names;
- nested lexical receivers using `self`, a method parameter, a function
  parameter, a `let` binding, and a case payload cross the public boundary
  with the exact contextual rows established by checkpoint 001;
- an earlier `define-methods` row appears in catalog order while a later root
  does not, and two same-selector overloads remain separate and ordered;
- a legitimate empty receiver catalog, an eligible prefix with no matches,
  and every ineligible or failed query all return the same public value `'()`;
  no fallback item distinguishes them; and
- repeated successful calls produce equal but non-`eq?` result lists and do
  not leak declarations between calls.

## Exact file scope

Implementation may add only:

- `aloe/completion-query.rkt`; and
- `tests/editor/completion/002-public-query.rkt`.

Do not edit:

- `aloe/private/completion-selection.rkt`, `aloe/type.rkt`,
  `aloe/private/expression-selection.rkt`, `aloe/parse.rkt`,
  `aloe/signature-catalog.rkt`, `aloe/main.rkt`, `aloe/library.rkt`,
  `aloe/driver.rkt`, `aloe/eval.rkt`, or `aloe/host.rkt`;
- checkpoint 000 or 001 production modules and tests;
- expression-query, signatures-of-type, source-location, LSP, or VS Code
  production modules and tests;
- `SPEC.md`, `CHECKPOINTS.md`, anything under `docs/checkpoints/`, or the
  completion specification, charter, README, and checkpoint documents; or
- `gel/`, `lib/`, `host/`, `examples/`, and existing fixtures.

Tests may create temporary files and directories under the platform temporary
directory for load and nonexistent-root cases and must remove them with an
unconditional cleanup action. They must not modify a checked-in source file.

If the public query requires a change to recovery, checker observation,
catalog semantics, standard bootstrap, Aloe syntax, or a predecessor test,
stop and return the checkpoint for design review.

## Required tests

Add `tests/editor/completion/002-public-query.rkt`. It is three directories
below the repository root, so use `../../../aloe/...` and
`../../../examples/...` for module and runtime paths. Every query case must
use exact source text and a documented one-based boundary. A display-only bar
helper is encouraged for constructed strings; it must remove exactly one bar
before calling the production query.

Compare complete `selector-completion-item` structures in exact order,
including label, detail, insert text, replacement start, and replacement
span. Cover at least:

1. The public module exports exactly the item structure and query operation.
   Pin item field order, constructor arity 5, query arity 2, accepted optional
   `#:source-path`, and absence of signature/checker/recovery/expression-query
   exports. `aloe/main.rkt` and `aloe/driver.rkt` do not re-export it.
2. Wrong-kind source, position, and source-path arguments raise argument errors
   naming `query-selector-completions`. Position zero is a wrong kind; the
   first positive boundary past end returns `'()` silently.
3. A supplied relative string or path is normalized to the same complete
   simplified base. Use an authoritative source string whose root path does
   not exist and whose earlier relative load does exist to prove both root
   non-opening and normalized load resolution.
4. Any buffer containing a parsed `load` with no source path returns `'()` and
   never resolves against the current directory. Test a load before and after
   an otherwise valid target. With a source path, a missing or malformed
   earlier load returns `'()` while a missing later load is skipped after a
   successful receiver.
5. Pin every exact Point Int and Point Float item described above. Cover
   complete `+` and `dist2`, partial `d` and `dist`, unmatched and interior
   prefixes, all boundaries of an exact selector, an empty unclosed hole, and
   a selector followed by arguments. Assert one common range per result.
6. Read exact `examples/boids.aloe` and pin all items and exact ranges at
   positions 515 and 2261. Do not replace these with substring-derived
   positions.
7. Query bootstrapped List and String receivers and pin every kernel plus
   installed-library item in order. Compare repeated calls for equal, fresh
   result lists. Production source must not contain the extension selectors.
8. A typed function receiver returns its one `call` item. A Point class-object
   selector hole returns only its `new` constructor item. `(f x)` remains an
   ordinary selector site and is filtered from the function receiver's
   catalog according to the normal prefix/exact rules.
9. Public queries inside a method, function, `let`, and case clause prove
   `self`, parameters, bindings, and payloads retain their contextual receiver
   catalogs. Include a rigid generic body with symbolic `T` or `U` details.
10. Earlier/later `define-methods` and duplicate overload cases pin exact item
    order and multiplicity after formatting. Include a selector requiring
    Racket escaping and prove `write` supplies the label and insert text.
11. A blank source, top-level gap or name, cursor in a comment or string,
    special-form position, receiver position, argument position, and position
    after a finished form return `'()`. Retain checkpoint 000's full focused
    suite as the exhaustive syntax-level proof.
12. Malformed strings and declarations, mismatched brackets, unrelated bad
    suffixes, more than 64 required closes, missing loads, unbound receivers,
    and other failures before receiver success return `'()` promptly and
    silently. Parameterize output and error ports and prove no prose leaks.
13. A no-row receiver, no-match prefix, and source failure all return the exact
    empty list. Items and captured output never contain the private marker or
    appended recovery text.
14. Querying a statically valid receiver containing `(1 / 0)` proves no
    evaluation occurs. A receiver depending on an unbound injected-host name
    returns `'()`. The public surface has no host or environment parameter.
15. A successful declaration query does not leak its class or installed
    method into the next call. A failed query likewise leaves the next call
    clean. Loaded files and the supplied source string remain unchanged.
16. Inspect production source narrowly enough to reject a second catalog,
    declaration-table walk for candidates, named Point/Boids/List/String
    selectors, `query-expression-at`, evaluator/runtime reflection calls,
    sorting/deduplication, snippets, and editor-protocol code. Behavior tests
    remain primary; do not pin harmless local helper names or formatting.

Tests may import the public completion module and, for constructing expected
values or independent catalog comparisons, existing public/shared modules.
They must not call the private recovery or completion observer as the subject
of a public-query assertion. Checkpoints 000–001 retain their own focused
tests for those internal boundaries.

## Hand check and acceptance

After the automated tests, run this from a Racket REPL at the repository root:

```racket
(require racket/file
         "aloe/completion-query.rkt")

(define point-path (path->complete-path "examples/point.aloe"))
(define source
  (string-append (file->string point-path)
                 "\n((Point new 1.0 2.0) d"))

(for/list
    ([item (in-list
            (query-selector-completions
             source
             (add1 (string-length source))
             #:source-path point-path))])
  (list (selector-completion-item-label item)
        (selector-completion-item-detail item)
        (selector-completion-item-insert-text item)
        (selector-completion-item-replacement-start item)
        (selector-completion-item-replacement-span item)))
```

With the checked-in 721-character `examples/point.aloe`, the exact result is:

```racket
'(("dist2" "((Point Float)) -> Float" "dist2" 744 1)
  ("dot" "((Point Float)) -> Float" "dot" 744 1))
```

Run:

```sh
raco test tests/editor/completion/002-public-query.rkt
raco test tests/editor/completion/001-contextual-receiver.rkt
raco test tests/editor/completion/000-selector-recovery.rkt
raco test tests/editor/expression-query/003-public-query.rkt
raco test tests/editor/signatures-of-type/002-declaration-query.rkt
raco test tests
git diff --check
```

The pre-checkpoint recursive baseline passes 2,186 of 2,188 tests. Its only
failures are the two documented pre-existing contradictions in
`tests/gel/presentations/003-doc-law.rkt`. Do not edit or weaken those tests or
their documentation. Require every focused and predecessor suite to be
completely green and the recursive suite to retain exactly those two failures
with no new failure. If that contradiction has been repaired before
implementation, require a completely green recursive suite.

The checkpoint is complete when the public query validates its arguments,
uses the exact current source with normalized optional path, builds one fresh
standard environment, returns stably filtered and exactly formatted items with
original-buffer ranges, contains all source failures as empty results, passes
the Point and Boids bars, performs no evaluation, and leaves all predecessor
behavior unchanged. Stop for review without committing. Do not add or change
the LSP adapter, completion capability, protocol request, UTF-16 edit
conversion, VS Code client, or manual editor checks.

## Explicit non-goals

- No `textDocument/completion`, `completionProvider`, trigger character,
  CompletionItem JSON, UTF-16 conversion, JSON-RPC dispatch, lifecycle, or
  adapter-failure change
- No VS Code extension, manifest, grammar, command, snippet, or client-side
  filtering change
- No `query-expression-at` change and no incomplete-hover recovery
- No public environment, host injection, evaluator, runtime `Mirror`, or host
  implementation call
- No second parser, delimiter scanner, incremental parse, arbitrary repair,
  or dirty overlay for loaded files
- No top-level name, class-name, special-form, argument, signature-help,
  documentation, fuzzy, ranked, recent-use, or wrap-form completion
- No Aloe syntax, send, dispatch, overload, generic, protocol, load, mutation,
  inheritance, macro, or numeric-coercion change
- No Boids source change, Electron test, global checkpoint, or implementation
  of the later LSP slice
