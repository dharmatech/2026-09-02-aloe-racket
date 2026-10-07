# Charter — parenthetical construction

**Status.** Handoff from the high-level discussion into a
**design conversation**. Not a checkpoint. Not an implementer
assignment. A colon spelling, `(Point new* x: 10 y: 20)`, was
explored on `experiment/2026-10-05-labeled-construction`. That
spelling is not this series and is not authority here.
Specification will live beside this file as `spec.md`.
Checkpoints will live in `checkpoints/`. Process:
[`docs/workflow.md`](../../../workflow.md). Project root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Branch:
`experiment/2026-10-06-parenthetical-construction`, cut from
`main` at `987cbd0`.

**Your job.** Write the specification for
**parenthetical-construction**. A `(fields ...)` class is still
built with one constructor. The positional spelling stays
`(Point new 10 20)`. The labeled spelling is a form in the
selector position whose tail is a binding list:

```aloe
(Point new* (x 10) (y 20))
```

Then **stop**. Do not write checkpoints. Do not implement.

This effort refuses defaulted fields, a mixed positional and
labeled call, labels on methods, labels on explicit
constructors, a copying `with`, self-quoting keyword values, a
`make` selector, a dictionary, square-bracket syntax, a macro
system, trailing-colon labels, editor completion of field
names, and relabeling the positional rebuilds in `file.aloe`
and `editor.aloe`. Those stay out so this spec stays small
enough to slice.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §5.
2. Record the locked decisions in §4. Those language choices
   are closed. The spec writes the sentences in `SPEC.md`. It
   does not add an error class or change a spelling.
3. Write `spec.md` in this folder. State the series facts in §7
   in the spec's own words. A later checkpoint-manager
   conversation slices **parenthetical-construction 000**, …
   under `checkpoints/` (not `docs/checkpoints/` unless a human
   promotes the series after review).
4. Stop. The human reviews the spec. Do not write those
   checkpoint files.

Keep the spec to the three layers in §7. A default, a keyword
value, a method label, a colon label, or a rewrite of
`file.aloe` is a defect in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| `SPEC.md` §2, §3.1, §3.2, §4.3, §4.10, §7.2, §8 | A send evaluates the receiver and the arguments. The selector is a source symbol and is not evaluated. A `(fields ...)` class has one constructor, `new`. `let` is `((name expr) ...)` and desugars to `fn` plus `call`. `case` in the second position is syntax, not a send. A source symbol in expression position is an environment lookup. `Symbol` has no reader literal. Labeled `make` is out of scope |
| `SPEC.md` §5.3 and §9 | Bare `(Option None)` does not determine its type parameter. The `if` witness is the accepted way to write an empty option. Golden `(Point new 1 2)` must keep running |
| [`docs/checkpoints/0083a-host-implementation-call-shape.md`](../../../checkpoints/0083a-host-implementation-call-shape.md) | The host boundary rejects Racket keyword arguments, required or optional |
| [`examples/aloemacs/main.aloe`](../../../../examples/aloemacs/main.aloe) | `aloemacs-editor` is one positional `AloemacsSession new` with nested positional constructors. This is the call the closing slice rewrites |
| [`archive/design-sketches/2026-10-06-aloemacs-labels/003-parens-let-aligned-let.aloe`](../../../../archive/design-sketches/2026-10-06-aloemacs-labels/003-parens-let-aligned-let.aloe) | The closing edit follows this sketch's two `let`s and flat session table, with the positional exceptions in §4.5. The prose sentence and the markdown fence in that file are not part of the program |
| [`docs/decisions.md`](../../../decisions.md) | Square brackets were left for later, without a special meaning. This series does not give them one |

