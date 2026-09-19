# Expression query

**Status.** Design specification for the local
`editor-expression-query` project. Not Aloe language law, not an
implementation checkpoint, and not a global checkpoint. The human reviews
this file before a later checkpoint-manager conversation slices it.

**Authority.** `SPEC.md` remains law for parsing, sends, types, top-level
order, and `load`. Editor-source-locations 000 supplies expression `srcloc`
values. The Signatures of a Type specification supplies
`type-signature-specs` and `signature-spec`. This project composes those
operations; it does not add another type or method catalog.

---

## 1. Public result

A new Racket module, `aloe/expression-query.rkt`, provides:

```racket
(struct expression-query-result (type signatures location) #:transparent)

(query-expression-at source-path position)
  ; source-path : path-string?
  ; position    : exact-positive-integer?
  ; -> (or/c expression-query-result? #f)
```

It also re-exports the existing transparent `signature-spec` structure so a
consumer needs only this module to inspect every part of the answer.

`source-path` names one complete Aloe source file. The query accepts both
Racket paths and path strings and does not impose a filename extension. It
normalizes the source name to a complete, simplified path before passing it to
`read-program`. The result's `location` therefore has that normalized path as
its `srcloc-source`.

`position` uses the same coordinate as `srcloc-position`: it is a one-based
character position in the source port. It is not a byte offset, a zero-based
editor offset, a `line:column` pair, or a UTF-16 position. A later adapter may
convert its own coordinates before calling this function.

For a position contained by an expression, the fields are:

- `type`: the selected expression's checker type converted with the existing
  `type->datum` operation;
- `signatures`: a fresh proper Racket list returned by the existing
  `type-signature-specs` operation for that checker type and its checker
  environment; and
- `location`: the `srcloc` of the selected expression, not the location of the
  token that happened to be addressed.

The query returns Racket data, not Aloe values. It does not produce a runtime
`List`, `Symbol`, `Mirror`, or `Signature`, and it does not evaluate the
program.

If the position is not contained by an expression, the result is `#f` after
the complete file has passed the same strict checking required for a matched
position. This includes leading or trailing top-level whitespace, a comment
between top-level forms, the newline after a complete top-level form, and the
position one character beyond end of file.

The module is the public boundary for this experiment. Do not re-export the
operation from `aloe/main.rkt`, add it to `driver.rkt`, or add a runtime Aloe
message for it.

## 2. Which expression owns a position

An expression location with start `s` and span `n` contains position `p` when:

```text
s <= p < s + n
```

Selection considers the expression structures produced by `read-program`:

- atoms and `load` have no expression children;
- `check` visits its left and right expressions;
- `define` visits its value;
- `define-class` and `define-methods` visit method bodies;
- `fn` visits its body;
- `case` visits its scrutinee, each clause body, and its optional `else` body;
  and
- a send visits its receiver and arguments.

Protocol signatures, field declarations, constructor declarations, method
parameter and return annotations, case payload names, stored `check` datums,
and a send's selector are not expression nodes.

Among all containing expression nodes, choose the one with the smallest
`srcloc-span`. When equal spans occur, choose the outermost node in the parsed
expression tree; equivalently, a preorder traversal keeps its first candidate
for an equal span. This tie rule is observable for parser sugar. For example,
the introduced `call` send and its introduced receiver function share a
`let` form's location; a position on `let` selects the outer send and therefore
the type of the whole source `let`, not the synthetic function type.

These consequences are locked:

- A position on an atom selects that atom.
- A position on the opening or closing parenthesis of a nested form selects
  that nested expression when its span is smaller than its parent's.
- Whitespace or a comment inside a list selects the smallest enclosing
  expression when it is not covered by a child expression.
- A position on a send selector selects the whole send. The selector is a
  literal dispatch name, not a separately typed expression; its
  `selector-loc` is not a second candidate.
- Whitespace after a top-level form selects nothing, even when it is on the
  same line.
- A position on declaration syntax that is not inside a method body selects
  the enclosing declaration expression. Its type is normally `Void` and its
  signature list is empty.

The position addresses only the named root file. A `(load ...)` form is an
expression in that file, but expressions parsed from the loaded file are not
descendants of the `load` node and cannot be selected using the root file's
coordinate. Query the loaded file by its own path to address its expressions.

