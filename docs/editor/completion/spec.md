# Selector completion

**Status.** Design specification for the local `editor-completion` project.
Not Aloe language law, not an implementation checkpoint, and not a global
checkpoint. The human reviews this file before a later checkpoint-manager
conversation slices it under `docs/editor/completion/checkpoints/`.

**Authority.** `SPEC.md` remains law for sends, selectors, types, source order,
and `load`. Editor source-locations supplies `selector-loc`. The
[Expression query](../expression-query/spec.md) supplies contextual checker
observation, but its complete-file and cursor-selection rules remain unchanged
for hover. [Signatures of a type](../signatures-of-type/spec.md) supplies the
only signature catalog. The [LSP adapter](../lsp/spec.md) supplies lifecycle,
document synchronization, file-URI handling, UTF-16 conversion, and failure
policy. This specification amends that adapter only to add
`textDocument/completion` and its advertised capability.

All predecessors are implemented and reviewed: `query-expression-at` exists,
`type-signature-specs` is the catalog, editor-lsp 000--009 provide hover, and
the VS Code client launches `racket -l aloe/lsp` through
`vscode-languageclient`.

---

## 1. Public Racket query

A new module, `aloe/completion-query.rkt`, provides:

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

`source` is the exact current buffer, including unsaved and incomplete text.
`position` is the one-based Racket character boundary at the cursor: position
1 is before the first character and `(add1 (string-length source))` is the
end-of-buffer boundary. It is not a byte offset or an LSP UTF-16 position.

`source-path`, when supplied, is normalized to a complete simplified path and
is passed to the existing reader as the source name. The root file need not
exist because `source` is authoritative. The path supplies the base directory
for ordinary Aloe `load` forms. A buffer containing `load` without a
`source-path` has no completion result; the query does not resolve it relative
to an ambient current directory.

Each result item contains only editor data:

- `label` is the selector symbol written as an Aloe/Racket source token;
- `detail` is the entire parameter-list datum, ` -> `, and the return datum,
  each rendered with Racket `write` in the same form used by hover;
- `insert-text` is exactly the selector token, with no surrounding list,
  trailing space, arguments, or snippet placeholders;
- `replacement-start` is a one-based Racket character position in the
  original source; and
- `replacement-span` is the number of original Racket characters to replace.

All returned items for one query have the same replacement range. At an empty
hole it is the zero-width cursor range. On an existing or partial selector it
is the whole selector token, not only the prefix before the cursor. Selecting
an item therefore replaces `dist`, rather than appending `dist2` to it.

For example, a row whose selector is `dist2`, parameters are
`((Point Float))`, and return is `Float` becomes:

```racket
(selector-completion-item
 "dist2" "((Point Float)) -> Float" "dist2" start span)
```

The query raises a Racket argument error naming
`query-selector-completions` for an argument of the wrong kind. A position
outside `1` through `(add1 (string-length source))`, an unreadable load, a
reader/parser/checker failure under the recovery rule below, or an ineligible
cursor returns the empty list. Buffer content is not reported as a Racket
exception to editor callers.

The module re-exports neither checker internals nor a second row structure. It
does not change or re-export `query-expression-at`.

## 2. Eligible selector sites

Completion applies only to the literal selector position of an ordinary Aloe
send:

```text
(receiver |)
(receiver partial|)
(receiver existing-selector arguments ...)
```

The bar marks a cursor boundary and is not source text. The receiver must be a
complete expression before the selector site. A cursor in an existing
selector token, including either token boundary, is eligible. A cursor after a
complete receiver and separating whitespace is an empty selector hole.

The answer describes the **receiver**, not the expression selected by hover at
the same visible token. In:

```aloe
((Point new 1.0 2.0) dist2 other)
```

hover on `dist2` describes the whole send and its numeric result. Selector
completion at `dist2` observes `(Point new 1.0 2.0)` and returns the rows of
`(Point Float)`.

The following are not selector sites:

- a cursor before a receiver, in an argument, or after a finished expression;
- the keyword or operand positions of `define`, `define-class`,
  `define-methods`, `load`, `fn`, `let`, `if`, `cond`, `case`, or `check`;
- a blank file or top-level name position; and
- a synthetic selector introduced by parser sugar, whose `selector-loc` is
  `#f`.

This does not change send syntax. In particular, `(f x)` is a send of literal
selector `x` to `f`; it does not call `f`. A function object's callable row is
offered as `call` only when that row comes from the receiver's signature
catalog.

