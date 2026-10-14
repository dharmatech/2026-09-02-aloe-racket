# modules 006 — File environments and the copy rule

**Status: Ready to implement.** Human review of this checkpoint
precedes its implementation.

If you have been told to read this file, it is the whole assignment.
It carries every rule this slice needs. The spec sections it names
are the authority behind it; read them if a rule here seems to need
more context, and do not implement anything else they describe.

## Goal

A loaded file runs in its own environment, and a load copies into the
loader only the names that file itself defines.

- Each base gets a separate **interactive environment** (the prompt),
  a child of the base. Every **keyed root** and every **nested load**
  on a miss gets a **file environment**, also a child of the base.
- A miss checks and evaluates the file's forms in its file
  environment, records the file's **exports** (its own `define`,
  `define-class`, and `define-protocol` bindings) in the cache entry,
  then **copies** them into the loader. A hit copies the entry's
  exports and runs nothing.
- The **loader** is the file environment of the file whose `load` it
  is, or the interactive environment for a load at the prompt and for
  every keyed root. A root's own definitions therefore land at the
  prompt, and its nested loads' definitions do not.
- The editor queries check the buffer as a file module.

So a driver that loaded only `main.aloe` sees `aloemacs-editor` and
the base, and nothing `main.aloe` got from its own loads. About a
hundred tests and one runner use names their root no longer copies;
each gains the loads it needs. That migration, verified on a scratch
copy, is most of this checkpoint's work.

This is slice 3e of the spec, the seventh checkpoint, and **the slice
the spec says is not split further**. If you prove it too big for one
conversation, stop and send it back. Stop when the focused proof and
the whole suite pass. Do not start slice 3f.

## Authority, identity, and starting point

- Identity: **modules 006**, filed as
  `docs/design/implementation/modules/checkpoints/006-file-environments.md`.
  A local language series on branch `experiment/2026-10-12-modules`.
  It takes no global number and gets no `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../workflow.md), root
  [AGENTS.md](../../../../../AGENTS.md), and
  [SPEC.md](../../../../../SPEC.md) before product edits. Evaluation
  is send with a literal selector. Function objects run only through
  `call`. No inheritance, mutation, macros, implicit Int/Float
  coercion, or new special forms.
- Predecessors, all committed: **000** (`5d435a5`, the per-base load
  cache and keyed roots), **001** (`efe39e7`, explicit loads and the
  census), **002** (`0f026a6`, `Option` on the base; the editor's
  base-library rule), **003** (`1ab41bb`, overload identity), **004**
  (`c6a0333`, method and protocol records: a method's body and
  annotations already resolve in the environment that wrote it),
  **005** (`f1311a9`, the conformance walk over the cache, the file
  environment, and the interactive environment; checker exports are
  `(name . type)` bindings).
- [../spec.md](../spec.md) governs. This checkpoint is its §6.5:
  - §2: base, interactive environment, file environment, root check,
    keyed root, unkeyed port, cache, entry, exports.
  - §6.5.1–§6.5.7: this slice.
  - §9.1: the entry points as read on 2026-10-12 (superseded here by
    the scratch run's inventory, below).
  - §12, row 3e: the `SPEC.md` and `docs/decisions.md` text.
  - §3: out of scope. No `import`, no export list, no prefixes.
- Collisions are slice 3f. In this slice a copied name that is already
  bound in the loader **replaces** it, as today.

### The tree at issuance

Line numbers are approximate; search before editing.

- `aloe/env.rkt`: `top-level-env` has `bindings parent int-class
  string-class option-class load-cache`. `make-top-level-env` builds a
  raw kernel environment; `make-local-env` makes a child sharing the
  class fields and the cache.
- `aloe/type.rkt`: `type-environment` has the same fields. The load
  rules are `typecheck-load!`, `typecheck-keyed-root`,
  `typecheck-once!`, and `typecheck-keyed-buffer` (the 002 base-library
  install); seeds are `record-checked-libraries!`. `typecheck-program`
  runs `(check-protocol-conformance! environment environment)` at
  depth zero. Definitions bind with `type-environment-set!` in the
  environment the form is checked in.
- `aloe/eval.rkt`: `eval-load!`, `eval-keyed-root`, `eval-once!`,
  `record-evaluated-libraries!` (evaluator seeds export the bare name
  `'(Option)`). Definitions bind with `env-define!`.
- Today a load, nested or keyed, checks and evaluates the file's forms
  **in the loader's environment**, which is the one shared
  environment. `make-driver` and `aloe/main.rkt`'s constructors return
  that shared environment.
