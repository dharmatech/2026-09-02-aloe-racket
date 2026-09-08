# Checkpoint 97 — integrate the typed host boundary

**Branch.** Create `experiment/host-boundary` from current
`experiment/class-constructors`, then merge `main` into it.

**Depends on.** Checkpoints 89–96 on this line, and checkpoints 83–88 as
already sealed on `main`.

**Status.** Complete (reviewed 2026-09-08 on `experiment/host-boundary` @ `0c3c5ed`)

## Goal

Put the sealed typed host boundary (checkpoints 83–88 on `main`) onto
the class-constructors line so one branch has **both**:

- constructor sets, named construction, `case`, and generic inference
  (checkpoints 89–96);
- descriptor-driven host capabilities, atomic injection, guarded
  crossing, Term, and host reflection (checkpoints 83–88).

This is an integration merge. Do not redesign the host architecture. Do
not start filesystem. Do not add crossing types.

## Depends on

- Parent: current `experiment/class-constructors` (constructors ratified
  through checkpoint 96; filesystem vocabulary and this host-boundary
  designer pair are documents only).
- Incoming: current `main` (typed host sealed at checkpoint 88, plus
  main's later handoff commit). Merge `main`, not
  `codex/typed-host-boundary`, and not a cherry-pick of 83–88.
- Not authority: `codex/unified-nominal-adts`, Proposal A,
  `define-family`.

## Authority / starting point

Law after this checkpoint is the merged `SPEC.md` described below.

Read, do not rewrite:

- `SPEC.md` §13 on `main` (“Typed host capabilities”).
- `docs/decisions.md` “Typed host capabilities (2026-09-06)” on `main`.
- `docs/checkpoints/0083-validated-host-declarations.md` through
  `0088-seal-typed-host-boundary.md` on `main` (via `git show`; do not
  check those branches out as the working copy).
- `aloe/host.rkt` on `main`.
- Constructor law already on this line: `SPEC.md` §§3.1–3.2, 4.10, 5.3,
  9, 13; checkpoints 89–96.
- Consumer pressure, not this slice: `docs/filesystem-vocabulary.md`.
  Do not change its locked public Aloe API.

Re-check the merge at implementation time. A preview from
`experiment/class-constructors` @ `04fdb72` vs `main` @ `0d01895`
(merge-base `b0d77da`) is in “Expected merge tension” below. If `main`
or the parent has moved, trust a fresh `git merge-tree`, not this
preview.

## Branch topology

```
experiment/class-constructors     # parent: constructors + case, no 83–88
  └── experiment/host-boundary    # this checkpoint creates this
```

Exact steps:

1. Start from current `experiment/class-constructors`. Do not switch the
   working copy to `main` or `codex/typed-host-boundary`.
2. `git checkout -b experiment/host-boundary`
3. `git merge main`
4. Resolve as specified here. Keep **both** constructor 89–96 and host
   83–88 normative.
5. Do not merge `codex/unified-nominal-adts`. Do not cherry-pick
   individual 83–88 commits. Do not merge this branch back to `main`.

## Expected merge tension

Preview of files changed on both sides since Gel text rendering
(`b0d77da`):

| File | Preview |
| --- | --- |
| `CHECKPOINTS.md` | **Conflict.** Both appended after 82. |
| `SPEC.md` | **Conflict** at §13; main also adds the type-grammar omission paragraph. |
| `docs/decisions.md` | **Conflict** at the last section; main also rewrites Host terminal input. |
| `docs/handoff.md` | **Conflict.** Whole current-state rewrite vs constructor handoff. |
| `aloe/eval.rkt` | Changed in both; preview auto-merged. |
| `aloe/type.rkt` | Changed in both; preview auto-merged. |
| `docs/philosophy.md` | Changed in both; preview auto-merged (main adds Host boundary). |

Takes from `main` in the preview (no constructor overlap): `aloe/driver.rkt`,
`aloe/env.rkt`, `aloe/host.rkt`, `docs/gel.md`, `host/racket/gel-run.rkt`,
`host/racket/term-run.rkt`, `host/racket/term.rkt`, host-API updates in
`tests/checkpoint-53.rkt`, `64`, `65`, `71`, `72`, and the new host
checkpoint docs/tests 83–88.

Stays from this line (main did not touch them): `aloe/parse.rkt`,
constructor checkpoints 89–96, `tests/checkpoint-90.rkt`–`95.rkt`,
`docs/class-constructors.md`, `docs/filesystem-vocabulary.md`,
`docs/host-boundary-designer.md`.

If git would drop constructor `case` or host sends from checker or
evaluator, that is a failed checkpoint, not a compromise. Restore both.

## Exact file scope

**Create** (already present if this document landed on the parent first):

- `docs/checkpoints/0097-integrate-typed-host-boundary.md` (this file)

**Add from `main` via merge** (do not rewrite their historical text):

- `docs/checkpoints/0083-validated-host-declarations.md`
- `docs/checkpoints/0083a-host-implementation-call-shape.md`
- `docs/checkpoints/0084-guarded-host-sends.md`
- `docs/checkpoints/0085-typed-host-injection.md`
- `docs/checkpoints/0086-checked-terminal-runners.md`
- `docs/checkpoints/0087-host-reflection.md`
- `docs/checkpoints/0088-seal-typed-host-boundary.md`
- `tests/checkpoint-83.rkt` through `tests/checkpoint-88.rkt`

**Must resolve / edit after the merge:**

- `CHECKPOINTS.md`
- `SPEC.md`
- `docs/decisions.md`
- `docs/handoff.md`
- `docs/philosophy.md` (only if auto-merge missed the host-boundary
  section or the constructor kernel bullet)
- `aloe/eval.rkt` and `aloe/type.rkt` (only to keep both dispatch
  paths if the merge is incomplete or tests fail)
- `tests/checkpoint-97.rkt` (new; compact coexistence test below)

**Take `main`'s sealed implementation** of:

- `aloe/host.rkt` (descriptor-driven; the old `host-message` hash API
  must not remain)
- `aloe/driver.rkt` (`driver-inject-host!`)
- `aloe/env.rkt` (`env-bound?`)
- `host/racket/term.rkt`, `term-run.rkt`, `gel-run.rkt`
- host-API updates in checkpoints 53, 64, 65, 71, 72
- `docs/gel.md` factual current-state updates from `main`

**Do not edit:**

- `docs/filesystem-vocabulary.md`
- `docs/host-boundary-designer.md`
- `docs/class-constructors.md` (historical Proposal B; `SPEC.md` is law)
- historical checkpoint documents 83–96 (do not rewrite them to pretend
  they always lived together)
- `examples/`, `lib/`, `gel/`, MPL sources
- no `host/racket/fs.rkt`, no `lib/fs.aloe`, no `lib/option.aloe`

Do not renumber historical checkpoints. New work starts at **97**.

## Required behavior

### Runtime and checker

After the merge, one process must:

1. Parse, typecheck, and evaluate constructor `case` as on this line
   (`eval-case` / `infer-case`; `case-expr` remains a special form, not
   a send).
2. Dispatch host sends through the sealed descriptor path from `main`
   (`host-receiver-send` / `infer-host-send`; injection via
   `driver-inject-host!`).
3. Reflect host receivers through the same interface identity (`Mirror`
   / `Signature` / exact-row `host-receiver-invoke-method`).
4. Keep Term as the first production capability, not ambient. Default
   drivers still have no `term` binding.

Concrete keep-both checks (the merge preview auto-applied main's host
hunks; verify they are still present **and** that constructor paths
were not deleted):

- `aloe/eval.rkt`: `case-expr` still evaluates via `eval-case`;
  `lookup-message` still sends to `host-receiver?` via
  `host-receiver-send`; exact-row invocation still uses
  `host-receiver-invoke-method`; host printers no longer leak
  receiver state (`#<Name>` only); host equality is identity (`eq?`).
- `aloe/type.rkt`: `case-expr` still goes to `infer-case`;
  `infer-send` still has a `host-receiver-type?` clause calling
  `infer-host-send`; `type-environment-inject-host!` remains only on
  the `driver-host-injection` submodule.
- `aloe/host.rkt` matches `main`: opaque `host-method` /
  `host-interface` / `host-receiver`, crossing vocabulary `Int` /
  `Bool` / `String` only, string normalization both ways, no public
  raw constructors, `evaluator-exact-host-method` submodule intact.
- `aloe/parse.rkt` is unchanged constructor parse from this line.

If a constructor-line test still mentions `host-message` or
`make-term-type-environment`, take `main`'s test update for that file.
Do not keep the old host API to make an old test pass.

### `SPEC.md`

Keep constructor rules **and** `main`'s typed-host section. Neither
swallows the other.

1. Keep the document title **Aloe 0.4 spec** (constructors are ratified
   0.4 on this line). Update the opening paragraph so sections 11–12
   remain 0.2–0.3, section 13 remains 0.4 constructors, and a new
   section 14 records the typed host boundary.
2. Keep this line's constructor edits in §§3.1–3.2, 4.10, 5.3, and 9
   (Option / Tree goldens stay).
3. Take `main`'s type-grammar omission paragraph after the §5.1 grammar:
   `Term` and arbitrary host-interface names are absent from source
   types; an injected host has an internal nominal type that cannot be
   written as an annotation.
4. Keep §13 **0.4 additions** from this line (constructor sets, `case`,
   generic construction from expected type). Do not replace it with
   host prose.
5. Add §14 **Typed host capabilities** by copying `main`'s current §13
   prose **verbatim**, including: crossing vocabulary is only `Int`,
   `Bool`, and `String`; explicit injection; one opaque
   `host-interface`; no arbitrary Racket call; no second send rule;
   default environments contain no optional capability.

Do not add `Term` or host interface names to the source type grammar.
Do not mention `Path`, `Entry`, `(List String)` crossing, or filesystem.

### `CHECKPOINTS.md`

After checkpoint 82, list **in number order**:

- 83, 83A, 84, 85, 86, 87, 88 — take the compact entries from `main`
- 89–96 — keep this line's constructor entries
- 97 — this integration

Do not paste full checkpoint specifications into the index. A compact
97 entry:

```text
## 97. [Integrate typed host boundary](docs/checkpoints/0097-integrate-typed-host-boundary.md)

- `experiment/host-boundary` merges sealed host checkpoints 83–88 from
  `main` onto constructor checkpoints 89–96. Crossing remains
  `Int`/`Bool`/`String`. No filesystem capability.
```

### `docs/decisions.md`

Keep all three of:

- `main`'s rewrite of **Host terminal input (2026-09-04)** (Term is the
  first optional typed capability; both runners inject a checked
  driver).
