# Charter — editor / LSP onto `main`

**Status.** Assignment for one merge conversation. Not Aloe law.
Not a language-feature checkpoint. Not a kernel rewrite.

**Your job.** Land already-implemented editor support (source
locations, signature catalog, expression/completion queries, LSP,
VS Code hover client) and String `len` / `take` / `starts-with?`
onto local `main`, **without** Gel-directory or Gel-presentations.
Then **stop**.

If you have been told to read this file, this is the whole assignment.

This is **one conversation**. It is not a designer spec, not a
checkpoint-manager split, and not a series of implementer chats.
The editor work is already done on `experiment/2026-09-12-editor`.
You are copying a whitelist of paths onto `main` and writing landing
docs. If tests fail or the whitelist is wrong, **stop and report**.
Do not fall back to merging the whole editor branch.

Do not unify the two parsers in `aloe/parse.rkt`. Do not extract
observers from `aloe/type.rkt`. Do not strip Mirror, Signature, or
the earlier Gel already on `main`. Do not add Gel-directory,
Gel-presentations, `gel/directory.aloe`, or `gel-directory-run`.
Do not update `origin/main`. Do not push.

The human will review the result in the parent high-level conversation.

---

## 1. How this conversation works

1. Read this charter. Confirm the facts in §3 against the live repo.
   If a SHA or ancestor check fails, **stop and report**.
2. Run the preflight in §6.
3. Create work branch `merge/editor-lsp` from local `main` (§7).
4. Checkout the path whitelist from the editor tip (§7). Do **not**
   `git merge experiment/2026-09-12-editor`.
5. Hand-edit the shared docs in §8. Do **not** checkout `SPEC.md`,
   `CHECKPOINTS.md`, `docs/handoff.md`, `docs/decisions.md`, or
   `README.md` from the editor branch.
6. Run tests (§9).
7. Fast-forward local `main` to the work branch (§10).
8. Write the completion report (§11). Stop.

Do not push. Do not force-push. Do not publish a GitHub PR unless the
human explicitly asks in this conversation.

---

## 2. Why this merge exists

The parent discussion decided:

1. Editor / LSP belongs on `main`.
2. Kernel elegance (one parser; observers out of `type.rkt`) is a
   **later** project. Merge now, refactor later.
3. Gel-directory and Gel-presentations stay experimental.
4. Mirror / Gel already on `main` are a **later** removal project.
   Do not start that here.
5. `experiment/2026-09-12-editor` remains the snapshot that has
   Gel + Mirror + directory UI + LSP together. Do not delete it.
   Do not merge `main` back into it in this assignment.

Spoken name: **editor / LSP merge**. String `len` / `take` /
`starts-with?` travel with it because they are small, useful, and
the editor catalog already lists them. They are not Gel.

This cannot be `git merge --ff-only experiment/2026-09-12-editor`.
That branch is stacked on Gel-directory. Fast-forwarding it would
put the directory UI on `main`.

---

## 3. Facts to verify before touching git

Record the SHAs you actually see. The numbers below were true when
this charter was last edited (2026-09-19). If the *editor tip*
drifted, stop.

The human already pushed the 0.3 landing and this charter to
`origin/main`. Local and origin were in sync. **Do not push** from
this assignment even if your landing commits leave local `main`
ahead again.

| Ref | Expected SHA (prefix) | Role |
|---|---|---|
| local `main` | has `docs/editor-lsp-merge.md`, no `aloe/lsp.rkt` | Destination. Constructors, Option, filesystem, host, Mirror/Gel stack, **no LSP**. Ancestor of `8b0a110`. |
| `experiment/2026-09-12-editor` | `aef6fa7` | **Source tree** for the whitelist. Do not merge this branch. |
| merge-base of those two | `8b0a110` | `experiment/filesystem` tip, before the 0.3 landing-docs commit. |
| `origin/main` | already published; may match `main` at start | **Do not push.** |

Must be true:

```sh
git merge-base --is-ancestor 8b0a110 main
git merge-base --is-ancestor 8b0a110 experiment/2026-09-12-editor
test ! -f aloe/lsp.rkt   # on main, before the work
test -f docs/editor-lsp-merge.md
```

Kernel files at the editor tip already contain String + editor
changes and **do not** contain Gel-directory interpreter changes.
Gel-directory after filesystem only added Aloe kernel edits in the
String commit (`97da6c6`). Checking out those kernel files from the
editor tip is therefore the String+editor kernel, not the directory
UI.

