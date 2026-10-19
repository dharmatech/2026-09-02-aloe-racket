# with

**Status: Complete. with 000 landed at `0aeeea6` and with 001 at
`c20a18f`, both 2026-10-08.** Standalone
checkpoints. **No charter. No spec.md. No checkpoint manager.**

Language change, then its Aloemacs consumer. Not Gel. Local
numbering: do not take the next global checkpoint integer, and do
not add this series to `CHECKPOINTS.md`, unless a human promotes it
after review.

**Project root:** `/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`checkpoints/000-field-update.md`](checkpoints/000-field-update.md) | Implemented; landed at `0aeeea6` |
| [`checkpoints/001-aloemacs-updates.md`](checkpoints/001-aloemacs-updates.md) | Implemented; landed at `c20a18f` |

Identity is `with`. Checkpoint 000 is spoken **with 000**. Checkpoint
001 is spoken **with 001**. Numbers are three digits, start at 000,
and are never renumbered. Do not issue 002 from this folder.

An instance of a `(fields ...)` class is updated by selector-position
`with`:

```scheme
(editor with
  (mark val)
  (scroll-row 0))
```

The tail is `(field expr)` pairs, including the one-field case.
Unmentioned fields stay. The result has the receiver's type. `new*`
stays the full labeled construction. **with 001** uses that form for
reconstructions of an existing Aloemacs instance. It does not change
behavior, and it does not change the startup construction in
`main.aloe`.

Process: [`docs/workflow.md`](../../../workflow.md).

If the implementer proves 001 is too big, stop and promote the
remaining classes to a charter rather than leaving the program half
converted.

Next conversation:

> Read `docs/workflow.md`. You are the implementer. Your assignment is `docs/design/implementation/with/checkpoints/001-aloemacs-updates.md`. If you have been told to read that file, it is the whole assignment.
