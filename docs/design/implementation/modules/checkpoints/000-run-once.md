# modules 000 — Run-once

**Status: Ready to implement.** Human review of this checkpoint
precedes its implementation.

If you have been told to read this file, it is the whole assignment.
It carries every rule this slice needs. The spec sections it names
are the authority behind it; read them if a rule here seems to need
more context, and do not implement anything else they describe.

## Goal

`load` runs a resolved path once per base. Each base gets a load
cache in the checker and one in the evaluator. A second load of the
same path with the same bytes runs nothing. A second load of the
same path with different bytes is a type error that installs
nothing. The list, string, and int libraries a default environment
installs are already-loaded entries.

The spelling stays `(load "path.aloe")`. The environment stays
shared: a load still writes every name the file defines, and every
name its own loads define, into the loading environment. No `.aloe`
file changes. No name a load introduces changes.

Three bugs end here. Each fails on today's tree (manager probe,
2026-10-13):

- a value built from a loaded class, passed where that class is
  expected after a second load of the file:
  `typecheck: type mismatch: expected Box, got Box`;
- the same with `lib/option.aloe`:
  `typecheck: type mismatch: expected (Option Int), got (Option Int)`;
- a keymap built from a loaded class, used by a later file that
  loads the class file again:
  `typecheck: generic instantiation mismatch for method run`.

This is the first checkpoint of the series. Stop when the focused
proof and the whole suite pass. Do not start the explicit-load layer.

## Authority, identity, and starting point

- Identity: **modules 000**, filed as
  `docs/design/implementation/modules/checkpoints/000-run-once.md`.
  A local language series on branch `experiment/2026-10-12-modules`.
  It takes no global number and gets no `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../workflow.md), root
  [AGENTS.md](../../../../../AGENTS.md), and
  [SPEC.md](../../../../../SPEC.md) before product edits. `SPEC.md`
  is Aloe law, amended only as **Language law** below says.
  Evaluation is send with a literal selector. Function objects run
  only through `call`. No inheritance, mutation, macros, implicit
  Int/Float coercion, or new special forms.
- [../spec.md](../spec.md) governs. This checkpoint narrows it to
  one slice:
  - §2: the vocabulary (base, keyed root, unkeyed port, resolved
    path, displayed path, cache, entry).
  - §3: the product boundary and the out-of-scope list.
  - §4: this layer. §4.1 rules, §4.2 error text, §4.3 seeds, §4.4
    keyed roots, §4.5 tests, §4.6 existing tests.
  - §12, row 000: the `SPEC.md` and `docs/decisions.md` text.
- Later slices change what this one builds. Do not anticipate them:
  no file environments, no copying, no `Option` install, no origins,
  no paths in hover or mismatches.

### Current tree

Line numbers are from the tree at issuance (2026-10-13) and are
approximate; search before editing.

- `aloe/parse.rkt:93` `load-expr-resolved-path`: `simplify-path` of
  `path->complete-path` against the loading file's directory, without
  the filesystem. A `load` parsed with no source directory resolves
  against `(current-directory)`. `read-program` (line 784) accepts a
  string or an input port and a `#:source-path`. This file is not
  edited.
- `aloe/type.rkt`: `type-environment` (line 71) has `bindings`,
  `parent`, `int-class`, `string-class`. `make-type-environment`
  (line 98) is the raw kernel constructor.
  `make-local-type-environment` (line 116) copies `int-class` and
  `string-class` from its parent. `typecheck-program` (line 547) is
  the root check when entered at depth zero and runs protocol
  conformance at its end. `typecheck-load!` (line 563) checks
  missing file, then the `current-typecheck-load-paths` cycle stack,
  then reads and checks the file into the same environment.
  `raise-type-error` (line 87) prefixes `typecheck: `. The
  `driver-host-injection` submodule (line 1995) is the existing
  pattern for a narrow hook the driver needs.
- `aloe/env.rkt`: `top-level-env` (line 18) has the same four
  fields. `make-top-level-env` (line 24) is the raw kernel
  constructor; `make-local-env` (line 39) copies `int-class` and
  `string-class`.
- `aloe/eval.rkt:39` `eval-load!`: missing file, then the
  `current-eval-load-paths` cycle stack, then reads and evaluates the
  file into the same environment.