If `examples/gel-directory.aloe` or `host/racket/gel-directory-run.rkt`
appears in your `git status` after the whitelist checkout, you grabbed
the wrong paths. Revert and stop.

---

## 4. In scope (land this)

From `experiment/2026-09-12-editor` (`aef6fa7`):

**String**

- Kernel messages `len` and `take` on `String`
- `lib/string.aloe` `starts-with?`, bootstrapped like `lib/list.aloe`
- Tests `tests/checkpoint-114.rkt` and `tests/checkpoint-115.rkt`
- Briefs `docs/string-len-take-brief.md`,
  `docs/string-starts-with-library-brief.md`
- Historical checkpoint notes `docs/checkpoints/0114-string-len-take.md`
  and `0115-string-starts-with.md` (keep their numbers; see §8.2)
- Decision “String kernel and library boundary (2026-09-10)”
- SPEC §4.6 String `define-methods`, §7.5 String table

**Editor / LSP** (already implemented; local series, not global 118)

- Source-location parser (`read-syntax` path) plus existing `parse-datum`
- `aloe/signature-catalog.rkt` shared with Mirror (leave that sharing)
- Expression query, completion query, `aloe/lsp.rkt`
- `docs/editor/**` and `tests/editor/**` as they exist on the source tip
- `editors/vscode/**` as tracked on the source tip (`.gitignore` already
  excludes `node_modules/`)
- `info.rkt` `net-lib` dependency
- One-line `tests/checkpoint-90.rkt` loc-field update

**Boid monomorphic** (on the same source tip; not Gel)

- `examples/boids.aloe`, SPEC grammar (`Boid` not `(Boid Type)`),
  decisions “Sim and numerics”, `docs/boid-monomorphic-brief.md`

**Archive scratch** already on that tip: `archive/test-intellisense*.aloe`,
`archive/boids-test-intellisense.aloe`.

Default drivers still receive **no** `fs-host` and **no** Term.
Do not change that.

---

## 5. Out of scope (do not land, do not start)

Do **not** take these paths from the editor tip (non-exhaustive; if
in doubt, leave it off):

| Leave off `main` | Notes |
|---|---|
| `docs/checkpoints/0108-*.md` … `0113-*.md`, `0116-*.md`, `0117-*.md` | Gel-directory global checkpoints |
| `tests/checkpoint-108.rkt` … `113.rkt`, `116.rkt`, `117.rkt` | Gel-directory tests |
| `examples/gel-directory.aloe`, `examples/gel-list.aloe`, `examples/gel-point.aloe` | Gel apps |
| `gel/directory.aloe`, `gel/presentations.aloe` | New Gel modules |
| `host/racket/gel-directory-run.rkt` | Directory runner |
| `docs/gel-directory-*.md`, `docs/gel/**` expansions | Directory / presentations docs |
| `tests/gel/**` | Local Gel series |
| Decision “Gel directory surface (2026-09-09)” | Belongs on the experiment branch |

Also out of scope **even if tempting**:

- `git merge experiment/2026-09-12-editor`
- Cherry-picking Gel-directory commits and then deleting files
- Unifying `parse-datum` / `parse-syntax-expression`
- Moving `typecheck-program/observe*` out of `type.rkt`
- Removing Mirror / Signature / `gel/loop.aloe` / `gel-run`
- MPL-ADT, Allo Emacs
- Updating `origin/main` or pushing
- Creating global checkpoint 118
- Committing `editors/vscode/node_modules/`
- Deleting or renaming `experiment/2026-09-12-editor`

After this assignment, `main` will still contain Mirror, Signature,
and the earlier Gel (`gel/loop.aloe`, `gel/main.aloe`, `gel/menu.aloe`,
`gel/stack.aloe`, `host/racket/gel-run.rkt`). That is correct. The
later removal project handles those.

---

## 6. Preflight

Working directory: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

1. `git status`. Local `main` may show untracked `editors/` leftover
   from an earlier editor working tree. Do not add that leftover as-is.
   The whitelist checkout will add the **tracked** `editors/vscode`
   files from the editor tip. Do not commit other untracked junk.
2. Confirm you are on a clean index, or stop and report.
3. Confirm the ancestor checks in §3.
4. Confirm `aloe/lsp.rkt` is absent on `main`.
5. Leave `experiment/2026-09-12-editor` where it is.

