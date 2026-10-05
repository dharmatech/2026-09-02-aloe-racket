# Charter — labeled construction

**Status.** Handoff from the high-level discussion into a **design
conversation**. Not a checkpoint. Not an implementer assignment.
Specification will live beside this file as `spec.md`.
Checkpoints will live in `checkpoints/`. Process:
[`docs/workflow.md`](../../../workflow.md). Project root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Branch:
`experiment/2026-10-05-labeled-construction`.

**Your job.** Write the specification for **labeled-construction**:
a constructor call may name every payload field, in any order, as
`field: value`. Positional construction stays. Then **stop**. Do
not write checkpoints. Do not implement.

This effort refuses defaulted fields, a mixed positional and
labeled call, labels on methods, a copying `with`, self-quoting
keyword values, a `make` selector, `case` labels, labels on
`List` / host messages, editor completion of field names, and
relabeling the positional rebuilds in `file.aloe` and
`editor.aloe`. Those stay out so this spec stays small enough
to slice.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §5.
2. Record the locked decisions in §4. There is no open question.
3. Write `spec.md` in this folder. State the series facts in §7
   in the spec's own words. A later checkpoint-manager
   conversation slices **labeled-construction 000**, …
   under `checkpoints/` (not `docs/checkpoints/` unless a human
   promotes the series after review).
4. Stop. The human reviews the spec. Do not write those
   checkpoint files.

Keep the spec to the three layers in §7. A default, a keyword
value, a method label, or a rewrite of `file.aloe` is a defect
in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| `SPEC.md` §2, §3.1, §3.2, §7.2, §8 | A send evaluates the receiver and the arguments. The selector is a source symbol and is not evaluated. A `(fields ...)` class has one constructor, `new`. An explicit constructor binds its own ordered payload. A source symbol in expression position is an environment lookup. `Symbol` has no reader literal. Labeled `make` is out of scope |
| `SPEC.md` §5.3 and §9 | Bare `(Option None)` does not determine its type parameter. The `if` witness is the accepted way to write an empty option. Golden `(Point new 1 2)` must keep running |
| [`docs/checkpoints/0083a-host-implementation-call-shape.md`](../../../checkpoints/0083a-host-implementation-call-shape.md) | The host boundary rejects Racket keyword arguments, required or optional |
| [`examples/aloemacs/main.aloe`](../../../../examples/aloemacs/main.aloe) | `aloemacs-editor` is one positional `AloemacsSession new` with nested positional constructors. This is the call the closing slice relabels |
| [`docs/decisions.md`](../../../decisions.md) | Square brackets were left as ordinary reader delimiters. This series does not give them a meaning |

The current Aloemacs classes are the evidence, not a predecessor
that must change first. `AloemacsSession` has fourteen fields.
`AloemacsEditor` has eight. `AloemacsPrompt` has seven. Their
positional rebuilds in `examples/aloemacs/file.aloe` and
`examples/aloemacs/editor.aloe` stay positional.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. Both spellings build the same constructor. `(Point new 1 2)`
   and `(Point new x: 1 y: 2)` are the same call shape at
   runtime: one payload, declaration order, no second selector.
2. A labeled call may name the fields in any order. The value
   expressions run in the order written. The stored payload is
   declaration order.
3. A labeled call that omits a field, repeats a field, names an
   unknown field, or contains a bare value is an error. A
   missing name is reported in declaration order. That error is
   not an arity error. A positional call with the wrong count
   is still an arity error.
4. `buffers:` is one token. It is not a value, not a variable,
   and not a `Symbol`. The same token outside a constructor
   label slot is a syntax error. A label with no value
   expression is a syntax error. `buffers :` with a space is
   not a label.
5. Labels on a method send, on `(List of ...)`, on
   `(List empty)`, on a host message, and on any other
   non-constructor are errors. Generic inference is unchanged.
   Bare `(Option None)` stays illegal. The host boundary still
   rejects Racket keyword arguments.
6. `SPEC.md` §3.2 describes the labeled spelling, and §8 no
   longer lists labeled `make` as out of scope. §9 still
   accepts `(Point new 1 2)`.
7. The closing slice rewrites only the `aloemacs-editor`
   definition in `examples/aloemacs/main.aloe`, with the same
   values it has now. Tests live under `tests/labeled-construction/`.

## 4. Locked decisions (record these; do not reopen)