- `aloe/library.rkt`: three promises, each reading one library with
  `read-program` and `#:source-path` the runtime path
  (`../lib/list.aloe` and so on). Exports the three
  `*-library-expressions` procedures.
  `tests/int-methods/001-library.rkt` and `tests/checkpoint-115.rkt`
  read those expressions.
- `aloe/main.rkt`: `make-type-environment` (line 29) and
  `make-top-level-env` (line 36) install the three libraries;
  `make-top-level-env` also builds a paired checker environment and
  memoizes it in `runtime-type-environments`.
  `type-environment-for` (line 46) is the fallback for a raw runtime
  environment: it builds a checker environment and installs the
  libraries into the raw one. `typecheck-source` (57), `eval-datum`,
  `eval-program`, and `eval-source` (74) follow.
- `aloe/driver.rkt`: `make-driver` (line 30) builds raw environments
  and installs the libraries into both. `driver-load-port!` (line
  99) reads the whole program, checks it, then evaluates each
  expression and prints each non-void result.
  `driver-load-file!` (line 126) opens the file and calls
  `driver-load-port!` with `#:source-path`.

Facts the manager probed on today's tree, 2026-10-13:

- A second `(load ".../lib/list.aloe")` into a driver, into
  `aloe/main.rkt`'s `make-top-level-env`, into a raw runtime
  environment through `eval-source`, or into `make-type-environment`
  through `typecheck-source` raises
  `typecheck: ambiguous message: fold`: `define-methods List`
  appends a second copy of each method.
- A second load of `lib/string.aloe` or `lib/int.aloe` succeeds and
  appends duplicates: `type-signature-specs` of `String` grows from 9
  rows to 10, of `Int` from 13 to 15; the runtime method lists grow
  from 1 to 2 and from 2 to 4.
- Hover inside `lib/list.aloe` (`query-expression-at`) raises the
  same `ambiguous message: fold`, because the query rechecks the
  file into an environment that already installed it. That stays
  as it is after this checkpoint. Slice 3a fixes it. Do not fix it
  here.
- The parser accepts only untyped `fn` parameters,
  `(fn (x y) body)`. Put type annotations in class methods, as the
  fixtures below do. A `define-class` needs a `(methods ...)`
  section, which may be empty.

### Size

Product edits are a cache field and its propagation in two structs,
the read-once bytes in `aloe/library.rkt`, one load rule per half,
keyed roots in two modules, and seeds at four install sites. Expect
roughly two hundred product lines and one focused test file. If it
does not fit one conversation, stop and say so.

## Exact file scope

### May create or edit

- `aloe/env.rkt`: the evaluator cache field and its propagation.
- `aloe/type.rkt`: the checker cache field, its propagation, the
  checker's load rule, and the hooks `aloe/main.rkt` and
  `aloe/driver.rkt` need, exposed through a `module*` submodule as
  `driver-host-injection` is, not through the main `provide`.
- `aloe/eval.rkt`: the evaluator's load rule and the hooks the two
  callers need. New exports are allowed.
- `aloe/library.rkt`: bytes, resolved paths, and the displayed-path
  procedure.
- `aloe/main.rkt`: seeds at its three install sites; keyed
  `typecheck-source` and `eval-source`.
- `aloe/driver.rkt`: seeds in `make-driver`; keyed
  `driver-load-port!` and so `driver-load-file!`.
- `SPEC.md` and `docs/decisions.md`: only the text in **Language
  law**.
- `tests/modules/000-run-once.rkt`, new.
- `tests/modules/fixtures/`, new: the fixtures named in **Tests**.

### Must leave untouched

- Every `.aloe` file: `examples/`, `lib/`, `gel/`, `archive/`, and
  the existing fixtures under `tests/`.
- `aloe/parse.rkt`, `aloe/expression-query.rkt`,
  `aloe/completion-query.rkt`, `aloe/lsp.rkt`, everything under
  `aloe/private/`, and `host/racket/`.
- The `provide` lists of `aloe/main.rkt` and `aloe/driver.rkt`.
  Tests use only names those modules, `aloe/env.rkt`, and
  `aloe/type.rkt`'s main `provide` already export.