The current Aloemacs classes are the evidence, not a predecessor
that must change first. `AloemacsSession` has fourteen fields.
`AloemacsEditor` has eight. `AloemacsPrompt` has seven. Their
positional rebuilds in `examples/aloemacs/file.aloe` and
`examples/aloemacs/editor.aloe` stay positional.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. Both spellings build the one `new` constructor of a
   `(fields ...)` class. `(Point new 10 20)` and
   `(Point new* (x 10) (y 20))` produce the same payload in
   declaration order. `new*` is not a second constructor and
   does not appear in `(mirror messages)`.
2. A labeled call may name the fields in any order. The value
   expressions run in the order written. They are not rearranged
   into field order before they run. Checking walks the fields
   in declaration order. The swapped call is accepted exactly
   when the unswapped call is. The values are then stored in
   declaration order.
3. A labeled call that omits a field, repeats a field, or names
   an unknown field is an error, in the classes and the order
   in §4.3. A missing name is reported in declaration order.
   That error is not an arity error. A positional call with the
   wrong count is still an arity error. A tail element that is
   not a binding pair is a syntax error.
4. The car of a binding pair is the field's source name, written
   as an ordinary symbol. It is not evaluated. A field whose
   name is `x:` is labeled `(x: expr)`. This series adds no
   second spelling for that name. Outside the pair, and in the
   cadr, a symbol is an ordinary expression.
   `(Point new (x 10) (y 20))` is a positional send, not a
   labeled call.
5. `new*` on anything other than the `new` constructor of a
   `(fields ...)` class is an error. Explicit constructors stay
   positional. Generic inference is unchanged. Bare
   `(Option None)` stays illegal. The host boundary still
   rejects Racket keyword arguments.
6. `SPEC.md` describes `new*` as syntax in the selector
   position, and §8 no longer lists labeled `make` as out of
   scope. The identifier rules gain no exception. §9 still
   accepts `(Point new 1 2)` and gains a labeled golden beside
   it.
7. The closing slice rewrites only the `aloemacs-editor`
   definition in `examples/aloemacs/main.aloe`, with the same
   values it has now, in the shape §4.5 names. In that same
   slice it may replace `expected-main-datums` in
   `tests/aloemacs/runner.rkt` with the datum `read` produces
   from that definition. The rest of that file stays. Series
   tests live under `tests/parenthetical-construction/`.

## 4. Locked decisions (record these; do not reopen)

### 4.1 Two spellings, one constructor

A `(fields ...)` class has one constructor. The programmer
chooses the spelling per call. The class does not declare a
spelling.

Positional construction is unchanged. `(Point new 10 20)` is
still a send. Arguments bind in declaration order. The wrong
count is an arity error.

```aloe
(Point new* (x 10) (y 20))
```

`new*` is syntax in the second position, the seat `case`
already occupies. The list is not a send. `new*` is not a
method, not a message, and not a second constructor. It does
not appear in `(mirror messages)`. A class does not gain a
method named `new*`. `new*` is reserved only in that selector
seat, the way `case` is. A source name `new*` in any other
position stays an ordinary name.

The tail is a list of binding pairs. Each pair is `(name expr)`.
`name` is a literal symbol, the field's declared source name.
It is not evaluated, not a variable, and not a binding in the
value expressions. `expr` is an ordinary expression, checked
and evaluated in the surrounding environment. A send written in
that expression is still a send. Only the immediate elements of
the tail are pairs. A nested list inside `expr` is not a label.

The pairs may be written in any order. Each value expression
runs in the order written, and the value it produces is stored
in declaration order. The designer chooses how the
implementation remembers which expression belongs to which
field until that expression has run. Rearranging the
expressions into field order and then running them is not this
rule.

The receiver is still evaluated. A computed receiver is legal
when the receiver expression typechecks under the rules that
already exist. `((if test Point also-point) new* (x 1) (y 2))`
is legal when `also-point` names the same class as `Point`.
`(if test Point Other)` is not made legal by this series when
`Point` and `Other` are different classes. A later macro may
only be able to expand a class name. This series does not
narrow the kernel form to a class name. That limit belongs to
the macro, not to this form.

