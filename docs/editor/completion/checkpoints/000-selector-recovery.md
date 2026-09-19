# Editor completion 000 — Selector-site recovery

**Status.** Implemented and reviewed. The focused 173-test suite, the required
source-location and expression-selection predecessor suites, and the exact hand
check are green. The recursive suite passes 2,171 of 2,173 tests; its only
failures are the two documented pre-existing
`tests/gel/presentations/003-doc-law.rkt` contradictions. This checkpoint
introduces no additional failure.

## Goal

Add the private, parser-only operation that recovers one ordinary Aloe send at
a cursor in its literal selector position. The operation inserts a private
marker, tries the existing reader and parser with zero through 64 EOF-closing
right parentheses, and maps the accepted temporary selector location back to
the exact selector token or empty hole in the original buffer.

This checkpoint proves syntactic eligibility and replacement ranges only. It
does not type the receiver, inspect a signature catalog, filter or format
completion items, add the public `query-selector-completions` operation, or
change the LSP adapter.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law. A non-special list is a send whose head
  is the receiver and whose second element is a literal selector. `(f x)` does
  not call `f`.
- `docs/editor/completion/spec.md` is the local design authority. Sections
  1–3 define buffer positions, eligible selector sites, marker insertion,
  bounded EOF closing, and original-source replacement mapping. Sections 4–8
  describe later checkpoints and are not implemented here.
- Editor-source-locations 000 is implemented. `read-program` produces exact
  Racket `srcloc` values, and an ordinary `send-expr` carries the literal
  selector's `selector-loc`. Parser-introduced sends have `selector-loc` equal
  to `#f`.
- Editor-expression-query 000 is implemented, but its expression ownership
  query is not selector recovery. This checkpoint may follow its established
  expression-tree traversal conventions; it must not change that predecessor.
- Editor-expression-query 001–003, editor-signatures-of-type 000–002, and
  editor-lsp 000–009 are implemented and reviewed. This slice calls none of
  their checker, catalog, public-query, snapshot, or protocol operations.

Identity is `(editor-completion, 000)`, spoken **editor-completion 000**. This
is a local editor checkpoint, not a global Aloe checkpoint and not an
extension of the completed expression-query or LSP checkpoint numbering. Do
not edit `CHECKPOINTS.md` or add a file under `docs/checkpoints/`.

## Private result and operation

Add `aloe/private/completion-selection.rkt` with exactly these exports:

```racket
(struct selector-completion-site
  (expressions target-send selector-text replacement-start replacement-span)
  #:transparent)

(recover-selector-completion-site source position
                                  #:source-path [source-path #f])
  ; source      : string?
  ; position    : exact-positive-integer?
  ; source-path : (or/c path-string? #f)
  ; -> (or/c selector-completion-site? #f)
```

The result fields are private substrate for later completion checkpoints:

- `expressions` is the exact parsed expression forest from the accepted
  marker-bearing candidate;
- `target-send` is the exact ordinary `send-expr` object in that forest whose
  literal `selector-loc` contains the inserted marker;
- `selector-text` is the complete original source token with the marker
  removed, or `""` for an empty selector hole;
- `replacement-start` is the one-based Racket character position of that
  original token or empty hole; and
- `replacement-span` is its original Racket character length.

`target-send` identity matters. A later checkpoint will observe
`(send-expr-receiver target-send)` in the same forest during one contextual
checker traversal. Do not copy or reconstruct either node.

The parsed forest necessarily retains the private marker in the target
send's temporary selector. It is internal checker input, not editor data. The
marker must not appear in `selector-text`, either replacement field, a source
file, output, or an exception message.

This is an internal operation. The stated argument kinds are caller
preconditions in 000; do not add the public argument-error contract belonging
to `query-selector-completions`. A positive position outside the buffer's
boundary range, a failed recovery, or an ineligible site returns `#f`. Valid
boundaries are exactly 1 through
`(add1 (string-length source))`.

Pass `source-path` unchanged to `read-program` as `#:source-path`. Do not
normalize it, require that it exist, open it, or make a sibling snapshot. The
source string remains authoritative. A later checkpoint owns public path
normalization and the rule that `load` without a source path has no result.

Do not export this structure or operation from `aloe/main.rkt`,
`aloe/driver.rkt`, `aloe/expression-query.rkt`, or another public module.

## The only recovery algorithm

For every in-range query, complete or incomplete, perform this exact bounded
operation:

