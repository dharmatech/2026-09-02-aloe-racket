# Class-name definition

**Status.** Design specification for the local `editor-definition`
project. Not Aloe language law, not an implementation checkpoint, and
not a global checkpoint. The human reviews this file before a later
checkpoint-manager conversation slices it under
`docs/editor/definition/checkpoints/`.

**Authority.** `SPEC.md` remains law and is not amended. The
[expression query](../expression-query/spec.md) owns expression
selection, `query-expression-at`, `#:document-path`, the base-library
rule, and hover's result; this project does not change them. The
[LSP adapter](../lsp/spec.md) owns framing, lifecycle, document sync,
the temporary sibling, UTF-16 conversion, and hover failure. Its
deferred-work list names definition; this specification lifts that
deferral for class names only and does not edit that file.
[Editor-source-locations 000](../source-locations/checkpoints/000-spans.md)
owns expression spans and the `parse-datum` rule; §3 below is its one
amendment. [Modules](../../design/implementation/modules/spec.md) §6.3
names the environment that resolves each annotation. LSP 3.17 is the
protocol for `textDocument/definition` only.

The checkpoint manager will not have the charter. Every rule needed to
slice this work is in this file.

---

## 1. Predecessors, as found on 2026-10-14

The tree at `019cd18` (product code as of `28c0f26`) has every
predecessor. Editor-lsp 010 landed afterwards (`6c81883`); see §3.1.

| Predecessor | Found |
|---|---|
| Editor-source-locations 000 | Every `*-expr` has a final `loc`; `send-expr` ends in `loc selector-loc`. `read-program` reads with `read-syntax` and `port-count-lines!`. `parse-datum` builds location-free trees through the same parser. |
| Editor-expression-query 000–003 | `aloe/expression-query.rkt` exports `query-expression-at` with `#:document-path`, and `expression-query-result` has four fields ending in `pathed-type`. |
| Editor-lsp 000–009 | `aloe/lsp.rkt` serves hover and completion. Initialize advertises `hoverProvider` (`#t`) and `completionProvider` (`{"triggerCharacters": [" "]}`). |
| Defining path (modules layer 4) | `class-info` ends in a mutable `defining-path`. Hover prints `from:` with `Name@path`. |

The VS Code client in `editors/vscode/` depends on
`vscode-languageclient` 9.0.1. Its `registerBuiltinFeatures` registers
`DefinitionFeature`, which registers a definition provider for the
client's own `documentSelector` when the server's capabilities contain
`definitionProvider: true`. So the client needs no change (§5.7).

## 2. Series and order

Series identity `definition`, spoken **editor-definition 000**.
Checkpoints live in `docs/editor/definition/checkpoints/`, three
digits from `000`, never renumbered. Tests live in
`tests/editor/definition/`; fixtures in
`tests/editor/definition/fixtures/`. Not `CHECKPOINTS.md`, not
`docs/checkpoints/`, not a rewrite of editor-lsp 000–009.

Three layers, in this order. The manager may split a layer that does
not fit one implementer conversation, and may not reorder them or add
a feature:

1. **Spans** (§3). The parser stores the class name's span on
   `define-class`, the target's span on `define-methods`, and the
   symbol spans of each type annotation. The checker copies the class
   name's span onto the class record. Hover is unchanged.
2. **Query** (§4). `query-definition-at` answers the cursors of §6.
   If this layer is split, the first part covers token kinds V, C, and
   M of §4.3 (variables, class names, `define-methods` targets) and
   the second covers kind T (type symbols). Each part is testable
   alone: §6.2 tags every jump with its kind, and every §6.3 cursor
   is `#f` in both parts. Before kind T exists, a type symbol is no
   token, and its §6.2 rows are `#f`.
3. **LSP** (§5). `textDocument/definition` adapts the query.

## 3. Spans (layer 1)

### 3.1 New fields

Each structure gains one field, after its existing fields:

| Structure | Fields after this series |
|---|---|
| `define-class-expr` | `name type-parameters protocol fields constructors methods loc name-loc` |
| `define-methods-expr` | `target methods loc target-loc` |
| `field-declaration` | `name type type-spans` |
| `parameter-declaration` | `name type type-spans` |
| `method-declaration` | `selector type-parameters parameters return-type body return-type-spans` |

- `name-loc` is the `srcloc` of the class-name symbol in the header:
  the header itself when it is a bare symbol, the first element of
  `(Name T ...)` otherwise. `(define-class (Option T) ...)` records
  the span of `Option`.
- `target-loc` is the `srcloc` of the `define-methods` target symbol.
- `type-spans` is the span tree (§3.2) of the field's or parameter's
  type. A constructor payload field is a `field-declaration`; a
  protocol signature's parameter is a `parameter-declaration`.
