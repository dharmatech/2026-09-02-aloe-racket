# Editor LSP adapter

Local experiment. Not Aloe law. Not Gel. Not a global checkpoint.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment that produces the spec |
| [`spec.md`](spec.md) | Reviewed design specification for the local series |
| [`checkpoints/000-hover.md`](checkpoints/000-hover.md) | **Implemented and reviewed.** End-to-end unchanged ASCII/LF Point hover |
| [`checkpoints/001-utf16-positions.md`](checkpoints/001-utf16-positions.md) | **Implemented and reviewed.** Complete UTF-16 and line-break position conversion |
| [`checkpoints/002-document-sync.md`](checkpoints/002-document-sync.md) | **Implemented and reviewed.** Atomic full-document change and close synchronization |
| [`checkpoints/003-buffer-snapshots.md`](checkpoints/003-buffer-snapshots.md) | **Implemented and reviewed.** Dirty-buffer sibling snapshots and relative-load preservation |
| [`checkpoints/004-hover-results.md`](checkpoints/004-hover-results.md) | **Implemented and reviewed.** Query-failure recovery and exact Hover rendering edges |
| [`checkpoints/005-framing.md`](checkpoints/005-framing.md) | **Implemented and reviewed.** Complete byte framing and recoverable JSON parse errors |
| [`checkpoints/006-json-rpc.md`](checkpoints/006-json-rpc.md) | **Implemented and reviewed.** Decoded JSON-RPC validation and method dispatch |
| [`checkpoints/007-lifecycle.md`](checkpoints/007-lifecycle.md) | **Implemented and reviewed.** Complete initialize, shutdown, exit, and EOF state machine |
| [`checkpoints/008-adapter-failures.md`](checkpoints/008-adapter-failures.md) | **Implemented and reviewed.** Recoverable unexpected Hover-adapter failures |
| [`checkpoints/009-launch.md`](checkpoints/009-launch.md) | **Implemented and reviewed.** Installed-module stdio launch and process status |

Editor-lsp 000–009 are implemented and reviewed. The planned local editor-lsp
series is complete; no further checkpoint is ready to implement.