1. Choose an ASCII identifier fragment that does not occur anywhere in
   `source`. A simple permitted sequence is `aloecompletioncursor`, then that
   base followed by `0`, `1`, and so on until the whole candidate fragment is
   absent. The fragment contains no whitespace, delimiter, quote, escape, or
   reader-prefix character.
2. Insert the fragment at the one-based cursor boundary without deleting or
   replacing source text.
3. Form 65 independent candidates. Each is the marker-bearing source followed
   by one LF and then exactly `k` right parentheses, for `k` from 0 through
   64 in increasing order.
4. Pass each candidate to the existing syntax-aware `read-program`, with the
   supplied `source-path`. A reader or Aloe parser failure rejects only that
   candidate and advances to the next close count.
5. Accept the first candidate that both reads and parses as a complete program
   and has exactly one ordinary `send-expr` whose non-`#f` `selector-loc`
   contains the entire inserted marker.
6. Map and validate that selector against the original source as specified
   below. A candidate whose mapping is ambiguous or invalid is not accepted.
   If no candidate qualifies, return `#f`.

The final LF is always present, including when the source already ends in LF.
The appended parentheses occur after it so an end-of-line comment cannot
swallow them. The zero-close candidate is attempted first even for a complete
buffer. Never append more than 64 parentheses.

Do not scan for balanced delimiters, parse only a prefix, delete trailing
text, substitute a selector, close with `]` or `}`, repair a string or quote,
or fabricate an AST. Text after the cursor remains character-for-character in
each candidate before the final LF and closes. Do not call `parse-datum` or
`parse-program` on reader datums; `read-program` is the one Aloe reader/parser
path.

Recovery must be silent. Expected reader and parser failures do not write to
the current output or error port and do not escape as editor-facing
exceptions. Do not catch breaks or termination, and do not evaluate or
typecheck a candidate.

## Finding the one ordinary selector

Search the accepted parsed expression forest in root source order. Traverse
only expression-valued fields, using the same edges as the completed
expression-selection substrate:

- atoms, `load-expr`, and `define-protocol-expr` are leaves;
- `check-expr` visits left then right;
- `define-expr` visits its value;
- `define-class-expr` and `define-methods-expr` visit method bodies in
  declaration order;
- `fn-expr` visits its body;
- `case-expr` visits its scrutinee, named-clause bodies in order, then an
  optional `else` body; and
- `send-expr` visits itself, then its receiver, then its arguments in source
  order.

An ordinary target must be a `send-expr` with a non-`#f` selector location.
For selector location start `s`, span `n`, cursor position `p`, and marker
length `m`, the location contains the entire marker exactly when:

```text
s <= p
p + m <= s + n
```

Collect by that source-location condition, not by searching a printed AST or
comparing the temporary selector symbol's name. There must be exactly one
such send. Zero or multiple matches reject the candidate.

Never treat declarations, binders, types, case constructor names, method
selectors, or a synthetic selector as expression children or selector sites.
A parser-introduced `let`, `if`, or `cond` send has no literal selector
location and is therefore ineligible at its synthetic selector. A real send
inside its receiver, argument, or body remains eligible normally.

This slice identifies syntax only. An unbound receiver is still a valid
syntactic site. Conversely, an expression that happens to have a useful type
is not eligible unless the cursor is in the literal selector position of an
ordinary parsed send.

## Exact original-source mapping

Map only from the accepted target's `selector-loc`; do not scan left or right
from the cursor looking for token characters.

Let the temporary selector start and span be `s` and `n`, and let marker
length be `m`. Require all of the following:

1. The marker range is fully contained as above and `n >= m`.
2. Removing exactly the inserted marker range from the temporary selector's
   source slice produces a range starting at `s` with span `n - m` in the
   original source.
3. That range is within the original source, and the original cursor boundary
   lies on it, including either boundary:

   ```text
   s <= p <= s + (n - m)
   ```

4. The original substring at that range is character-for-character equal to the
   temporary selector token after removing the marker.
5. If the mapped span is zero, require `s = p` and require that the temporary
   selector consists only of the inserted marker. Return `selector-text` as
   `""`, `replacement-start` as `p`, and `replacement-span` as 0.
6. If the mapped span is nonzero, require the complete mapped substring to
   read as exactly one Racket symbol followed by EOF. Return that original
   substring unchanged as `selector-text`, `s` as `replacement-start`, and
   `n - m` as `replacement-span`.