- `return-type-spans` is the span tree of the method's return type,
  for a method in `define-class`, in `define-methods`, and for a
  protocol signature.

Each span is taken from the syntax object of that symbol, the same way
`selector-loc` is: through the parser's one location helper,
`syntax-location`, never from `syntax-position` directly. Since
[editor-lsp 010](../lsp/checkpoints/010-crlf-positions.md) that helper
counts CR LF as two characters, so the new spans count the source text
the way the LSP converter does. This series does not reopen 010. The
whole-form `loc` of `define-class-expr` and `define-methods-expr` stays
the form's span.

### 3.2 Span trees

**Choice: a tree of the same shape as the type.** The span tree of a
type form is:

- for a symbol: its `srcloc`;
- for a form that `syntax->list` turns into a list: a list of the
  span trees of its elements, in order, of the same length;
- for anything else (a number, a string, a vector, an improper list):
  `#f`.

The `type` field is unchanged: it is still the datum of the same form.
So at every list and every symbol, `type` and its span tree have the
same shape, and the query walks the two together. Examples, writing
`[X]` for the `srcloc` of the symbol `X`:

| Type datum | Span tree |
|---|---|
| `Point` | `[Point]` |
| `(Option Point)` | `([Option] [Point])` |
| `(List (Box Point))` | `([List] ([Box] [Point]))` |
| `(-> Int Point)` | `([->] [Int] [Point])` |

Every symbol gets a span, including `->`, `List`, kernel names, and
type parameters. The parser does not decide which symbols name
classes; the query does (§4.5). Each occurrence has its own span, so
two uses of one name stay apart.

A tree stored in one field of one declaration is not the program-wide
parallel syntax tree that editor-source-locations 000 bans.

### 3.3 `parse-datum`

`parse-datum` and `parse-program` set every new field to `#f`: the
whole `type-spans` or `return-type-spans` field is `#f`, not a tree of
`#f`. The rule is a single test in the shared parser: when the type
form carries no source location, the field is `#f`. Under
`read-program` every form carries one. Two `parse-datum` trees of the
same datum still compare `equal?`.

### 3.4 What does not change

- Editor-source-locations 000's five bans hold: no wrapper node, side
  table, parallel syntax tree, structure property, or new expression
  type. The one amendment is that a name token which is not an
  expression may carry a `srcloc`: the class name, the
  `define-methods` target, and the symbols of a type.
- These stay without spans: `constructor-declaration`, `case-clause`,
  the name of `define-protocol`, the name of `define`, `fn` and `let`
  parameters, `case` payload names, `new*` and `with` binding names,
  the type parameters in a class header, a method's `(type ...)`
  names, a class's protocol slot, method selectors, and constructor
  selectors.
- One parser. Field, parameter, constructor, and protocol-signature
  declarations are now parsed from their syntax objects instead of
  from `syntax->datum`, so the spans are available. They still store
  the same datums, accept exactly the same grammar, and raise the same
  `parse-datum` errors with the same text.
- Expression nodes, `expression-loc`, `selector-loc`, and hover's
  selection are unchanged. The type sexpr stays a raw datum. Aloe's
  meaning does not change: a field is still a name and a type sexpr.

### 3.5 The class record

`class-info` gains one field holding the class name's span.
`check-class-definition!` copies it from the form's `name-loc` when it
builds the record; it is `#f` for a form built by `parse-datum`. The
`define-methods` target span is not copied onto any class. The
evaluator's `class-value` gains nothing.

A loaded file's parse is not kept, so the class record is what a later
query reads. The base's `Option` record carries the span read from the
bytes `aloe/library.rkt` read when its promise was first forced.

Tests read the field through a test-only hook: a `type.rkt` submodule
`class-name-span` exporting `(checker-class-name-loc environment name)`,
the span on the class record bound to `name`, or `#f`; it raises an
error when `name` is not bound to a class.

### 3.6 Migration

Existing constructions and matches of the five structures gain the new
`#f` fields (constructions) or `_` (matches) and nothing else, the
mechanical permission from editor-source-locations 000. Read from the
tree on 2026-10-14 by grepping each structure name after an open
parenthesis:

- `aloe/parse.rkt`, `aloe/type.rkt`, `aloe/eval.rkt`,
  `aloe/private/expression-selection.rkt`,
  `aloe/private/completion-selection.rkt`;
- `tests/checkpoint-115.rkt`, `tests/int-methods/001-library.rkt`,
  `tests/editor/signatures-of-type/000-shared-catalog.rkt`,
  `tests/editor/source-locations/000-spans.rkt`,
  `tests/modules/001-census.rkt`.