### 4.1 Two spellings, one constructor

A call is positional or labeled. The programmer chooses per
call. The class does not declare a spelling.

Positional construction is unchanged. Arguments bind in
declaration order. The wrong count is an arity error.

A call is labeled when any argument is a label token. It then
names each field of **that constructor's** payload exactly
once. Order is free. The name binds the value. An explicit
constructor uses its own fields, not the union of every
constructor on the class. `(AloemacsCommand FindFile)` has an
empty payload, so a label on it is an unknown field.
`(Option Some value: x)` is legal, and `(Option Some x)` stays
legal.

These are not two overloads of `new`. After checking, the
evaluator passes a positional payload. Labels are gone before
the instance is built.

### 4.2 The label is grammar

The reader already yields `buffers:` as one symbol. The colon
is the spelling of a label. The field's name remains
`buffers`, in `(fields (buffers ...))` and in `(self buffers)`.

A trailing-colon token is legal only as a label immediately
followed by one value expression, inside a send's argument
list. The parser records that pair on the send. It does not
need to know whether the selector is a constructor.

Everywhere else a trailing-colon token is a syntax error,
including expression position, selector position, a receiver,
a field name, a method name, a `define` name, and a `let` or
`fn` parameter. A label that is not followed by a value is a
syntax error.

A leading colon, as in the archive token `:position`, is a
different symbol. It stays an environment lookup. This series
does not reserve it.

The checker accepts recorded labels only when the receiver's
type is a class and the selector is one of that class's
constructors. `new` is that selector for a `(fields ...)`
class. Named constructors such as `Some`, `Leaf`, and
`FindFile` use the same rule. Any other send that carries a
label is an error.

### 4.3 Checking and evaluation

Match labels by name, then check each value against that
field's type the way a positional argument is checked today,
including expected types and generic inference. Do not make
bare `(Option None)` legal. Do not change `(if test then else)`.

Evaluate the receiver. Do not evaluate the selector. Do not
evaluate the labels. Evaluate the value expressions in source
order, including when that order differs from field order.
Store the payload in declaration order. Two labeled calls that
supply the same values in different orders build the same
instance.

Report missing fields in declaration order. Report a repeated
name. Report an unknown name. Report a bare value inside a
labeled call. Keep positional arity errors on positional calls.

### 4.4 What stays a value

`(List of ...)`, `(List empty)`, `(Symbol intern ...)`,
`(Text from-string ...)`, ordinary methods, protocol sends,
numeric sends, and host messages do not take labels. `case`
binders stay positional. `Mirror` and `Signature` do not gain
a label query. Labels are not selectors and do not appear in
`(mirror messages)`.

Do not implement labels as Racket keyword arguments. Checkpoint
83a still rejects required and optional keyword call shapes at
the host boundary.

### 4.5 The closing edit

One product edit, after the language slice is real. In
[`examples/aloemacs/main.aloe`](../../../../examples/aloemacs/main.aloe),
rewrite the `aloemacs-editor` definition so these constructions
are labeled, with the values they already have:

| Constructor | Labels |
|---|---|
| `AloemacsSession new` | `buffers` `fs` `echo` `searching` `query` `origin` `wrapped` `failing` `kill-ring` `pending` `prompt` `last-submission` `waiting-command` `windows` |
| `AloemacsBuffers new` | `before` `current-buffer` `after` |
| `AloemacsBuffer new` | `editor` `path` `id` |
| `AloemacsEditor new` | `text` `point` `quit` `scroll-row` `scroll-col` `history` `mark` `text-rows` |
| `AloemacsPrompt new` | `label` `text` `column` `completion-note` `completion-lines` `completion-matches` `completion-start` |
| `AloemacsWindows new` | `tree` `selected` `columns` `rows` |

Leave these spellings as they are, inside that same definition:
`(Text from-string ...)`, `(Position new ...)`,
`(Option None)`, `(Option Some ...)`, `(Path new ...)`,
`(Fs new ...)`, `(List empty)`, `(AloemacsCommand FindFile)`,
`(AloemacsWindowTree Leaf ...)`, and `(AloemacsView new ...)`.
The `if` witnesses around `(Option None)` stay.

Do not edit `examples/aloemacs/file.aloe` or
`examples/aloemacs/editor.aloe`. Do not relabel any other call
site in the repository as part of this series.

