# aloemacs windows

**Status: Revised spec accepted; aloemacs-windows 000–006 implemented and verified in the current checkout; final human review pending.**
Not Aloe law. Not Gel. Not a global checkpoint. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment. The spec writer reads this |
| [`spec.md`](spec.md) | Accepted design authority: behavior, interfaces, revised partition, staging, file scopes, tests, and verification |
| [`scope-review.md`](scope-review.md) | Historical size finding and partition background; not the replacement spec |
| [`checkpoints/000-split.md`](checkpoints/000-split.md) | Historical returned assignment, unimplemented and unchanged; do not resume it |
| [`checkpoints/000-buffer-identity.md`](checkpoints/000-buffer-identity.md) | Implemented replacement aloemacs-windows 000; stable buffer identity, allocation, lookup, and buffer migration |
| [`checkpoints/001-state-foundation.md`](checkpoints/001-state-foundation.md) | Implemented aloemacs-windows 001; window types, session migration, and complete one-leaf state integration |
| [`checkpoints/002-synchronization-completion.md`](checkpoints/002-synchronization-completion.md) | Implemented aloemacs-windows 002; complete constructed multi-view state synchronization |
| [`checkpoints/003-layout-and-rendering.md`](checkpoints/003-layout-and-rendering.md) | Implemented aloemacs-windows 003; nominal geometry, explicit-origin rows, selected-view fit, composition, and resize fallback |
| [`checkpoints/004-split.md`](checkpoints/004-split.md) | Implemented aloemacs-windows 004; both split sends/commands/keys, nominal geometry guards, shared ownership, selected post-split fit, and echo rules |
| [`checkpoints/005-delete-and-other.md`](checkpoints/005-delete-and-other.md) | Implemented aloemacs-windows 005; next/wrap selection, origin handoff, sibling promotion, buffer-ID-dependent resets, deletion lock guards, and echo rules |
| [`checkpoints/006-lock.md`](checkpoints/006-lock.md) | Implemented aloemacs-windows 006; public lock toggle/key, exact-bit-only change, geometry protection, and preserved buffer/resize behavior |
| `checkpoints/` | 000–006 are issued and implemented. 006 is the final part of the accepted series; final human review remains |

Parent map: [`../README.md`](../README.md).

