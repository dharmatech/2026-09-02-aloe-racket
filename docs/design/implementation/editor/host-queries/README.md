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
| [`checkpoints/000-query-hosts.md`](checkpoints/000-query-hosts.md) | Implemented 2026-10-16, manager-reviewed (conforming), accepted: layer 1 (spec §2). `#:hosts` on the three queries, the checker's `query-host-binding` hook, and host binding on the query base. Focused test: 12 test cases in `tests/editor/host-queries/000-query-hosts.rkt`, with four fixtures under `tests/editor/host-queries/fixtures/configured/`. Whole suite: 3075 tests (3059, the 12 new cases, and 4 modules-census cases for the new fixtures); under `-j 4` the only failure was `tests/aloemacs/window-pictures.rkt`'s 30 ms timing bar (30.5 ms), which passes alone (27.5 ms). The one existing test edit is completion 002's keyword line |
| [`checkpoints/001-manifest-reader.md`](checkpoints/001-manifest-reader.md) | Implemented 2026-10-16, manager-reviewed (conforming), accepted 2026-10-17: layer 2, first part (spec §2's reader/server split). `aloe/host-manifest.rkt` with `read-document-hosts`, the effects rule in `host/racket/README.md`, the effects census, and the static-require proof. Focused test: 9 test cases in `tests/editor/host-queries/001-manifest-reader.rkt`, with the fixtures `configured/aloe-hosts.rktd` and `configured/failing.aloe`. Whole suite: 3085 tests, all passing under `-j 4` (3075, the 9 new cases, and 1 modules-census case for `failing.aloe`), no existing test edited. Editor-host-queries 002, the server side, follows it |
| [`checkpoints/002-lsp-hosts.md`](checkpoints/002-lsp-hosts.md) | Implemented 2026-10-17, manager-reviewed (conforming), hand check passed, accepted: layer 2, second part, the last. `aloe/lsp.rkt` passes a document's manifest hosts to hover, definition, and completion; the two product manifests `examples/aloemacs/aloe-hosts.rktd` and `gel/aloe-hosts.rktd`; the `broken/` fixtures. Focused test: 6 test cases in `tests/editor/host-queries/002-lsp-hosts.rkt`. Whole suite: 3092 tests (3085, the 6 new cases, and 1 modules-census case for `broken/neighbor.aloe`); under `-j 4` the only failure was `tests/aloemacs/window-pictures.rkt`'s 30 ms timing bar (33.2 ms), which passes alone (29.1 ms). The three edited tests are the require-list pins in `tests/editor/lsp/004-hover-results.rkt`, `tests/editor/lsp/008-adapter-failures.rkt`, and `tests/editor/completion/003-lsp-completion.rkt`. `npm test` in `editors/vscode/` passes 14 of 14. The VS Code hand check is the human's |

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
000 ([`checkpoints/000-query-hosts.md`](checkpoints/000-query-hosts.md))
is implemented, manager-reviewed (conforming), and accepted. Layer 2 is
split at the reader/server seam. Editor-host-queries 001
([`checkpoints/001-manifest-reader.md`](checkpoints/001-manifest-reader.md)),
the manifest reader, is implemented, manager-reviewed (conforming), and
accepted. Editor-host-queries 002
([`checkpoints/002-lsp-hosts.md`](checkpoints/002-lsp-hosts.md)), the
server side and the last checkpoint, is implemented, manager-reviewed
(conforming), and accepted. The VS Code hand check passed.

**Series stop (2026-10-17).** Both layers of the spec are implemented:
the queries accept host interfaces (000), and the language server reads
a document's `aloe-hosts.rktd` row and passes its hosts (001, the
reader; 002, the server). Hover, completion, and go to definition answer
in `examples/aloemacs/main.aloe` and `gel/main.aloe` in VS Code, with no
client change. The spec has no further layer, so no
editor-host-queries 003 is issued. Its non-goals (§14) stay out of
scope: runners reading the manifest, a factory element, diagnostics for
a manifest, caching or file watching, definition into Racket source,
and `tui-term` in `info.rkt`'s deps. New work there starts from a
high-level discussion, not from this series.
