# Host-boundary designer brief

**Status.** Working handoff for one Grok conversation. Not law. Not a
checkpoint. `SPEC.md` remains law for the running language.

**Your job.** You are the **designer** for putting the typed host
boundary onto `experiment/class-constructors` and then extending that
boundary only as the filesystem vocabulary requires. You write small
checkpoint documents. You do not implement them.

If you have been told “read `docs/host-boundary-designer.md`,” this file
is the whole assignment. Follow it until the human says the host-boundary
pair is done.

## 1. How this conversation works

1. Read this brief and the authority files in §3.
2. Write **one** checkpoint document under `docs/checkpoints/`.
3. Stop. The human reviews it.
4. If they approve, they hand that checkpoint to a **different**
   implementer conversation (possibly a different agent). That
   conversation implements only that slice, adds tests, runs the named
   verification, and stops when green.
5. The human brings the result back here. Review the diff **against the
   written checkpoint**, not against this chat (the implementer will not
   have this chat either). Check file scope, tests, non-goals, and
   whether they started the next slice.
6. If the checkpoint was ambiguous, that is a design defect: fix the
   document before authorizing a follow-up. Do not patch the language in
   passing.
7. Only then write the next checkpoint.

Never implement, merge, or create a runtime branch in this conversation.
Never write an omnibus “do the host boundary” checkpoint.

Checkpoint shape follows the existing ones
(`docs/checkpoints/0090-parse-constructors-and-case.md`,
`docs/checkpoints/0088-seal-typed-host-boundary.md` on `main`,
`docs/checkpoints/0096-ratify-class-constructors.md`):

- goal
- depends on
- authority / starting point
- exact file scope
- required behavior
- tests and hand check
- acceptance
- explicit non-goals

The implementer will not have this brief in context. Put every
reconciliation rule they need in the checkpoint itself.

## 2. Program context (why you exist)

Aloe is a prototype interpreter in Racket. Class constructors
(Proposal B: constructor sets + `case`) are implemented and ratified on
`experiment/class-constructors` through checkpoint 96. They stay off
`main` until an application proves them.

That application is a read-only filesystem vocabulary:
`docs/filesystem-vocabulary.md`. A directory listing is mixed (`File` /
`Directory` / …), so `(List Entry)` plus exhaustive `case` is the proof.

Filesystem effects must come from Racket through the typed host
boundary (checkpoints 83–88). That work is already on `main` and is
**not** on class constructors. The two lines diverged after Gel text
rendering.

This pair exists because filesystem cannot be implemented until the
host seam is on this line, and because listing cannot cross today’s
`Int` / `Bool` / `String` vocabulary. A later filesystem designer pair
will consume your result. You do not build the filesystem library.

Unified Nominal ADTs (`codex/unified-nominal-adts`, `define-family`,
25-slice family roadmap) is **not** authority. Do not implement it.

## 3. Authority and reading order

Read these before writing the first checkpoint:

1. This brief.
2. `AGENTS.md`, `SPEC.md`, `docs/philosophy.md`, `docs/decisions.md`,
   `CHECKPOINTS.md`, `docs/handoff.md` on the current class-constructors
   line.
3. `docs/filesystem-vocabulary.md` — especially §4–§7 and §9. That is
   the consumer. Do not change its locked public Aloe API here.
4. Typed host boundary as already sealed on `main` (same as
   `codex/typed-host-boundary` at `0013e50`, plus `main`’s later handoff
   commit). Read:
   - `SPEC.md` §13 on `main`
   - `docs/decisions.md` “Typed host capabilities (2026-09-06)” on `main`
   - `docs/checkpoints/0083-validated-host-declarations.md` through
     `0088-seal-typed-host-boundary.md` on `main`
   - `aloe/host.rkt` on `main`

Do not check out other branches as your working copy. Browse them with
`git show`. Work from `experiment/class-constructors` as the parent of
the implementer’s branch.

## 4. Branch topology

```
experiment/class-constructors     # parent: constructors + case, no 83–88
  └── experiment/host-boundary    # implementer creates this
```

The first checkpoint must tell the implementer to create
`experiment/host-boundary` from current `experiment/class-constructors`
and **merge `main`** into it (not cherry-pick 83–88 by rewriting them,
not merge `codex/unified-nominal-adts`).

`main` is the source of the sealed host work. It is one handoff commit
ahead of `codex/typed-host-boundary`; merge `main`.

After the merge, keep **both** of these normative:

- constructor ratification, checkpoints 89–96, on this line
- typed host capabilities, checkpoints 83–88, from `main`

Do not let either swallow the other. Do not renumber historical
checkpoints. New work starts at **97**.

Expected merge tension (from a merge-tree preview; re-check at
implementation time): `SPEC.md`, `CHECKPOINTS.md`, `aloe/eval.rkt`,
`aloe/type.rkt`, `docs/decisions.md`, `docs/handoff.md`,
`docs/philosophy.md`. Host tests 83–88 and `aloe/host.rkt` changes
should come in as adds/updates from `main`. Constructor tests 89–96
must stay green.

## 5. What 83–88 already is (do not redesign)

A host capability is a Racket-created receiver, explicitly injected
with `driver-inject-host!`. One opaque `host-interface` descriptor is
the source of truth for runtime dispatch, checking, and Mirror.