Class objects may naturally return their constructor rows when the cursor is
already in a send such as `(Point |)`. That is selector completion on the
typed receiver `Point`, not completion of `Point` after `(` and not a
blank-file class list.

## 3. The one recovery rule: cursor marker plus EOF close

Every query, complete or incomplete, uses this one bounded recovery rule. It
does not add an Aloe grammar, scan for balanced delimiters, or parse a prefix
with editor-owned code.

1. Choose a private ASCII identifier fragment that does not occur in
   `source`. Insert it at the cursor boundary. The fragment is query-internal
   and is never returned to the user.
2. Pass the resulting text through the existing `read-program` syntax-aware
   reader and Aloe parser. First try it unchanged except for a final newline.
   If that fails, try again after that newline with one `)`, then two, through
   at most 64 appended right parentheses.
3. Accept the first candidate that reads and parses as a complete program and
   contains exactly one ordinary `send-expr` whose source `selector-loc`
   contains the entire inserted marker. That send is the target and its
   `receiver` is the expression to observe.
4. If no candidate qualifies, return the empty list. Do not delete or replace
   other source text, repair a quote or mismatched bracket, try another
   delimiter, or fall back to a fabricated catalog.

Insertion makes both required cases readable by the ordinary reader. In an
empty hole, the marker temporarily occupies the selector position. In a
partial or existing selector, it becomes part of that symbol token. Appended
right parentheses close lists that remain open at end of buffer. The final
newline prevents an end-of-line comment from swallowing the appended
parentheses.

The fixed 0--64 attempt bound is part of the contract. It makes failure finite
and observable without implementing delimiter balancing. A buffer that would
need more closes simply has no items in this experiment.

The accepted selector location maps back to the original buffer by removing
the marker's contribution to its span. If the marker was the entire temporary
selector, the mapped replacement span is zero at the original cursor.
Otherwise the mapped range must be exactly one original source token and the
cursor must lie on that token. Failure to map it unambiguously returns no
items.

This recovery is deliberately narrower than an incremental parser. Text after
the cursor remains in the candidate and must be readable after EOF closing.
An unfinished string, malformed declaration, or unrelated mismatched
delimiter is not recovered. Hover continues to reject every incomplete file
under the Expression query specification.

## 4. Contextual receiver typing

After recovery identifies a target send, completion observes that exact
send's receiver in one ordinary checker traversal. It reuses the contextual
observation mechanism established for expression queries; it must not detach
the receiver and call `type-of` in a top-level environment.

The completion observation differs from hover in one necessary way. As soon
as inference of the target receiver succeeds, it retains the receiver's
checker type and the exact lexical checker environment, obtains rows with:

```racket
(type-signature-specs receiver-type receiver-environment)
```

and exits the traversal before resolving the marker-bearing selector. It does
not type the target send's selector or arguments. It also does not require the
rest of the enclosing root or later roots to typecheck. Errors encountered
before or while inferring the receiver return no items; errors that occur only
after the receiver are irrelevant to this query.

This early boundary is what permits completion of `d`, `dist`, and an empty
selector hole without treating the marker as an Aloe special form or a real
message. It also preserves lexical context for `self`, method and function
parameters, `let` bindings, case payloads, expected types already available
at the receiver, and earlier top-level declarations.

Each call creates a fresh checker environment and installs the standard List
then String libraries in the same order as `make-driver`,
`query-expression-at`, and the public default environment. Earlier root forms
and earlier loads affect the receiver normally. Later roots do not
retroactively contribute bindings or `define-methods` rows. Loaded source is
read from disk relative to `source-path`; open-document overlays for loaded
files are not substituted.

The existing expression-query rule for observing a selected expression in a
deferred generic method body applies to a target receiver there as well. The
body is checked in its rigid declaration context. Completion does not eagerly
check unrelated deferred bodies.

The query is static only. It does not evaluate the buffer, invoke a method,
construct a runtime `Mirror`, or call a host implementation. There is no host
injection parameter. A receiver that depends on an unbound injected host has
no items.

## 5. Catalog, order, and prefix filtering

`type-signature-specs` is the sole source of candidate rows. Completion code
must not walk `class-info-methods`, inspect declarations to build items, copy
kernel rows, name List/String extension selectors, or maintain an editor
catalog. Fields, methods, overloads, installed methods, constructors,
protocol rows, functions, and host rows appear only as that query returns
them.

