# aloemacs prompt commands

**Status: Complete. Checkpoints 000–002 implemented, reviewed with no findings, and accepted.**
Not Aloe law. Not Gel. Not a global checkpoint. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment. The spec writer reads this |
| [`spec.md`](spec.md) | Accepted design authority for the checkpoint manager and implementers |
| [`checkpoints/000-find-file.md`](checkpoints/000-find-file.md) | Implemented, reviewed with no findings, and accepted |
| [`checkpoints/001-save-as.md`](checkpoints/001-save-as.md) | Implemented, reviewed with no findings, and accepted |
| [`checkpoints/002-select-buffer.md`](checkpoints/002-select-buffer.md) | Implemented, reviewed with no findings, and accepted |
| `checkpoints/` | All three implemented, reviewed, and accepted. Series complete; no 003 |

Parent map: [`../README.md`](../README.md).

Series identity is **aloemacs-prompt-commands**. Checkpoint 000 is
spoken **aloemacs-prompt-commands 000** and is filed as
`checkpoints/000-find-file.md`. Checkpoint 001 is spoken
**aloemacs-prompt-commands 001** and is filed as
`checkpoints/001-save-as.md`. Checkpoint 002 is spoken
**aloemacs-prompt-commands 002** and is filed as
`checkpoints/002-select-buffer.md`. 000 is find-file. 001 is
save-as. 002 is selection by the derived buffer name. Do not write
global 116. Do not write `spec.md` in the discussion that issued
this charter.

Find-file, save-as, and named selection are commands that start the
existing prompt. Return runs the command on the submitted string.
Escape runs nothing. Direct `visit` still replaces the current
buffer. Completion, a directory listing, and windows stay later
series.

The spec was reviewed against the existing prompt, buffer zipper, command
dispatch, and filesystem seams and accepted under the user's instruction
to proceed if it was ready.

**aloemacs-prompt-commands 000** is implemented, reviewed against its
written checkpoint with no findings, and accepted by the user. The manager
reviewed the product diff, the focused proof, and all sixteen migrated
test files. Command execution, bounded current-first lookup, the shared visit/find-file read
policy, slot threading, submission/completion order, buffer preservation,
and the retained editor/runner/host boundaries follow the accepted design.
The migrated tests retain their substantive assertions and replace only
the newly bound find-file prefix-miss cases with positive chord coverage.

The implementer reported initial failures from missing slot, lookup, and
chord behavior. The manager independently reran the named verification:
15 focused tests and 326 full aloemacs tests passed, and
`git diff --check` was clean. The user accepted 000 and requested 001.

**aloemacs-prompt-commands 001** is implemented, reviewed against its
written checkpoint with no findings, and accepted by the user. The
manager reviewed the SaveAs command/start/completion arms, nested
binding, path helpers, submitted
write action, new focused proof, and five existing test updates. One thin
write precedes binding; successful writes retain the exact editor and
neighbors; refusals and cancellation preserve the specified values and
effects. The thirteen-field session, shared protocol, find-file behavior,
and editor/runner/host boundaries remain within the accepted design.
Existing assertions are retained, with growing inventories and positive
save-as chord coverage replacing only the newly bound prefix-miss cases.

The implementer reported initial failures from missing SaveAs/helpers
and the unbound chord. The manager independently reran the named
verification: 32 combined focused tests and 343 full aloemacs tests
passed, and `git diff --check` was clean. The user accepted 001 and
requested 002.

**aloemacs-prompt-commands 002** is implemented and reviewed against its
written checkpoint with no findings, and accepted by the user. The
manager reviewed SelectBuffer's constructor/name/start/completion arms,
the final nested binding, submitted selection action, new focused proof,
and five existing test updates. Selection sends the exact typed string
to the existing bounded lookup and uses the existing selection helper;
it makes zero Fs calls. Current-first and forward duplicate matching,
exact editor/path/order retention, misses, cancellation, and complete
runner frames follow the accepted design. The thirteen-field session,
single waiting slot, earlier command behavior, and editor/host/runner
boundaries remain intact. Existing proofs retain their substantive
assertions and update only the growing inventories and newly bound chord.

The implementer reported an initial focused run failing 18 of 19 tests
on missing behavior. The manager independently reran the named
verification: 51 combined focused tests and 362 full aloemacs tests
passed, and `git diff --check` was clean. The user accepted 002 and
requested a commit of the complete change set. The series is complete.
The checkpoint manager updated the review records and parent maps,
with no product or test edits.
002 is the final checkpoint; do not write 003 or start another feature.

Original implementer handoff for 002:

> Read `docs/workflow.md`. You are the implementer. Your assignment is `docs/design/implementation/aloemacs/prompt-commands/checkpoints/002-select-buffer.md`. If you have been told to read that file, it is the whole assignment.

Original implementer handoff for 001:

> Read `docs/workflow.md`. You are the implementer. Your assignment is `docs/design/implementation/aloemacs/prompt-commands/checkpoints/001-save-as.md`. If you have been told to read that file, it is the whole assignment.

Original implementer handoff for 000:

> Read `docs/workflow.md`. You are the implementer. Your assignment is `docs/design/implementation/aloemacs/prompt-commands/checkpoints/000-find-file.md`. If you have been told to read that file, it is the whole assignment.

Original designer handoff:

> Read `docs/workflow.md`. You are the designer. Your assignment is `docs/design/implementation/aloemacs/prompt-commands/charter.md`. If you have been told to read that file, it is the whole assignment.
