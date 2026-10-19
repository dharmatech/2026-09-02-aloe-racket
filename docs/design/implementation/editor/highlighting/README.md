# Editor syntax highlighting

Local experiment. Not Aloe law. Not Gel. Not a global checkpoint.
Not a language query: this is a VS Code client skin over lexical
rules. It is not LSP semantic tokens and not tree-sitter.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment that produces the spec |
| [`spec.md`](spec.md) | Reviewed design specification for the local project |
| [`checkpoints/000-lexical-highlighting.md`](checkpoints/000-lexical-highlighting.md) | **Implemented and reviewed.** TextMate lexical scopes and declarative language configuration |

Depends on the implemented and reviewed **editor-vscode 000**: language id
`aloe` and the extension in `editors/vscode/` already exist. Do not write
global checkpoints or reopen Hover, completion, or `aloe/lsp.rkt`.

Implemented and reviewed: **editor-highlighting 000**. This local project is
closed with exactly one slice; do not issue 001.