- `aloe/main.rkt`: `make-type-environment`, `make-top-level-env`,
  `type-environment-for` (the raw-environment fallback; a weak table
  from runtime environment to checker environment), `typecheck-source`,
  `eval-datum`, `eval-program`, `eval-source`, and the `query-base`
  submodule (`base-library-path`, `typecheck-base-library-buffer`).
- `aloe/driver.rkt`: `make-driver` builds two raw environments and
  installs into them; `driver-inject-host!` writes the driver's two
  environments; `driver-load-port!` keyed and unkeyed.
- `aloe/expression-query.rkt` and `aloe/completion-query.rkt` check a
  non-library buffer in a fresh `make-type-environment`.
- Source pins to respect: `tests/editor/completion/002-public-query.rkt`
  requires `aloe/completion-query.rkt` to contain `make-type-environment`,
  `typecheck-program/observe-selector-receiver`, and
  `recover-selector-completion-site` exactly twice each.
  `tests/checkpoint-65.rkt` forbids `gel-handle-key`, `gel-text`, and
  `key-value->string` in `host/racket/gel-run.rkt`.

### Scratch run

The manager implemented this slice on a copy of the repository: the
environments, loads, copies, roots, queries, and runner below, about
250 product lines. On that copy, before any test edit, **112 test
files failed when each was run alone**. The parallel suite run
reported only 60 failing files: many tests fail inside a module-level
helper. The per-file run is the inventory. Every failure was a name
the test's root no longer copies, except the cases in **Special
cases**.

The manager then applied the migration in **Migration** and the two
deletions you will find there, and the whole suite passed: every test
file, run alone and under `-j 4`. Every case in the focused proof
below was probed on that copy.

Two traps from that run:

- `aloe/env.rkt`'s struct changes shape, so a test compiled against
  the old struct dies at load with `instantiate-linklet: mismatch`.
  `raco test -y` recompiles it; if a file still shows that error, it is
  stale bytecode, not a failure.
- Run each failing test file alone to read its first error; the
  parallel summary hides module-level failures.

### Size

Large. About 250 product lines across six modules and the Gel runner;
a focused test of fourteen cases; three `SPEC.md` sections, one
decisions entry, and two editor-spec sentences; and a test migration
of 112 files, nearly all a few added loads under five mechanical
rules. Script the mechanical edits, the way the manager did, and run
the suite per file. If it will not fit one conversation, stop and say
so.

## Exact file scope

### May create or edit

