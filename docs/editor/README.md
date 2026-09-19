# Editor support — prerequisite projects

Local work. Not Aloe law. Not Gel. Not the global checkpoint spine
(`docs/checkpoints/`, `CHECKPOINTS.md`). Do not number these 118,
119, … .

The editor question is already in `docs/philosophy.md`: ask what
messages an expression understands **before the program runs**. VS
Code / LSP is a later host skin over language queries, the same way
`host/racket/gel-run.rkt` is a TTY skin over Gel. Do not start at
the skin.

Identity is `(project, number)`. Spoken name is **project 000**.

## Process

Each project is either:

- **Brief** — the work is locked enough to slice. A checkpoint-manager
  conversation writes local `000`, `001`, … under that folder.
- **Charter** — open questions remain. A **new** designer conversation
  reads the charter, writes `spec.md` in that folder, and stops. It
  does not write checkpoints and does not implement.

Do not design or implement a later project in an earlier project's
conversation.

## Order

| # | Project | Path | This conversation | Depends on |
|---|---|---|---|---|
| 1 | Source locations | [`source-locations/`](source-locations/) | **Implemented and reviewed.** editor-source-locations 000. | — |
| 2 | Signatures of a type | [`signatures-of-type/`](signatures-of-type/) | **Implemented and reviewed.** editor-signatures-of-type 000–002. | — |
| 3 | Expression query | [`expression-query/`](expression-query/) | **Implemented and reviewed.** editor-expression-query 000–003. | 1, 2 |
| 4 | LSP adapter | [`lsp/`](lsp/) | **Implemented and reviewed.** editor-lsp 000–009. | 3 |
| 5 | VS Code client | [`vscode/`](vscode/) | **Implemented and reviewed.** editor-vscode 000 (hover). | 4 |
| 6 | Completion | [`completion/`](completion/) | **Implemented and reviewed.** editor-completion 000–003. | 3, 4 |

Projects 1–6 are implemented and reviewed. Project 5 is the VS Code hover
client. Project 6's reviewed [`completion/spec.md`](completion/spec.md) is
implemented by editor-completion 000–002 for the public Racket query and 003
for its LSP integration.

Incomplete-buffer recovery is **in** project 6's first spec (one named
rule, tested). It remains out of hover. Highlighting, wrap-form, and
top-level name completion stay off this map.

## Not in this map

These are easy to smuggle in as "editor prerequisites." They are not.

- A new parser, or leaving the Racket reader
- Full incremental parse / as-you-type recovery beyond the one named
  completion rule
- Macros / `syntax-rules` / `syntax-case`
- Wrap-the-preceding-expression as a VS Code command
- Rename, go-to-definition, semantic tokens, formatting
- Embedding Gel in VS Code
- Global checkpoints

Library methods, host receivers, and (later) library macros should
show up because the **query** reads the checker after expansion, not
because the editor learned a new keyword.

## First consumer of each language project

| Project | Consumer that is not VS Code |
|---|---|
| Source locations | Tests of spans; then the expression query |
| Signatures of a type | Tests against `Mirror` rows; REPL / Gel may reuse later |
| Expression query | A Racket function and, if the spec wants it, a CLI |
| Completion | Snippet + cursor unit tests; LSP then wraps the same function |

If a proposed slice has no consumer besides "we will need this for
LSP," it is too early.