`new*` applies only to the `new` constructor of a
`(fields ...)` class. Explicit constructors stay positional.
`(Option Some x)`, `(AloemacsCommand FindFile)`, and
`(AloemacsWindowTree Leaf ...)` do not gain a star and do not
take pairs as labels. `(List of ...)`, `(List empty)`, and
`(List new*)` are not this form.

The spelling `(Point new (x 10) (y 20))` is not labeled
construction. It is a positional send of whatever those
expressions evaluate to. The colon spelling
`(Point new* x: 10 y: 20)` is not labeled construction in this
series.

### 4.2 The pair is the whole label notation

There is no label token distinct from the field name. The reader
does not change. Identifier rules do not change. A trailing
colon remains an ordinary character in a source name, including
inside a pair and outside this form. `(define x: 123)` stays
legal. This series does not reserve the colon, and it does not
test a colon spelling of `new*`.

A well-formed tail element is a list of exactly two elements
whose first element is a symbol. Anything else in the tail is a
syntax error: a bare value, a one-element list, a longer list,
a non-list, or a first element that is not a symbol. The car is
not computed. An empty tail is well-formed syntax:
`(Empty new*)`. Its validity depends on the class, under §4.3.

Square brackets receive no meaning from this series. The
goldens and the closing edit use parentheses. The series does
not require the parser to preserve delimiter shape.

### 4.3 Checking and evaluation

Parse the tail before using the receiver. A malformed tail
element is a syntax error. Name checks and type checks do not
run for that call.

Otherwise check the receiver with the existing rules. If that
check fails, the failure is the existing one. If the receiver
is not the `new` constructor of a `(fields ...)` class, the
error is ineligible `new*`. `(List new*)` is this error when
`List` is not such a class. An empty `(fields)` class accepts
`(Empty new*)`.

If the receiver is eligible, walk the pairs in written order.
The first pair whose name is not a field of that constructor is
an unknown-field error. The first pair whose name repeats an
earlier pair is a duplicate-field error. Whichever of those two
pairs occurs first is the error reported. Do not report both.
`(Point new* (z 1) (x 1) (x 2))` reports unknown `z`.
`(Point new* (x 1) (x 2) (z 3))` reports duplicate `x`.

If every pair names a field exactly once and one or more fields
are absent, the error is missing field. List every missing name
in declaration order. That error is not an arity error. Do not
typecheck the values first. `(Point new* (y "bad"))` reports
missing `x` and does not report a type error for `y`. A
positional call with the wrong count is still an arity error.

If the names are exactly the fields, check the value
expressions in declaration order, the same walk a positional
call already uses. A labeled call is accepted exactly when the
positional call with those values in declaration order is
accepted. Writing the pairs in another order does not change
that result. Expected types and generic inference are
unchanged. `(List empty)` and an unannotated `fn` still take a
type from the field they are checked against. Do not make bare
`(Option None)` legal. Do not change `(if test then else)`.

Evaluate the receiver. Do not evaluate `new*`. Do not evaluate
the field names. Evaluate the value expressions in source
order, including when that order differs from field order. Do
not rearrange those expressions into declaration order and then
run them. Store each resulting value in declaration order.
The check walk and the evaluation order are allowed to differ.
A host capability may have an effect when its expression runs.
Two labeled calls that supply the same values build the same
instance.

This evaluation is the same correspondence as a parallel `let`
whose body is positional `new` in declaration order:

```aloe
(Point new* (y (+ x 1)) (x 10))
```

runs `(+ x 1)` and then `10`, with the outer `x` still visible,
and stores `10` in `x` and that sum in `y`. The `let` names do
not see each other, which is what `SPEC.md` §4.3 already does.
Checking is not that expansion. Expanding to `let` before
`type-of` drops the expected type a field gives its value. The
spec must not check `new*` by that route.