One test edit is not mechanical and is permitted by name: in
`tests/editor/source-locations/000-spans.rkt`, `normalize-locations`
compares a `read-program` tree with a `parse-datum` tree after mapping
every `srcloc` to `#f`. A span tree would normalize to a list of `#f`
where `parse-datum` stores `#f`. The helper also maps the whole
`type-spans` field of `field-declaration` and `parameter-declaration`,
and the whole `return-type-spans` field of `method-declaration`, to
`#f`. No other assertion in that file changes.

The manager confirms this inventory with a scratch run of the product
edit and the whole suite, and treats the failing locations as the
inventory.

## 4. The query (layer 2)

### 4.1 Public function

A new module, `aloe/definition-query.rkt`, provides:

```racket
(struct definition-query-result (location text) #:transparent)

(query-definition-at source-path position
                     #:document-path [document-path source-path])
  ; source-path   : path-string?
  ; position      : exact-positive-integer?
  ; document-path : path-string?
  ; -> (or/c definition-query-result? #f)
```

`position` is the coordinate `query-expression-at` uses: a one-based
character position, as `srcloc-position` counts it.

A result is a jump. `#f` is no jump. A miss is not an error.

### 4.2 Reading and identity

Exactly as `query-expression-at`:

- The source path is normalized to a complete, simplified path and
  must name a regular file. Its bytes are read once and parsed by
  `read-program` with that path as `#:source-path`.
- `#:document-path` is the buffer's identity. It defaults to the
  source path. When it names a base library (`lib/list.aloe`,
  `lib/string.aloe`, `lib/int.aloe`, `lib/option.aloe`), the buffer is
  checked by the base-library rule; otherwise as a file module at the
  identity path. Both go through the same `query-base` hooks of
  `aloe/main.rkt` that `query-expression-at` uses
  (`base-library-path`, `typecheck-base-library-buffer`,
  `typecheck-file-module-buffer`).
- Loads resolve from the source path's directory and are read from
  disk.

### 4.3 Name tokens

The query finds the name token at the position. It walks every
expression node the expression query's selection walks (the children
`expression-children` in `aloe/private/expression-selection.rkt`
gives; that module may export it), and collects these tokens:

