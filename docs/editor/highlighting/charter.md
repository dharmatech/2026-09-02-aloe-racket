# Charter — VS Code lexical highlighting

**Status.** Handoff from the highlighting discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/editor/README.md`](../README.md).

**Your job.** Turn this charter into a specification for a **TextMate
grammar plus language configuration** in the existing Aloe VS Code
extension, so `.aloe` buffers color comments, strings, numbers,
booleans, SPEC special forms, and capitalized type/class names.
Then **stop**. Do not write checkpoints. Do not implement. Do not
specify LSP semantic tokens, tree-sitter, selector-position coloring,
themes, snippets, wrap-the-preceding-form, or aloemacs highlighting.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter and the authority in §5.
2. Confirm predecessors in §2 exist. If not, **stop**.
3. Record the locked decisions in §4. Resolve only §4.8.
4. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **editor-highlighting 000** under
   `docs/editor/highlighting/checkpoints/` (not `docs/checkpoints/`,
   not `docs/editor/vscode/checkpoints/`, not a new hover series).
   The expected series is **one checkpoint**. Do not plan 001.
5. Stop. The human reviews it. Do not write those checkpoint files
   and do not add grammar files.

The checkpoint manager and implementers will not have this charter.
Put every rule they need in the specification.

Keep the spec **small enough to slice once**. A second Aloe parser,
semantic tokens, a tree-sitter grammar, a keyword list of library
selectors, and GitHub Linguist registration are defects in this
document.

## 2. Predecessors (do not start without these)

| Project | Ready when |
|---|---|
| [`../vscode/`](../vscode/) | editor-vscode 000 implemented and reviewed; language id `aloe`; extension in `editors/vscode/` |

Hover and completion already work. Opening a `*.aloe` file still
looks like plain text. This project colors the buffer **in the
editor**, without asking the language server.

editor-vscode 000's spec currently forbids a grammar and bracket
configuration. This project supersedes that prohibition. It does
not reopen hover, launch, or `aloe.racketPath`. Do not rewrite
[`../vscode/checkpoints/000-hover-client.md`](../vscode/checkpoints/000-hover-client.md).
The highlighting spec must name which editor-vscode 000 **tests**
and which vscode-spec sentences this project amends.

## 3. Why this experiment exists

Aloe is edited in VS Code. The useful first coloring is lexical:

- comments and literals so strings do not look like code
- SPEC special forms so `define-class` / `let` / `case` stand out
- capitalized names so types and classes are easy to scan

SPEC already says type and class names start with a capital letter
**by convention**, not by enforcement. That is a highlighter rule,
not a checker rule.

Semantic tokens and tree-sitter are real later layers. They are
not this experiment. Incomplete buffers already constrain the
checker; highlighting must keep working while the file is broken
and while the language server is down.

## 4. Locked decisions (record these; do not reopen 4.1–4.7)

The discussion already picked these. The spec restates them as law.

### 4.1 Layout and identity

| | Path |
|---|---|
| Spec, checkpoints | `docs/editor/highlighting/` |
| Grammar, language configuration, tests | `editors/vscode/` |

Identity is `(editor-highlighting, 000)`, spoken
**editor-highlighting 000**. This is not editor-vscode 001 and not
a global Aloe checkpoint.

Do not put files under `aloe/`, `host/`, `docs/design/`, or the
repository root. Do not create a second VS Code extension.

### 4.2 Mechanism

- One TextMate grammar contributed on language id `aloe`
  (`scopeName` `source.aloe`).
- One `language-configuration.json` for comments, brackets, and
  auto-closing pairs, referenced from the existing language
  contribution.
- Coloring is client-side. The grammar must work if Racket is
  missing and if the language server never starts.
- Do not advertise or implement `semanticTokensProvider`.
- Do not add a tree-sitter grammar, WASM parser, or JavaScript
  Aloe reader.

### 4.3 What to color in 000

Required:

| Kind | Rule |
|---|---|
| Line comments | `;` to end of line (files use `;;` by convention; both are `;` comments) |
| Strings | `"…"` with the usual escapes the Racket reader accepts |
| Numbers | `Int` and `Float` literals |
| Booleans | `#t` `#f` |
| Special forms | the closed list in §4.4 |
| Section words | the closed list in §4.5 |
| Capitalized names | identifiers matching `[A-Z][A-Za-z0-9]*` as types/classes |

Capitalized names also pick up constructors (`Some`, `None`) and
type parameters (`T`, `U`). That is intended: every nominal name
stands out from selectors and locals. Do not try to separate
classes from constructors in 000.

The type rule must not fire inside comments or strings.

### 4.4 Special-form keyword list (closed)

Color these as keywords, and **only** these, plus §4.5:

- `define`
- `define-class`
- `define-methods`
- `define-protocol`
- `fn`
- `let`
- `if`
- `cond`
- `load`
- `check`
- `case`

This list is SPEC special forms (sections 4 and 11), not a catalog
of messages. Do **not** color `call`, `new`, `self`, field names,
or library selectors (`len`, `append`, `starts-with?`, …).

### 4.5 Section words (closed)

Color these as keywords when they appear as identifiers:

- `fields`
- `methods`
- `constructors`
- `type`
- `else`