- Every existing test. §4.6 of the spec says none observes a re-run
  on purpose. If one fails, stop and report the file, the
  assertion, and the failure; do not edit it.
- `CHECKPOINTS.md`, `docs/checkpoints/`, `docs/philosophy.md`, this
  folder's `README.md`, `charter.md`, `spec.md`, this checkpoint, and
  every other design document.

These lists are exhaustive. If another file is necessary, stop and
send this checkpoint back.

## Required behavior

### 1. Words

- **Base.** The checker environment and the evaluator environment
  that `make-driver` builds, and that `make-type-environment` and
  `make-top-level-env` in `aloe/main.rkt` build. In this checkpoint
  the one shared environment is the base and the interactive
  environment at once.
- **Raw constructors.** `make-type-environment` in `aloe/type.rkt`
  and `make-top-level-env` in `aloe/env.rkt`. They carry an empty
  cache and install nothing.
- **Resolved path.** For a `load`, what `load-expr-resolved-path`
  returns. For a root, `simplify-path` of `path->complete-path` of
  its source path, with `#f` for the filesystem argument, whether or
  not a file exists there. Cache keys are path values, never
  strings, compared with `equal?`. Two spellings of one file are one
  key.
- **Keyed root.** `driver-load-port!` with `#:source-path` (so
  `driver-load-file!` and `host/racket/term-run.rkt`);
  `typecheck-source` with `#:source-path`; `eval-source` with
  `#:source-path`. Its key is the resolved source path. Its bytes
  are the bytes read from the port, or the UTF-8 encoding of a
  string input.
- **Unkeyed.** `driver-load-port!` without a source path, a string
  given to `typecheck-source` or `eval-source` without one,
  `driver-eval!`, `driver-prepare!`, `eval-datum`, `eval-program`,
  the REPL, and the editor queries. Never a cache entry. Loads
  nested inside them are ordinary loads and use the cache.
- **Displayed path.** The resolved path relative to the repository
  root, with `/` separators, when the resolved path is inside that
  root; otherwise the resolved path as a string. The repository root
  is the parent of `aloe/`, found from a runtime path in
  `aloe/library.rkt` the way it already reaches `../lib/`. Inside
  means the root's path elements are a prefix of the path's
  elements; a string prefix is wrong (a sibling directory
  `2026-09-02-aloe-racket-old/` is outside). Examples:
  `<root>/lib/text.aloe` → `lib/text.aloe`;
  `/tmp/aloe-x/box.aloe` → `/tmp/aloe-x/box.aloe`.

### 2. The caches

- Add one cache field to `type-environment` and one to
  `top-level-env`. The raw constructors make a fresh empty cache.
  `make-local-type-environment` and `make-local-env` share the
  parent's cache by reference, the way they share `int-class` and
  `string-class`. A child never has a cache of its own.
- A cache is a mutable `equal?`-keyed hash from resolved path to
  entry. A checker entry holds a state, `running` or `completed`,
  the source bytes, and exports. An evaluator entry holds a state
  and exports. Exports are always `'()` in this checkpoint and
  nothing reads them.
- Two bases never share a cache. Each `make-driver`, each
  `aloe/main.rkt` construction, and each editor query's fresh
  environment starts empty and then records the seeds of §6.

### 3. The checker's rule

One procedure in `aloe/type.rkt` applies this rule for a nested
`load` (`typecheck-load!`) and for a keyed root. For a path:

1. A nested `load` of a missing file raises today's
   `load file not found: <resolved path>`, before the cache.
2. A running entry, or the path on today's cycle stack, raises
   today's `load cycle: <resolved path>`.
3. Read the bytes: the file's, for a `load`; the root's, for a
   keyed root.
4. A completed entry with equal bytes is a **hit**. Nothing is
   parsed or checked. A `load` is `Void`.
5. A completed entry with different bytes raises the error in §7,
   before anything from the new bytes is parsed or installed.
   Bindings from the earlier load stay as they are.
6. No entry is a **miss**. Record a running entry with the bytes.
   Parse the expressions from those bytes: `read-program` on a byte
   port with `#:source-path` the source path, so source locations
   are what they are today. Check them as today: a nested load
   through `typecheck-program` at the current depth plus one with
   the path on the cycle stack; a keyed root through
   `typecheck-program` entered at depth zero, so it is still the
   root check and conformance still runs at its end. Then mark the
   entry completed.