| Kind | Token | Where |
|---|---|---|
| V | a variable's `loc` | every `variable-expr` |
| C | `name-loc` | every `define-class-expr` |
| M | `target-loc` | every `define-methods-expr` |
| T | each `srcloc` in a span tree | the `type-spans` of every field of a `define-class` (its `fields` section and each constructor's fields); the `type-spans` of every parameter and the `return-type-spans` of every method in a `define-class`, in a `define-methods`, and in each signature of a `define-protocol-expr` |

A token with start `s` and span `n` answers position `p` when
`s <= p < s + n`, the expression query's containment. Tokens are
symbols and never overlap, so at most one answers. A V token answers
exactly where hover would select that variable.

When no token answers, the answer is `#f`. That covers a selector, a
constructor selector, `new*`, `with`, a binding site, a case payload
name, a header type parameter, a protocol slot, a `define-protocol`
name, a parenthesis, whitespace, a comment, a string, a number, and a
`load` path. The file is still checked first (§4.8).

### 4.4 Resolving a token

Each token resolves to a class record or to nothing, in the one
ordinary checker pass that checks the buffer. The query does not run a
second pass and does not replay a send.

- **V.** The variable's type at its successful inference, in its real
  context, resolved at the end of its enclosing root form: the type
  hover reports for it. A `class-type` names its record. Anything else
  is nothing.
- **C.** The record the checker built for that `define-class` form.
- **M.** The binding `check-method-definitions!` reads for the target:
  the target symbol in the environment the `define-methods` form is
  checked in. A `class-type` names its record. The `List`, `String`,
  and `Int` class objects are nothing.
- **T.** §4.5.

### 4.5 Type symbols

A type symbol resolves in the environment that wrote its annotation,
with the type parameters in scope there. These are the arguments the
checker already passes when it checks the annotation at its
declaration:

| Annotation | Checked by | Environment | Type parameters in scope |
|---|---|---|---|
| a field type, in `fields` or a constructor | `check-class-definition!` | the `define-class` form's | the class's |
| a parameter or return type in `define-class` | `check-method-types!` | the form's | the class's, plus the method's `(type ...)` |
| a parameter or return type in `define-methods` | `check-method-types!` | the form's | the target's (a class's type parameters; `T` for `List`; none for `String` and `Int`), plus the method's `(type ...)` |
| a parameter or return type in a protocol signature | `check-method-types!` | the `define-protocol` form's | none (the parser stores `'()`) |

The method's set is the substitution `extend-method-substitution`
builds. A `define-methods` form has no type parameters of its own. A
deferred re-check of a method body resolves annotations again with a
send's substitution; that resolution is not the declaration and is
not observed (§4.8).

When the checker has checked that annotation, the query resolves its
token there, walking the type datum and its span tree together from
the root, by the cases `type-from-sexpr` uses:

| Where the symbol sits | Resolution |
|---|---|
| the whole type, or an argument the checker resolves | `Int`, `Float`, `Bool`, `String`, `Symbol`, `Mirror`, `Signature`: nothing. A type parameter in scope: nothing. Otherwise its binding in the environment: a `class-type` names its record; a protocol or anything else is nothing. |
| the head of a list | `->`: nothing. `List`: nothing. Otherwise its binding in the environment: a `class-type` names its record. |
| an argument of `->` or `List`, or of a head bound to a generic class | resolved by the first row. |
| an argument of a head bound to a class with no type parameters | nothing. The checker accepts `(Point Int)` on a non-generic `Point` without reading its arguments, so it never resolves them. |

The walk must agree with `type-from-sexpr` case by case. The checkpoint
may factor those cases out of `type-from-sexpr` so both use one copy.
It must not change what `type-from-sexpr` accepts or the text of its
errors.

### 4.6 When a resolved class jumps

A token whose record is `c` jumps when all of these hold:

1. The token's symbol is `eq?` to `c`'s name. An alias fails here:
   after `(define P Point)`, `P` resolves to `Point`'s record and is
   not its name. The use of a local that reuses the class's own name
   passes: in `((fn (Point) (Point new 1 2)) call Point)` the body's
   `Point` jumps.
2. `c` has a defining path.
3. `c` has a class-name span.

Otherwise the answer is `#f`. Kernel classes have no record or no
defining path; protocols and type parameters have no record. A C token
always meets rule 1.

### 4.7 The answer

For a jump to record `c`:

- `location` is a `srcloc` whose source is `c`'s defining path, and
  whose line, column, position, and span are `c`'s class-name span.
  The source is rebuilt from the defining path. It is never the source
  path when that differs from the identity path, so a temporary
  sibling never appears.
- `text` is the load-cache entry under `c`'s defining path in the
  query's base, its bytes decoded by `bytes->string/utf-8` with U+FFFD
  as the error character. That entry holds the bytes `c`'s
  `define-class` was parsed from:

| Class | Defining path | `text` |
|---|---|---|
| defined by the queried buffer | the identity path | the buffer, as read from the source path |
| defined by a nested load | that file's resolved path | the bytes read for that load |
| the base's `Option`, used from another file | `lib/option.aloe` | the promise's bytes |
| defined by a queried base-library buffer | the identity path | the buffer |

The LSP adapter converts the range with `text` (§5.4).

### 4.8 One pass, deferred bodies, and failure

The checker observes the token in its one pass, the way the expression
query observes an expression:

- A V token is retained at each successful inference and resolved at
  the end of its enclosing root form. Types from a failed overload
  candidate or another speculative path are not answers.
- A C, M, or T token is observed where §4.4 and §4.5 say: when the
  form's record is built, when the target is read, or when the
  annotation is checked at its declaration.
- When the token's owner (the `variable-expr`, or the `define-class`,
  `define-methods`, or `define-protocol` form that holds the token)
  lies inside a deferred generic method body, that body is checked at
  its declaration, as expression-query §5 does for a selected
  expression. `selected-expression-in-method-body?` also considers
  the definition owner; with no definition observer active it answers
  exactly as today, for hover and for completion. A class name inside
  an `AloemacsSession`
  method body is this case. Observations made while re-checking a
  deferred body for a concrete send are ignored.
- The answer is built only after the complete file has checked.

Failure policy is `query-expression-at` §6 with `who` set to
`query-definition-at`: argument errors, a missing source file, reader
and parser failures, and Aloe checker failures raise with their
existing text; a later checker error suppresses an earlier
observation. A valid position that does not jump returns `#f` after
the complete file checks. Repeated calls are independent.

### 4.9 Boundary

- `aloe/definition-query.rkt` is the public boundary. It is not
  re-exported from `aloe/main.rkt`, not added to `driver.rkt`, and not
  an Aloe message or runtime binding. It does not evaluate the
  program and has no host-injection parameter.
- The checker side is a narrow bridge, like the expression query's: a
  `type.rkt` submodule (for example `definition-query-observation`)
  that checks the program with the definition observer active and
  returns the jump's class-name span, defining path, and that path's
  cache bytes, or `#f`. The observer lives in
  `aloe/private/checker-observation.rkt`. Token finding lives in a
  private module (for example `aloe/private/definition-selection.rkt`).
- The definition result is not `expression-query-result`. Do not add a
  definition field to that struct, and do not make hover call this
  query. `aloe/expression-query.rkt` does not change.

## 5. LSP (layer 3)

### 5.1 Capability

The initialize result gains `definitionProvider: true` beside the
existing capabilities:

```json
{
  "capabilities": {
    "positionEncoding": "utf-16",
    "textDocumentSync": { "openClose": true, "change": 1 },
    "hoverProvider": true,
    "completionProvider": { "triggerCharacters": [" "] },
    "definitionProvider": true
  },
  "serverInfo": { "name": "aloe-lsp" }
}
```

Every existing test that asserts the initialize result gains
`'definitionProvider #t` and keeps `hoverProvider` and
`completionProvider`. The implementer finds them with
`grep -rln "'hoverProvider" tests`; this spec does not fix their
number.

### 5.2 Request

`textDocument/definition` joins the supported requests. Its params are
`TextDocumentPositionParams`, checked with hover's shape check; extra
keys such as `workDoneToken` and `partialResultToken` are ignored.
Invalid params get `-32602`. Before initialize the request gets
`-32002`; after shutdown, `-32600`. Hover and completion are
unchanged.

The flow is hover's: the document is found by its exact URI, the URI
becomes a local path, the LSP position becomes a query position with
the existing converter, and the synchronized text is queried through
the existing path: the document path when its bytes match the disk,
otherwise a temporary sibling queried with `#:document-path` set to
the document's path and removed afterwards. A query that raises counts
as no answer, as `invoke-query` already does for hover.

`aloe/lsp.rkt` imports `query-definition-at` and the result accessors
from `aloe/definition-query.rkt`, and nothing from the parser or the
checker. One definition request makes at most one query call. It makes
none for an unopened document, an unsupported URI, or an invalid
position.

### 5.3 Result

The result is one LSP `Location`, or JSON null. It is not a list and
not a `LocationLink`.

### 5.4 Location

- **uri.** When the location's source equals the document's local path
  (both simplified, without touching the filesystem), the `uri` is the
  document's URI exactly as the client sent it. Otherwise it is
  `(url->string (path->url source))`. The sibling never appears.
- **range.** If the location starts at `s` with span `n`, convert the
  offsets `s - 1` and `s - 1 + n` with the existing offset converter
  over the result's `text`. If either is invalid, the result is null.
  When the location names the queried document, `text` is the
  synchronized text: the query read exactly the synchronized bytes,
  from the document or from its sibling. For a loaded file, `text` is
  the bytes that were checked.

For the §6 fixture, definition on `Box` at LSP line 26, character 7
returns:

```json
{
  "uri": "<the document's URI as sent>",
  "range": {
    "start": { "line": 6, "character": 15 },
    "end": { "line": 6, "character": 18 }
  }
}
```

### 5.5 Null and errors

The result is null when no token jumps, the document is unopened or
not a supported local file URI, the position is invalid, the buffer is
incomplete or malformed or fails checking, a needed file cannot be
read, or the range cannot be converted. These are not diagnostics.
This project publishes no diagnostics.

A snapshot failure is `-32803` with hover's message, "unable to create
synchronized document snapshot". Any other unexpected adapter failure
is `-32803` with "unable to produce definition result". The server
stays available.

### 5.6 Test hook

`run-lsp-server/with-queries` in the `test-support` submodule gains an
optional keyword argument `#:definition-query`, defaulting to
`query-definition-at`. Existing calls do not change. A stub on the
sibling path accepts `#:document-path`.

### 5.7 VS Code

`editors/vscode/` does not change. `createClientOptions` still returns
only `documentSelector`, and
`editors/vscode/test/000-hover-client.test.js` stays green without an
edit. Section 1 records why the client picks up `definitionProvider`.

## 6. Fixtures and the normative cursors

Fixtures are ASCII (except `wide.aloe`) with one LF after every line.

`tests/editor/definition/fixtures/point.aloe`:

```aloe
(define-class Point
  (fields
    (x Int)
    (y Int))
  (methods))
```

`tests/editor/definition/fixtures/shapes.aloe`, 52 lines, 1077 bytes:

```aloe
(load "point.aloe")
; Point and Box in a comment do not jump.

(define-protocol Mover
  (moved (by Point) Point))

(define-class (Box T)
  (fields
    (item T)
    (corner Point)
    (spare (Option Point)))
  (methods
    (fresh () Point
      (Point new 0 0))))

(define-class Segment Mover
  (constructors
    (Line (fields (from Point) (to Point)))
    (Dot (fields (at Point))))
  (methods
    (moved (by Point) Point
      by)))

(define-methods Point
  (methods
    (boxed (type A) (item A) (Box A)
      (Box new item self (Option None)))
    (nudge (m Mover) Point
      (m moved self))))

(define-methods Box
  (methods
    (item-of () T
      (self item))))

(define P Point)

(define-class Holder
  (fields
    (p P)
    (boxes (List (Box Point)))
    (maker (-> Int Point)))
  (methods))

(define origin (Point new 0 0))
(define ox (origin x))
(define alias-made (P new 3 4))
(define again ((fn (Point) (Point new 1 2)) call Point))
(define third (Point new* (x 5) (y 6)))
(define shifted (origin with (x 9)))
(define no-points (List empty))
(define label "Point")
```

`tests/editor/definition/fixtures/wide.aloe`, one line. The string
holds U+1F600 (UTF-8 bytes `F0 9F 98 80`):

```aloe
(define wide "😀") (define-class Wide (fields (n Int)) (methods))
```

`tests/editor/definition/fixtures/wide-user.aloe`:

```aloe
(load "wide.aloe")
(define w (Wide new 1))
```

All four files check on the found tree; `Box`'s methods are deferred
(a generic class with a `fields` section).

### 6.1 Targets

Lines are one-based, columns zero-based, positions one-based, as
`srcloc` reports them. The File column names the file. A result's
`srcloc-source` is that file's complete, simplified path (the class's
defining path), for example the absolute path of `lib/option.aloe`,
not the repository-relative form a `from:` line prints.

