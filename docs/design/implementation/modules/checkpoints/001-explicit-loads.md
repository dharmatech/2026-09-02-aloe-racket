# modules 001 — Explicit loads

**Status: Ready to implement.** Human review of this checkpoint
precedes its implementation.

If you have been told to read this file, it is the whole assignment.
It carries every rule this slice needs. The spec sections it names
are the authority behind it; read them if a rule here seems to need
more context, and do not implement anything else they describe.

## Goal

Every census file comes to load each file whose names it uses, while
a load still includes everything. `Math` moves into its own file,
`examples/mpl/math.aloe`. A census test proves, file by file, that no
file uses a name it neither defines nor gets from a direct load.

Nothing a program sees changes. Under modules 000 the added loads
are hits: the file already ran in that base, so the load runs
nothing and binds nothing new. The point of this layer is the slice
after next: once each file has its own environment (slice 3e), a
missing load becomes an unbound name. Until then the suite cannot see
a missing load, and the census test is the only proof.

No Racket module under `aloe/` changes. `SPEC.md` does not change.

This is modules 001. Stop when the census test and the whole suite
pass. Do not start slice 3a.

## Authority, identity, and starting point

- Identity: **modules 001**, filed as
  `docs/design/implementation/modules/checkpoints/001-explicit-loads.md`.
  A local language series on branch `experiment/2026-10-12-modules`.
  It takes no global number and gets no `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../workflow.md), root
  [AGENTS.md](../../../../../AGENTS.md), and
  [SPEC.md](../../../../../SPEC.md) before editing. Evaluation is send
  with a literal selector. Function objects run only through `call`.
  No inheritance, mutation, macros, implicit Int/Float coercion, or
  new special forms.
- Predecessor: **modules 000**, committed as `5d435a5`. A resolved
  path runs once per base; a second load of the same bytes runs
  nothing. That is why this layer cannot come first: under the old
  `load`, a second load of a file rebuilt its classes.
- [../spec.md](../spec.md) governs. This checkpoint narrows it to one
  slice:
  - §5: this layer. §5.1 the census and free names, §5.2 the loads,
    §5.3 the `Math` file, §5.4 the pins, §5.5 the census test, §5.6
    acceptance.
  - §3: the out-of-scope list.
  - §12, row "Layer 2": the `docs/decisions.md` text.
- The spec allows splitting this layer by tree. This checkpoint does
  not split it: on their own, the Gel and MPL edits are five small
  `.aloe` edits that change no test, and the census test covers every
  tree at once.

### The tree at issuance

The manager ran a scratch census (a walker over the parsed source,
following the rules in **Census test** below) over today's tree, on
2026-10-13. Eleven files have free names:

| File | Free names |
|---|---|
| `examples/aloemacs/file.aloe` | `Text`, `Position`, `Span` |
| `examples/aloemacs/main.aloe` | `AloemacsEditor`, `Text`, `Position`, `Path`, `Fs` |
| `gel/loop.aloe` | `GelRow`, `gel-rows` |
| `gel/main.aloe` | `GelStack` |
| `examples/mpl/sym.aloe` | `Math` |
| `examples/mpl/sum.aloe` | `Math` |
| `examples/mpl/num.aloe` | `Math` |
| `examples/mpl/prod.aloe` | `Math`, `Num` |
| `examples/mpl/pow.aloe` | `Math`, `Num` |
| `examples/mpl/identities.aloe` | `Sym` |
| `tests/modules/fixtures/keymap-user.aloe` | `commands` |

That is the spec's §5.2 table plus `keymap-user.aloe`, a fixture
modules 000 added after the spec was written. It uses `commands`,
which `keymap.aloe` defines, without loading `keymap.aloe`.

Two more things the scratch census saw, and what they are:

- `lib/disk.aloe` uses `H` and `lib/list.aloe` uses `T` inside
  `define-methods`. Those are type parameters of the class being
  extended, not names. The census test binds them (see **Type
  parameters**).
- `tests/editor/source-locations/fixtures/000-spans.aloe` uses `Point`
  and `p`. `tests/editor/source-locations/000-spans.rkt` only parses
  it for source locations; nothing loads or checks it. It is not a
  census file.

The manager then applied the edits in **Required behavior** to a copy
of the repository and ran the whole suite. Exactly 17 assertions in
17 files failed, all of them the pins in **Pins**. With those pins
edited the 17 files and `tests/modules` passed. No Gel, MPL, hover,
or completion test moved.

### Size

About twenty `.aloe` lines, seventeen one-assertion test edits, one
new `.aloe` file, one decisions entry, and one new test file of a few
hundred lines. One conversation.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`, `examples/aloemacs/main.aloe`: the
  added loads only.