7. If the check exits without completing, by raising or any other
   escape, remove the running entry, then let the exit continue. A
   later load tries again. Entries that nested loads completed
   before the failure stay.

The criterion is the bytes, never a modification time.

### 4. The evaluator's rule

One procedure in `aloe/eval.rkt` applies this rule for a nested
`load` (`eval-load!`) and for a keyed root:

1. A nested `load` of a missing file is today's
   `load file not found`, before the cache.
2. A running entry, or the path on today's cycle stack, is today's
   `load cycle`.
3. A completed entry is a hit, with no byte comparison. Nothing is
   read or run. A `load` evaluates to void.
4. Otherwise record a running entry, evaluate (a `load` reads and
   parses its file as today), then mark it completed.
5. If evaluation raises, remove the running entry and re-raise.
   Definitions it already made stay.

The evaluator relies on the checker having checked first, which
every entry point already does.

### 5. Keyed roots

- `driver-load-port!` with `#:source-path` reads the port to the
  end into bytes, applies §3 to the whole program, then §4. On a
  miss it evaluates each expression and prints each non-void result
  exactly as today. On an evaluator hit it returns `'()` and writes
  nothing. `driver-load-file!` therefore returns `'()` on its
  second call for one path in one driver. If the checker hit but the
  evaluator has no entry (a `driver-prepare!` of a `load` whose
  thunk never ran can leave that state), the evaluator parses the
  same bytes and runs them as a miss.
- `typecheck-source` with `#:source-path` applies §3 in the given
  checker environment. A miss returns what it returns today; a hit
  returns `Void` (`type->datum` gives `'Void`).
- `eval-source` with `#:source-path` applies §3 in the paired checker
  environment that `type-environment-for` gives, then §4 in the
  given runtime environment. A miss returns what it returns today;
  a hit returns void.
- A keyed root and a nested `load` that resolve to one path share
  one entry. A `driver-load-file!` of a file followed by
  `(load "that file")` with unchanged bytes is a hit, and the other
  way around.
- A keyed root whose path has no file on disk
  (`tests/checkpoint-86.rkt` passes `#:source-path
  "bad-terminal-program"` with a string port) is keyed by that
  resolved name; its bytes come from the port.
- Unkeyed inputs read and run exactly as today. Running the same
  unkeyed text twice runs its definitions twice.
- `driver-load-port!` without a source path, `driver-eval!`,
  `driver-prepare!`, `eval-datum`, and `eval-program` do not change.

### 6. Seeds

- `aloe/library.rkt` reads each of `lib/list.aloe`,
  `lib/string.aloe`, and `lib/int.aloe` once per process into bytes
  and parses its expressions from those bytes, with the same
  `#:source-path` as today. The promise stays a process-wide read;
  it is not a cache entry. It exports, per library, the expressions
  (the existing procedure names, returning the same values with the
  same source locations), the bytes, and the resolved path; and it
  exports the displayed-path procedure the checker uses.
- `make-driver`, `make-type-environment` and `make-top-level-env`
  in `aloe/main.rkt`, and the `type-environment-for` fallback
  install the three libraries exactly as today, in the same order,
  and then record each as a completed entry under its resolved path
  in each cache that site built: a checker entry with the bytes the
  install parsed, an evaluator entry, exports `'()`.
- The raw constructors record nothing. `lib/option.aloe` is not a
  seed.

So a later `(load ".../lib/list.aloe")` of the same bytes is a hit:
`define-methods List` does not run again and the method tables keep
their length. A keyed root at a library's path with different bytes
is the changed-bytes error.

### 7. Error text

The changed-bytes error is an `exn:fail:aloe-type`, raised through
`raise-type-error`, with exactly this message, where the path is
the displayed path:

```text
typecheck: load file changed: lib/text.aloe; this version does not reload a changed file
```

`load file not found` and `load cycle` keep today's text and print
the resolved path, not the displayed path.

### 8. What stays

- Missing-file errors, cycle errors, and path resolution.
- The shared environment: a miss checks and evaluates into the
  loading environment, as today. A hit binds nothing new, because
  the first load already wrote every name.