Require a test that swaps two pairs, including an empty list
and a function whose type comes from the field. The swapped
call typechecks exactly when the unswapped call does, and the
value expressions run in the written order. Tests pin the error
class, the field names involved, and declaration order when
missing fields are reported. They do not pin the full wording
of a diagnostic. The classes are syntax, missing field, unknown
field, duplicate field, positional arity, and ineligible
`new*`. A later clearer sentence does not have to match an
older one word for word.

### 4.4 What stays a value

`(List of ...)`, `(List empty)`, `(Symbol intern ...)`,
`(Text from-string ...)`, ordinary methods, protocol sends,
numeric sends, host messages, and explicit constructors do not
take labels. `case` binders stay positional.

This series does not add a `Mirror` or `Signature` query for
labels. It does not decide that constructor field names stay
invisible. For a `(fields ...)` class the names are already
selectors. A later series may expose them.

Do not implement labels as Racket keyword arguments. Checkpoint
83a still rejects required and optional keyword call shapes at
the host boundary.

Field names are the construction names. A labeled call still
means the same thing when a field moves, and it fails when that
field is renamed. A positional call whose fields have different
types fails when those fields trade places. When the fields have
the same type, the positional call still typechecks and the
values change jobs. Adding or removing a field breaks both
spellings. A separate initialization name was considered and
set aside. If a later design needs a construction input that is
not a stored field, that is a new design.

The pair shape is the surface a later template macro can emit
by rearranging lists. A later macro may replace `new*` only
after a replacement is shown to preserve source-order
evaluation and declaration-order checking, including the
expected type a function expression takes from its field. This
series does not build that macro, does not specify it, and does
not have to prove the replacement. The decisions entry records
the constraint so a later series can find it.

### 4.5 The closing edit

One product edit, after the language slice is real. In
[`examples/aloemacs/main.aloe`](../../../../examples/aloemacs/main.aloe),
rewrite `aloemacs-editor` to the two-`let` shape of
[`003-parens-let-aligned-let.aloe`](../../../../archive/design-sketches/2026-10-06-aloemacs-labels/003-parens-let-aligned-let.aloe).
Keep that sketch's binding names and nesting. The inner `let`
is the body of the outer `let`, so it sees `initial-buffer`.
Drop the sketch's prose sentence and markdown fence.

These constructions use `new*` and name the fields they already
have, each value a binding pair:

| Constructor | Field names, in declaration order |
|---|---|
| `AloemacsSession new*` | `buffers` `fs` `echo` `searching` `query` `origin` `wrapped` `failing` `kill-ring` `pending` `prompt` `last-submission` `waiting-command` `windows` |
| `AloemacsBuffers new*` | `before` `current-buffer` `after` |
| `AloemacsBuffer new*` | `editor` `path` `id` |
| `AloemacsEditor new*` | `text` `point` `quit` `scroll-row` `scroll-col` `history` `mark` `text-rows` |
| `AloemacsPrompt new*` | `label` `text` `column` `completion-note` `completion-lines` `completion-matches` `completion-start` |
| `AloemacsWindows new*` | `tree` `selected` `columns` `rows` |

Leave these spellings positional inside that same definition,
including where the sketch labels them:

| Sketch form | Closing edit |
|---|---|
| `(Position new* (line 0) (column 0))` | `(Position new 0 0)` |
| `(Path new* (text "/typed-none"))` | `(Path new "/typed-none")` |
| `(Fs new* (host fs-host))` | `(Fs new fs-host)` |
| labeled `AloemacsView new*` | `(AloemacsView new 0 0 0 0 #f)` |

Also leave `(Text from-string ...)`, `(Option None)`,
`(Option Some ...)`, `(List empty)`, `(AloemacsCommand FindFile)`,
and `(AloemacsWindowTree Leaf ...)`. The `if` witnesses around
`(Option None)` stay. Column alignment is not language law. The
closing edit may keep the sketch's columns.

