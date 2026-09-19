# Charter — parser / checker elegance

**Status.** Assignment for one refactor conversation. Not Aloe law.
Not a new language feature. Not LSP redesign.

**Your job.** Make the kernel look like one grammar and one checker
again. Unify the duplicated parser in `aloe/parse.rkt`. Move editor
observation out of the middle of `aloe/type.rkt`. Then **stop**.

If you have been told to read this file, this is the whole assignment.

This is **one conversation** with **two slices** (two commits). It is
not a designer spec, not a checkpoint-manager split, and not global
checkpoint 118. Behavior stays the same. Tests stay green. If slice 1
is green and slice 2 starts to redesign the checker, **stop after
slice 1** and report.

Do not change SPEC language. Do not strip Mirror, Signature, or Gel.
Do not change LSP JSON, hover text, or completion items. Do not unify
by deleting source locations. Do not rewrite `aloe/eval.rkt`. Do not
push.

The human will review in the parent high-level conversation.

---

## 1. How this conversation works

1. Read this charter. Confirm §3 against the live tree.
2. Branch `refactor/parser-checker-elegance` from local `main`.
3. Slice 1 — one parser (§7). Commit. `raco test tests` green.
4. Slice 2 — checker observation seam (§8). Commit. `raco test tests`
   green.
5. Fast-forward local `main` with `--ff-only` (§10).
6. Completion report (§11). Stop.

Do not push. Do not force-push. Do not open a GitHub PR unless the
human asks in this conversation.

---

## 2. Why this refactor exists

Editor source-locations kept `parse-datum` as a location-free entry
and added a second full grammar, `parse-syntax-expression`, so
`read-program` could use `read-syntax`. Those two copies now fill
`aloe/parse.rkt` (~1125 lines). Helpers are doubled too:
`parse-method-declaration` / `parse-method-syntax`, `parse-case` /
`parse-case-syntax`, `desugar-let` / `desugar-let-syntax`,
`desugar-cond` / `desugar-cond-syntax`, class parsing in `parse-datum`
versus `parse-class-syntax`.

Editor queries then poked the real checker: parameters
`current-expression-observer` and
`current-selector-receiver-observer`, plus
`typecheck-program/observe*` sitting between `type-of` and
`infer-expression` in `aloe/type.rkt` (~1929 lines). The intended
seam is already named at the bottom of that file (the
`expression-query-observation` and `completion-query-observation`
submodules). The implementation is not yet that small.

The parent discussion kept Mirror and Gel. This assignment does
**not** wait on removing them. `type-signature-specs` is shared
language plumbing for LSP *and* Mirror; do not delete it.

---

## 3. Facts to verify

On current `main` (after the editor/LSP landing):

- `aloe/parse.rkt` defines `parse-datum` (around line 453) and
  `parse-syntax-expression` (around line 936). `read-program` uses
  `read-syntax` then `parse-syntax-expression`. `eval-datum` /
  `driver-eval!` use `parse-datum`.
- Expression structs already have `loc`. `send-expr` also has
  `selector-loc`. `parse-datum` trees use `#f` for those fields.
- `aloe/type.rkt` calls `retain-expression-observation!` and
  `observe-selector-receiver!` at the end of `infer-expression`, and
  `materialize-expression-observation-at-root-end!` in
  `typecheck-program`. `selected-expression-in-method-body?` forces a
  method-body check when a query target lives in that body.
- `aloe/expression-query.rkt` and `aloe/completion-query.rkt` require
  the type.rkt submodules. Keep those call sites working (re-export
  is fine).

If `aloe/lsp.rkt` is missing, you are on the wrong branch. Stop.

---

## 4. In scope

**Slice 1 — one grammar in `aloe/parse.rkt`**

- One implementation of each special form and of send.
- `read-program` still uses the Racket reader with `read-syntax` and
  still fills `loc` / `selector-loc` from those syntax objects.
- `parse-datum` remains public. Every `loc` and `selector-loc` in a
  tree it returns is `#f`. Two `parse-datum` trees for the same datum
  still `equal?`. Existing tests that construct structs with `#f`
  locs keep working.
- `parse-program` stays the datum entry (location-free).
- Error symbols may remain `'parse-datum` so existing
  `check-exn #rx"parse-datum"` tests pass.

**Slice 2 — observation out of the checker spine**

- Move observer structs, parameters, `typecheck-program/observe`,
  `typecheck-program/observe-selector-receiver`,
  `retain-expression-observation!`,
  `observe-selector-receiver!`, and
  `materialize-expression-observation-at-root-end!` out of the middle
  of `aloe/type.rkt`.
- Preferred home: `aloe/private/checker-observation.rkt` (name may
  vary). `type.rkt` may require it. Do **not** have `type.rkt`
  require `expression-query.rkt` or `completion-query.rkt` (cycle).