The single-symbol check uses Racket's reader only to validate the exact slice;
it is not a second Aloe parser and must not widen or rediscover the range. A
nonempty mapped token that is not exactly one symbol rejects the candidate.

All cursor boundaries within one existing selector token therefore produce
the same original replacement range. For the source shown with a non-source
bar:

```text
(receiver di|st argument)
```

the bar is one-based boundary 13. The site has selector text `"dist"`,
replacement start 11, and replacement span 4. Boundaries 11, before `d`, and
15, after `t`, produce the same three editor fields.

For:

```text
(receiver |)
```

the bar is boundary 11 in the original source `(receiver )`. The site has
selector text `""`, replacement start 11, and replacement span 0. The same
result is required for the incomplete end-of-buffer source `(receiver ` with
the cursor at boundary 11 after EOF closing succeeds.

## Eligibility consequences

The parser and mapping rules must produce these results without a separate
editor grammar:

- A complete selector, a partial selector, either boundary of a selector
  token, and an interior selector boundary are eligible.
- A selector followed by arguments is eligible and replaces only the complete
  selector token.
- Whitespace after a complete receiver and before the closing delimiter or
  end of buffer is an empty selector hole.
- A nested send's selector is eligible, including inside a method, function,
  `let`, or `case` body.
- `(f x)` is an ordinary send whose eligible selector is `x`; this operation
  does not reinterpret it as a function call.
- `(Point |)` is an eligible selector hole on the class-object receiver. It is
  not top-level class-name completion.

These positions are ineligible and return `#f`:

- before or inside the receiver rather than its selector;
- in an argument or in whitespace after a completed selector;
- after a finished expression, between top-level expressions, in a blank
  buffer, or in a top-level name;
- in a string or comment;
- the keyword, binder, annotation, or operand positions of `define`,
  `define-class`, `define-methods`, `load`, `fn`, `let`, `if`, `cond`, `case`,
  or `check`;
- a parser-synthetic selector whose `selector-loc` is `#f`;
- a source with an unfinished string, unrelated malformed declaration,
  mismatched bracket, or extra closing delimiter that EOF right-parenthesis
  appending cannot repair; and
- a source requiring 65 or more appended right parentheses.

Do not decide whether a token is an exact catalog selector or a prefix in
this checkpoint. Both are syntactically recovered as `selector-text`; stable
catalog filtering belongs to a later slice.

## Exact file scope

Implementation may add only:

- `aloe/private/completion-selection.rkt`; and
- `tests/editor/completion/000-selector-recovery.rkt`.

Do not edit:

- `aloe/parse.rkt`, `aloe/type.rkt`, `aloe/expression-query.rkt`,
  `aloe/lsp.rkt`, `aloe/main.rkt`, `aloe/driver.rkt`, or the evaluator;
- `aloe/private/expression-selection.rkt`, the signature catalog, or another
  predecessor project's production or test files;
- `SPEC.md`, `CHECKPOINTS.md`, anything under `docs/checkpoints/`, or the
  completion specification, charter, README, or checkpoint documents; or
- `gel/`, `lib/`, `host/`, `examples/`, or another editor project.

If exact recovery requires a parser change, another reader, a delimiter
scanner, a new source-location representation, or checker knowledge, stop and
return the checkpoint for design review.

## Required tests

Add `tests/editor/completion/000-selector-recovery.rkt`. It is three
directories below the repository root, so use `../../../aloe/...` in module
paths. Prefer a small test helper that accepts source containing exactly one
display-only `|`, removes it, and derives the documented one-based cursor
boundary. The operation itself never accepts or sees that bar.

Test exact structure fields and AST identity, not merely truthiness. For every
successful site, prove that `target-send` is `eq?` to the matching send in
`expressions`, and that its receiver is the exact receiver node in that send.
Cover at least:

1. `(receiver di|st argument)` yields `"dist"`, start 11, span 4. Repeat at
   the token's start and end boundaries and require the identical range.
2. A partial selector at end of buffer maps the entire partial token. An empty
   unclosed `(receiver |` recovers with one appended close and yields the
   zero-width cursor range.
3. A complete nested Point-shaped send such as
   `((Point new 1.0 2.0) di|st other)` targets the outer send, retains the
   exact inner send as its receiver, and excludes the argument from the edit.
4. A selector site nested in a class method body and one nested in parser
   sugar are found through the complete expression traversal. Positions on
   the synthetic `call`/conditional sends themselves remain ineligible.