Before filtering, row order is exactly the order returned by
`type-signature-specs`. Filtering is stable: it removes rows but never sorts,
ranks, groups, or deduplicates them. Overloads therefore remain separate
items in catalog order even when their labels match.

The mapped original selector token determines filtering:

- an empty selector hole returns every row;
- if the complete original token reads as a symbol equal to any candidate
  selector, it is an existing selector and returns every row, regardless of
  the cursor's position within that token; and
- otherwise the cursor must be at the token's end. Its source-token text is a
  prefix, and only items whose source-token labels begin with that prefix are
  retained.

If the nonempty original token cannot be read as one symbol, return no items.
The exact-selector rule makes completion on the `+` or `dist2` of a complete,
valid send show the receiver's whole menu. On Point, partial `d` keeps
`dist2` and `dot` in their original relative order, while partial `dist` keeps
only `dist2`.

Item formatting happens only after row selection. It uses the shared
`signature-spec` fields and Racket datum writing. It performs no additional
substitution, arity inference, documentation lookup, or signature-help work.

## 6. LSP amendment

`aloe/lsp.rkt` adds `textDocument/completion` without changing any hover,
framing, lifecycle, synchronization, URI, or UTF-16 rule in the LSP adapter
specification.

Initialization now advertises:

```json
{
  "capabilities": {
    "positionEncoding": "utf-16",
    "textDocumentSync": {
      "openClose": true,
      "change": 1
    },
    "hoverProvider": true,
    "completionProvider": {
      "triggerCharacters": [" "]
    }
  },
  "serverInfo": {
    "name": "aloe-lsp"
  }
}
```

Space is the only trigger character in 000. Manual client invocation remains
available. There is no `.` trigger and no resolve request.

For a valid `textDocument/completion` request on an open local `file:`
document, the adapter:

1. converts the zero-based UTF-16 LSP position to the one-based Racket
   boundary using the existing synchronized-text conversion;
2. calls `query-selector-completions` exactly once with the exact synchronized
   text and the decoded document path as `#:source-path`; and
3. converts each item's original-source replacement start and span back to an
   LSP range against that same synchronized text.

Unlike hover, completion does not need a temporary sibling snapshot: its
public query accepts the buffer string. Hover retains its current exact
snapshot behavior and still calls `query-expression-at`. Completion does not
call `query-expression-at` at the cursor, because that operation would type
the whole send rather than its receiver.

The successful result is a `CompletionItem[]` in query order. Each item has
exactly these completion fields:

```json
{
  "label": "dist2",
  "detail": "((Point Float)) -> Float",
  "insertText": "dist2",
  "textEdit": {
    "range": {
      "start": { "line": 0, "character": 24 },
      "end": { "line": 0, "character": 28 }
    },
    "newText": "dist2"
  }
}
```

The shown range is illustrative; protocol tests pin ranges from their own
fixtures. `insertText` and `textEdit.newText` are the same selector token.
There is no completion kind, sort key, filter text, snippet format,
documentation, command, or deferred resolve data.

An eligible query with no rows or no prefix matches returns the empty JSON
array. An unopened or unsupported URI, invalid LSP position, or ineligible or
unrecoverable buffer also returns the empty array. Malformed request shapes
retain the adapter's existing `InvalidParams` behavior. An unexpected adapter
failure uses the existing `RequestFailed` handling and never terminates the
server. No completion failure becomes hover prose or a diagnostic.

The adapter may import the completion query and its result accessors. It must
not import the parser, checker internals, or `type-signature-specs`, and must
not build or filter message rows itself.

## 7. VS Code remains a thin client

The existing VS Code extension already uses `vscode-languageclient` 9.0.1
with an Aloe file document selector. That client forwards completion requests
for server-advertised completion capability. No extension production or
manifest change is specified.

In particular, do not add JavaScript or TypeScript parsing, dispatch,
signature rows, completion filtering, trigger registration, or insertion
logic. If a future implementation demonstrates that the existing language
client does not forward the advertised standard capability, stop for design
review rather than copying Aloe behavior into the extension.

Manual VS Code checks on Point and Boids may follow implementation review, but
they are not the proof for 000. Blank-file behavior is not an acceptance test
and must not be claimed as supported.

## 8. Required unit and protocol coverage