## 3. Reading and location-less trees

The query reads the entire file through `read-program` with the normalized
path supplied as `#:source-path`. It does not use `read`, `parse-datum`,
`parse-program`, `syntax->datum` on whole forms, a second parser, or a text
scanner.

`parse-datum` and `parse-program` remain location-less APIs. A tree whose
`expression-loc` is `#f` has no address and cannot match a source position.
The path-based public query never guesses a location for such a tree. Any
internal selection helper used by the implementation must ignore
location-less nodes and return no selected expression when all nodes are
location-less.

Incomplete input is outside this project. An unclosed list, a missing
selector such as `(receiver)`, or a selector hole such as `(receiver ` is a
reader/parser failure, not a partial expression query. There is no
well-formed-prefix, recovery, or best-effort mode.

## 4. Checker environment

Every call creates a fresh checker environment. Before checking the source,
it installs the standard List library and then the standard String library in
the same order as `make-driver` and the public default environment. Thus an
ordinary query sees the methods from `lib/list.aloe` and `lib/string.aloe`
without requiring the source file to load them.

`load` keeps its existing Aloe meaning. A loaded file is resolved relative to
the file containing its `load`, is read with source locations, and is checked
in the same checker environment. Bindings and `define-methods` rows installed
by an earlier load are visible to later expressions in the loading file.
Existing missing-file and load-cycle behavior is unchanged.

The query has no host-injection parameter. A source file that requires an
injected host binding fails as unbound in this experiment. Adding a
host-configured query is a separate design; the path argument does not imply
ambient application capabilities.

Only static checking runs. No runtime environment is made, no expression is
evaluated, no host implementation is invoked, and no output from the source
program is produced.

## 5. Type at the selected expression

The selected node must be inferred in its real checker context. It must not be
detached from the program and passed to `type-of` in the top-level
environment. Detaching would lose `self`, method parameters, `fn` parameters,
`let` bindings, case payload bindings, expected types, and constraints from
the containing expression.

Conceptually, one ordinary checker pass observes the selected expression:

1. Read and select the node by object identity, or retain that no node matched.
2. Start from the fresh default checker environment.
3. Check root expressions in source order, including loads at their existing
   positions.
4. If a node matched, when its successful inference returns, retain that
   checker type and the lexical checker environment used for it.
5. At the successful end of the matched node's enclosing root expression,
   resolve and materialize its type datum and signature rows. Waiting until
   the root finishes allows expected types and sibling use within that root to
   finish constraining inference variables.
6. Continue checking the remaining root expressions. If the complete file
   succeeds, return the materialized answer for a match or `#f` for a gap.

Materializing at the end of the enclosing root expression also locks Aloe's
sequential environment rule. Declarations, loads, and method installations in
earlier root forms are visible. Changes made by the enclosing root form itself
are visible according to the checker's existing rules—for example, all rows
in one `define-methods` form are installed before its bodies are checked.
Later root forms do not retroactively add rows to an earlier expression's
answer.

The observed type is the one from the successful derivation. Types from a
failed overload candidate or another speculative checker path are not query
results. `type-signature-specs` receives the retained checker type and the
same lexical environment in which it was inferred; the expression-query
module must not inspect `class-info-methods` or build signature rows itself.

### Generic method bodies

The current checker may defer a legacy generic class method body until a
concrete instance send. That optimization must not make source inside the
method unqueryable.

When the selected expression is inside such a deferred method body, check
that one containing body at its declaration form using the declared return
type, `self` as the class instance over its rigid class parameters, and rigid
method-local parameters. Capture the selected expression from this generic
declaration context before any later concrete instantiation. Do not eagerly
check unrelated deferred bodies and do not change normal Aloe program
acceptance outside this query.

For example, selecting `self` inside a method of `(Point T)` reports type
`(Point T)` and Point rows parameterized by `T`, even if the file contains no
`(Point new ...)` construction or method send.

## 6. Complete-file and failure policy

This is a strict complete-file query:

- The entire root file must read and parse successfully before checking.
- The entire root file and every encountered load must typecheck.
- Checking stops at the first type error in normal checker order.
- A later error invalidates an answer captured earlier; no partial result is
  returned.
- Protocol conformance at the end of the outer program remains part of
  successful checking.