- **Typed host capabilities (2026-09-06)** from `main` (verbatim).
- **Class constructors (2026-09-07)** from this line (verbatim).

Order those last two by date: host 2026-09-06, then constructors
2026-09-07. Do not drop either. Do not add a filesystem decision.

### `docs/handoff.md`

Describe the runtime as **constructors plus typed host boundary**. Do
not claim a filesystem library exists.

Required resulting document:

- Reading order may take `main`'s mention of `docs/gel.md`.
- Keep a short branch note: Proposal B is law in `SPEC.md` on
  `experiment/host-boundary`; Proposal A / `codex/unified-nominal-adts`
  is not authority; constructors are **not** merged to `main`.
- Current state: interpreter + checker; constructor sets and `case`;
  typed host capabilities through checkpoint 88's sealed architecture;
  tests through 97 green on this branch. Include the constructor/MPL
  facts this line already lists (Math as supertype, no implicit Int
  lift, identities as current behavior).
- Include `main`'s **Typed host boundary** section, with crossing still
  `Int` / `Bool` / `String`, Term not ambient, no handwritten checker
  facades. Do not say filesystem crossing exists.
- How-to-work keeps both this line's MPL/checker constraints **and**
  `main`'s host constraints (host facts in Racket; domain objects in
  Aloe).