| Target | File | Line | Column | Position | Span |
|---|---|---:|---:|---:|---:|
| Point | `point.aloe` | 1 | 14 | 15 | 5 |
| Box | `shapes.aloe` | 7 | 15 | 131 | 3 |
| Segment | `shapes.aloe` | 16 | 14 | 279 | 7 |
| Holder | `shapes.aloe` | 38 | 14 | 702 | 6 |
| Option | `lib/option.aloe` | 1 | 15 | 16 | 6 |
| Wide | `wide.aloe` | 1 | 32 | 33 | 4 |

### 6.2 Cursors in `shapes.aloe` that jump

The cursor is the token's first character. Every character of the
token answers the same.

| Kind | Line | Col | Position | Token | Jumps to |
|---|---:|---:|---:|---|---|
| T | 5 | 13 | 100 | `Point` in a protocol parameter type | Point |
| T | 5 | 20 | 107 | `Point` as a protocol return type | Point |
| C | 7 | 15 | 131 | `Box` in the generic header | Box |
| T | 10 | 12 | 173 | `Point`, a field type | Point |
| T | 11 | 12 | 192 | `Option` in `(Option Point)` | Option |
| T | 11 | 19 | 199 | `Point` in `(Option Point)` | Point |
| T | 13 | 14 | 233 | `Point`, a method return type | Point |
| V | 14 | 7 | 246 | `Point` in a deferred generic body | Point |
| C | 16 | 14 | 279 | `Segment` in a bare header | Segment |
| T | 18 | 24 | 333 | `Point`, a constructor payload type | Point |
| T | 21 | 15 | 410 | `Point`, a method parameter type | Point |
| M | 24 | 16 | 452 | `Point`, a target from another file | Point |
| T | 26 | 30 | 499 | `Box` in `(Box A)` in `define-methods` | Box |
| V | 27 | 7 | 513 | `Box` as a receiver | Box |
| V | 27 | 26 | 532 | `Option` as a receiver | Option |
| T | 28 | 21 | 568 | `Point`, a return type in `define-methods` | Point |
| M | 31 | 16 | 615 | `Box`, a target in the same file | Box |
| V | 36 | 10 | 680 | `Point` in `(define P Point)` | Point |
| C | 38 | 14 | 702 | `Holder` | Holder |
| T | 41 | 18 | 747 | `Box` in `(List (Box Point))` | Box |
| T | 41 | 22 | 751 | `Point` in `(List (Box Point))` | Point |
| T | 42 | 19 | 779 | `Point` in `(-> Int Point)` | Point |
| V | 45 | 16 | 818 | `Point` in `(Point new 0 0)` | Point |
| V | 48 | 28 | 917 | the body's `Point` in `((fn (Point) ...) call Point)` | Point |
| V | 48 | 49 | 938 | the argument `Point` | Point |
| V | 49 | 15 | 961 | `Point` before `new*` | Point |