### 4.6 Documents the spec amends

Amend `SPEC.md` §3.2 so a constructor argument list may be
positional or fully labeled. Delete the sentence that labeled
construction (`make`) is out of scope. Remove `labeled make`
from §8. Do not add a `make` selector. Keep §9's positional
`Point` goldens, and add a labeled golden beside them.

Add one dated entry to `docs/decisions.md`: constructor labels
are grammar, the colon token is not a value, square brackets
were not used, and defaults, mixed calls, method labels, and
`make` were rejected.

The spec writes the exact sentences. The decisions above are
the content. Tests pin the wording the spec chooses for each
error class: syntax, missing field, unknown field, duplicate
field, mixed call, positional arity, and label on a
non-constructor.

### 4.7 Where code may live

- `aloe/parse.rkt`, `aloe/type.rkt`, and `aloe/eval.rkt`, in
  the existing send and construction paths
- `SPEC.md` §3.2, §8, and §9
- `docs/decisions.md`, the one entry in §4.6
- `tests/labeled-construction/`
- `examples/aloemacs/main.aloe`, and only the definition in §4.5,
  and only in the closing slice

The language server reads the same parser. Existing programs
must still parse and check. This series adds no completion
query and no new editor feature.

Not in this series: `CHECKPOINTS.md`, `docs/checkpoints/`,
`examples/aloemacs/file.aloe`, `examples/aloemacs/editor.aloe`,
Gel, the host keyword check, and `aloe/lsp.rkt` beyond what the
shared parser requires.

## 5. Authority

- `SPEC.md` §2, §3.1, §3.2, §5.3, §7.2, §8, and §9. This spec
  amends §3.2, §8, and §9 only as §4.6 allows. Where this
  charter and `SPEC.md` disagree about labeled construction,
  the charter wins and the spec records the amendment. For
  every other rule, `SPEC.md` wins.
- [`docs/philosophy.md`](../../../philosophy.md). Syntax is
  added from a program that cannot be read, and the addition
  stays the label slot. It does not become a keyword type.
- [`docs/decisions.md`](../../../decisions.md). The `if` entry
  left `[]` without a special meaning. This series does not
  add one.
- [`docs/checkpoints/0083a-host-implementation-call-shape.md`](../../../checkpoints/0083a-host-implementation-call-shape.md).
  Host methods stay positional Racket calls.
- [`examples/aloemacs/main.aloe`](../../../../examples/aloemacs/main.aloe)
  is the source of the values the closing slice must preserve.
- [`docs/workflow.md`](../../../workflow.md) is the process, not
  language law.

## 6. Non-goals

- A default value for an omitted label
- A bare value and a label in the same call
- Labels on methods, `List`, host messages, or `case`
- `(self with prompt: ...)` or any copy-and-replace form
- A `make` selector, or any second constructor selector
- Self-quoting keywords, a `Symbol` reader literal, or computed
  field names
- Square-bracket pairs
- Making bare `(Option None)` typecheck
- Editor completion or highlighting of labels
- Relabeling `file.aloe`, `editor.aloe`, or any call site other
  than §4.5
- Promoting the series onto `CHECKPOINTS.md` inside the spec

## 7. Handoff

Series identity: `labeled-construction`. Checkpoint 000 is spoken
**labeled-construction 000** and filed as
`checkpoints/000-slug.md`. Numbers are three digits, start at
000, and are never renumbered. The checkpoint manager writes one
checkpoint, then stops. Project root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Code and tests
go there, not in this design folder. Local numbering. Work stays
on `experiment/2026-10-05-labeled-construction`.

Intended layer order:

1. **Grammar.** The trailing-colon token and the parse errors in
   §4.2. Positional programs still parse. The AST can record a
   labeled argument on a send.
2. **Law.** The checking and evaluation rules in §4.1–§4.4, the
   `SPEC.md` and `docs/decisions.md` edits in §4.6, and tests for
   both spellings, order, generics, and each error class.
3. **The session definition.** The one edit in §4.5.

The spec may merge layer 1 into layer 2 when a grammar-only
checkpoint would be too thin to test on its own. It keeps this
order otherwise. It does not merge layer 3 into the language
slice. It adds no fourth layer and no feature from §6. A manager
may split a layer that misses checkpoint size, keeps this order,
and adds no features.

If you have been told to read this file, this is the whole assignment.