- `gel/loop.aloe`, `gel/main.aloe`: the added loads only.
- `examples/mpl/math.aloe`: new.
- `examples/mpl/core.aloe`: the `define-protocol Math` form leaves; a
  load of `math.aloe` takes its place.
- `examples/mpl/sym.aloe`, `sum.aloe`, `num.aloe`, `prod.aloe`,
  `pow.aloe`, `identities.aloe`: the added loads only.
- `tests/modules/fixtures/keymap-user.aloe`: the added load only.
- The pin assertion in each of the 17 test files under **Pins**, and
  nothing else in those files except the one test-case name noted
  there.
- `tests/modules/001-census.rkt`: new. The spec names this file
  (§5.5).
- `docs/decisions.md`: only the entry in **Decisions**.

### Must leave untouched

- Every Racket module under `aloe/`, and `host/racket/`.
- `SPEC.md`.
- Every other `.aloe` file, including `examples/aloemacs/editor.aloe`,
  everything under `lib/`, `gel/menu.aloe`, `gel/stack.aloe`,
  `examples/boids.aloe`, `examples/point.aloe`, every other test
  fixture, `editors/`, and `archive/`.
- Every other test, including `tests/modules/000-run-once.rkt`, the
  MPL tests, the Gel tests, and the `define-class` name lists that
  the pin files also hold.
- `CHECKPOINTS.md`, `docs/checkpoints/`, this folder's `README.md`,
  `charter.md`, `spec.md`, this checkpoint, and every other design
  document.

These lists are exhaustive. If another file is necessary, stop and
send this checkpoint back.

## Required behavior

### 1. The loads this layer adds

Add each load as a top-level `(load "...")` datum next to the file's
existing leading loads, with the same relative spelling. Keep
comments and blank lines as they are. After the edit, each file's
leading datums are exactly:

| File | Leading datums, in order |
|---|---|
| `examples/aloemacs/file.aloe` | `(load "editor.aloe")`, `(load "../../lib/text.aloe")`, `(load "../../lib/fs.aloe")` |
| `examples/aloemacs/main.aloe` | `(load "file.aloe")`, `(load "editor.aloe")`, `(load "../../lib/text.aloe")`, `(load "../../lib/fs.aloe")`, then `(define aloemacs-editor ...)` |
| `gel/loop.aloe` | `(load "stack.aloe")`, `(load "menu.aloe")` |
| `gel/main.aloe` | `(load "loop.aloe")`, `(load "stack.aloe")` |
| `examples/mpl/core.aloe` | `(load "math.aloe")`, `(load "sym.aloe")`, `(load "sum.aloe")`, `(load "num.aloe")`, `(load "prod.aloe")`, `(load "pow.aloe")` |
| `examples/mpl/sym.aloe`, `sum.aloe`, `num.aloe` | `(load "math.aloe")` |
| `examples/mpl/prod.aloe`, `pow.aloe` | `(load "math.aloe")`, `(load "num.aloe")` |
| `examples/mpl/identities.aloe` | `(load "core.aloe")`, `(load "sym.aloe")` |
| `tests/modules/fixtures/keymap-user.aloe` | `(load "command.aloe")`, `(load "keymap.aloe")` |

