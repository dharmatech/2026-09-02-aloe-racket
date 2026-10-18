# Designer probes for aloemacs frame time

Evidence behind
[`docs/design/implementation/aloemacs/frame-time/spec.md`](../../../../docs/design/implementation/aloemacs/frame-time/spec.md),
taken on 18 October 2026 at `29c5103`, alone unless a number says
`-j 4`. Not a specification, not a checkpoint, not a test. The record
in the folder above is the discussion's; this folder is the designer's.

Every measurement ran in an `rsync` copy of the repository with one
variant's `.aloe` edits applied. No product file in the tree was
edited.

| File | What it is |
|---|---|
| [`prototype.diff`](prototype.diff) | The spec's design as revised: both checkpoints' product edits, the draft `tests/aloemacs/frame-time.rkt` and `frame-time-cells.rkt`, and the timing section removed from `window-pictures.rkt`. Applies to `29c5103` with `git apply`. A draft, not the checkpoints' text |
| [`variants.diff`](variants.diff) | The `.aloe` edits of each variant the spec measures: **A**, the record's doubled padding and block check; **B**, A with one zipper walk from the point; **C**, A with the List read of spec §6; **C4c**, A with a read through one joined String; **F**, the spec's first draft, which blanked the whole block and cut it back into rows; **G000b**, checkpoint 000's product edit alone |
| [`probe.rkt`](probe.rkt) | Medians of a sample for each variant and case. Its `ctl` fixture puts the tab on lines with *n* mod 7 = 0. Its `-key` and `-hk` cases put `handle-key` inside the clock; the spec's test sends `handle-event`, 0.01 ms more |
| [`pieces.rkt`](pieces.rkt) | Spec §7.5: one sample after the series, piece by piece. Its fixture is the spec's, *n* mod 7 = 3 |
| [`density.rkt`](density.rkt) | Spec §5.4's density table: `safe-rows` on one leaf for several mixes of controls |
| [`lines-from-equivalence.rkt`](lines-from-equivalence.rkt) | Spec §6.1's contract on small texts: 1,018 checks |
| [`grok-review.md`](grok-review.md) | Grok's review of the spec as committed in `9a30ec0`, verbatim |

Each probe takes a repository copy as its first argument and runs from
a `main` submodule, so `raco test` and `raco make` run nothing:

```sh
racket probe.rkt <tree> 2400 11 first,wide,one,wide-end,one-end
racket probe.rkt <tree> 2400 11 wide,one ctl
racket pieces.rkt <tree> 2400 2300
racket density.rkt <tree>
racket lines-from-equivalence.rkt <tree>
```

## After Grok's review

Measuring the review's density remark showed more than a missing
sentence. The first draft blanked controls in the whole joined block, so
each control copied the block: 85 ms for a 52×109 leaf of tabs and 310
ms for a 53×220 frame of them, against 25 and 52 ms today. The revised
§5.2 finds which controls the block holds and blanks only those, row by
row. It is never quadratic in the leaf, and at the densest mix it is
about a sixth slower than today. On the timed fixture's sparse tabs it
costs about 0.5 ms more than the first draft.

The revision also takes the review's other points:

- Every timed case gets its own session value.
- `other-window` stops after four sends.
- Each table names what its clock covers, and the payoff lines use one
  clock.
- The sample sends `handle-event`, the runner's own send.
- The cost model says the key still copies the file once.
- The spec says which margins the suite holds and which only review
  holds. An alone median above 15 ms fails a checkpoint.
- The `lines-from` contract covers well-formed texts only.

## Runs

The five whole-suite runs under `-j 4` in spec §8.5 used the tree from
`prototype.diff`, 3,806 tests each, with `PLTCOLLECTS="<tree>:"`. Each
had one failure, `tests/editor/lsp/009-launch.rkt`, which that override
causes and which passes alone without it. The inventory runs in spec
§13 used the product edits alone, with no new tests: 3,094 tests and the
same one failure. Today's code passes the draft `frame-time-cells.rkt`'s
702 checks that do not send `safe-rows`, so its reference painter agrees
with today's bytes.
