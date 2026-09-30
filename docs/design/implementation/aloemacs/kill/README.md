# aloemacs kill

**Status.** Spec accepted. Aloemacs-kill 000 and 001 are implemented and
reviewed. 002 is implemented and awaits human review. Clearing the mark uses the
zero-argument `clear-mark` method specified in §4. Not Aloe law,
Gel, or a global checkpoint. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment. The spec writer reads this |
| [`spec.md`](spec.md) | Accepted design authority for this series |
| [`checkpoints/000-text-excerpt.md`](checkpoints/000-text-excerpt.md) | `Text.excerpt` checkpoint, implemented |
| [`checkpoints/001-mark-kill-yank.md`](checkpoints/001-mark-kill-yank.md) | Session mark, kill, and yank, implemented |
| [`checkpoints/002-term-kill-keys.md`](checkpoints/002-term-kill-keys.md) | Physical key conversion, implemented; awaiting human review |

Parent map: [`../README.md`](../README.md).

Series identity is **aloemacs-kill**. Checkpoint 000 is the
`Text.excerpt` read. Checkpoint 001 is the mark, the kill-ring,
and yank. Checkpoint 002 maps the four physical chords. Do not write
global 116. Do not paint the region, and
do not add a host clipboard in this series.

Human review of 002 is next. Compare its two-file change with the checkpoint
and the accepted spec, including the raw NUL decoding test. The focused test
and full aloemacs suite pass. No 003 is planned.