There is no attempt to continue after an error and no result containing both
rows and diagnostics.

Failure behavior is:

- A non-`path-string?` path or non-positive/non-exact position is a Racket
  argument error whose `who` is `query-expression-at`.
- A path that does not name a readable regular file is an error naming that
  path. Normal filesystem exceptions may propagate if opening fails.
- Reader and Aloe parser failures propagate; they are not converted into an
  empty query result.
- Aloe checker failures remain the existing `exn:fail:aloe-type?` errors and
  retain their existing text. This project does not add location prefixes to
  errors.
- A valid position outside every expression returns `#f`, not an exception.

Repeated calls are independent. A failed or successful query does not retain
classes, bindings, installed methods, inference constraints, or load state for
the next call.

## 7. Normative Point fixture

The later implementation tests use an ASCII fixture with exactly these bytes
and one LF after every shown line:

```aloe
(define-class (Point T)
  (fields
    (x T)
    (y T))
  (methods
    (+ (other (Point T)) (Point T)
      self)
    (dist2 (other (Point T)) T
      (self x))))
(Point new 1 2)
```

In that fixture, the final send has line 10, zero-based column 0, one-based
position 163, and span 15. Position 170 is the `n` in its literal `new`
selector. Because a selector selects its whole send, querying position 170
returns:

```text
type: (Point Int)
location: line 10, column 0, position 163, span 15
signatures, in order:
  x     : ()          -> Int
  y     : ()          -> Int
  +     : (Point Int) -> (Point Int)
  dist2 : (Point Int) -> Int
```

The signature values are exact `signature-spec` structures: parameter lists
contain type datums, so the `+` row's parameters field is
`'((Point Int))`, not a formatted string. Tests compare full rows and order,
not just selector names.

The same fixture must also prove that selecting `self` in the generic `+`
body works in declaration context and returns `(Point T)` with the same four
rows parameterized by `T` where applicable.

## 8. Required coverage for later slices

The completed implementation must prove at least:

- the exact public arity, result structure, type datum, signature structures,
  and returned `srcloc`;
- the normative Point selector position and full ordered rows above;
- innermost selection for nested atoms and sends, send selection on a
  selector, parenthesis selection, inner whitespace, top-level whitespace,
  and the equal-span outer tie for `let` or `if` sugar;
- a nested expression using `self`, a method parameter, a `fn` or `let`
  parameter, and a case payload is inferred in lexical context rather than as
  a detached top-level expression;
- a selected expression in an otherwise deferred generic method body is
  reported in its rigid declaration context;
- default List and String library extension rows are present without source
  loads and are not duplicated across repeated queries;
- an earlier `load` contributes a class or installed method used by the
  selected expression, with relative paths resolved from the loading file;
- a `define-methods` form after the selected root expression does not appear
  retroactively in its signature rows, while the complete later form is still
  checked;
- no evaluation or host implementation call occurs;
- `parse-datum` and `parse-program` trees have no matching address;
- missing root and loaded files, malformed input, and the first checker error
  fail as specified; a later checker error suppresses an earlier captured
  answer; and
- a valid top-level gap returns `#f`.

Tests must use `type-signature-specs` as the source of rows or compare query
rows to it. Production expression-query code must not name Point methods,
List/String library selectors, kernel selectors, or inspect declaration
method tables.

## 9. Deferred work and non-goals

- A CLI, `./bin/aloe messages`, serialized output, and exit-code design
- LSP, JSON-RPC, VS Code, Emacs, UTF-16 conversion, completion, and hover
- Incomplete or unclosed-buffer recovery, incremental parsing, and
  well-formed-prefix queries
- Selector holes or completion after a receiver
- Querying an unsaved source string or a caller-supplied syntax tree
- Host injection or application-specific prelude configuration
- Evaluating the file, reflecting runtime values, or invoking signatures
- Location-bearing diagnostic redesign or checking past the first error
- New syntax, special forms, macros, inheritance, mutation, coercion, or
  changes to send and overload semantics
- A second type/signature catalog or direct `class-info-methods` traversal

When the implementation satisfies this specification, stop. A later local
checkpoint-manager conversation decides the slices. An LSP adapter consumes
the finished Racket query; it does not change this project's semantics.