- `driver-prepare!`. Its thunk's first run reads a loaded file that
  was checked earlier; a change in between is outside this series.
- The editor queries. They still check the queried file's
  expressions into the query's fresh environment, unkeyed. Loads
  nested in that file use the cache. Hover inside `lib/list.aloe`
  still raises `ambiguous message: fold`.
- `define-methods`, overloads, conformance, `Option`, and
  `String find`.

## Language law

Edit `SPEC.md` §11, first bullet only. Replace it with:

> - `load` reads, typechecks, and evaluates another Aloe file in the
>   same environment, resolving relative paths from the loading file
>   before the current directory and project root. A resolved path
>   runs once per base: a later `load` of the same path with the same
>   bytes runs nothing, and a later `load` of the same path with
>   different bytes is a type error. The list, string, and int
>   libraries installed in a default environment count as already
>   loaded.

Add one section at the end of `docs/decisions.md`, in that file's
`## Title (date)` shape, dated the day you land it:

> ## Run-once load (YYYY-MM-DD)
>
> Decided: a load cache per base, keyed by resolved path, in the
> checker and the evaluator; the checker compares bytes and rejects a
> changed file; the evaluator reuses by path. Rejected: a process-wide
> cache, a modification-time criterion, a byte comparison in the
> evaluator, and any reload of an edited file.

Do not edit the 2026-09-08 "Option library" entry; slice 3a does.

## Tests

Write `tests/modules/000-run-once.rkt` first and run it against the
unmodified product. Groups 1–7, 9, 10, and 11 must fail there.
Groups 8, 12, and 13 pin behavior that does not change and pass
before and after. Report what the first run showed.

Follow the driver style of `tests/checkpoint-20.rkt` and
`tests/aloemacs/keymap-session.rkt`. Use `rackunit` `test-case`s and
a fresh driver or environment per group unless the group says
otherwise. Build fixture paths with `define-runtime-path`. A `load`
inside a datum or a string uses an absolute path built from those
runtime paths, except where group 5 asks for a relative spelling.
Observe runtime class identity with `env-lookup` on
`driver-runtime-environment` (or on an `aloe/main.rkt` environment)
and `eq?`. Observe checker class identity by typechecking a `check`
of an old value against a new construction. Count methods with
`type-signature-specs` on `(list-type (int-type))`, `(string-type)`,
and `(int-type)` in the checker, and with `list-class-object-methods`,
`string-class-object-methods`, and `int-class-object-methods` at
runtime. Compute counts before and after; do not hard-code them.

Files that change on disk go in a temporary directory:
`make-temporary-directory` with `#:base-dir "/tmp"`, deleted with
`delete-directory/files` when the group ends, as
`tests/checkpoint-106.rkt` does. Never write under `lib/`,
`examples/`, or `tests/modules/fixtures/` from the test.

### Fixtures

Create these under `tests/modules/fixtures/`, exactly. The manager
probed each on today's tree.

`box.aloe`:

```scheme
(define-class Box
  (fields
    (value Int))
  (methods
    (get () Int
      (self value))))
```

`box-root.aloe` (its result row is how a run shows):

```scheme
(load "box.aloe")

((Box new 3) get)
```

`command.aloe`:

```scheme
(define-class Command
  (fields
    (name String))
  (methods
    (label () String
      (self name))))
```

`keymap.aloe`:

```scheme
(load "command.aloe")

(define commands
  (List of (Command new "save") (Command new "quit")))
```

`keymap-user.aloe`:

```scheme
(load "command.aloe")

(define-class Runner
  (fields)
  (methods
    (run (c Command) String
      (c label))))

(define first-label
  ((Runner new) run (commands first)))
```

`failing-check.aloe` (checks, then fails at run time):

```scheme
(define before-failure 1)

(check 1 2)
```

### Focused proof: `tests/modules/000-run-once.rkt`

1. **Box.** `(load box)`; `(define b (Box new 3))`; capture the
   runtime `Box`; `(load box)` again. `(check b (Box new 3))`
   typechecks and runs, and the runtime `Box` is `eq?` to the
   captured one.