---

## 7. Bring-up procedure

```sh
git checkout main
git checkout -b merge/editor-lsp

SRC=experiment/2026-09-12-editor

git checkout "$SRC" -- \
  aloe/completion-query.rkt \
  aloe/expression-query.rkt \
  aloe/lsp.rkt \
  aloe/parse.rkt \
  aloe/eval.rkt \
  aloe/type.rkt \
  aloe/driver.rkt \
  aloe/env.rkt \
  aloe/library.rkt \
  aloe/main.rkt \
  aloe/private \
  aloe/signature-catalog.rkt \
  lib/string.aloe \
  tests/checkpoint-90.rkt \
  tests/checkpoint-114.rkt \
  tests/checkpoint-115.rkt \
  tests/editor \
  docs/editor \
  docs/string-len-take-brief.md \
  docs/string-starts-with-library-brief.md \
  docs/checkpoints/0114-string-len-take.md \
  docs/checkpoints/0115-string-starts-with.md \
  docs/boid-monomorphic-brief.md \
  editors/vscode \
  examples/boids.aloe \
  info.rkt \
  archive/boids-test-intellisense.aloe \
  archive/test-intellisense.aloe \
  archive/test-intellisense-000.aloe \
  archive/test-intellisense-001.aloe
```

That list is the assignment. Do not add paths because they “look
related.”

Immediately verify the negative:

```sh
test ! -f examples/gel-directory.aloe
test ! -f host/racket/gel-directory-run.rkt
test ! -f gel/directory.aloe
test ! -f tests/checkpoint-108.rkt
test ! -f docs/checkpoints/0108-gel-application-start.md
test -f aloe/lsp.rkt
test -f lib/string.aloe
```

If any negative test fails, `git reset --hard` the work branch to
`main` and stop.

You may make **one or two** commits on `merge/editor-lsp` for the
code bring-up plus the §8 docs. Do not split into editor-project
checkpoints.

Suggested commit message for the code bring-up:

```text
Land editor LSP and String len/take on main
```

---

## 8. Shared docs (hand-edit on the work branch)

Do **not** `git checkout "$SRC" -- SPEC.md CHECKPOINTS.md README.md docs/handoff.md docs/decisions.md`.
The editor-tip versions describe Gel-directory as current.

### 8.1 `SPEC.md`

Keep the title and section numbering already on `main` (0.4 /
constructors / host). Apply only:

- §4.6: `define-methods` may target `List` or `String` (editor-tip
  wording).
- §5.1 / §5.2: `Boid` is not generic; flock is `(List Boid)`
  (editor-tip wording).
- §7.5 `String`: kernel `=`, `append`, `len`, `take`; `starts-with?`
  is `lib/string.aloe` (copy from the editor-tip SPEC).

Do not copy Gel-directory prose. Do not retitle SPEC.

### 8.2 `CHECKPOINTS.md`

After checkpoint 107, record:

- Checkpoints **108–113** and **116–117** are Gel-directory work.
  They live on `experiment/gel-directory-surface` and later Gel
  branches. They are **not** on `main`. Do not paste their bodies.
- **114** and **115** (String `len`/`take`, `starts-with?`) **are**
  on `main`. Link the existing `docs/checkpoints/0114-*.md` and
  `0115-*.md` files. Keep those numbers; do not renumber to 108.
- Editor / LSP is **not** a global checkpoint. Point at
  `docs/editor/README.md`. Do not write checkpoint 118.

### 8.3 `docs/decisions.md`

Add:

- Boid monomorphic correction under “Sim and numerics” (editor-tip
  wording).
- “String kernel and library boundary (2026-09-10)” from the editor
  tip.

Do **not** add “Gel directory surface (2026-09-09)”.

### 8.4 `docs/handoff.md`

- Current state is `main` after this landing: checkpoint 107, plus
  String 114–115, plus editor/LSP as local projects.
- Mention `lib/string.aloe` and that default drivers still have no
  host capabilities.
- Mention that `docs/editor/` is on `main` and is not Gel.
- It is still correct that Mirror, Signature, and the earlier Gel
  remain on `main`.
- Do **not** paste Gel-directory, presentations, or
  `gel-directory-run` as current `main` law.