- Keep a **narrow seam** in the checker: `infer-expression` may still
  call two hooks after inference; `typecheck-program` may still
  notify end-of-root; method checking may still ask “does a selected
  node live in this body?” That last behavior must not regress.
- Existing submodules on `type.rkt` may remain as re-exports so
  query files need not churn. Shrinking those requires is allowed if
  tests stay green.

**Docs**

- This charter’s status line when landed.
- A short journal note is preferred.
- At most a sentence in `docs/handoff.md` that there is one parser
  and a query seam. Do not rewrite SPEC.

---

## 5. Out of scope

- SPEC language (constructors, `case`, host, Mirror, String, Boid)
- Deleting `loc` / `selector-loc` or going back to `read` without
  syntax
- Changing what hover/completion return
- Moving `type-signature-specs` unless it is a trivial relocation
  that does not export the whole checker type representation. Prefer
  leaving it in `type.rkt` over a tangled move.
- Rewriting Mirror invoke, Gel, host.rkt, LSP protocol
- Unifying `eval.rkt` dispatch
- MPL-ADT, Allo Emacs, Gel-directory
- Global checkpoints 118+
- Pushing `origin/main`

---

## 6. Preflight

Working directory: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

1. `git status` clean except this charter if you still need to commit
   it onto `main` first.
2. `test -f aloe/lsp.rkt`
3. `raco test tests` green on `main` before you edit. If it is already
   red, stop.

---

## 7. Slice 1 — parser

Work on `refactor/parser-checker-elegance`.

Locked approach: the **syntax parser is the grammar**. `parse-datum`
becomes a wrapper (for example `datum->syntax` then the syntax
parser, then force every `loc` / `selector-loc` to `#f` if the wrap
invents empty srclocs). Shared helpers that take an explicit loc are
also fine. Two independent `cond`/`match` copies of `define-class`,
`case`, `let`, `cond`, `fn`, `load`, `check`, `define-protocol`,
`define-methods`, and send are **not** fine.

Do not add a third parser. Do not replace the Racket reader.

Bar:

- `tests/editor/source-locations/000-spans.rkt` still proves
  `read-program` spans and selector locs.
- Existing `parse-datum` tests (including `tests/checkpoint-90.rkt`)
  still pass with `#f` locs.
- Full `raco test tests` green.
- `aloe/parse.rkt` no longer contains a second complete copy of the
  special-form list. Line count should drop a lot from 1125; do not
  fail the slice on an exact number.

Commit:

```text
Unify parse-datum and parse-syntax-expression
```

---

## 8. Slice 2 — checker observation

After slice 1 is green.

Bar:

- `aloe/type.rkt` no longer defines the observe API in the block
  between `type-of` / `typecheck-program` and `infer-expression`.
  That block should read as the checker again.
- `raco test tests` green, including `tests/editor/expression-query/`
  and `tests/editor/completion/`.
- `infer-expression` still infers the same types. Do not change
  unification, constructors, or host checking to make a query pass.

Commit:

```text
Move checker observation out of type.rkt spine
```

If this slice needs a new public checker API, stop and report
instead of inventing one. The existing submodule contracts are
enough.

---

## 9. Tests

After each slice:

```sh
raco test tests
```

Also run, if you touched VS Code files (you should not):

```sh
cd editors/vscode && npm test
```

Spot-check once at the end:

- `(Point new 1 2)`
- `("abc" len)` → `3`
- `(Option Some 1)` after loading `lib/option.aloe`
- default `./bin/aloe` has no `fs-host`

Do not start Gel or VS Code as a UI session.

---

## 10. Land on `main`

```sh
git checkout main
git merge --ff-only refactor/parser-checker-elegance
```

`--ff-only` is required. Include this charter on `main` if it is not
already there. Set its status to:

> **Status.** Landed on `main` at \<sha\>. Historical refactor assignment.

Optional journal: `docs/journal/` — one parser; observation seam;
no language change.

Do not push.

---

## 11. Completion report

Paste back to the parent discussion:

- `main` SHA before and after
- whether both slices landed, or only slice 1
- `raco test tests` result
- `aloe/parse.rkt` and `aloe/type.rkt` line counts before and after
- confirmation that `parse-datum` is still location-free
- confirmation that `read-program` still supplies spans
- confirmation that Mirror/Gel/LSP were not redesigned
- reminder that nothing was pushed

Then stop.

---

## 12. Authority

- this file
- `SPEC.md` (do not edit language)
- `docs/philosophy.md` — kernel stays small; editor questions are
  why sends are typed
- `docs/editor/source-locations/checkpoints/000-spans.md` — loc
  fields and `parse-datum` location-free contract, except this
  assignment **does** collapse the two grammars that 000 introduced
- `docs/editor/README.md` — editor work is not global checkpoints
- `AGENTS.md`

Not authority: Proposal A, Gel-directory specs, a new parser, a
compiler.