- Application pressure: a later pair will implement
  `docs/filesystem-vocabulary.md` after this host-boundary line is
  complete. Do **not** copy `main`'s “filesystem remains deliberately
  undecided” as if that vocabulary document did not exist. Do **not**
  claim `Path` / `Entry` / `Fs` are implemented.

### `docs/philosophy.md`

Keep this line's kernel bullet (constructor selectors and `case`). Keep
`main`'s **Host boundary** section (explicit capability values, not
ambient kernel powers).

### `docs/gel.md`

Take `main`'s factual updates (checked injection, descriptor Term,
Mirror on host receivers). Leave future filesystem rows exploratory.
Do not add Path/Entry selectors.

## Tests and hand check

Add `tests/checkpoint-97.rkt` as a compact coexistence test. Do not
repeat the 83–88 matrices or the 90–95 constructor matrices.

Cover:

1. A fresh `make-driver` still has no `term` binding in runtime or
   checker environments (same assertion as checkpoint 88).
2. Injecting production Term and sending `(term write-line "sealed")`
   still returns `"sealed"` and writes `"sealed\r\n"`.
3. The **same** driver, after that injection, still typechecks and
   evaluates a constructor `case` golden:

   ```aloe
   (define-class (Option T)
     (constructors
       (None (fields))
       (Some (fields (value T))))
     (methods
       (present? () Bool
         (self case
           (None () #f)
           (Some (value) #t)))))
   ```

   `((Option Some "x") present?)` → `#t`