`else` is `cond` / `case` syntax. `type` is the method-local type
parameter header. Do not add `quote`, `begin`, or other Scheme
forms that are not Aloe special forms.

### 4.6 Out of 000

- LSP semantic tokens, inlay hints, diagnostics coloring
- Tree-sitter
- Coloring **selector position** (the second element of a send)
- Coloring `self` as a keyword
- Distinguishing constructors from classes from type parameters
- A keyword list of kernel or library selectors
- Rainbow parens as a custom feature (VS Code bracket-pair
  colorization is enough once `()` are in language configuration)
- Themes, snippets, formatters, wrap-the-preceding-expression
- GitHub Linguist, Shiki, Markdown fenced-block injection
- Neovim, Emacs, aloemacs, or a second editor
- Changes to `aloe/*.rkt`, hover, completion, or document sync
- Marketplace publication, TypeScript, bundlers, Electron tests

### 4.7 Tests and vscode 000 amendments

- Automated proof must tokenize fixtures and check scopes. Opening
  VS Code is not the only test.
- Do not add `@vscode/test-electron` or an Electron harness.
- Existing editor-vscode 000 tests currently assert that
  `package.json` contributes only `configuration` and `languages`,
  and that there are no `devDependencies`. This project **must**
  update those assertions so the suite stays green. Do not leave
  000 tests failing. Do not delete the hover/launch proofs.
- Acceptance hand check: Extension Development Host, open an
  existing `.aloe` fixture (for example
  [`tests/editor/lsp/fixtures/point.aloe`](../../../tests/editor/lsp/fixtures/point.aloe)
  or [`lib/text.aloe`](../../../lib/text.aloe)). Confirm comments,
  strings, numbers, booleans, special forms, and capitalized names
  are colored, and that hover on `(Point new 1 2)` is unchanged.
- `editors/vscode/` `npm test` remains the Node test command.

### 4.8 Leftovers (resolve these)

1. **TextMate scopes.** Pick ordinary scopes so Dark+ already
   colors them. A starting table, not a requirement to copy
   blindly:

   | Kind | Suggested scope |
   |---|---|
   | Line comment | `comment.line.semicolon.aloe` |
   | String | `string.quoted.double.aloe` |
   | Integer / float | `constant.numeric.aloe` |
   | `#t` `#f` | `constant.language.boolean.aloe` |
   | Special forms | `keyword.control.aloe` |
   | Section words | `keyword.other.aloe` |
   | Capitalized names | `entity.name.type.aloe` |

   Record the chosen scopes in the spec. Change the table only to
   make a built-in theme actually color the token.

2. **Block and sexp comments.** Line comments are required. Decide
   whether `#| … |#` and `#;` are in 000. If they are not cheap
   and well-tested, leave them out; the Racket reader still
   accepts them, they just stay uncolored.

3. **Grammar test harness.** Name the tool and the fixture
   location. A pinned extension-local `devDependency` for
   TextMate token tests is allowed. Do not add a repository-root
   Node package. Do not use Electron.

4. **Language configuration details.** Comments, `()`, and
   auto-closing quotes/parens are required. Decide
   `wordSeparators` / word pattern so Aloe identifiers such as
   `starts-with?` and `before?` behave as words. Do not invent
   indentation rules beyond what language configuration can say
   without a formatter.

5. **Grammar file shape.** JSON TextMate grammar under
   `editors/vscode/` (for example `syntaxes/aloe.tmLanguage.json`).
   No YAML build step unless you can justify it; 000 has no
   compile step today.

Do not use §4.8 to add features from §4.6.

## 5. Authority

- `SPEC.md` §1 (capitalized type/class convention), §4 and §11
  (special forms)
- [`../vscode/spec.md`](../vscode/spec.md) — existing extension
  identity, launch, hover; this project amends only the "no
  grammar / no language configuration" non-goals
- [`../vscode/checkpoints/000-hover-client.md`](../vscode/checkpoints/000-hover-client.md)
  — tests that must stay passing except for the named manifest
  amendments
- [`../README.md`](../README.md)
- VS Code [syntax highlight guide](https://code.visualstudio.com/api/language-extensions/syntax-highlight-guide)
  and language-configuration docs, as needed for contribution
  shape

`SPEC.md` remains Aloe language law. This spec is not language law.
Do not treat library files or `aloe/parse.rkt` as a second keyword
list.

## 6. Non-goals

- Reimplementing Aloe in JavaScript
- Editing `aloe/lsp.rkt`, the checker, expression query, or
  completion query
- Semantic tokens, tree-sitter, selector highlighting
- Diagnostics, go-to-definition, formatting
- Teaching the editor a catalog of messages
- Gel, aloemacs, GitHub linguist
- Global Aloe checkpoints

## 7. Git

Work lives on branch `experiment/2026-09-19-syntax-highlighting`,
cut from `main` at the parser/checker elegance landing
(`0aa1a4a`). Do not implement on
`experiment/2026-09-19-aloemacs` or
`experiment/2026-09-12-editor`. Do not merge those branches into
this one.

Landing on `main` is a later human decision after 000 is reviewed.
This conversation does not merge, push, or rebase aloemacs.