Racket unit tests under `tests/editor/completion/` are the first consumer.
They must be green before adding the LSP request. Every case consists of exact
source text (a fixture or string), a documented cursor boundary, and expected
items in exact order. Tests compare labels, details, insert text, and
replacement ranges, not only selector sets.

### Point

Use the Point declaration from `examples/point.aloe` or an exact test fixture.
A complete send with receiver `(Point new 1 2)` and cursor on its `+` selector
returns these eight items in order:

```text
x     : ()            -> Int
y     : ()            -> Int
+     : ((Point Int)) -> (Point Int)
-     : ((Point Int)) -> (Point Int)
dist2 : ((Point Int)) -> Int
dot   : ((Point Int)) -> Int
*     : (Int)         -> (Point Int)
/     : (Int)         -> (Point Int)
```

A complete send with receiver `(Point new 1.0 2.0)` and cursor on `dist2`
returns the same selector order with every `Int` above replaced by `Float`.
These tests prove that completion types the receiver, since the complete
`dist2` send itself has type `Float`.

Partial `d` on that Point receiver returns `dist2` then `dot`; partial `dist`
returns only `dist2`. In both cases `insert-text` is the bare selector token
and the edit replaces the whole partial token. An empty, unclosed source such
as:

```aloe
((Point new 1.0 2.0) |
```

with the declaration available earlier in the source returns all eight rows,
uses a zero-width edit at `|`, and proves the recovery rule before any LSP
test is written.

### Boids

Read the exact `examples/boids.aloe` text with that file as `#:source-path` so
its `load "point.aloe"` resolves normally.

- The `dist2` selector beginning at one-based position 515 (line 20,
  zero-based column 37) has receiver `(self position)` of type
  `(Point Float)` and returns the eight Point Float rows above.
- The first `neighbors` send to `b`, whose selector begins at one-based
  position 2261 (line 76, zero-based column 30), has receiver `Boid` and
  returns these rows in order:

```text
position : ()                  -> (Point Float)
velocity : ()                  -> (Point Float)
in-view? : (Boid)              -> Bool
neighbors: ((List Boid) Float) -> (List Boid)
cohere   : ((List Boid))       -> (Point Float)
align    : ((List Boid))       -> (Point Float)
separate : ((List Boid))       -> (Point Float)
advance  : ((Point Float))     -> Boid
```

These positions address the first character of the named complete selector;
the exact-token rule returns the receiver's full catalog.

### Boundaries and failures

Unit coverage also proves:

- a selector hole after a receiver, a partial token at end of buffer, both
  boundaries of an existing selector, and a selector followed by arguments;
- nested lexical receivers using `self`, a parameter, and a `let` binding;
- an earlier `define-methods` row appears in catalog position while a later
  one does not;
- two same-selector overload rows remain separate and ordered;
- malformed strings, mismatched brackets, cursors in comments/strings,
  special-form positions, argument positions, top-level gaps, positions past
  end, missing loads, and more than 64 required closes return promptly with
  no items;
- the marker and appended text never appear in labels, edits, source files,
  or error output; and
- the query performs no evaluation or host call.

After those unit tests pass, recorded LSP tests prove the exact initialize
capability, the space trigger only, UTF-16 conversion (including a
supplementary character before the selector), ordered CompletionItems and
edit ranges, incomplete synchronized text without a temporary snapshot, an
empty result, and unchanged hover behavior. The recursive existing editor and
language suites remain green.

## 9. Deferred work and non-goals

- Completion of top-level names, classes after `(`, special forms,
  `define-class`, `define-methods`, `fn`, `let`, or `if`
- Wrap-the-preceding-expression or inserting a surrounding send
- A blank-file class list or workspace symbol index
- Argument completion, signature help, selector documentation, snippets,
  popularity ranking, fuzzy matching, or recent-use ordering
- A second Aloe reader, incremental parser, delimiter scanner, TypeScript
  method table, or checking past arbitrary syntax errors
- Highlighting, TextMate grammar, semantic tokens, themes, diagnostics,
  source-locations 001, formatting, rename, or go-to-definition
- Dirty-buffer overlays for loaded files, non-file documents, or host/MPL
  injection
- Evaluation, Gel integration, Mirror invocation, mutation, inheritance,
  macros, numeric coercion, or any change to Aloe sends
- Changing Boids back to `(Boid T)`
- Electron tests as the acceptance bar

When this specification is approved, a later checkpoint-manager conversation
may slice editor-completion 000, 001, and so on under this folder. This design
conversation writes no checkpoint files and implements no code.