4. `make-host-method` still rejects a non-crossing return type. Use a
   symbol that is not `Int`, `Bool`, or `String` (for example
   `'Path`). Do not add `(List String)` as a permitted crossing type
   here, even as a test helper.

Existing tests that must stay green without being rewritten:

- host: `tests/checkpoint-83.rkt`–`88.rkt` and the updated 53/64/65/71/72
- constructors: `tests/checkpoint-90.rkt`–`95.rkt`
- the rest of the suite (Gel, Boids, MPL)

### Hand check

Keep checkpoint 88's in-memory Term check exactly:

```racket
(require "aloe/driver.rkt"
         "host/racket/term.rkt")

(define output (open-output-string))
(define state (make-driver))
(driver-inject-host!
 state 'term (make-term-receiver output (lambda () "unused")))

(list (driver-eval! state '(term write-line "sealed"))
      (get-output-string output))
```

Expected result:

```racket
'("sealed" "sealed\r\n")
```

## Acceptance

Complete when:

- `experiment/host-boundary` exists, parented at current
  `experiment/class-constructors`, with `main` merged (not cherry-picked,
  not unified-nominal-adts).
- `SPEC.md` has constructor rules and the typed-host section; source
  type grammar still omits host interface names; crossing is still only
  `Int` / `Bool` / `String`.
- `CHECKPOINTS.md` lists 83–88, then 89–96, then 97.
- Checker and evaluator dispatch both `case` and host sends.
- `raco test` is green, including 83–88 and 90–95, plus
  `tests/checkpoint-97.rkt`.
- The hand check above holds.
- `git diff --check` is clean.
- No filesystem capability, no `Path` / `Entry` / `Fs`, no
  `(List String)` crossing.

Stop for review. Do not start checkpoint 98. Do not merge to `main`.

## Explicit non-goals

- Filesystem vocabulary (`Path`, `Entry`, `Fs`, `lib/fs.aloe`, real
  directory goldens, Gel filesystem UI).
- Homogeneous `(List String)` as a host crossing type (later slice).
- Generic field retention of a host-receiver type, or source-written
  host interface names (later slice if needed).
- `lib/option.aloe` as a loadable library.
- Redesigning descriptor-driven injection, Term, or crossing
  validation.
- Opaque host handles, `Result` crossing, bytes, mutable directory
  handles, nested lists, `(List Entry)` crossing.
- Proposal A / `define-family`.
- Merging class constructors to `main`.
- Rewriting historical checkpoints 83–96.
- Implementing any later host-boundary extension in this change.