Also: `Wide` in `wide-user.aloe` (V, line 2, column 11, position 31)
jumps to Wide.

### 6.3 Cursors in `shapes.aloe` that do not jump

| Line | Col | Position | What is there |
|---:|---:|---:|---|
| 2 | 2 | 23 | `Point` in a comment |
| 4 | 17 | 81 | `Mover`, a `define-protocol` name |
| 7 | 19 | 135 | `T`, a header type parameter |
| 9 | 10 | 158 | `T`, a field type that is a type parameter |
| 14 | 6 | 245 | the parenthesis before `Point` |
| 14 | 12 | 251 | the space just after `Point` |
| 14 | 13 | 252 | `new`, a selector |
| 16 | 22 | 287 | `Mover`, a protocol slot |
| 18 | 5 | 314 | `Line`, a constructor selector |
| 26 | 26 | 495 | `A` in `(item A)`, a method type parameter |
| 26 | 34 | 503 | `A` in `(Box A)` |
| 27 | 20 | 526 | `self`, an instance |
| 27 | 33 | 539 | `None`, a selector |
| 28 | 14 | 561 | `Mover`, a protocol in a type |
| 33 | 16 | 646 | `T`, the target's type parameter in `define-methods` |
| 36 | 8 | 678 | `P`, a `define` name |
| 40 | 7 | 726 | `P`, an alias in a field type |
| 41 | 12 | 741 | `List`, a kernel name in a type |
| 42 | 12 | 772 | `->` |
| 42 | 15 | 775 | `Int`, a kernel name in a type |
| 46 | 12 | 846 | `origin`, an instance |
| 46 | 19 | 853 | `x`, a field-read selector |
| 47 | 20 | 877 | `P`, an alias in an expression |
| 48 | 20 | 909 | `Point`, the `fn` parameter |
| 48 | 44 | 933 | `call` |
| 49 | 21 | 967 | `new*` |
| 50 | 24 | 1010 | `with` |
| 51 | 19 | 1042 | `List`, a kernel class in an expression |
| 52 | 15 | 1070 | `Point` inside a string |