A class file that had no load before gets its load on the first line
and a blank line before its `define-class`.

### 2. The `Math` file

`examples/mpl/math.aloe` is new. It contains exactly the
`(define-protocol Math ...)` form that opens `examples/mpl/core.aloe`
today, moved verbatim: the same twelve lines, the same eleven
signatures in the same order, ending in a newline. It loads nothing.

`core.aloe` loses that form and the blank line after it, and begins
with `(load "math.aloe")` directly followed by its five class loads.
Its `define-methods` forms do not change.

A name a loaded file uses that its loader defines cannot be fixed with
a load of the loader: that load is a cycle. `Math` is that case, and
moving it is the only such repair in this layer.

### 3. What does not change

- No existing load is removed. In particular
  `examples/mpl/identities.aloe` keeps `(load "core.aloe")`: the
  census sees names only, and `core.aloe` is where the protocol
  methods come from. `lib/text.aloe`, `lib/fs.aloe`, and
  `lib/disk.aloe` keep `(load "option.aloe")`.
- No file gains a load of `lib/option.aloe`. `Option` is not counted
  in this layer; slice 3a makes it a base name.
- `file.aloe` is not split, and no prefix is dropped. Adding the
  `lib/text.aloe` load to `file.aloe` is not that split.
- No `define-class` name list pinned by any test changes.
- Every program the suite loads sees the same names and the same
  classes. MPL still conforms. The MPL and Gel tests do not change.

## Census test: `tests/modules/001-census.rkt`

Write it first. Run it against the tree as you found it, before any
`.aloe` edit. It must report exactly the eleven files in the table
above, each with exactly those names, and nothing else. Report that
run. Then make the edits and run it again.

### The census files

Every `.aloe` file under `examples/`, `lib/`, `gel/`, and `tests/`,
found by walking those directories from the project root, except
`tests/editor/source-locations/fixtures/000-spans.aloe`. Name that
exclusion in the test with its reason, and assert the excluded file
exists, so the exclusion cannot go stale silently. `archive/` and
`editors/` are not walked. Locate the project root with
`define-runtime-path`. Do not list the census files by hand: a
fixture added later is a census file automatically.

### Free names

For each census file, its free names are the names it **references**,
minus:

- its own definitions: the names of its top-level `define`,
  `define-class`, and `define-protocol` forms;
- the base names: `dummy`, `List`, `Int`, `String`, `Symbol`,
  `Mirror`, and the injected hosts `term` and `fs-host`;
- `Option`, which this layer does not count (say so in a comment;
  slice 3a installs it on the base);
- the own definitions of each file it loads **directly**: that file's
  top-level `define`, `define-class`, and `define-protocol` names,
  not the names that file in turn loads. A direct load is a
  top-level `load` in the file, resolved as the language resolves it
  (`load-expr-resolved-path`). `define-methods` defines no name.

A **reference** is:

- a name in expression position that no enclosing binder binds;
- a class or protocol name in a type: a field type, a constructor
  field type, a method parameter type, a method return type, a
  protocol signature's parameter or return type;
- the protocol position of a `define-class`;
- the target of a `define-methods`.

These are **not** references:

- selectors, including constructor selectors in sends and in `case`
  clauses;
- the field labels of `new*` and `with`;
- names bound by a binder: `fn` parameters (and so `let` names),
  method parameters, `self` in a method body, `case` payload names;
- `->` and the kernel type names `Int`, `Float`, `Bool`, `String`,
  `Symbol`, `Mirror`, and `Signature`;
- type parameters in scope (next section).

### Type parameters

A symbol in a type is not a reference when it is a type parameter in
scope:

- inside a `define-class`, that class's own type parameters;
- inside a method, its `(type A ...)` parameters;
- inside a `define-methods` on class `C`, `C`'s type parameters, read
  from `C`'s `define-class` in the same file or in a direct load. For
  `List` it is the kernel element parameter `T`. `Int` and `String`
  have none.

