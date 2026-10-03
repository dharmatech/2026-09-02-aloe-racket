# aloemacs minibuffer

**Status: Both checkpoints implemented, reviewed, and accepted.**
Not Aloe law. Not Gel. Not a global checkpoint. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment. The spec writer reads this |
| [`spec.md`](spec.md) | Accepted design authority for the checkpoint manager and implementers |
| [`checkpoints/000-prompt-value.md`](checkpoints/000-prompt-value.md) | Implemented, reviewed with no findings, and accepted |
| [`checkpoints/001-type-submit-cancel.md`](checkpoints/001-type-submit-cancel.md) | Implemented, reviewed with no findings, and accepted |

Parent map: [`../README.md`](../README.md).

Series identity is **aloemacs-minibuffer**. Checkpoint 000 is spoken
**aloemacs-minibuffer 000** and is filed as
`checkpoints/000-prompt-value.md`. Checkpoint 001 is spoken
**aloemacs-minibuffer 001** and is filed as
`checkpoints/001-type-submit-cancel.md`. 000 is the prompt value
on the echo row. 001 is typing, submit, and cancel. Do not write
global 116. Do not write `spec.md` in the discussion that issued
this charter.

The prompt is its own small editor, shown on the echo row, outside
the buffer zipper. A test starts it, types, submits or cancels, and
reads the submitted string. The current buffer stays as it was.
Find-file, save-as, named switch-buffer, completion, and windows
stay later series.

000 is implemented, reviewed against its written checkpoint with no
findings, and accepted by the user. The product diff preserves the
required value, session reconstruction, visit, and frame contracts;
the focused proof covers them, and the fourteen migrated test files
retain their substantive assertions. Editor, runner, commands, keymaps,
input routing, host, library, and language boundaries remain intact.

Reported implementation verification is 13 expected initial focused
failures, followed by 13 focused tests and 292 full aloemacs tests
passing, with `git diff --check` clean. The manager reviewed the product
diff, focused tests, and migrated fixtures and independently checked
whitespace; the manager did not rerun the test suites.

001 is implemented, reviewed against its written checkpoint with no
findings, and accepted by the user. The product adds exactly six prompt
editing methods, five session methods, and the active-prompt routing arm. Start guards,
quit/search/prompt/idle precedence, buffer/editor preservation, ignored
keys, submission lifetime, and the retained frame/visit seams follow
the accepted design. The extended value tests retain 000's proof; the
new session tests use independent expectations, state snapshots, and
counted Fs doubles. Existing product and fixture changes from 000 are
preserved, with no new command, binding, runner, host, library, or
language change.

Reported initial verification was 18 expected failures among 31 focused
tests. Final reported verification is 31 focused tests and 310 full
aloemacs tests passing, with `git diff --check` clean. The manager
reviewed the product changes and both focused test files and
independently checked whitespace; the manager did not rerun the test
suites. The completed series is accepted against the accepted
[`spec.md`](spec.md) §5. This series ends at 001; there is no 002.
Commands that consume the submitted string remain a later series.

Original implementer handoff for 001:

> Read `docs/workflow.md`. You are the implementer. Your assignment is `docs/design/implementation/aloemacs/minibuffer/checkpoints/001-type-submit-cancel.md`. If you have been told to read that file, it is the whole assignment.

Original implementer handoff for 000:

> Read `docs/workflow.md`. You are the implementer. Your assignment is `docs/design/implementation/aloemacs/minibuffer/checkpoints/000-prompt-value.md`. If you have been told to read that file, it is the whole assignment.

Original designer handoff:

> Read `docs/workflow.md`. You are the designer. Your assignment is `docs/design/implementation/aloemacs/minibuffer/charter.md`. If you have been told to read that file, it is the whole assignment.
