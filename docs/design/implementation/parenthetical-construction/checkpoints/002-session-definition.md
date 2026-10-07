# parenthetical-construction 002 — The session definition

**Status: Implemented in the working tree and checkpoint-manager reviewed
(2026-10-07).** Issued on 2026-10-07 after review of the accepted spec and
the checking/evaluation predecessor. Its requirements and starting point
below are retained from issuance.

The implementation review confirms that the actual startup definition
matches the spec and checkpoint targets as datums, the runner diff changes
only its explicit expected datum, and the independent session test covers
startup type/value preservation, all fourteen fields, and all seven locals.
The full suite, including this checkpoint's focused tests, passes
**2,650 tests**. `git diff --check` is green. This closing checkpoint
completes the accepted series in the working tree; human review follows.

## Goal

Rewrite only `aloemacs-editor` in `examples/aloemacs/main.aloe` to the
spec's two-`let`, fully labeled startup definition. Update its explicit
source snapshot and prove that the checked startup value is unchanged.

Stop when this consumer slice and its regression tests are green. This is
the closing checkpoint of the series; no further consumer rewrite or
language work belongs here.

If you have been told to read this file, this is the whole assignment.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **parenthetical-construction 002**. File:
  `checkpoints/002-session-definition.md`. Number this locally; do not add
  a global checkpoint or a `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Branch: `experiment/2026-10-06-parenthetical-construction`, created
  from `main` at `987cbd0`. Continue on this branch; a human merges it.
- Read [`docs/workflow.md`](../../../../workflow.md),
  [`SPEC.md`](../../../../../SPEC.md), and
  [`CHECKPOINTS.md`](../../../../../CHECKPOINTS.md) before writing code.
  `SPEC.md` is language law, including the completed `new*` amendments.
- Accepted [../spec.md](../spec.md) §§1–3 govern the series, boundaries,
  tools, and exhaustive scopes. All of §6 governs this slice; §§7–8 supply
  its verification and acceptance obligations. §§4–5 describe completed
  language work. The charter, sketches, earlier conversation, and colon
  experiment are not additional authority.
- Predecessor: **parenthetical-construction 001 — Checking, evaluation,
  and language law** is implemented in the working tree and reviewed
  against its written checkpoint. Its focused verification passes
  **72 tests**, including the host keyword rejection checks. Preserve the
  existing work from 000 and 001; do not reimplement it.
- `main.aloe` still contains its source-relative load and original
  positional startup definition. `tests/aloemacs/runner.rkt` has an
  explicit `expected-main-datums` snapshot and runtime assertions.
  The manager checked §6's target definition in memory: its type is
  `(AloemacsSession FsHost)` and Aloe `check` accepts equality with the
  original positional startup state in the same explicitly injected driver.

Evaluation remains send; selectors are literal; functions execute through
`call`; `let` expands to `fn` plus `call` with parallel bindings. Add no
inheritance, Aloe mutation, macros, implicit Int/Float coercion, or other
special form.

The manager also ran `TMPDIR=/tmp raco test -y tests`: **2,646 tests
passed**. The whitespace check is green. These results verify the
predecessor; this checkpoint's source rewrite and new test remain to be
implemented in a separate conversation.

## Exact file scope

### May create or edit

- `examples/aloemacs/main.aloe`: only replace the `aloemacs-editor`
  definition with the target below. Keep `(load "file.aloe")` unchanged.
- `tests/aloemacs/runner.rkt`: only replace the value of
  `expected-main-datums` with the explicit expected datum for that load and
  the rewritten definition. Leave the comparison and every runtime
  assertion unchanged.
- Create `tests/parenthetical-construction/session.rkt`. Keep focused
  helpers and independent expected source/datum fixtures in this file.
  Use existing checked-driver, parser, type, environment, and filesystem
  test-double interfaces; add no production support.

### Must leave untouched

- Every kernel, parser, checker, evaluator, query, driver, host, library,
  signature-catalog, editor, language-server, and tooling module.
- Every other `.aloe` file, especially `examples/aloemacs/file.aloe` and
  `examples/aloemacs/editor.aloe`; other construction sites are out of scope.
- All other existing tests and fixtures, including this series' grammar,
  law, and editor tests and `tests/aloemacs/windows-state-foundation.rkt`.
- `SPEC.md`, `docs/decisions.md`, `CHECKPOINTS.md`, global checkpoints,
  and this series' README, charter, spec, and checkpoint documents.
- The colon experiment, Gel, Boids, and unrelated working-tree changes.

These lists are exhaustive. If another file or a broader change is
necessary, stop and return this checkpoint to the manager instead of
widening it. If the slice cannot fit one implementer conversation, return
the size finding to the manager.

## Slice requirements

### 1. Exact startup definition

Replace the definition with this target from feature-spec §6. Preserve its
binding names, nesting, values, pair order, and all `if` witnesses,
including their inactive alternatives. Alignment is optional and has no
language meaning. Put no Markdown fence or explanatory prose in the source.

```aloe
(define aloemacs-editor
  (let ((initial-buffer
          (AloemacsBuffer new*
            (editor
              (AloemacsEditor new*
                (text       (Text from-string ""))
                (point      (Position new 0 0))
                (quit       #f)
                (scroll-row 0)
                (scroll-col 0)
                (history    (List empty))
                (mark
                  (if #t
                      (Option None)
                      (Option Some (Position new 0 0))))
                (text-rows  0)))
            (path
              (if #t
                  (Option None)
                  (Option Some (Path new "/typed-none"))))
            (id 0)))

        (inactive-prompt
          (if #t
              (Option None)
              (Option Some
                (AloemacsPrompt new*
                  (label              "")
                  (text               "")
                  (column             0)
                  (completion-note    "")
                  (completion-lines   (List empty))
                  (completion-matches (List empty))
                  (completion-start   0)))))

        (initial-windows
          (AloemacsWindows new*
            (tree
              (AloemacsWindowTree Leaf (AloemacsView new 0 0 0 0 #f)))
            (selected 0)
            (columns  0)
            (rows     0))))

    (let ((initial-buffers
            (AloemacsBuffers new*
              (before         (List empty))
              (current-buffer initial-buffer)
              (after          (List empty))))

          (initial-pending
            (if #t
                (Option None)
                (Option Some aloemacs-global-keymap)))

          (initial-last-submission
            (if #t
                (Option None)
                (Option Some "")))

          (initial-waiting-command
            (if #t
                (Option None)
                (Option Some (AloemacsCommand FindFile)))))

      (AloemacsSession new*
        (buffers         initial-buffers)
        (fs              (Fs new fs-host))
        (echo            "")
        (searching       #f)
        (query           "")
        (origin          (Position new 0 0))
        (wrapped         #f)
        (failing         #f)
        (kill-ring       (List empty))
        (pending         initial-pending)
        (prompt          inactive-prompt)
        (last-submission initial-last-submission)
        (waiting-command initial-waiting-command)
        (windows         initial-windows)))))
```

The inner `let` is the outer `let`'s body and can see `initial-buffer`.
Bindings within either `let` are parallel; do not flatten the two groups
or introduce top-level bindings for these locals. Preserve the `if`
witnesses rather than changing generic inference to accept standalone
`(Option None)`.

These are the only relabeled constructors, with their declaration order:

| Class | Fields |
|---|---|
| `AloemacsSession` | `buffers fs echo searching query origin wrapped failing kill-ring pending prompt last-submission waiting-command windows` |
| `AloemacsBuffers` | `before current-buffer after` |
| `AloemacsBuffer` | `editor path id` |
| `AloemacsEditor` | `text point quit scroll-row scroll-col history mark text-rows` |
| `AloemacsPrompt` | `label text column completion-note completion-lines completion-matches completion-start` |
| `AloemacsWindows` | `tree selected columns rows` |

`Position`, `Path`, `Fs`, and `AloemacsView` stay positional throughout
this definition. `Option None`, `Option Some`, `AloemacsWindowTree Leaf`,
`AloemacsCommand FindFile`, and ordinary sends retain their existing
spelling. Use parentheses; add no colon labels or square-bracket meaning.

### 2. Explicit source snapshot

Replace only the value of `expected-main-datums` in
`tests/aloemacs/runner.rkt` with the literal list that `read` returns for
the unchanged load plus the target definition. Keep the expected datum
explicit; do not obtain it by reading `main.aloe` at test time, loading the
spec, or importing the new session test's fixture.

Keep `source-datums`, the source comparison, and all runtime/runner
assertions unchanged. The existing empty-text, point, option, host
injection, frame, and iteration assertions must pass as written. No
other existing source snapshot needs changing.

### 3. Independent startup preservation test

Use `rackunit` in `tests/parenthetical-construction/session.rkt`:

- Resolve the actual `examples/aloemacs/main.aloe` with
  `define-runtime-path` and load it through `driver-load-file!` in a fresh
  checked driver. Do not test a copied labeled definition instead of the
  actual file.
- Explicitly inject `fs-host` using `make-fs-double` from
  `host/racket/fs.rkt`. Reuse that same injected receiver for both the
  actual and expected values. Do not use the production filesystem or
  inject a capability implicitly.
- Independently construct the original startup state using positional
  `new` and the original `if` witnesses in that same driver. Keep this
  expected datum literal in the test; do not derive it from the actual
  source, its AST, or `expected-main-datums`. It may use test-local helpers
  for the unchanged positional subexpressions, but no `new*` or session
  transition method may construct the expected state.
- Compare the entire actual value with that positional value using Aloe
  `check`. Also compare each of the fourteen session fields so failures
  identify the changed association. Both values must have checked type
  `(AloemacsSession FsHost)`.
- Observe the initial buffer/editor contents, point, empty collections,
  absent options, and initial leaf/view/windows state as below. Use the
  existing field sends and constructor `case` rules.
- Check that the seven locals from the two `let` groups are absent from
  both the runtime and type environments after loading `main.aloe`.

The independent expected state must retain these observations:

| Part | Initial state |
|---|---|
| Session | `echo = ""`, `searching = #f`, `query = ""`, origin line/column `0/0`, `wrapped = #f`, `failing = #f`, empty `kill-ring` |
| Session options | `pending`, `prompt`, `last-submission`, and `waiting-command` are `None` |
| Filesystem | The `Fs` value wraps the explicitly injected `fs-host` |
| Buffers | Empty `before` and `after`; current buffer has id `0` and path `None` |
| Editor | Empty text, point line/column `0/0`, `quit = #f`, scroll row/column `0/0`, empty history, mark `None`, `text-rows = 0` |
| Windows | A single `Leaf` with view id/buffer-id/scroll-row/scroll-col `0/0/0/0` and `locked = #f`; selected/columns/rows `0/0/0` |

The inactive prompt alternative still has its seven original values:
empty label/text/completion-note, column `0`, empty completion-lines and
completion-matches, and completion-start `0`. The literal runner snapshot
protects that alternative's source even though the startup option is
absent. Keep the inactive path, mark, pending, submission, and command
witnesses as well.

## Verification and completion

Run from `/home/dharmatech/journal/2026-09-02-aloe-racket`:

```sh
TMPDIR=/tmp raco test -y tests/parenthetical-construction/session.rkt tests/aloemacs/runner.rkt tests/aloemacs/windows-state-foundation.rkt
TMPDIR=/tmp raco test -y tests
git diff --check
```

`TMPDIR=/tmp` and `-y` are required. The full command is recursive; do not
replace it with `tests/*.rkt`. Do not commit `compiled/`. After a `.rkt`
edit, tests or `raco make host/racket/aloemacs-run.rkt bin/aloe` must
rebuild bytecode before launching; `.aloe`-only edits need no rebuild.

An optional terminal check after verification is:

```sh
racket host/racket/aloemacs-run.rkt
```

The empty editor starts as before and Escape exits. Use the existing
optional `tui-term` dependency if available; do not install or change it.
This hand check does not replace automated acceptance.

Complete when the target definition and explicit snapshot match, the new
test proves startup type/value preservation and local binding scope,
existing runner behavior assertions pass unchanged, the focused and full
suites and whitespace check pass, and every change stays within scope.
Report changed files and verification results, then stop for human review.
Do not start or write another checkpoint, relabel another call site,
commit, or merge.

## Explicit non-goals

- Further parser, checking, evaluation, reflection, generic inference,
  language-document, diagnostic, completion, or editor API changes.
- Labels on methods, host messages, `List`, or explicit constructors;
  defaults, mixed tails, colon label tokens, new keyword handling, macros,
  `make`, copying `with`, or any new special form.
- Changes to buffer, editor, prompt, window, filesystem, or terminal
  behavior; other consumer rewrites or existing test changes.
- New dependencies, production filesystem access for tests, global
  checkpoint numbering, Gel, Boids, committing, or merging.