The session table then binds `buffers`, `pending`,
`last-submission`, `waiting-command`, `prompt`, and `windows` to
the names introduced by the two `let`s, and leaves the short
values inline. `(origin (Position new 0 0))` and
`(fs (Fs new fs-host))` are two of those inline values.

Do not edit `examples/aloemacs/file.aloe` or
`examples/aloemacs/editor.aloe`. Do not relabel any other call
site in the repository as part of this series.

`tests/aloemacs/runner.rkt` compares `(source-datums main-path)`
with `expected-main-datums`, and `source-datums` is `read`. The
closing slice replaces that one expected list with the datum of
the rewritten definition. It does not change the runtime
assertions in that file, including the checked type, the empty
text, the point, and the absent options. No other test file
snapshots this source.

### 4.6 Documents the spec amends

Amend `SPEC.md` so a `(fields ...)` constructor may be called
positionally with `new`, or fully labeled with `new*` in the
selector position. Place `new*` with the special forms, beside
`case`: it is syntax, not a send. The tail is the binding-pair
list in §4.1. Delete the sentence that labeled construction
(`make`) is out of scope. Remove `labeled make` from §8. Do not
add a `make` selector. Keep §9's positional `Point` goldens, and
add a labeled golden beside them. One labeled golden is
`(Point new* (x 1) (y 2))`, equal to `(Point new 1 2)`, and
`((Point new* (y 2) (x 1)) x)` is `1`.

The identifier rules do not grow an exception. §1, §2.1, and
§7.2 stay as they are. The amendment is the form, not a
restriction on source names.

Add one dated entry to `docs/decisions.md`: labeled construction
is a `new*` form in the selector position; each label is a
binding pair `(name expr)` in the `let` shape; the car is the
field's source name and is not evaluated; the colon experiment
on `experiment/2026-10-05-labeled-construction` is not this
series; square brackets were not given a meaning; defaults,
mixed calls, method labels, explicit-constructor labels, and
`make` were rejected. A positional call whose equal-typed fields
trade places still typechecks and changes meaning. A labeled
call does not. After the value expressions have run, the stored
payload is that positional constructor's payload. The checking
is not the `let` expansion in §4.3. A later macro replaces this
form only after an expansion preserves source-order evaluation
and declaration-order checking, including the expected type a
function expression takes from its field. This series does not
build that macro and does not have to prove the replacement.

The spec writes the sentences. The decisions above are the
content.

### 4.7 Where code may live

- `aloe/parse.rkt`, `aloe/type.rkt`, and `aloe/eval.rkt`. `new*`
  joins the second-position path that already recognizes `case`,
  then the existing construction walk
- Expression walkers that match node kinds, so the new node
  does not make them fail or skip its children. The children
  are the receiver and the value expressions. The field-name
  symbols are not children. This includes
  `aloe/private/expression-selection.rkt`,
  `aloe/private/completion-selection.rkt`,
  `aloe/completion-query.rkt`, and the same match in
  `tests/editor/source-locations/000-spans.rkt`. The change
  keeps hover and completion working inside a value. It does
  not complete a field name
- `SPEC.md`, the construction rule, the special-form section,
  §8, and §9, as §4.6 allows
- `docs/decisions.md`, the one entry in §4.6
- `tests/parenthetical-construction/`
- `examples/aloemacs/main.aloe`, and only the definition in §4.5,
  and only in the closing slice
- `tests/aloemacs/runner.rkt`, and only the value of
  `expected-main-datums`, and only in the closing slice. The
  comparison and every runtime assertion stay

The language server reads the same parser. Existing programs
must still parse and check. Hover and completion inside a
`new*` value must keep working. This series adds no completion
query for field names and no new editor feature.

Not in this series: `CHECKPOINTS.md`, `docs/checkpoints/`,
`examples/aloemacs/file.aloe`, `examples/aloemacs/editor.aloe`,
Gel, the host keyword check, the identifier sections, the colon
experiment's files, and any editor change beyond teaching those
walkers the new node.

