# Editor host-configured queries

Local experiment. Not Aloe law. Not Gel. Not a global checkpoint.

Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

Series identity `host-queries`, spoken **editor-host-queries 000**.
Checkpoints, when a later conversation writes them, live in
`checkpoints/` and are numbered from 000. Tests live in
`tests/editor/host-queries/`. Code stays in the project root. Branch:
`experiment/2026-10-16-host-queries`, on top of
`experiment/2026-10-14-definition`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment that produces the spec |
| [`spec.md`](spec.md) | Design specification. Reviewed 2026-10-16 (revised in review, 5432ff6); the authority for the checkpoints |
| [`checkpoints/000-query-hosts.md`](checkpoints/000-query-hosts.md) | Written 2026-10-16, awaiting review: layer 1 (spec §2). `#:hosts` on the three queries, the checker's `query-host-binding` hook, and host binding on the query base. Not implemented |

Hover and go-to-definition miss on every position in
`examples/aloemacs/main.aloe`, because the file uses the injected
`fs-host`. They miss on `gel/main.aloe` the same way, because of `term`.
Completion still answers where its receiver is typed before that use,
but it offers nothing after `(fs-host ` or `(term `. Only the runners
inject those hosts. This project adds a manifest beside
the program. The language server reads the manifest and binds each
host's type, taken from the real interface, on the query's base. Nothing
is evaluated.

Depends on **expression query**, **editor-lsp 000–010**, **completion**,
and **editor-definition 000–003** (closed at `6deecab`). Parent map:
[`../README.md`](../README.md), project 9.

**Status.** Spec reviewed and accepted 2026-10-16. Editor-host-queries
000 is written and awaits the human's review. Next: after that review,
an implementer conversation implements
[`checkpoints/000-query-hosts.md`](checkpoints/000-query-hosts.md).
