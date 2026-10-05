# aloemacs completion page

**Status: Spec accepted; aloemacs-completion-page 000 ready to implement.**
The checkpoint manager reviewed [`spec.md`](spec.md) and issued
[000 — Page the list](checkpoints/000-page-the-list.md), then stopped.
Implementation and its human review follow in a separate conversation.
Not Aloe law. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Designer assignment |
| [`spec.md`](spec.md) | Accepted design authority for the manager and implementer |
| [000 — Page the list](checkpoints/000-page-the-list.md) | Ready to implement; the only checkpoint in this series |

Parent map: [`../README.md`](../README.md). Predecessor:
[`../completion/`](../completion/). This series does not edit that
spec or its checkpoints.

Series identity is **aloemacs-completion-page**. Checkpoint 000 is
spoken **aloemacs-completion-page 000** and is filed as
`checkpoints/000-page-the-list.md`. 000 moves a window over the
names the last Tab already matched, on find-file and save-as.
Return still submits the typed text. Do not write global checkpoint
numbers. Do not write `spec.md` in the discussion that issued this
charter.

The accepted spec chooses Page Down and Page Up, with no wrap at either end.
Windows keep the existing eight-row cap: seven names and a summary when
any retained names are hidden; up to eight names need no summary. The
summary counts all names outside the current window. 000 is the whole
series; there is no 001.

`C-x C-f` and `C-x C-w` already list a directory on Tab. Past eight
prepared rows the last row is a count. This series shows the names
behind that count. A live list, a highlighted row, and a directory
browser stay later.

Next handoff:

> Read `docs/workflow.md`. You are the implementer of aloemacs-completion-page 000. Your assignment is `docs/design/implementation/aloemacs/completion-page/checkpoints/000-page-the-list.md`. If you have been told to read that file, it is the whole assignment.
