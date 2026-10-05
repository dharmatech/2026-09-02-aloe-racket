# aloemacs completion

**Status: Checkpoint 000 reviewed on 2026-10-04; checkpoint 001 ready to implement.**
[`spec.md`](spec.md) places recursive scans on the fieldless nongeneric
`AloemacsCompletionScan`. Fs queries and prompt results stay on
`(AloemacsSession H)`. [000](checkpoints/000-complete-on-tab.md) is
implemented in the current working tree and reviewed against its
assignment. Its focused proofs pass (17 tests), and the full no-TTY
aloemacs suite passes (483 tests). Its original ready-to-implement status
records the earlier handoff.
[001](checkpoints/001-show-matches.md) is now the implementer assignment:
paint prepared lines above the prompt and use the shorter session root
for rendering and selected fit. The accepted spec remains the design
authority; no spec revision was needed for this handoff.
[checker-recursion](../../checker-recursion/) is withdrawn as a
predecessor and is not an assignment. Not Aloe law. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Designer assignment for the placement revision |
| [`spec.md`](spec.md) | Accepted design authority, including nongeneric scan placement |
| [`checkpoints/000-complete-on-tab.md`](checkpoints/000-complete-on-tab.md) | Implemented and reviewed: prefill, Tab, notes, and prepared names |
| [`checkpoints/001-show-matches.md`](checkpoints/001-show-matches.md) | Ready implementer assignment: list painting, session geometry, selected fit, and exact frame proof |

Parent map: [`../README.md`](../README.md).

Series identity is **aloemacs-completion**. Checkpoint 000 is
spoken **aloemacs-completion 000** and is filed as
`checkpoints/000-complete-on-tab.md`. Checkpoint 001 is spoken
**aloemacs-completion 001** and is filed as
`checkpoints/001-show-matches.md`. 000 is Tab on find-file and
save-as: prefill, prefix completion, and a readable result.
001 paints that result above the prompt. Do not write global
checkpoint numbers. Do not write `spec.md` in the discussion
that issued this charter.

`C-x C-f` and `C-x C-w` open with a directory or path already
in the prompt. Tab completes the last component. A unique
directory gains a trailing `/`. When Tab cannot add a
character, the matching names appear above the prompt. Return
still submits the typed text. Select-buffer, `M-x`, a live
list, and a directory browser stay later.

The idle-echo checkpoint stays its own handoff. This series
does not replace it.

A recursive send on `(AloemacsSession H)` re-enters its own body
check. PlainScan finishes; the same scan on a legacy generic
`(fields ...)` class does not. Spec §3.3 keeps `complete-prompt`
and Fs on the session and places the recursive scans on
`AloemacsCompletionScan`. The checker stays unchanged.

Next handoff:

> Read `docs/workflow.md`. You are the implementer. Your assignment is `docs/design/implementation/aloemacs/completion/checkpoints/001-show-matches.md`. Read its accepted spec authority, implement aloemacs-completion 001 only, run its focused proofs and the full aloemacs suite, and stop when green. If you have been told to read that file, it is the whole assignment.