## 5. Authority

- `SPEC.md` §2, §3.1, §3.2, §4.3, §4.10, §5.3, §7.2, §8, and §9.
  This spec amends the construction rule, the special-form
  section, §8, and §9 only as §4.6 allows. It does not amend the
  identifier rules. Where this charter and `SPEC.md` disagree
  about labeled construction, the charter wins and the spec
  records the amendment. For every other rule, `SPEC.md` wins.
- [`docs/philosophy.md`](../../../philosophy.md). The session
  definition is the pressure: several arguments are `#f`, `0`,
  or `""`, and the field is visible only by counting. The
  binding pair is the readable mark, and it is the shape `let`
  already uses. The addition does not become a keyword type, a
  dictionary, or a macro system.
- [`docs/decisions.md`](../../../decisions.md). The `if` entry
  left `[]` without a special meaning. This series does not
  add one.
- [`docs/checkpoints/0083a-host-implementation-call-shape.md`](../../../checkpoints/0083a-host-implementation-call-shape.md).
  Host methods stay positional Racket calls.
- [`examples/aloemacs/main.aloe`](../../../../examples/aloemacs/main.aloe)
  is the source of the values the closing slice must preserve.
- The sketch in §4.5 is the source of the closing edit's `let`
  structure. The positional exceptions in that section win where
  the sketch labels a small constructor.
- [`docs/workflow.md`](../../../workflow.md) is the process, not
  language law.
- `experiment/2026-10-05-labeled-construction` is a separate
  experiment. Its charter, spec, and grammar are not authority
  on this branch.

## 6. Non-goals

- A default value for an omitted field
- A bare value and a binding pair in the same call
- Labels on methods, `List`, host messages, or `case`
- Labels on explicit constructors (`Some`, `Leaf`, `FindFile`,
  and the rest)
- `(self with (prompt ...))` or any copy-and-replace form
- A `make` selector, or any second constructor
- Trailing-colon labels, a colon reservation, or the `x::`
  spelling
- Self-quoting keywords, a `Symbol` reader literal, or computed
  field names
- Square-bracket syntax, or a dictionary used as the payload
- Making bare `(Option None)` typecheck
- Editor completion or highlighting of field names
- A `Mirror` or `Signature` query in this series
- A macro system, or a proof that a macro can replace `new*`
- Relabeling `file.aloe`, `editor.aloe`, or any call site other
  than §4.5
- Promoting the series onto `CHECKPOINTS.md` inside the spec
- Carrying the colon experiment's tests or parser into this
  branch

## 7. Handoff

Series identity: `parenthetical-construction`. Checkpoint 000 is
spoken **parenthetical-construction 000** and filed as
`checkpoints/000-slug.md`. Numbers are three digits, start at
000, and are never renumbered. The checkpoint manager writes one
checkpoint, then stops. Project root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Code and tests
go there, not in this design folder. Local numbering. Work stays
on `experiment/2026-10-06-parenthetical-construction`.

Intended layer order:

1. **Grammar.** `new*` in the selector position, the binding
   pairs, and the syntax errors in §4.2. Positional programs
   still parse. A colon-suffix name still parses as an ordinary
   name, because the identifier rules do not change.
2. **Law.** The checking and evaluation rules in §4.1–§4.4, the
   `SPEC.md` and `docs/decisions.md` edits in §4.6, and tests
   for both spellings, order, generics, and each error class.
3. **The session definition.** The one edit in §4.5.

The spec may merge layer 1 into layer 2 when a grammar-only
checkpoint would be too thin to test on its own. It keeps this
order otherwise. It does not merge layer 3 into the language
slice. It adds no fourth layer and no feature from §6. A manager
may split a layer that misses checkpoint size, keeps this order,
and adds no features.

If you have been told to read this file, this is the whole assignment.
