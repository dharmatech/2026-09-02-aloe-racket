# spine

The global checkpoint spine: the checkpoints numbered across the
whole language, and the briefs, designer assignments, locked
vocabularies, and one-conversation charters that produced them. The
index is [`CHECKPOINTS.md`](CHECKPOINTS.md), in this folder.
[`SPEC.md`](../../../../SPEC.md) is law.

The spine is closed at **checkpoint 118** (2026-10-19). No further
global number is issued, and nothing new is written here. A change to
the kernel is a series folder beside this one, with
`(project, number)` identity. Process:
[`docs/workflow.md`](../../../workflow.md).

Every file here lived at the top of `docs/` until docs-layout 000
moved it. Contents are unchanged apart from paths.

## Checkpoints

`checkpoints/NNNN-slug.md`. The files present run from `0072` to
`0118`. `CHECKPOINTS.md` records every number: 1 through 71 predate
per-checkpoint documents, 12 through 52 are `tests/checkpoint-N.rkt`,
and the index says where 108 through 113 and 116 through 117 live.

| Range | Topic | Written from |
|---|---|---|
| 0072–0082 | Gel stack, step, key, rows, picks, text | [`docs/gel.md`](../../../gel.md), law for the Gel phase |
| 0083–0088, with 0083a | Typed host boundary | `docs/decisions.md`, Typed host capabilities (2026-09-06) |
| 0089–0096 | Class constructors and `case`, Proposal B | [`class-constructors.md`](class-constructors.md) |
| 0097–0099 | The typed host boundary on the constructor branch, `(List String)` crossing, generic retention | [`host-boundary-designer.md`](host-boundary-designer.md), [`host-boundary-extensions.md`](host-boundary-extensions.md) |
| 0100–0104 | `Option` library and the thin filesystem library | [`filesystem-designer.md`](filesystem-designer.md), [`filesystem-vocabulary.md`](filesystem-vocabulary.md) |
| 0105–0107 | Live `Disk`, `Location`, and `Item` | [`filesystem-oo-surface.md`](filesystem-oo-surface.md), [`filesystem-oo-vocabulary.md`](filesystem-oo-vocabulary.md), [`filesystem-oo-designer.md`](filesystem-oo-designer.md) |
| 0114–0115 | String `len`, `take`, `starts-with?` | [`string-len-take-brief.md`](string-len-take-brief.md), [`string-starts-with-library-brief.md`](string-starts-with-library-brief.md) |
| 0118 | The evaluator under the compile limit | [`evaluator-compile-limit-brief.md`](evaluator-compile-limit-brief.md) |

## Briefs, vocabularies, and charters

| File | Role | Status |
|---|---|---|
| [`host-boundary-designer.md`](host-boundary-designer.md) | Designer brief for checkpoints 97–99 | Complete through 99 |
| [`host-boundary-extensions.md`](host-boundary-extensions.md) | Working design for the `(List String)` crossing and generic retention | Implemented by 98–99 and 101–104 |
| [`class-constructors.md`](class-constructors.md) | Proposal B: constructors and receiver-anchored `case` | Ratified into `SPEC.md` by checkpoint 96; historical |
| [`filesystem-designer.md`](filesystem-designer.md) | Designer brief for the thin filesystem library | Complete through 104 |
| [`filesystem-vocabulary.md`](filesystem-vocabulary.md) | Locked thin vocabulary, `lib/fs.aloe` | Implemented through 104 |
| [`filesystem-oo-surface.md`](filesystem-oo-surface.md) | Design-conversation brief for the live surface | Produced `filesystem-oo-vocabulary.md` |
| [`filesystem-oo-vocabulary.md`](filesystem-oo-vocabulary.md) | Locked live vocabulary, `lib/disk.aloe` | Implemented through 107; `Location.entries` and `enter` not issued |
| [`filesystem-oo-designer.md`](filesystem-oo-designer.md) | Checkpoint-manager brief for 105–107 | Complete |
| [`string-len-take-brief.md`](string-len-take-brief.md) | Checkpoint-manager brief for 114 | Landed |
| [`string-starts-with-library-brief.md`](string-starts-with-library-brief.md) | Checkpoint-manager brief for 115 | Landed |
| [`evaluator-compile-limit-brief.md`](evaluator-compile-limit-brief.md) | Checkpoint-manager brief for 118 | Landed 2026-10-18 at `29c5103` |
| [`0.3-language-merge.md`](0.3-language-merge.md) | One-conversation charter: land the language work on `main` | Landed at `8b0a110` |
| [`editor-lsp-merge.md`](editor-lsp-merge.md) | One-conversation charter: land editor support on `main` | Landed at `266e031` |
| [`parser-checker-elegance.md`](parser-checker-elegance.md) | One-conversation charter: one grammar, one checker | Landed at `8701dce` |
| [`boid-monomorphic-brief.md`](boid-monomorphic-brief.md) | One-shot brief: monomorphic `Boid` | Landed; `Boid` is monomorphic in `examples/boids.aloe` |

Each file keeps its own **Status** line. When this table and that
line disagree, the file is right.