- `aloe/env.rkt`, `aloe/type.rkt`, `aloe/eval.rkt`, `aloe/main.rkt`,
  `aloe/driver.rkt`, `aloe/expression-query.rkt`,
  `aloe/completion-query.rkt`, `aloe/private/checker-observation.rkt`
  (only if needed; the manager's version did not need it).
- `host/racket/gel-run.rkt`: one added load.
- `SPEC.md`, `docs/decisions.md`, `docs/editor/expression-query/spec.md`,
  `docs/editor/completion/spec.md`: only the text in **Language law**
  and **Editor documents**.
- The test files in **Migration**, only as it says.
- `tests/modules/006-file-environments.rkt`: new.
- New fixtures under `tests/modules/fixtures/`: `sym-late-error.aloe`
  (Migration) and those the focused proof names. Every fixture there
  is a census file: it must load each file whose names it uses
  (`tests/modules/001-census.rkt` checks). A file that must use an
  unbound name on purpose goes in a temporary directory instead.

### Must leave untouched

- Every `.aloe` file under `examples/`, `lib/`, and `gel/`.
- `aloe/parse.rkt`, `aloe/lsp.rkt`, `aloe/library.rkt`,
  `host/racket/aloemacs-run.rkt`, `host/racket/term-run.rkt`, and every
  other host module.
- Every test not in **Migration**.
- `CHECKPOINTS.md`, `docs/checkpoints/`, `docs/philosophy.md`, this
  folder's `README.md`, `charter.md`, `spec.md`, this checkpoint, and
  every other design document.

These lists are exhaustive. If another file is necessary, stop and
send this checkpoint back.

## Required behavior

### 1. Environments

In both halves:

- **Base.** What the raw constructor builds plus the installed
  libraries, the seeds, the base `Option` field, and injected hosts.
  User definitions never land on the base.
- **Interactive environment.** A child of the base with no bindings of
  its own at first. The prompt, `driver-eval!`, `driver-prepare!`, an
  unkeyed port, and unkeyed `eval-source` / `typecheck-source` /
  `eval-datum` / `eval-program` evaluate there.
- **File environment.** A child of the base that records the file's
  resolved path (a new field; `#f` on every other environment).
  Bindings: the file's own definitions plus what its own loads copy
  in. It shares the base's cache and class fields, like any child.
- **Base of an environment.** The end of its parent chain. Export
  `env-base` from `aloe/env.rkt`, and `type-environment-base` from
  `aloe/type.rkt`'s `load-cache` submodule; tests use both.

### 2. Loading and copying

When a `load` or a keyed root reaches a path, 000's cache rules come
first (missing file, cycle, changed bytes, hit, miss), against the
**base's** cache. Then:

- **Miss.** Make a file environment under the base, record the running
  entry, check (or evaluate) the file's forms **in that file
  environment**, compute its exports, complete the entry with them,
  then copy them into the loader.
- **Hit.** Copy the entry's exports into the loader. Nothing runs.
- **Exports.** For each top-level `define`, `define-class`, and
  `define-protocol` form of the file, in order and once per name, the
  name and the binding it has in the file environment's **own** table
  after the forms ran. Checker entries store `(name . type)` (as 005
  set up); evaluator entries now store `(name . value)` the same way.
  `define-methods` exports nothing.
- **Copy.** Bind each exported name in the loader to that same type or
  value (the same class record, the same protocol record, the same
  value). Names a file only received from its own loads are not
  exported, so they are not copied onward. A copied name already bound
  in the loader replaces it. Copying the same cached binding again is
  harmless.
- **A failed load copies nothing.** If the check or the run raises, the
  entry is removed as today, nothing is copied, and the definitions it
  made stay in its own file environment, out of sight.
- **Seeds.** The evaluator's `Option` seed exports
  `(Option . <the base's Option class>)`, like the checker's, so a load
  of `lib/option.aloe` is a hit that copies the base class. The other
  three seeds export nothing.

The **loader**: the file environment of the file whose `load` form it
is; the interactive environment for a `load` at the prompt, in
`driver-eval!`, `driver-prepare!`, or an unkeyed port; and the
interactive environment the caller gave for every keyed root
(`driver-load-file!`, keyed `driver-load-port!`, keyed `eval-source`
and `typecheck-source`). For `typecheck-source` and the other
`aloe/main.rkt` entry points, the loader is the environment the caller
passed (see §4), and its base is the end of that environment's chain.

### 3. Roots and conformance

- A keyed root's forms run in its own file environment. On a miss,
  `typecheck-source` returns the root check's type and `eval-source`
  its last value, as today; `driver-load-port!` prints each non-void
  result and returns them, evaluating in the file environment. Hits
  return `Void`, void, and `'()` as today.
- Conformance (005) needs both environments. For a keyed root and for
  an outermost `load` (a `load` datum at the prompt), the file
  environment is the loaded file's and the interactive environment is
  the loader. For an unkeyed root they are the same environment. Pass
  the interactive environment however you like (an argument or a
  parameter); in the manager's version a parameter that
  `typecheck-program` reads at depth zero was enough, and
  `checker-observation.rkt` did not change.
- Conformance still runs only at depth zero, after the root's forms.

### 4. `aloe/main.rkt`

- `make-type-environment` and `make-top-level-env` return the
  **interactive environment of a fresh base**. The weak table maps the
  runtime interactive environment to its checker interactive
  environment.
- `eval-source`, `eval-program`, and `eval-datum` evaluate in the
  interactive environment for the environment given: the given one if
  it is an interactive environment from `make-top-level-env`;
  otherwise it is a **raw kernel environment**, which is bootstrapped
  in place as today (libraries, seeds, base `Option`) and becomes the
  base of an interactive environment created and memoized beside it.
  Every later call with the same raw object uses that memoized child.
  The raw object never holds a prompt definition.
- `typecheck-source` checks in the environment passed. That is its
  loader.

### 5. `aloe/driver.rkt`

- `make-driver` builds a base in each half, installs and seeds it as
  today, and stores each half's **interactive environment** in the
  `driver` struct.
- `driver-inject-host!` still refuses a name bound anywhere in the
  interactive environment's chain, and writes the binding into the
  **base**, so every file loaded afterwards sees it.
- `driver-eval!` and `driver-prepare!` check and evaluate in the
  interactive environments. `driver-load-port!` follows §3.

### 6. The editor queries

- A hover or completion query whose identity path is not a base
  library checks the buffer as a **file module**: a fresh base (from
  `make-type-environment`, whose parent is the base) and its empty
  interactive environment; a file environment under that base keyed by
  the identity path in the base's cache, with the buffer's bytes; the
  observed check runs in the file environment, with the query's
  interactive environment as conformance's interactive environment.
  Nested loads follow §2.
- A query of a base library follows 002 unchanged.
- Completion without a `source-path` checks in a fresh interactive
  environment, as today.
- Keep `aloe/completion-query.rkt`'s three source pins (see the tree).
  The manager kept them by adding one procedure to `aloe/main.rkt`'s
  `query-base` submodule for the file-module case and leaving the
  existing `make-type-environment` call for the no-path case.
- Consequences, all tested: hover on a class the buffer defines and on
  a class a nested load copies both resolve; hover inside
  `examples/mpl/sym.aloe` is still a failed query (JSON null in the
  adapter), now because `sym.aloe` binds `Sym` and its protocol
  methods are absent.

### 7. The Gel runner

`host/racket/gel-run.rkt` adds `(driver-load-file! state gel-stack-path)`
after its load of `examples/point.aloe`, with
`(define-runtime-path gel-stack-path "../../gel/stack.aloe")`, because
its expression uses `gel-empty-stack`. `host/racket/aloemacs-run.rkt`
uses only `aloemacs-editor` and does not change; its prompt
redefinition of `aloemacs-editor` still replaces.

### 8. What stays

- 000–005's rules: run once per base, changed bytes, cycles, missing
  files, method and protocol records, record-based overloads, the
  conformance walk and its error text, the base `Option`.
- A second definition of a name in one environment replaces the
  first: at the prompt, through `driver-eval!`, and in a file that
  defines a name twice.
- No collision error (3f), no origins, no defining paths (layer 4).

## Language law

`SPEC.md`, these edits only:

- §11, replace the first bullet (the `load` bullet that 000 extended)
  with:

  > - `load` reads, typechecks, and evaluates another Aloe file once
  >   per base, as a file module: the file runs in its own
  >   environment, whose parent is the base, and the names it defines
  >   with `define`, `define-class`, and `define-protocol` are copied
  >   into the loading environment. Names the file only received from
  >   its own loads are not copied. Relative paths resolve from the
  >   loading file before the current directory and project root. A
  >   later `load` of the same path with the same bytes copies the
  >   same definitions without running the file; different bytes are
  >   a type error. The prompt is not a file: its parent is the base,
  >   and a file loaded there copies its definitions into the prompt's
  >   environment. A program given with a source path is a file
  >   module.

- §3.1, after the bullet "`self` is implicit in every method body."
  add the bullet: "A method body, and the types named in its signature,
  are checked and evaluated in the environment of the file that wrote
  the method, whether in the class form or in a later
  `define-methods`."
- §3.3, append to the "Rules for this slice" list the bullet: "A
  protocol's signatures are resolved in the file that wrote the
  protocol."
- §4.6, after the paragraph that ends "so `T` is not implicitly in
  scope there." add: "A method added with `define-methods` runs in the
  file that wrote it."
- §8, the bullet "modules beyond `load`" becomes "modules beyond
  `load`'s file modules: `import`, export lists, prefixes, renames,
  packages, a load path, reload of an edited file".

`docs/decisions.md`: add one section at the end, dated the day you
land it:

> ## File modules and the copy rule (YYYY-MM-DD)
>
> Decided: a load copies the loaded file's own definitions, in a file
> and at the prompt; a file's environment is a child of the base; a
> root's definitions go to the prompt; methods and protocols resolve
> where they were written; a load of `editor.aloe` binds the names
> `editor.aloe` defines, and `Span` is bound by a load of
> `lib/text.aloe`. Rejected: `import`, a prefix clause, export lists,
> barrels, a load path, a declared module name, per-importer method
> tables, scoped selectors, parenting a file at the loader or at a
> bare kernel.

## Editor documents

- `docs/editor/expression-query/spec.md` §1: after the paragraph that
  begins "`#:document-path`, when supplied," add: "The file is checked
  as a file module: its own environment is a child of the default
  environment, and its nested loads copy only what they define."
- `docs/editor/completion/spec.md` §1: after the paragraph that begins
  "`source-path` is also the buffer's identity." add: "The buffer is
  checked as a file module: its own environment is a child of the
  default environment, and its nested loads copy only what they
  define." In the paragraph that begins "Each call creates a fresh
  checker environment", "installs the standard List then String
  libraries" becomes "installs the standard List then String
  libraries, then `lib/int.aloe` and `lib/option.aloe`,".

## Migration

The manager's scratch run is the inventory: these 112 test files and
`host/racket/gel-run.rkt` (§7), and no others. Your own per-file run
after the product edit is the check. Name new runtime paths however
reads best in each file.

### A. Aloemacs and the parenthetical session (56 files)

A test that loads an Aloemacs root then uses names from the files that
root loads. After the product edit those names are unbound. Add loads
of the defining files next to the root load, through the same call the
root uses (`ev`, `driver-eval!`, or a `driver-eval!` after a
`driver-load-file!`). They are cache hits that copy:

| Root loaded | Add loads of |
|---|---|
| `examples/aloemacs/main.aloe` | `examples/aloemacs/file.aloe`, `examples/aloemacs/editor.aloe`, `lib/text.aloe`, `lib/fs.aloe` |
| `examples/aloemacs/file.aloe` | `examples/aloemacs/editor.aloe`, `lib/text.aloe`, `lib/fs.aloe` |
| `examples/aloemacs/editor.aloe` | `lib/text.aloe` |

Put them right after the root load. When the root load is the last
expression of a helper (its line also closes the helper), put them
right before it, so the helper's result is unchanged. A helper that
loads `(if main? main-path file-path)` gets all four after it
(`echo-session.rkt`, `kill-session.rkt`, `search-session.rkt`); the
`(if file? file-path editor-path)` helper in `safe-cells.rkt` gets
`lib/text.aloe`, `editor.aloe`, and `lib/fs.aloe` before it. A root
load inside a `check-exn` thunk or a `parameterize` that captures
output stays as it is; the scratch run needed none of those changed.

Files (under `tests/aloemacs/` unless noted): `buffer-collection`,
`buffer-session`, `buffer-value`, `completion-frame`,
`completion-page-frame`, `completion-page-session`,
`completion-session`, `echo-session`, `editor-keys`, `file-session`,
`frame`, `idle-echo`, `index-001-editor-movement`, `index-002-frame`,
`int-min`, `keymap-prefix`, `keymap-session`, `kill-session`,
`minibuffer-session`, `minibuffer-value`, `mode-buttons-paint`,
`mode-buttons-press`, `mode-line-one-view`, `mode-line-split-views`,
`motion-editor`, `mouse`, `next-lines`, `prompt-commands-find-file`,
`prompt-commands-save-as`, `prompt-commands-select-buffer`, `runner`
(special case, below), `safe-cell-scan`, `safe-cells`,
`search-session`, `split-drag-bar`, `split-drag-mode-line`,
`split-drag-motion`, `split-drag-weights`, `text-line-length`,
`undo-editor`, `undo-session`, `viewport-editor`, `viewport-top`,
`visited-unchanged`, `window-bars-one-view`, `window-bars-split`,
`window-pictures`, `window-point`, `windows-buffer-identity`,
`windows-delete-and-other`, `windows-layout-and-rendering`,
`windows-lock`, `windows-split`, `windows-state-foundation`,
`windows-state`; and `tests/parenthetical-construction/session.rkt`
(after its `driver-load-file!` of `main.aloe`).

### B. MPL (23 files)

`tests/checkpoint-29.rkt` through `tests/checkpoint-51.rkt` each build a
setup string whose first line is exactly
`(format "(load ~s)\n" (path->string core-path))`. After that line add
six more, loading `math.aloe`, `sym.aloe`, `sum.aloe`, `num.aloe`,
`prod.aloe`, and `pow.aloe` from the same directory (the manager used
`(path->string (build-path core-path 'up "sym.aloe"))`, which the load
path resolves). `tests/checkpoint-51.rkt` also loads `core.aloe` into a
REPL driver with `driver-load-file!`; after that line add a
`driver-eval!` load of `sym.aloe` into the same driver.

### C. Gel (22 files)

A test that loads a Gel root then uses names from the files it loads:

| Root loaded | Add loads of |
|---|---|
| `gel/stack.aloe` | `gel/menu.aloe` |
| `gel/loop.aloe` | `gel/stack.aloe`, `gel/menu.aloe` |
| `gel/main.aloe` | `gel/loop.aloe`, `gel/stack.aloe`, `gel/menu.aloe` |

A `(format "(load ~s)" (path->string <root>))` string passed to
`eval-source` or `typecheck-source` becomes one string with the extra
loads after the root's. A `(load-runtime! <root> ...)` helper call is
followed by the same call for each extra file. A
`(void (driver-load-file! <driver> <root> (open-output-string)))` is
followed by `driver-eval!` loads into that driver.

Files: `tests/checkpoint-59.rkt`, `61`, `62`, `63`, `65`, `66`, `67`,
`68`, `69`, `70`, `71`, `72`, `73`, `74`, `75`, `76`, `77`, `78`, `79`,
`80`, `81`, `82`. Two of them need more:

- `tests/checkpoint-71.rkt` and `tests/checkpoint-72.rkt` inject `term`
  with `env-define!` on the environment `make-top-level-env` returns.
  That is now the interactive environment, which a file does not see.
  Inject on its base instead: `(env-define! (env-base environment) 'term ...)`
  (and `env-base` added to their `(only-in "../aloe/env.rkt" ...)`).
  This is what `driver-inject-host!` does.
- `tests/checkpoint-72.rkt` also has two strings that load `loop.aloe`
  and then use `GelStack` and `gel-empty-stack` in the same string
  (`"(load ~s) ((GelStack new (List empty)) push 10)"` and
  `"(load ~s) ((gel-empty-stack push 1) push 2)"`); each gets a load of
  `gel/stack.aloe` after the first.

### D. Boids (6 files)

`tests/checkpoint-15.rkt`, `17`, `18`, `19`, `21`, `22` check or
evaluate `boids.aloe` with `#:source-path boids-path` into an
environment and later use `Point`. After each such top-level form, add
a load of `examples/point.aloe` into the same environment with the
same operation (`(typecheck-source (format "(load ~s)" ...) env)` or
`(eval-source ... env)`).

### E. Special cases

- **`tests/checkpoint-86.rkt`.** After its
  `(check-equal? (driver-load-file! state point-path load-output) '())`
  add the same check for `gel/stack.aloe`, mirroring §7.
- **`tests/checkpoint-20.rkt`.** Its last assertion ("Nested relative
  loads are allowed and share bindings with their caller") pins the old
  rule. Replace it with: a load of `tests/fixtures/load-nested-a.aloe`
  followed by `nested-value` raises `unbound symbol: nested-value`
  (`load-nested-a.aloe` defines nothing; `nested-value` is
  `load-nested-b.aloe`'s); and a program that loads
  `load-nested-a.aloe`, then `load-nested-b.aloe`, then reads
  `nested-value` is `7`. Reword the comment to say so.
- **`tests/aloemacs/runner.rkt`.** In "main loads an exact checked
  starting state into only one driver", the loop after
  `driver-load-file!` of `main.aloe` asserts every name is bound. Assert
  the new rule instead: `aloemacs-editor` is bound in `state` and not in
  `fresh-state`; `AloemacsPrompt`, `AloemacsCompletionScan`,
  `AloemacsBuffer`, `AloemacsBuffers`, `AloemacsSession`,
  `AloemacsEditor`, `Text`, `Fs`, and `Path` are unbound in both. Every
  later assertion in that case uses only `aloemacs-editor` and `fs-host`
  and stays.
- **The keymap redefinitions (decided by the human, 2026-10-14).** Two
  tests replace `aloemacs-global-keymap` at the prompt so that
  `file.aloe`'s idle dispatch uses a test keymap. File modules make that
  impossible by design: `file.aloe`'s methods resolve their own
  keymap. Delete those steps:
  - `tests/aloemacs/buffer-session.rkt`, in "test-only maps follow
    pending consumption and search precedence": delete the four
    statements after `(same-session st '(active handle-key "find") 'active)`
    (the `def!` of `aloemacs-global-keymap`, the `def!` of `idle`, and
    the two `same-session` sends on `idle`), and close the `for` loop on
    that line instead.
  - `tests/aloemacs/keymap-session.rkt`: delete the whole test case
    "idle dispatch uses a bound character before the map's optional
    default".

  Both files also take the group A loads. Production idle dispatch
  stays covered by "production maps keep their exact commands, prefix
  and idle misses".
- **`tests/modules/000-run-once.rkt`.**
  - In "a keyed root runs once": `box-root.aloe` defines nothing
    itself, so after the first `driver-load-file!` of it, `Box` is not
    at the prompt. Add `(driver-eval! file-state (load-datum box-path))`
    (a hit) before `(define box-class ...)`.
  - In "a failed load can be tried again": a failed load copies
    nothing. Replace `(check-equal? (driver-eval! state 'before-failure) 1)`
    with `(check-false (env-bound? (driver-runtime-environment state) 'before-failure))`.
- **`tests/modules/004-method-records.rkt`.** In "the base tables are
  per base", the libraries record the **base**: compare against
  `(type-environment-base (driver-type-environment state))` and
  `(env-base (driver-runtime-environment state))`. After the prompt's
  `define-methods Int ... thrice`, the `Int` records are `min` and
  `max` at the base and `thrice` at the interactive environment
  (`driver-type-environment` / `driver-runtime-environment`). Require
  `type-environment-base` from `(submod "../../aloe/type.rkt" load-cache)`,
  `env-base` from `aloe/env.rkt`, and `take`/`drop` from `racket/list`
  as needed.
- **`tests/modules/005-conformance.rkt`.** In "a loaded class without
  its methods fails at the root's end", `after-load` now lives in the
  root's file environment and cannot be seen. Replace the
  `type-environment-bound?` check with: `driver-load-file!` of a new
  fixture `tests/modules/fixtures/sym-late-error.aloe`, exactly

  ```scheme
  (load "../../../examples/mpl/sym.aloe")

  (define after-load (1 + "a"))
  ```

  into a fresh driver raises exactly
  `typecheck: Int + expects an Int argument`: the root's own later
  form is checked before conformance runs. Keep the `env-bound?` check.

## Tests

### Focused proof: `tests/modules/006-file-environments.rkt`

Write it first and run it against the tree as you found it; report
which cases fail. Cases 1, 5, 6, and 10 fail there, and so do the
`env-base` parts of 2 and 12: `env-base` does not exist yet, so for
that first run reach it with `dynamic-require` (as 005's implementer
did for its hook) or the file will not compile. The rest pin behavior
that holds before and after.

Use drivers, `aloe/main.rkt` environments, and raw environments as
named. Observe identity with `eq?` on runtime values; observe binding
with `env-bound?` / `type-environment-bound?`; pin error messages
exactly. Files that must use an unbound name go in a temporary
directory under `/tmp`, loaded by absolute path.

1. **A load copies only the file's own names.** In a driver, after a
   load of `examples/aloemacs/editor.aloe`, `AloemacsEditor`,
   `UndoFrame`, and `safe-cell-controls` are bound in both halves and
   `Span`, `Text`, and `Position` are not. After a load of
   `lib/text.aloe`, `Span` is bound. In a file: a temporary file that
   loads `editor.aloe` by absolute path and then
   `(define probe Span)` fails `driver-load-file!` with exactly
   `typecheck: unbound symbol: Span`; the same file with
   `(define probe safe-cell-controls)` loads.
2. **`Option` is the base's.** After `(load ".../lib/option.aloe")` at
   the prompt, the runtime `Option` is `eq?` to
   `(env-lookup (env-base R) 'Option)`. After the prompt defines the
   SPEC §3.1 `Option`, `("abc" find "b" 0)` still has the base class:
   `(check found ("abc" find "b" 0))` holds for a `found` made before.
3. **One `lib/text.aloe` per base.** In a driver, load `lib/text.aloe`
   and capture `Text`; load `examples/aloemacs/editor.aloe` and
   `examples/aloemacs/file.aloe`, then `lib/text.aloe` again: `Text` is
   still `eq?`, and `Option` is still `eq?` to the base's.
4. **A second root unions; a repeat copies again.** In a driver with a
   `term` injected, `driver-load-file!` of `gel/main.aloe` then of
   `examples/point.aloe`: `gel-main` and `Point` are both bound. A
   second `driver-load-file!` of `examples/point.aloe` returns `'()` and
   `Point` is still `eq?`.
5. **`eval-source` and the raw environment.** On an `aloe/main.rkt`
   `make-top-level-env` `E`: `eval-source` of `examples/boids.aloe`'s
   text with its `#:source-path` binds `demo` in `E` but not `Point`, and
   `(eval-source "(((demo step) flock) len)" E)` is `3`; an unkeyed
   `eval-source` of `(load "<point.aloe>") (Point new 1 2)` into `E`
   binds `Point`. On a raw `make-top-level-env` from `aloe/env.rkt`
   `RAW`: the same keyed call, then `(((demo step) flock) len)` through
   `eval-source` on `RAW` is `3`, while `(env-bound? RAW 'demo)` is
   `#f` and `(env-bound? RAW 'Option)` is `#t`.
6. **Keyed and unkeyed ports.** `driver-load-port!` with a
   `#:source-path` in the fixtures directory of the text
   `(load "<box.aloe>") (define-class KeyedThing (fields) (methods))`
   binds `KeyedThing` at the prompt and not `Box`. In another driver the
   same text without a source path binds both.
7. **Gel end to end.** In a driver with a scripted `term` that answers
   `"q"` (as `tests/checkpoint-86.rkt` builds one), `driver-load-file!`
   of `gel/main.aloe`, `examples/point.aloe`, and `gel/stack.aloe`, then
   `driver-eval!` of `host/racket/gel-run.rkt`'s expression
   `(gel-main call ((gel-empty-stack push (Point new 1 2)) push (Point new 10 20)))`,
   raises nothing.
8. **`matching-picks` runs where it was written.** In a driver that
   loaded `gel/loop.aloe`, `gel/stack.aloe`, and `gel/menu.aloe`, the
   program `tests/checkpoint-80.rkt` typechecks (its `rows-80`,
   `row-80`, `stack-80`, and `(stack-80 matching-picks row-80)`) has type
   `GelPicks` and runs.
9. **A later load replaces a prompt name.** In a driver,
   `(define-class Point (fields) (methods))` at the prompt, then a load of
   `examples/point.aloe`: `Point` is now the file's class (not `eq?` to
   the prompt's) and `(Point new 1 2)` typechecks. (Slice 3f makes this
   an error.)
10. **`define-methods` runs in the file that wrote it.** Fixtures:
    `holder.aloe` `(define-class Holder (fields) (methods))`;
    `holder-helper.aloe` `(define helper-value 41)`;
    `holder-methods.aloe` loading both and adding
    `(define-methods Holder (methods (answer () Int (helper-value + 1))))`.
    At the prompt, load `holder.aloe` and `holder-methods.aloe`:
    `((Holder new) answer)` is `42`, and `helper-value` is not bound at
    the prompt.
11. **Two drivers.** A driver that loaded `box.aloe` binds `Box`; a
    second fresh driver does not.
12. **Hosts live on the base.** In a driver that loaded `box.aloe`,
    `driver-inject-host!` of `'Box` raises (already bound), and of
    `'fs-host` with an fs double succeeds and binds `fs-host` in
    `(env-base R)`. A fixture `uses-fs-host.aloe`,
    `(define the-host fs-host)`, then loads without error.
13. **Hover.** `query-expression-at` on
    `tests/editor/expression-query/fixtures/003-public-query/root.aloe`
    at `(Loaded new 7)` gives `'Loaded` (a class a nested load copied);
    on `tests/editor/lsp/fixtures/point.aloe` at `(Point new 1 2)` gives
    `'(Point Int)` (a class the buffer defines); on
    `examples/mpl/sym.aloe` at position 1 raises exactly
    `typecheck: class Sym does not implement protocol Math method show`.
14. **MPL conforms.** `driver-load-file!` of `examples/mpl/core.aloe`
    into a fresh driver returns `'()`.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/modules/006-file-environments.rkt
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

Then run every test file alone (each already compiled) and confirm each
exits 0; the parallel summary is not the inventory.
`tests/aloemacs/window-pictures.rkt` has a 30 ms timing bar that can
fail under parallel load; rerun it alone before calling it a failure.

After the `.rkt` edits, rebuild the launch bytecode with
`raco make host/racket/aloemacs-run.rkt host/racket/gel-run.rkt bin/aloe`
and confirm `./bin/aloe --quit tests/modules/fixtures/box-root.aloe`
still prints `3`.

The checkpoint is complete when:

- the focused proof passes, and its first run against the tree as you
  found it was reported;
- every test file passes, and the only edits to existing tests are the
  ones in **Migration**;
- no `.aloe` file under `examples/`, `lib/`, or `gel/` changed;
  `aloe/parse.rkt`, `aloe/lsp.rkt`, and the hosts other than
  `gel-run.rkt` are untouched;
- `SPEC.md`, `docs/decisions.md`, and the two editor specs carry exactly
  the text above;
- the whitespace check is clean (also for new, untracked files) and the
  file scope was respected.

Report the results and stop. Do not commit. Do not start slice 3f.

## Non-goals

- The collision error, origins, or refusing a file's definition of a
  base name (slice 3f).
- Defining paths, `pathed-type`, or hover `from:` lines (layer 4).
- `import`, export lists, private names, prefixes, a load path.
- Per-importer method tables or scoped selectors. `define-methods`
  still mutates the one class record.
- Any `.aloe` change under `examples/`, `lib/`, or `gel/`, including
  splitting `file.aloe` or making a session carry its own keymap.
- Dirty-buffer overlays for nested loads, or other editor features.