`Int` in `point.aloe` (line 3, column 7, position 38) does not jump.

### 6.4 The hover golden

Hover on `Point` at line 36, column 10 of `shapes.aloe` (LSP line 35,
character 10) is unchanged by this series. Its text is:

```text
type: (Class Point)
from: (Class Point@tests/editor/definition/fixtures/point.aloe)
messages:
  new : (Int Int) -> Point
```

and its range is LSP line 35, characters 10 to 15.

## 7. Required coverage

Run as `TMPDIR=/tmp raco test -j 4 -y <paths>`, the new test file
first, then any suite the checkpoint names, then `tests`.

**Spans.** On `shapes.aloe` read with `read-program`: `name-loc` for
`Box`, `Segment`, and `Holder`; `target-loc` for both
`define-methods`; span trees for a field type, `(Option Point)`,
`(List (Box Point))`, `(-> Int Point)`, a constructor payload, a
method parameter and return type, `(item A)` and `(Box A)`, and the
protocol signature; every `srcloc-source` is the fixture path; the
whole-form `loc` values are unchanged. `parse-datum` of the same forms
gives `#f` in every new field, and two parses are `equal?`. The class
record: `checker-class-name-loc` gives the `name-loc` for a class
checked from `read-program`, `#f` for one built from `parse-datum`,
and the `Option` span (line 1, column 15, position 16, span 6) for a
fresh base's `Option`. Hover at §6.4's cursor through
`query-expression-at` returns the same type, pathed type, rows, and
location as before.

**Query.**

- Every row of §6.2 returns its target's `location` (source,
  line, column, position, span) and a `text` equal to that file's
  text. Every row of §6.3 returns `#f`.
- The last character of a token jumps; the next position does not.
- `Option` twice: a use from `shapes.aloe` lands in `lib/option.aloe`;
  a query of `lib/option.aloe` on its own header lands in itself. A
  copy of `lib/option.aloe` with `"; edited\n"` prepended, written to
  a temporary directory and queried with `#:document-path` set to
  `lib/option.aloe`, answers `Option` at line 2, column 15, position
  25, span 6, with the source `lib/option.aloe` and the copy's text.
- A dirty queried buffer: copies of `shapes.aloe` and `point.aloe` in
  a temporary directory, the `shapes` copy queried with
  `#:document-path` set to the real `shapes.aloe`. `Box` answers with
  the real path as its source and the copy's text. `Point` answers
  with the copied `point.aloe`, which the load read.
- `Wide` from `wide-user.aloe` answers line 1, column 32, position 33,
  span 4, and its `text` holds the emoji.
- Failures: argument errors name `query-definition-at`; a missing file
  raises; a malformed buffer raises the parser error; a type error
  anywhere in the file raises `exn:fail:aloe-type?`, including at a
  jump cursor; a later error suppresses an earlier observation.
- Two calls in a row return equal answers.

**LSP.**

- The exact initialize result of §5.1; every migrated capability test.
- Recorded open/definition exchanges over `shapes.aloe`, opened with
  a percent-encoded URI as `tests/editor/lsp/000-hover.rkt` does:
  `Box` (LSP 26:7) returns that exact URI and range 6:15–6:18;
  `Point` (LSP 9:12) returns the `path->url` URI of `point.aloe` and
  range 0:14–0:19; `Option` (LSP 10:12) returns the URI of
  `lib/option.aloe` and range 0:15–0:21.
- `Wide` from `wide-user.aloe` (LSP 1:11) returns range 0:33–0:37. The
  emoji counts two UTF-16 units.
