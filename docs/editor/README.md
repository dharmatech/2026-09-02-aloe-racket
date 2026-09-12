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
| 1 | Source locations | [`source-locations/`](source-locations/) | **Brief.** Start here. | — |
| 2 | Signatures of a type | [`signatures-of-type/`](signatures-of-type/) | Charter. Independent of 1. | — |
| 3 | Expression query | [`expression-query/`](expression-query/) | Charter. After 1 and 2 exist. | 1, 2 |
| 4 | LSP adapter | [`lsp/`](lsp/) | Charter. After 3 exists. | 3 |

Project 2 can be designed while 1 is being built. Project 3 must not
start until 1 and 2 are specified (3's charter says what to wait for).
Project 4 must not start until 3 has a spec and a working query.

A VS Code extension is a client of 4, not a fifth language project.
It is named in the LSP charter as a later thin client. Do not open a
VS Code folder until the adapter's spec exists.

## Not in this map

These are easy to smuggle in as "editor prerequisites." They are not.

- Incomplete / unclosed buffer recovery
- A new parser, or leaving the Racket reader
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
| Source locations | Tests of spans; then type errors with `path:line:column` |
| Signatures of a type | Tests against `Mirror` rows; REPL / Gel may reuse later |
| Expression query | A Racket function and, if the spec wants it, a CLI |

If a proposed slice has no consumer besides "we will need this for
LSP," it is too early.