2. **`(Option Int)`.** The same with `lib/option.aloe`:
   `(define o (Option Some 1))` between two loads, then
   `(check o (Option Some 1))` typechecks and runs; the runtime
   `Option` is `eq?` across the second load.
3. **Keymap order.** `(load keymap)`, `(load command)`,
   `(load keymap-user)`, all through `driver-eval!`. All of it
   typechecks and runs, and `first-label` is `"save"`.
4. **Changed bytes.** In a temporary directory write `changing.aloe`
   as `(define changing-value 1)`.
   - Through `driver-eval!`: load it; rewrite it as
     `(define changing-value 2)` and `(define added-value 3)`; load
     it again. The error is an `exn:fail:aloe-type` whose message is
     exactly §7's with that file's resolved path as a string (it is
     outside the repository). `changing-value` is still `1` at
     runtime, and `added-value` is bound in neither half
     (`env-bound?`, `type-environment-bound?`). Rewrite the original
     bytes and load again: no error, `changing-value` is `1`.
   - The same through `driver-load-file!` on a fresh driver: the
     second call raises the same message; after restoring the bytes
     it returns `'()`.
5. **Two spellings, one key.** In one driver,
   `(load "box.aloe")` with `current-directory` parameterized to the
   fixtures directory, `(define b (Box new 3))`, then a load of the
   absolute spelling `<fixtures>/../fixtures/box.aloe`. Group 1's
   `check` and `eq?` hold.
6. **Seeds.** For each of `lib/list.aloe`, `lib/string.aloe`, and
   `lib/int.aloe`, on a fresh driver:
   - `(load <library>)` through `driver-eval!` raises nothing, and
     the checker rows and runtime methods of `List`, `String`, or
     `Int` have the same count before and after;
   - `driver-load-port!` of `(open-input-string "(define changed 1)\n")`
     with `#:source-path` the library's path raises exactly
     `typecheck: load file changed: lib/list.aloe; this version does not reload a changed file`
     (with `lib/string.aloe` or `lib/int.aloe`), and `changed` is
     unbound;
   - `driver-load-port!` of the library's own bytes
     (`file->bytes`, through `open-input-bytes`) with that
     `#:source-path` returns `'()`;
   - a second `make-driver`'s `List`, `String`, and `Int` class
     objects are not `eq?` to the first driver's, and a load of the
     library into it is also a hit.

   And through `aloe/main.rkt`, for `lib/list.aloe`: `eval-source`
   of the load into `make-top-level-env` raises nothing;
   `typecheck-source` of the load into `make-type-environment`
   returns `'Void` and leaves the `List` row count unchanged;
   `eval-source` of the load into a raw `make-top-level-env` from
   `aloe/env.rkt` raises nothing. Each of these raises
   `ambiguous message: fold` today.
7. **Diamond.** Load `lib/text.aloe`, capture the runtime `Option`,
   `(define o (Option Some 1))`, load `lib/fs.aloe`. `Option` is
   `eq?` to the captured class and `(check o (Option Some 1))`
   typechecks and runs.
8. **Cycle and missing file.** A load of
   `tests/fixtures/load-cycle-a.aloe` raises
   `typecheck: load cycle: <resolved load-cycle-a.aloe>`, twice in a
   row in one driver. A load of a missing
   `tests/modules/fixtures/no-such-file.aloe` raises
   `typecheck: load file not found: <resolved path>`.
9. **Unkeyed port.** `driver-load-port!` without a source path, twice
   in one driver, of this text, with the absolute path of `box.aloe`
   put in by `format`:

    ```text
    (define-class Local
      (fields
        (n Int))
      (methods))

    (load "<absolute box.aloe>")
    ```

   `Local` after the second run is not `eq?` to `Local` after the
   first; `Box` is `eq?`.
10. **Keyed roots.** The text

    ```text
    (define-class Tally
      (fields
        (n Int))
      (methods))

    ((Tally new 4) n)
    ```

    - `driver-load-port!` twice in one driver with `#:source-path`
      `<fixtures>/keyed-port.aloe` (no such file exists): the first
      returns `'(4)` and writes `"4\n"`; the second returns `'()`
      and writes nothing; `Tally` is `eq?` across them.
    - `driver-load-file!` of `box-root.aloe` twice in one driver:
      `'(3)`, then `'()`; the output port holds `"3\n"` once. A
      following `(load box-root)` through `driver-eval!` is a hit
      (`Box` stays `eq?`).
    - `eval-source` of the text twice into one `aloe/main.rkt`
      `make-top-level-env` with that `#:source-path`: `4`, then
      void; `Tally` is `eq?`.
    - `typecheck-source` of the text twice into one `aloe/main.rkt`
      `make-type-environment` with that `#:source-path`: `'Int`,
      then `'Void` through `type->datum`.