Series identity is **aloemacs-windows**. Replacement 000 is spoken
**aloemacs-windows 000** and is filed as
`checkpoints/000-buffer-identity.md`. The intended order is buffer
identity; window state and synchronization; layout, rendering, and fit;
both splits; delete and other-window; window lock.
[Spec §1](spec.md#1-series-predecessors-and-authority) records the original
000–005 partition and permits further state separation under §3.7.
The manager has applied [spec §3.7](spec.md#37-further-separation-of-window-state-when-needed)
to separate window state before issuing 001. That part combines four new
types, a session-constructor migration across twenty existing test files,
one-leaf operation integration, and constructed multi-view synchronization.
Keeping the last obligation separate gives the migration a complete,
independently tested stop. The number-to-part mapping is now:

| Identity | Part | Focused proof | State |
|---|---|---|---|
| **aloemacs-windows 000** | Buffer identity | `tests/aloemacs/windows-buffer-identity.rkt` | Implemented |
| **aloemacs-windows 001** | State foundation | `tests/aloemacs/windows-state-foundation.rkt` | Implemented |
| **aloemacs-windows 002** | Synchronization completion | `tests/aloemacs/windows-state.rkt` | Implemented |
| **aloemacs-windows 003** | Layout, rendering, and fit | `tests/aloemacs/windows-layout-and-rendering.rkt` | Implemented |
| **aloemacs-windows 004** | Both splits | `tests/aloemacs/windows-split.rkt` | Implemented |
| **aloemacs-windows 005** | Delete and other-window | `tests/aloemacs/windows-delete-and-other.rkt` | Implemented |
| **aloemacs-windows 006** | Window lock | `tests/aloemacs/windows-lock.rkt` | Implemented |

001 introduced `with-origin`, startup configuration, the window types,
session field, complete session-constructor migration, positive-size
bookkeeping, and existing-operation rules for one-leaf sessions. Several
buffers are supported; pure trees with several leaves are testable, but
multi-view session transitions and painting are not supported at its
intermediate stop. No constructor migration remains for its successor.

002 permits only `file.aloe` changes and creation of `windows-state.rkt`.
It proves selected-only mirroring/retargeting,
all-view killed-ID retargeting, singleton reset of matching views, and
exact inactive origins/locks/size. Current inventory searches show no
existing test needs an adjustment, so its checkpoint keeps every existing
test untouched. No constructor migration, editor/startup change, geometry,
or command belongs there. Constructed multi-view transitions become
supported; fit still uses the predecessor full text rectangle and painting
stays at the one-view contract. 003 replaces that temporary fit/paint
boundary with the accepted layout behavior, without adding commands.

003 may edit `editor.aloe` and `file.aloe`, creates
`windows-layout-and-rendering.rkt`, and permits only the temporary-fit
expectation adjustment in the existing `windows-state.rkt`. Inventory
searches found no other existing test adjustment necessary. It keeps all
direct-editor and one-view frame goldens exact. Constructed trees prove
multi-view rendering and resize through scripted host doubles; startup,
the actual runner, and all current keys remain unchanged. Both splits
follow after human review of 003.

004 may edit only `file.aloe` for product behavior and creates
`windows-split.rkt`, including actual production-runner split scenarios.
Its checkpoint permits narrow command/map inventory and newly bound
prefix-miss adjustments in eight named existing tests; all earlier state,
geometry, rendering, and effect proofs remain intact. Guards use selected
nominal geometry at the remembered size, even during display fallback.
Both child origins begin at the live pre-split origin; one post-split
fit changes only selected and the shared editor. Delete, other-window,
public view entry, and lock toggle remain later parts.

005 may edit only `file.aloe` for product behavior and creates
`windows-delete-and-other.rkt`, including actual production-runner
selection/deletion scenarios. Nine named existing test files may receive
only command/map inventory, newly bound prefix-miss, and now-owned
entry/command absence adjustments. Other-window visits tree order and
hands off origins without fitting; delete promotes the immediate sibling
and checks all four coordinates of surviving locked rectangles at the
remembered nominal size. Same-buffer entry preserves search/pending;
different-buffer entry resets them while keeping any prompt/slot.
The public lock toggle completes the series in implemented part 006.

006 may edit only `file.aloe` for product behavior and creates
`windows-lock.rkt`, including actual production-runner locking scenarios.
Ten named existing test files may receive only command/map inventory,
newly bound prefix-miss, and now-owned toggle absence adjustments.
Toggle changes only the selected lock bit. Existing guards protect
existence and all four nominal rectangle coordinates; exact unchanged
locked geometry permits deletion. Locks retain editing, buffer retargeting,
prompt, and terminal resize/fallback behavior. No visual marker is added.

The number-to-part mapping is fully issued; it creates no placeholder
checkpoint or later exploration authorization. Issued numbers remain
fixed. No maximum count was locked, and separation added no behavior.
The manager writes one
checkpoint at a time and stops for review. Do not write global 116 or
write `spec.md` from the discussion role.

A window is a view of a buffer. `C-x 2` and `C-x 3` split the
selected view. `C-x 0` deletes it. `C-x o` selects the next view.
`C-x l` toggles lock. Other commands leave the tree in place.
The mode line stays a later exploration.

The historical omnibus 000 was returned before implementation because
it exceeded one conversation. The user approved relaxing the checkpoint
count cap, and the revised accepted spec separates the work without
changing product behavior. Replacement 000 was then issued for buffer
identity. On 2026-10-03 the user reported that replacement implemented
and requested the next checkpoint. The manager issued state foundation
as 001 under the spec's permitted further separation. The accepted spec,
scope-review record, historical checkpoint, and implementation remained
unchanged by that checkpoint-manager turn.

Before issuing 001, manager starting-point verification on 2026-10-03:
`TMPDIR=/tmp raco test -y tests/aloemacs` passed all 372 tests, including
the completed buffer-identity proof. Tracked changes and the new
checkpoint/updated README passed whitespace checks. No product or test
file was edited by the manager.

On the user's next-checkpoint request, the manager found 001's complete
state foundation and focused proof present in the current checkout and
issued synchronization completion as 002, using the already recorded
§3.7 partition. No further separation or spec revision was needed.

Before issuing 002, manager starting-point verification on 2026-10-03:
`TMPDIR=/tmp raco test -y tests/aloemacs` passed all 381 tests, including
buffer identity and state foundation. That manager turn wrote only
`checkpoints/002-synchronization-completion.md` and updated this README.
The accepted spec, earlier checkpoints, product, and tests remain unchanged.

On the user's next-checkpoint request, the manager found 002's complete
constructed multi-view synchronization and focused proof present in the
current checkout and issued layout, rendering, and fit as 003. The number
mapping stays unchanged; no further separation or spec revision was needed.
This manager turn writes only `checkpoints/003-layout-and-rendering.md`
and updates this README. It leaves the accepted spec, earlier checkpoints,
product, and tests unchanged.

Manager starting-point verification for 003 on 2026-10-03:
`TMPDIR=/tmp raco test -y tests/aloemacs` passed all 393 tests, including
buffer identity, state foundation, and synchronization completion.
Tracked changes and the new checkpoint/updated README passed whitespace
checks; relative document links resolve. No product or test file was edited
by the manager.

On the user's next-checkpoint request, the manager found 003's layout,
rendering, selected-fit, fallback implementation, and focused proof
present in the current checkout and issued both splits as 004. The
number mapping stays unchanged; no further separation or spec revision
was needed. This manager turn writes only `checkpoints/004-split.md`
and updates this README. It leaves the accepted spec, earlier checkpoints,
product, and tests unchanged.

Manager starting-point verification for 004 on 2026-10-03:
`TMPDIR=/tmp raco test -y tests/aloemacs` passed all 403 tests, including
the completed layout/rendering proof and all earlier identity/state
proofs. Tracked changes and the new checkpoint/updated README passed
whitespace checks; relative document links resolve. No product or test
file was edited by the manager.

On the user's next-checkpoint request, the manager found 004's two
split commands, geometry guards, post-split fit, echo rules, production
runner scenarios, and focused proof present in the current checkout and
issued delete and other-window as 005. The number mapping stays unchanged;
no further separation or spec revision was needed. This manager turn
writes only `checkpoints/005-delete-and-other.md` and updates this README.
It leaves the accepted spec, earlier checkpoints, product, and tests
unchanged.

Manager starting-point verification for 005 on 2026-10-03:
`TMPDIR=/tmp raco test -y tests/aloemacs` passed all 414 tests, including
the completed split proof and all earlier identity/state/layout proofs.
Tracked changes and the new checkpoint/updated README passed whitespace
checks; all relative document links resolve. Checksums confirm that the
accepted spec, earlier checkpoints, product, and tests were unchanged
by this manager turn.

On the user's next-checkpoint request, the manager found 005's selection,
origin handoff, sibling promotion, geometry guards, echo/reset rules,
production-runner scenarios, and focused proof present in the current
checkout and issued window lock as 006. The number mapping stays
unchanged; no further separation or spec revision was needed. This
manager turn writes only `checkpoints/006-lock.md` and updates this
README. It leaves the accepted spec, earlier checkpoints, product,
and tests unchanged.

Manager starting-point verification for 006 on 2026-10-03:
`TMPDIR=/tmp raco test -y tests/aloemacs` passed all 428 tests, including
the completed delete/other-window proof and all earlier windows proofs.
Tracked changes and the new checkpoint/updated README passed whitespace
checks; all 29 relative document links resolve. Checksums confirm that
the accepted spec, earlier checkpoints, product, and tests were unchanged
by this manager turn.

On the user's next-checkpoint request, the manager found 006's public
toggle, selected-bit-only replacement, command/key integration, and
focused proof present in the current checkout. The accepted spec has no
remaining part: 006 is the final checkpoint after the permitted state
separation. No 007 is issued. This manager turn updates only this README;
the accepted spec, all issued checkpoints, product, and tests stay unchanged.

Manager closeout verification on 2026-10-03:
`TMPDIR=/tmp raco test -y tests/aloemacs/windows-lock.rkt` passed all
9 focused tests; `TMPDIR=/tmp raco test -y tests/aloemacs` passed all
437 tests. Source review confirms the toggle replaces only the selected
lock bit and deletion compares all four nominal rectangle coordinates.
Tracked changes and this README update passed whitespace checks.
Checksums confirm that the spec, issued checkpoints, product, and tests
were unchanged by this manager turn.

The next step is human review against spec §9's completed-series
acceptance. A mode line or another exploration needs its own design
assignment; it is not an additional checkpoint under this windows spec.