5. `(f |x)` proves ordinary-send syntax, and `(Point |)` proves the
   class-object selector hole, without calling, constructing, checking, or
   evaluating either receiver.
6. Cursor positions before/in a receiver, in each argument, after a finished
   form, in a top-level gap, in a blank file, in comments, and in strings all
   return `#f`.
7. Representative keyword and operand positions for every special-form family
   listed above return `#f`. Include `let`, `if`, and `cond` to pin the
   `selector-loc = #f` synthetic-send exclusion.
8. A malformed string, mismatched `[`/`)`, unrelated malformed form after the
   cursor, and an extra closing delimiter return `#f`; the implementation does
   not discard the suffix to obtain a result.
9. Programmatically build nested, otherwise-valid incomplete sends that need
   exactly 64 appended right parentheses and require success. The same shape
   needing 65 closes returns `#f`. Do not weaken this to a vague large-input
   test.
10. Include the implementation's initial marker candidate and several
    marker-looking symbols elsewhere in the source, then recover an unrelated
    selector site correctly. This proves collision avoidance rather than
    assuming a magic fragment is absent.
11. The first positive boundary beyond `(add1 (string-length source))`
    returns `#f` promptly. Wrong-kind argument behavior remains deferred to
    the public query checkpoint.
12. Supply a non-existent `#:source-path` and prove it is retained as the
    reader source name while no file is created or opened. A `load` form may
    parse as a leaf, but this checkpoint does not resolve it.
13. Parameterize output and error ports around expected recovery failures and
    prove they remain empty. Returned selector text and replacement data never
    contain the chosen marker or appended recovery text.

Tests must not import `aloe/type.rkt`, `aloe/signature-catalog.rkt`,
`aloe/expression-query.rkt`, or `aloe/lsp.rkt`. They must not create a type
environment, invoke a host, or inspect a completion row. No Point or Boids
catalog expectation belongs in 000.

## Hand check and acceptance

After the automated tests, run this from a Racket REPL at the repository root:

```racket
(require "aloe/parse.rkt"
         "aloe/private/completion-selection.rkt")

(define site
  (recover-selector-completion-site
   "(receiver dist argument)"
   13))

(list (selector-completion-site-selector-text site)
      (selector-completion-site-replacement-start site)
      (selector-completion-site-replacement-span site)
      (variable-expr-name
       (send-expr-receiver
        (selector-completion-site-target-send site))))
```

The exact result is:

```racket
'("dist" 11 4 receiver)
```

Then run:

```sh
raco test tests/editor/completion/000-selector-recovery.rkt
raco test tests/editor/source-locations/000-spans.rkt
raco test tests/editor/expression-query/000-selection.rkt
raco test tests
git diff --check
```

The pre-checkpoint recursive baseline passes 1,998 of 2,000 tests. Its only
failures are the two pre-existing wording/shape contradictions in
`tests/gel/presentations/003-doc-law.rkt`. Do not edit or weaken those tests or
their documentation. Require every focused suite to be completely green and
the recursive suite to retain exactly those two failures with no new failure.
If that baseline contradiction has been repaired before implementation,
require a completely green recursive suite.

The checkpoint is complete when the private operation recovers only ordinary
literal selector sites, maps every accepted site to the exact original token
or empty range, obeys the 0–64 bound, remains silent on rejected buffers, the
hand check succeeds, and all required tests meet the baseline above. Stop for
review without committing. Do not begin contextual receiver typing, the
public query, filtering, item formatting, LSP completion, or VS Code checks.

## Explicit non-goals

- No checker observation, receiver type, lexical environment, or early exit
- No `type-signature-specs`, signature rows, prefix filtering, ordering, or
  completion-item formatting
- No public `aloe/completion-query.rkt`, argument-error surface, path
  normalization, List/String bootstrap, or load checking
- No Point or Boids typed acceptance rows
- No LSP capability, completion request, UTF-16 conversion, document lookup,
  edit range, framing, lifecycle, or failure-policy change
- No VS Code extension or manifest change
- No evaluation, runtime `Mirror`, host injection, host implementation call,
  or source-file mutation
- No second Aloe parser, incremental parser, token scanner, delimiter
  balancer, broad error repair, or fabricated catalog
- No top-level name, class-name, special-form, argument, blank-file, snippet,
  signature-help, or wrap-the-preceding-expression completion
