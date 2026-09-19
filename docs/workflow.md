# Conversation workflow

Baseline process for new work in this repository. Not Aloe language
law. `SPEC.md` remains law. Change this file when a project needs a
different shape; do not reverse-engineer the process from folder
layout.

## Why conversations are split

A high-level discussion, a specification, a checkpoint series, and an
implementation do not belong in the same chat. Each later conversation
starts without the earlier transcript. The artifact that conversation
writes must carry every rule the next conversation needs.

## Default pipeline

```text
high-level discussion
        │
        ├─ map / README   (what exists, order, non-goals)
        └─ charter.md     (open questions, bar, authority)
                │
                ▼
        designer conversation
                │  writes spec.md, then stops
                ▼
        checkpoint-manager conversation
                │  writes one checkpoint, then stops
                ▼
        implementer conversation
                │  implements that checkpoint, tests, stops when green
                ▼
        human review → next checkpoint (or back to charter / spec)
```

Do not skip human review between stages. Do not write the rest of a
checkpoint series in advance.

## Roles

### High-level discussion

Decide whether the work exists, what it is for, what it is not, and
how it splits into projects. Write a map and, when the shape is still
open, a charter per project.

This conversation does not write `spec.md`, does not write
checkpoints, and does not implement.

When the work is already locked (a vocabulary, a SPEC amendment, a
small kernel lift), the high-level discussion may write a **brief**
that goes straight to a checkpoint manager. That is the "Brief"
case in [`docs/editor/README.md`](editor/README.md).

### Designer

Reads one charter. Resolves its open questions. Writes `spec.md` in
the same folder. Stops.

Does not write checkpoints. Does not implement. Does not specify a
later project inside an earlier project's spec.

The checkpoint manager will not have the charter in context. Every
rule needed to slice the work belongs in the spec.

### Checkpoint manager

Reads the spec, or a brief that already is the design. Writes **one**
checkpoint document. Stops.

After the human reviews an implementation against that checkpoint,
this conversation — or a new one pointed at the same brief — writes
the next number. It never issues `000`–`00N` as a batch.

Does not implement. Does not merge. Does not invent design the spec
left open. If the spec is impossible to slice, send it back.

The implementer will not have the spec conversation or the manager
brief. Every rule needed to implement the slice belongs in the
checkpoint.

The manager conversation may also review the implementer's diff
**against the written checkpoint**, not against this chat. If the
checkpoint was ambiguous, that is a design defect: fix the document
before authorizing a follow-up.

### Implementer

Reads the one approved checkpoint, plus the authority that checkpoint
names. Implements only that slice. Adds tests in the same change.
Runs the named verification. Stops when green.

Does not start the next checkpoint. Does not silently add adjacent
features. Does not amend `SPEC.md` or a public API unless the
checkpoint says so.

## Checkpoint size

A checkpoint is one conversation of implementation.

- Large enough to be a meaningful, testable section: a vertical slice
  or a closed algebra, not a one-line rename.
- Small enough that an implementer can finish it without running out
  of context: one feature, named files, named tests, named non-goals.
- Wrong: an omnibus "do the filesystem" or "do the language server"
  checkpoint.
- Wrong: a slice so thin that the next three have to be opened before
  anything is proved.

If a slice cannot be tested without the next slice, it is not a
checkpoint yet. Combine or redesign.

## Checkpoint contents

Follow the existing shape
([`docs/checkpoints/0103-fs-path-algebra.md`](checkpoints/0103-fs-path-algebra.md),
[`docs/editor/lsp/checkpoints/000-hover.md`](editor/lsp/checkpoints/000-hover.md)):

- goal
- depends on / identity
- authority and starting point
- exact file scope (may edit / must not edit)
- required behavior
- tests and any hand check
- acceptance
- explicit non-goals

Identity is either a global number (`checkpoint 103`) or
`(project, number)` spoken **project 000** (for example
`editor-lsp 000`). Do not mix local project work into
`CHECKPOINTS.md` or `docs/checkpoints/` unless the work is actually
on the language spine.

## Where files live

### Language spine

Used for kernel, host boundary, and libraries that extend Aloe
itself.

| Artifact | Path |
|---|---|
| Checkpoints index | [`CHECKPOINTS.md`](../CHECKPOINTS.md) |
| Checkpoint | `docs/checkpoints/NNNN-slug.md` |
| Tests | `tests/checkpoint-N.rkt` |
| Designer / manager brief | `docs/<topic>-designer.md` or `docs/<topic>-brief.md` |

### Local project

Used for application or editor work that must not take the next
global integer. New projects default here:

```text
docs/design/implementation/<project>/
  README.md              map entry / status
  charter.md             designer assignment (if shape is open)
  spec.md                designer output
  checkpoint-manager.md  optional; manager assignment for 000
  checkpoints/000-slug.md
```

A project that still has open shape questions may use a subfolder
per layer (`text/`, `term/`, …) under that root, each with its own
charter, spec, and `checkpoints/`. Identity remains
`(project, number)` or `(project-layer, number)`.

Tests sit under `tests/<project>/`, not `tests/checkpoint-N.rkt`.

Existing local maps stay where they are. Do not move
[`docs/editor/`](editor/README.md) into `docs/design/implementation/`.
Do not put new work under `docs/editor/` unless it is actually that
editor-support line.

## Handoff

Start the next conversation by naming one file:

> Read `docs/workflow.md`. You are the designer. Your assignment is
> `docs/design/implementation/<project>/charter.md`. If you have been
> told to read that file, it is the whole assignment.

Each assignment file should say that last sentence itself.

Typical next-conversation jobs:

| Role | Read first |
|---|---|
| Designer | the project's `charter.md` |
| Checkpoint manager | the project's `spec.md`, or a `*-designer.md` / `*-brief.md` / `checkpoint-manager.md` |
| Implementer | the one checkpoint file |

## When not to use this pipeline

Stay in one conversation when the work is not a design-and-slice
problem, for example:

- Fast-forwarding already-landed work onto `main`
  ([`docs/0.3-language-merge.md`](0.3-language-merge.md))
- A small refactor whose charter already names the slices
  ([`docs/parser-checker-elegance.md`](parser-checker-elegance.md))
- A question, investigation, or map with no code

Those charters should say they are not a designer spec and not a
checkpoint-manager split.
