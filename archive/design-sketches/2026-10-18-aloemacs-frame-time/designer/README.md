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
| [`prototype.diff`](prototype.diff) | The spec's design: both checkpoints' product edits, the draft `tests/aloemacs/frame-time.rkt` and `frame-time-cells.rkt`, and the timing section removed from `window-pictures.rkt`. Applies to `29c5103` with `git apply`. A draft, not the checkpoints' text |
| [`variants.diff`](variants.diff) | The `.aloe` edits of each variant measured in spec §5.4, §6.3, and §7: **A**, the record's doubled padding and block check; **B**, A with one zipper walk from the point; **C**, A with the List read of spec §6; **C4c**, A with a read through one joined String; **G000**, checkpoint 000's product edit alone |
| [`probe.rkt`](probe.rkt) | Medians of the test's sample for each variant and case. Its `ctl` fixture puts the tab on lines with *n* mod 7 = 0 |
| [`pieces.rkt`](pieces.rkt) | Spec §7.5: one sample after the series, piece by piece. Its fixture is the spec's, *n* mod 7 = 3 |
| [`lines-from-equivalence.rkt`](lines-from-equivalence.rkt) | Spec §6.1's contract on small texts: 1,018 checks |

Each probe takes a repository copy as its first argument and runs from
a `main` submodule, so `raco test` and `raco make` run nothing:

```sh
racket probe.rkt <tree> 2400 11 first,wide,one,wide-end,one-end
racket probe.rkt <tree> 2400 11 wide,one ctl
racket pieces.rkt <tree> 2400 2300
racket lines-from-equivalence.rkt <tree>
```

The five whole-suite runs under `-j 4` in spec §8.5 used the tree from
`prototype.diff` before two later touches: `frame-time-cells.rkt` was
not yet written, and `lines-from` sent `indexed-value` first instead of
taking the `from-string` arm itself, with the same results. They ran
with `PLTCOLLECTS="<tree>:"`. Each run had one failure,
`tests/editor/lsp/009-launch.rkt`, which that override causes and which
passes alone without it. With the final `lines-from`, `tests/aloemacs`
passed 673 tests before the draft cells file was added, and the 1,018
equivalence checks passed. The draft `frame-time-cells.rkt` then passed
its 709 checks on the final tree and on checkpoint 000's tree alone.
Today's code passes the draft's 702 checks that do not send
`safe-rows`, so its reference painter agrees with today's bytes.