That last rule is what keeps `H` in `lib/disk.aloe` and `T` in
`lib/list.aloe` from reading as names.

### How to walk

Read each census file with `read-program` from `aloe/parse.rkt`,
with `#:source-path` the file's path, and walk the parse structs that
module exports. The parser already turns `let`, `cond`, and `if` into
`fn` and sends, and already separates selectors, labels, and binders
from expressions, so the walk is a short `match` over
`variable-expr`, `send-expr` (receiver and arguments, never the
selector), `check-expr`, `define-expr`, `fn-expr`, `case-expr`
(`case-clause` payload names bind in that clause's body),
`new-star-expr` and `with-expr` (receiver and binding values, never
`construction-binding-name`), `define-class-expr`,
`define-protocol-expr` (its signatures are `method-declaration`s with
no body), `define-methods-expr`, and `load-expr`. Types are datums: a
symbol, or a list whose every element, head included, is walked.

The walker lives in the test file. Nothing is added to `aloe/`; the
language gains no checker that walks identifiers.

### Required cases

1. **Every census file has no free names.** One check per file, with
   a failure message that names the file and its free names. Before
   the edits this reports the eleven files of the table; after, none.
2. **The walker sees names.** Run the same free-name procedure on
   each program below, parsed from a string, and check the exact set.
   The manager ran each through the scratch census on 2026-10-13.

   | Program | Free names |
   |---|---|
   | `(define-class A (fields (b B)) (methods))` | `B` |
   | `(define f (fn (x) (x foo y)))` | `y` |
   | `(define-class (C T) (fields (v T)) (methods (get () T (self v))))` | none |
   | `(define-methods List (methods (twice () (List T) (self append self))))` | none |
   | `(define g (fn (o) (o case (Some (v) (v + z)) (None () 0))))` | `z` |
   | `(define h (Point new* (x 1) (y q)))` | `Point`, `q` |
   | `(define w (p with (x r)))` | `p`, `r` |
   | `(define k (let ((n 1)) (n + m)))` | `m` |
   | `(define-protocol P (m (other Q) R))` | `Q`, `R` |
   | `(define-methods Foo (methods (pick (type A) (a A) A a)))` | `Foo` |
   | `(define-class D Proto (fields) (methods))` | `Proto` |
   | `(define-class K (fields (a Int) (b Float) (c Bool) (d String) (e Symbol) (f Mirror) (g Signature) (h (-> Int Bool))) (methods))` | none |
   | `(define o (Option Some 1))`, `(define t term)`, `(define u fs-host)` | none |

   And one with a direct load: the text
   `(load "file.aloe") (define e AloemacsEditor) (define b AloemacsBuffer)`
   parsed with `#:source-path` a path in `examples/aloemacs/` (the
   file need not exist) has the free name `AloemacsEditor` only:
   `AloemacsBuffer` is `file.aloe`'s own definition, and
   `AloemacsEditor` is `editor.aloe`'s, which `file.aloe` only loads.
3. **The leading loads.** For each file in the table of §1, its
   datums, read with `read`, begin with exactly that row's loads, in
   that order, and the datum after them is not a `load`. This is how
   the test shows no existing load was removed and the order is the
   one written.
4. **The `Math` file.** `examples/mpl/math.aloe` holds exactly one
   datum, a `define-protocol` named `Math` with eleven signatures.
   `examples/mpl/core.aloe` holds no `define-protocol`.

## Pins

Each of these 16 files holds one assertion on the first two datums of
`examples/aloemacs/file.aloe`. The variable is `datums` in the first
ten and `source` in the last six. The line numbers are from the tree
at issuance:

| File | Line | Variable |
|---|---|---|
| `tests/aloemacs/buffer-value.rkt` | 178 | `datums` |
| `tests/aloemacs/completion-page-session.rkt` | 193 | `datums` |
| `tests/aloemacs/completion-session.rkt` | 184 | `datums` |
| `tests/aloemacs/minibuffer-value.rkt` | 169 | `datums` |
| `tests/aloemacs/mode-buttons-paint.rkt` | 134 | `datums` |
| `tests/aloemacs/mode-line-row.rkt` | 21 | `datums` |
| `tests/aloemacs/prompt-commands-find-file.rkt` | 164 | `datums` |
| `tests/aloemacs/window-bars-one-view.rkt` | 157 | `datums` |
| `tests/aloemacs/window-bars-split.rkt` | 201 | `datums` |
| `tests/aloemacs/windows-buffer-identity.rkt` | 138 | `datums` |
| `tests/aloemacs/windows-delete-and-other.rkt` | 169 | `source` |
| `tests/aloemacs/windows-lock.rkt` | 175 | `source` |
| `tests/aloemacs/windows-split.rkt` | 164 | `source` |
| `tests/aloemacs/windows-layout-and-rendering.rkt` | 468 | `source` |
| `tests/aloemacs/windows-state-foundation.rkt` | 134 | `source` |
| `tests/aloemacs/windows-state.rkt` | 627 | `source` |

Each reads

```racket
(check-equal? (take datums 2) '((load "editor.aloe") (load "../../lib/fs.aloe")))
```

and becomes

```racket
(check-equal? (take datums 3)
              '((load "editor.aloe")
                (load "../../lib/text.aloe")
                (load "../../lib/fs.aloe")))
```

with `source` in place of `datums` where the file uses it. Do not
touch the `(take d 2)` comparisons in `mode-line-row.rkt` and
`window-bars-one-view.rkt` that find `(define-class AloemacsEditor`;
they are not pins on the loads.

`tests/aloemacs/runner.rkt` pins all of `main.aloe` as
`expected-main-datums` (line 22). Its leading `(load "file.aloe")`
gains the three loads after it:

```racket
'((load "file.aloe")
  (load "editor.aloe")
  (load "../../lib/text.aloe")
  (load "../../lib/fs.aloe")
  (define aloemacs-editor
    ...
```

The test case that uses it (line 171) is named "main has exactly the
source-relative load and empty starting state"; change `load` to
`loads` in that name and change nothing else in it.

That is the whole inventory. The scratch run is how it was found: the
suite after the `.aloe` edits failed in exactly these 17 places. If
your run fails anywhere else, stop and report the file and the
assertion.

## Decisions

Add one section at the end of `docs/decisions.md`, after "Run-once
load", in that file's `## Title (date)` shape, dated the day you land
it:

> ## Explicit loads (YYYY-MM-DD)
>
> Decided: every census file loads each file whose names it uses;
> `Math` lives in `examples/mpl/math.aloe`. Rejected: a barrel file
> and a checker that walks identifiers.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/modules/001-census.rkt
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

The checkpoint is complete when:

- the census test passes, and its first run against the tree as you
  found it reported exactly the eleven files of the table;
- the whole suite passes, and the only edits to existing tests are the
  17 pins and the one test-case name;
- no Racket module under `aloe/` or `host/` changed, and `SPEC.md` did
  not change;
- `git diff -- examples/mpl/core.aloe examples/mpl/math.aloe` shows
  the `define-protocol Math` lines moved unchanged;
- the whitespace check is clean and the file scope was respected.

Report the results and stop. Do not commit. Do not start slice 3a.

## Non-goals

- Changing what `load` does, or any Racket module.
- Installing `lib/option.aloe` on the base, or adding a load of it
  anywhere.
- Splitting `examples/aloemacs/file.aloe`, dropping an `Aloemacs` or
  `Gel` prefix, or renaming anything.
- A barrel file, an export list, or any new form.
- Adding a load to a test's Racket code or to a string a test
  evaluates. A string evaluated in the interactive environment is not
  a census file. Slice 3e handles the entry points.
- Editing `host/racket/gel-run.rkt` or `host/racket/aloemacs-run.rkt`.
- Moving any `define-methods` form, or anything in `core.aloe` other
  than the protocol.
