# Editor source locations

Local experiment. Not Aloe law. Not Gel. Not a global checkpoint.

| File | Role |
|---|---|
| [`checkpoint-manager.md`](checkpoint-manager.md) | Assignment for the slicing conversation |
| [`checkpoints/000-spans.md`](checkpoints/000-spans.md) | **Implemented and reviewed.** `read-program` expression spans; datum compatibility |

Predecessor: current `aloe/parse.rkt` (`read` then `parse-datum`).
This series does not continue Gel numbering and does not continue
the global spine.

Editor-source-locations 000 is implemented and reviewed. No later checkpoint
has been issued; editor-source-locations 001 remains unissued.

Editor-lsp 010 amends 000: `read-program` positions and spans count
CR and LF as two characters of the source text. Lines, columns, and
sources are still the reader's.