- Leave `experiment/2026-09-12-editor` described as the branch that
  still has Gel-directory stacked with LSP, if you mention it at all.

### 8.5 `README.md`

Small updates only:

- Layout: `lib/string.aloe`, `docs/editor/`, `editors/vscode/`.
- Still an exploratory prototype. Do not announce a finished release.
- Do not claim Gel-directory.

### 8.6 This charter

Copy `docs/editor-lsp-merge.md` onto the work branch if it is not
already there (it should be, if you branched from `main` after this
file was committed). When the landing is done, set the status line
to:

> **Status.** Landed on `main` at \<sha\>. Historical merge assignment.

### 8.7 Journal (optional but preferred)

Short `docs/journal/` note: editor/LSP and String `len`/`take` /
`starts-with?` landed on `main` without Gel-directory. Dual parser
and Mirror/Gel removal are not this landing.

### 8.8 Do not edit

- Constructor / filesystem / host kernel behavior
- `lib/option.aloe`, `lib/fs.aloe`, `lib/disk.aloe`
- `gel/loop.aloe`, `gel/main.aloe`, `gel/menu.aloe`, `gel/stack.aloe`
- `host/racket/gel-run.rkt`
- `docs/class-constructors.md` except you must not re-open Proposal A

---

## 9. Tests

From the project root, on `merge/editor-lsp` before fast-forwarding
`main`:

```sh
raco test tests
```

That must include `tests/editor/**`, `tests/checkpoint-114.rkt`, and
`tests/checkpoint-115.rkt`. Green is required.

VS Code client (optional if Node is available; required if you
touched `editors/vscode`):

```sh
cd editors/vscode && npm ci && npm test
```

Do not commit `node_modules/`. Do not require a human to open VS Code.

If `raco test tests` is red, **stop and report**. Do not “fix” by
bringing Gel-directory files onto the branch. Do not skip tests.
Do not weaken the checker.

Spot-check:

- `(Point new 1 2)` still works
- `("abc" len)` → `3`
- default `./bin/aloe` still has no `fs-host`
- `aloe/lsp.rkt` exists; `examples/gel-directory.aloe` does not

Do not start Gel or VS Code as a manual UI session.

---

## 10. Land on `main`

```sh
git checkout main
git merge --ff-only merge/editor-lsp
```

`--ff-only` is required for this last step. If it refuses, stop and
report. Leave the work-branch name in place; do not delete
`experiment/2026-09-12-editor`.

---

## 11. Completion report

End the conversation with a short report the human can paste back
into the parent discussion:

- `main` SHA before and after
- work-branch SHA
- whether the whitelist checkout stayed inside §7
- `raco test tests` result
- `npm test` result, or that Node was skipped and why
- confirmation that `aloe/lsp.rkt` and `lib/string.aloe` are **present**
- confirmation that `examples/gel-directory.aloe`,
  `host/racket/gel-directory-run.rkt`, `gel/directory.aloe`, and
  `tests/checkpoint-108.rkt` are **absent**
- confirmation that `experiment/2026-09-12-editor` was not deleted
  or merged into `main` as a branch
- reminder that `origin/main` was not updated
- reminder that Mirror/Gel remain on `main` (later project) and
  that parser unification was not done (later project)

Then stop.

---

## 12. What this merge does *not* decide

Leave these for the parent conversation.

1. **Unify `parse.rkt` / extract type-checker observers.** Later
   elegance project, preferably after Mirror/Gel removal so
   `type.rkt` is not rewritten twice.
2. **Remove Mirror / Gel from `main`.** Later project. Keep
   `signature-catalog.rkt` for LSP. Keep
   `experiment/2026-09-12-editor` as the Gel+Mirror+LSP snapshot.
3. **`origin/main`.** Once, after the parent is happy with local
   `main`. Not this assignment.

---

## 13. Authority

Read, in order:

- this file
- `SPEC.md` on current `main` (law you must not break)
- editor-tip `SPEC.md` only as the source of the §8.1 String/Boid
  hunks
- `docs/philosophy.md`
- `docs/editor/README.md` on the editor tip (local editor law:
  not global checkpoints)
- `AGENTS.md`
- `docs/0.3-language-merge.md` as the previous landing; do not
  rerun it

Not authority:

- `codex/unified-nominal-adts`
- Gel-directory / presentations specs, except as things **not** to
  copy
- the parent chat transcript, except as this charter records it