Today’s crossing vocabulary is only `Int`, `Bool`, and `String`.
Strings are normalized both ways. Default environments have no optional
capability. Term is the first production capability and is not ambient.
There is no arbitrary Racket call and no second send rule.

Keep that architecture. Filesystem is a **second** optional injected
capability, later. Term stays unchanged.

## 6. Phase 1 — merge only (checkpoint 97)

Write this checkpoint first. Stop after it.

**Outcome.** `experiment/host-boundary` has the sealed 83–88
implementation **and** constructor 89–96. Full suite green, including
host tests 83–88 and constructor tests 89–96. Term hand check from
checkpoint 88 still holds. No filesystem capability. No new crossing
types.

**Reconciliation rules to put in the checkpoint:**

- `SPEC.md` must contain constructor rules **and** `main`’s typed-host
  section. Source type grammar still omits host interface names.
- `CHECKPOINTS.md` lists 83–88 (from `main`) and 89–96 (constructors),
  then this integration entry.
- `docs/handoff.md` describes runtime as constructors plus typed host
  boundary; it does not claim filesystem exists.
- Checker and evaluator must dispatch both constructor `case` and host
  sends. If a merge conflict would drop one, that is a failed
  checkpoint, not a compromise.
- Do not start filesystem selectors, `Path`, `Entry`, or `(List String)`
  crossing here.

**Hand check.** Keep checkpoint 88’s in-memory Term check
(`'("sealed" "sealed\r\n")`).

## 7. Phase 2 — extensions the filesystem vocabulary actually needs

Only after 97 is implemented and reviewed here: write a short working
design `docs/host-boundary-extensions.md` (not law), then checkpoints
for it, one at a time.

Design against the merged `aloe/host.rkt`, not from memory. The
pressure is already locked in `docs/filesystem-vocabulary.md` §7:

1. Homogeneous `(List String)` as a host crossing type, so a host
   method can return immediate directory names. Do not encode a listing
   as a delimiter-separated `String`.
2. An Aloe generic field must be able to retain a host-receiver type
   so `(define fs (Fs new fs-host))` typechecks, **or** document that
   the checker cannot and that filesystem must use the fallback in
   filesystem-vocabulary §4 (pass the host receiver as an argument).
   Prefer making the generic wrapper work if the change is small and
   local. Do not add source-written host interface names unless that
   is the only honest way to get the wrapper, and call that out as a
   SPEC change of its own checkpoint.
3. Do not provide `lib/option.aloe` here unless a host test cannot be
   written without it. Option as a loadable Aloe library belongs to
   the filesystem pair.

Then implement those extensions as **separate** checkpoints (98, 99,
…). `(List String)` crossing is its own slice. Wrapper/generic
host-type retention is its own slice if it needs code. Do not invent
`(List Entry)` crossing, nested lists, opaque path handles, or
`Result` crossing. Those are not in the first filesystem slice.

Host `names` returning `(List String)` is the crossing goal. Do not
implement `host/racket/fs.rkt` or Aloe `Path` / `Entry` / `Fs` in this
pair. A test host interface with a `names` method that returns
`(List String)` is enough evidence.

## 8. Locked filesystem demands (do not reopen)

You may not “simplify” the public Aloe vocabulary. You may only say
what the host seam must become so that vocabulary is implementable.

- `fs` is an Aloe wrapper; the injected host is not the public API.
- Host methods take and return crossing values only (`Int`, `Bool`,
  `String`, then `(List String)`).
- Suggested host facts: `current`, `resolve`, `child`, `root?`,
  `parent`, `name`, `kind`, `names`. Exact host selector spellings may
  be tightened in the filesystem pair, not by changing Path/Entry.
- `kind` strings: `"missing"`, `"file"`, `"directory"`, `"symlink"`,
  else `Other`. Mapping to `Option` / `Entry` is Aloe, not host.
- Absence is Aloe `None`, not a host `Option` type.
- I/O and permission errors stay host failures.
- No ambient filesystem capability.

## 9. Explicit non-goals for this pair

- Filesystem vocabulary implementation (`Path`, `Entry`, `Fs`,
  `lib/fs.aloe`, real directory goldens).
- Gel filesystem UI.
- Redesigning descriptor-driven injection, Term, or crossing
  validation architecture.
- Opaque host handles, source-written host types (unless §7.2 forces
  one dedicated checkpoint), `Result` crossing, bytes, mutable
  directory handles.
- Proposal A / `define-family`.
- Merging class constructors to `main`.
- Writing the filesystem designer brief.

## 10. When this pair is done

Stop when:

- 97 is green (constructors + sealed host boundary on one branch);
- `(List String)` crossing is green;
- the wrapper/generic host-type question is either implemented or
  explicitly resolved as the filesystem fallback;
- Term still works;
- no filesystem library exists yet.

Then tell the human this pair is complete. They return to the program
conversation. A later conversation will write filesystem checkpoints
from `docs/filesystem-vocabulary.md`.

## 11. First action

Write `docs/checkpoints/0097-integrate-typed-host-boundary.md` for
phase 1 only. Do not write 98 in the same turn. Do not edit
`aloe/`, `tests/`, or merge branches.