11. **Checker first.** In a temporary directory, load
    `checked.aloe` (`(define checked-value 1)`) through
    `driver-eval!`, so both entries are completed. Rewrite it as
    `(define checked-value 2)` and `(define evaluated-value 3)`.
    `driver-eval!` of the load raises the changed-bytes error;
    `evaluated-value` is not bound at runtime and `checked-value` is
    still `1`.
12. **Two bases.** A driver loads `box.aloe`; a second `make-driver`
    loads it too. Each run is a miss: the second driver's `Box` is
    not `eq?` to the first's.
13. **Failed entries are removed.**
    - In a temporary directory write `broken.aloe` as
      `(define broken (1 + "a"))`. Its load raises a type error.
      Rewrite it as `(define broken (1 + 2))`; its load now succeeds
      and `broken` is `3`. (A leftover running entry would say
      `load cycle`; a completed one would say `load file changed`.)
    - `failing-check.aloe`: its load raises
      `eval-aloe: check failed: 1 => 1 vs 2 => 2`; `before-failure`
      is `1`; a second load raises the same `check failed` error,
      not `load cycle`.

### Existing tests

Today these load one path twice into one environment and re-run it.
After this checkpoint the second load is a hit. Each stays green
without edits; the suite run is the proof.

- The `lib/option.aloe` diamond under `examples/aloemacs/file.aloe`
  (through `editor.aloe` → `lib/text.aloe` and through
  `lib/fs.aloe`): every test under `tests/aloemacs/` that loads
  `file.aloe` or `main.aloe`, `tests/parenthetical-construction/session.rkt`,
  and `host/racket/aloemacs-run.rkt`; `tests/checkpoint-105.rkt`,
  `106`, and `107` where they load `lib/disk.aloe` and `lib/fs.aloe`
  into one driver.
- A root loaded after a nested load of the same file: the editor
  tests that load `file.aloe` and then `main.aloe` into one driver;
  `tests/aloemacs/next-lines.rkt` and `text-line-length.rkt`
  (`lib/text.aloe`, then `editor.aloe`); and
  `tests/editor/completion/002-public-query.rkt` and
  `003-lsp-completion.rkt` (`examples/point.aloe` directly and
  through `boids.aloe`).
- The case "classes and constants load twice" in
  `tests/aloemacs/keymap-session.rkt` builds a fresh driver per
  iteration and is unaffected.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/modules/000-run-once.rkt
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

The checkpoint is complete when:

- the focused proof passes, and its first run against the
  unmodified product was reported;
- the whole suite passes with no existing test edited;
- no `.aloe` file changed, the editor queries and `aloe/parse.rkt`
  are untouched, and the `provide` lists of `aloe/main.rkt` and
  `aloe/driver.rkt` are unchanged;
- `SPEC.md` and `docs/decisions.md` carry exactly the **Language
  law** text;
- the whitespace check is clean and the file scope was respected.

Report the results and stop. Do not commit. Do not start the
explicit-load layer.

## Non-goals

- File environments, the interactive environment as a separate
  object, copying exports, or any change to which names a program
  sees.
- Adding a `load` to any `.aloe` file, or moving `Math`.
- Installing `lib/option.aloe`, changing `String find`, or keying
  the editor queries. Hover inside a base library stays as it is.
- Comparing records in overload selection, a runtime protocol
  record, method records, or conformance over a wider set.
- Origins, the collision error, defining paths, or paths in hover or
  mismatches.
- Reload of an edited file, dependent invalidation, a process-wide
  cache, a modification-time check, or a byte comparison in the
  evaluator.
- `import`, export lists, prefixes, a load path, packages, or a
  module name separate from the path.
- Any edit to `driver-prepare!`, the REPL, or the hosts beyond what
  keyed roots need.