- `lib/option.aloe` opened clean with its own URI: definition on its
  header (LSP 0:15) returns that same URI.
- A dirty buffer: after a `didChange` that prepends one LF to
  `shapes.aloe`, `Box` at LSP 27:7 returns the document's URI and
  range 7:15–7:18. No sibling remains, and the file on disk is
  unchanged.
- Null for a miss cursor (`new`, LSP 13:13), an unopened document, an
  unsupported URI, an invalid position, a buffer with a type error, and
  a malformed buffer. The server keeps answering.
- `-32602` for invalid params, `-32002` before initialize.
- A counting stub passed as `#:definition-query` sees exactly one call
  per valid request, and none for an unopened document or an invalid
  position.
- §6.4's hover, byte for byte.
- `npm test` in `editors/vscode/` passes, and `git diff` shows no
  change under `editors/vscode/`.

Production code names no fixture class, no kernel class list beyond
`type-from-sexpr`'s own, and no Aloemacs name.

## 8. The hand check

After the LSP layer, in VS Code with the extension running
`racket -l aloe/lsp`. Put the caret inside the name or Ctrl+click it.
A caret after a name's last character addresses the next character,
which is a miss, as hover's containment is. Line numbers are as of
2026-10-14; find each line by its text if `file.aloe` has moved.

1. Open `examples/aloemacs/file.aloe`. Go to definition on
   `AloemacsBuffer` in `(AloemacsBuffer new` on line 1488, inside an
   `AloemacsSession` method. The editor moves to line 132,
   `(define-class AloemacsBuffer`. The caret rests at the start of the
   name, and the name highlights briefly.
2. Go to definition on `Position` in `(Position new 0 0)` on line 239.
   `lib/text.aloe` opens at line 3, on `Position`.
3. Go to definition on the field type in `(current-buffer
   AloemacsBuffer)` on line 152, which lands on line 132. Then on
   `Option` in `(pending (Option (AloemacsKeymap AloemacsBinding)))`
   on line 1240, which opens `lib/option.aloe` on `Option`.
4. Open `examples/aloemacs/main.aloe`. Go to definition on
   `AloemacsBuffer` in `(AloemacsBuffer new* ...)`. Nothing happens,
   and hover there is empty too: §9, first item.

The charter named `main.aloe` for this check. On 2026-10-14 the human
moved it to `file.aloe` for the reason in §9.

## 9. Accepted consequences

- **`main.aloe` is a whole-file miss.** `examples/aloemacs/main.aloe`
  line 74 uses `fs-host`. Only the Aloemacs runner injects it, and the
  editor queries have no host injection, so the query fails checking
  with `typecheck: unbound symbol: fs-host`. Hover there is already
  null. `(AloemacsBuffer new* ...)` occurs only in that file. Decided
  by the human, 2026-10-14: keep the no-host rule and check in
  `file.aloe`.
- A type error anywhere in a file turns definition off for the whole
  file.
- A class brought in by `load` is located from the bytes read for that
  load, including when that file is open with unsaved edits; the range
  comes from those bytes. A use of `Option` from another file uses the
  bytes `aloe/library.rkt` read when its promise was first forced, once
  per process. A query whose document is `lib/option.aloe` uses that
  buffer.
- An alias never jumps, although hover on it shows the class and its
  `from:` path.
- Arguments of a non-generic class head, as in `(Point Foo)`, are
  never resolved by the checker and never jump.

## 10. Non-goals

- Method selectors, constructor selectors, `new*`, and `with`
- Protocols as jump targets
- A binding site of `define`, `let`, or `fn`. A later use that meets
  §4.6 still jumps.
- Go-to-type-definition on an instance
- References, rename, signature help, formatting, code actions,
  semantic tokens, diagnostics
- Aloemacs calling the query, a file sidebar, or highlighting in
  Aloemacs
- An Aloe message, driver export, or runtime binding for the query
- A workspace index, a dirty overlay for a nested load, or incremental
  sync
- Typed `fn`, or any other grammar change whose purpose is a new jump
  site
- Host injection in the editor queries
- A VS Code extension change, a second editor, a client-side parser,
  or a TypeScript or JavaScript copy of name resolution
- A change to how editor-lsp 010 counts positions
- `CHECKPOINTS.md` and `docs/checkpoints/`
- Gel, evaluation, and host capabilities

## 11. Documents

Each checkpoint updates this folder's `README.md` file table and
status, and project 8's cell in [`../README.md`](../README.md). No
checkpoint edits `SPEC.md`, `docs/editor/lsp/spec.md`,
`docs/editor/expression-query/spec.md`, or
`docs/editor/source-locations/checkpoints/000-spans.md`.

When the implementation satisfies this specification, stop. The
checkpoint manager decides the slices. It writes one checkpoint, then
stops.
