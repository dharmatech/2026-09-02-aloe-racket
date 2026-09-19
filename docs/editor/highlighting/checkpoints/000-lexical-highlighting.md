# Editor highlighting 000 — VS Code lexical highlighting

**Status.** Implemented and reviewed; closed successfully. Both extension-
local Node test files and `git diff --check` are green. The required Extension
Development Host checks passed for lexical scopes, editor interactions,
unchanged Hover, and highlighting with Racket unavailable.

## Goal

Extend the existing local VS Code extension in `editors/vscode/` with one
JSON TextMate grammar and one declarative language configuration for language
id `aloe`. Opening a `.aloe` file must color Aloe lexical tokens immediately,
including when Racket is unavailable or the Aloe language server never
starts.

This slice adds only lexical highlighting, comment configuration, parenthesis
and quote pairing, and Aloe word selection. It does not change the extension's
JavaScript, language-server behavior, Hover, completion, document
synchronization, activation event, or launch configuration. It does not
advertise or register semantic tokens.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, predecessors, and identity

- `SPEC.md` section 1 owns Aloe atoms and the convention that nominal names
  begin with a capital letter. Sections 4 and 11 own the closed special-form
  set. This highlighter does not amend Aloe language law.
- `docs/editor/highlighting/spec.md` is the reviewed local design authority
  from which this checkpoint is issued.
- `docs/editor/vscode/spec.md` owns the existing extension identity, launch,
  lifecycle, Hover behavior, document selector, and `aloe.racketPath`.
- Editor-vscode 000 is implemented and reviewed. This checkpoint amends only
  its prohibitions on a TextMate grammar and language configuration and the
  corresponding manifest and dependency assertions named below.
- The VS Code syntax-highlighting and language-configuration contribution
  shapes are the editor-platform authority. The Racket reader owns string
  escapes and reader comments; it does not supply another Aloe keyword list.

Identity is `(editor-highlighting, 000)`, spoken **editor-highlighting 000**.
This is not editor-vscode 001, an editor-lsp checkpoint, or a global Aloe
checkpoint. Do not edit `CHECKPOINTS.md`, add a file under
`docs/checkpoints/`, or continue the numbering after this slice. There is no
editor-highlighting 001.

Work on the existing `experiment/2026-09-19-syntax-highlighting` branch. Do
not move this work to an aloemacs or general editor branch and do not merge,
push, rebase, or land it as part of this checkpoint.

## Exact implementation file scope

Implementation may add or update only:

- `editors/vscode/package.json`;
- `editors/vscode/package-lock.json`;
- `editors/vscode/language-configuration.json`;
- `editors/vscode/syntaxes/aloe.tmLanguage.json`;
- `editors/vscode/test/000-highlighting.test.js`;
- `editors/vscode/test/fixtures/highlighting.aloe`; and
- the manifest, dependency, and lockfile assertions explicitly superseded
  below in `editors/vscode/test/000-hover-client.test.js`.

Do not edit:

- `editors/vscode/extension.js`, `client-options.js`, `.gitignore`, or
  `.vscode/launch.json`;
- `docs/editor/vscode/checkpoints/000-hover-client.md` or any project
  specification, charter, README, or checkpoint document;
- `aloe/`, `host/`, `gel/`, `lib/`, `examples/`, or repository Racket tests;
- the editor-lsp, completion, expression-query, signatures-of-type, or
  source-locations projects; or
- a repository-root package manifest, lockfile, test, build step, or ignore
  rule.

Do not create another extension, language id, grammar source, generated
grammar, production tokenizer module, compiler, or bundled output directory.

## Manifest and package changes

Retain every existing extension identity and behavior:

- name `aloe-language-client`;
- display name `Aloe`;
- publisher `aloe-local`;
- version `0.0.1`;
- CommonJS entry `./extension.js`;
- VS Code engine `^1.82.0`;
- activation event `onLanguage:aloe`;
- the sole `aloe.racketPath` setting; and
- the sole runtime dependency `vscode-languageclient` pinned exactly to
  `9.0.1`.

The existing `contributes.languages` array remains a one-entry array. Add
only `configuration` to that entry:

```json
{
  "id": "aloe",
  "aliases": ["Aloe"],
  "extensions": [".aloe"],
  "configuration": "./language-configuration.json"
}
```

Add exactly one `contributes.grammars` entry:

```json
{
  "language": "aloe",
  "scopeName": "source.aloe",
  "path": "./syntaxes/aloe.tmLanguage.json"
}
```

The contribution keys are exactly `languages`, `configuration`, and
`grammars`. Do not contribute another language, grammar, setting, command,
snippet, theme, menu, keybinding, debug adapter, task, or editor feature.

Add exactly these extension-local test dependencies, pinned without range
operators:

```json
"devDependencies": {
  "vscode-oniguruma": "2.0.1",
  "vscode-textmate": "9.3.2"
}
```

Property order is not semantic. Keep `scripts` exactly
`{ "test": "node --test" }`. Add no build, generation, lint, package,
publish, prepublish, or Electron script. Regenerate the extension-local
`package-lock.json` from the manifest. Its root entry must record the two
exact development dependencies, and the installed entries for
`node_modules/vscode-oniguruma` and `node_modules/vscode-textmate` must be
versions `2.0.1` and `9.3.2`, respectively. Do not add
`@vscode/test-electron`, TypeScript, a bundler, or a second runtime
dependency.

The dependencies are test-only. Neither tokenizer package is loaded by
`extension.js`.

## TextMate grammar

Add one JSON grammar at
`editors/vscode/syntaxes/aloe.tmLanguage.json`. Its top-level `scopeName` is
exactly `source.aloe`, and it loads under that scope through
`vscode-textmate.Registry`. There is no YAML source, conversion step,
injection grammar, embedded language, or second scope root.

Assign these scopes:

| Source token | Required TextMate scope |
|---|---|
| `;` line comment, including the delimiter | `comment.line.semicolon.aloe` |
| nested `#| ... |#` block comment, including delimiters | `comment.block.aloe` |
| double-quoted string, including quotes | `string.quoted.double.aloe` |
| recognized escape within a string | `constant.character.escape.aloe` |
| integer or float literal | `constant.numeric.aloe` |
| `#t` or `#f` | `constant.language.boolean.aloe` |
| special form from the closed set below | `keyword.control.aloe` |
| section word from the closed set below | `keyword.other.aloe` |
| capitalized nominal name | `entity.name.type.aloe` |

Unmatched source retains only `source.aloe`. Parentheses need no custom scope;
bracket matching and VS Code bracket-pair colorization come from the language
configuration.

### Closed keyword sets

Only these identifiers receive `keyword.control.aloe`:

```text
define define-class define-methods define-protocol fn let if cond load check case
```

Only these identifiers receive `keyword.other.aloe`:

```text
fields methods constructors type else
```

Keyword matching is position-independent. Do not try to decide whether a
token is in list-head or selector position.

A complete identifier matching `[A-Z][A-Za-z0-9]*` receives
`entity.name.type.aloe`. This deliberately includes class and type names,
constructors such as `Some` and `None`, and type parameters such as `T` and
`U`. Do not distinguish those categories.

The following remain ordinary `source.aloe` identifiers: `call`, `new`,
`self`, `quote`, `begin`, field names, and kernel or library selectors such
as `len`, `append`, `starts-with?`, and `before?`.

### Complete-token boundaries

Keyword, boolean, numeric, and capitalized-name matches must consume one
complete reader token. For this grammar, a token boundary is the start or end
of input, whitespace, or one of these datum delimiters:

```text
( ) [ ] { } " ' ` , ;
```

Do not use `\b`. Punctuation not listed above remains part of an identifier
for boundary purposes. In particular, `define-class?`, `my-Point`, `#true`,
and `Some?` must not be partially scoped as `define-class`, `Point`, `#t`, or
`Some`. Numeric prefixes in symbols must likewise remain unscoped.

### Rule precedence and regions

Order and structure the grammar so comments and strings win over all ordinary
token rules, floats win over integers, and both keyword groups win over
capitalized names. Only the escape rule is active inside a string. Only the
recursively included block-comment rule is active inside a block comment.
Keywords, booleans, numbers, and capitalized names must never acquire their
ordinary scopes inside a comment or string.

A semicolon begins a line comment and scopes through the physical end of
line. Both `;` and `;;` therefore work.

A `#|` begins `comment.block.aloe` and ends at its matching `|#`. The block
rule includes itself so nested and multi-line block comments work.
Unterminated block comments retain their comment scope through end of
document. Ordinary tokenization resumes after the matching outer delimiter.

`#;` S-expression comments are intentionally not recognized. Correct datum
termination would require a reader-like recursive grammar. `#;` therefore
receives no comment scope in this checkpoint even though Racket accepts it.

### Numbers

Recognize these ordinary decimal spellings:

- integer: optional `+` or `-`, then one or more decimal digits;
- float: optional `+` or `-`, then either a decimal point with digits on at
  least one side, or decimal digits followed by `e` or `E`; and
- either float form may have an exponent with an optional sign and required
  digits.

Integers and floats both receive `constant.numeric.aloe`. Full-token
boundaries are required. Radix, exactness, rational, complex, NaN, infinity,
and other Racket number spellings need not be recognized.

### Strings and escapes

A string begins and ends with `"` and may span lines. The string itself
receives `string.quoted.double.aloe`. Inside it, scope these recognized Racket
reader escapes as `constant.character.escape.aloe`:

- simple escapes `a`, `b`, `t`, `n`, `v`, `f`, `r`, `e`, `"`, `'`, and `\`;
- one-to-three-digit octal escapes;
- one-to-two-digit `x` escapes;
- one-to-four-digit `u` escapes;
- one-to-eight-digit `U` escapes; and
- an escaped LF, CR, or CRLF newline.

Longer alternatives take precedence when one is a prefix of another. The
escape rule must consume an escaped quote so it does not close the string.
An invalid escape need not receive the escape sub-scope; its surrounding text
remains string-scoped until an unescaped closing quote or end of document. An
unterminated string retains its string scope through end of document.

## Exact language configuration

Add `editors/vscode/language-configuration.json` with exactly this parsed JSON
value, apart from insignificant whitespace:

```json
{
  "comments": {
    "lineComment": ";",
    "blockComment": ["#|", "|#"]
  },
  "brackets": [["(", ")"]],
  "autoClosingPairs": [
    { "open": "(", "close": ")", "notIn": ["string", "comment"] },
    { "open": "\"", "close": "\"", "notIn": ["string", "comment"] }
  ],
  "surroundingPairs": [
    ["(", ")"],
    ["\"", "\""]
  ],
  "wordPattern": "[^\\s()\\[\\]{}\"'`,;]+"
}
```

The word pattern uses the grammar's delimiter set. Double-click, word
navigation, and completion replacement therefore treat `starts-with?`,
`before?`, `define-class`, `empty?`, `+`, and `<=` as whole words. Use
`wordPattern`; do not mutate or document a user `editor.wordSeparators`
setting.

Do not add square or curly bracket pairs, a single-quote pair, comment
continuation, folding markers, `onEnterRules`, indentation rules, formatting,
or Lisp indentation.

## Fixture and tokenizer harness

Add `editors/vscode/test/fixtures/highlighting.aloe` as the human and automated
token survey. It must include enough source to exercise all ordinary token
categories, every closed-set keyword, representative nominal names, nested
multi-line block comments, and the ordinary unscoped identifiers and
near-misses listed above. Include positive and negative integers and floats,
both booleans, `;` and `;;` comments, and strings with representative simple,
octal, hexadecimal/Unicode, escaped-quote, escaped-backslash, and continued-
line escapes. Capitalized-looking and keyword-looking text must also appear
inside strings and comments so the suite proves region precedence.

Add `editors/vscode/test/000-highlighting.test.js` using `node:test` and
`node:assert`. Load `vscode-oniguruma/release/onig.wasm`, the JSON grammar, and
scope `source.aloe` through a `vscode-textmate.Registry`. Tokenize the fixture
one physical line at a time and carry each returned rule stack into the next
line. Inspect token text and complete scope stacks. Merely parsing JSON,
matching the source with parallel JavaScript regular expressions, or
snapshotting colored pixels is not proof of the grammar.

Small inline source arrays may cover mutually exclusive end-of-document cases
such as an unterminated string and an unterminated block comment. They must use
the same loaded grammar and tokenization helper as the fixture. Tests must not
start Racket, load the language server, launch VS Code or Electron, access the
network, or use a production tokenizer.

At minimum, the automated tests prove:

1. The manifest retains the exact extension name, display name, publisher,
   version, CommonJS entry, VS Code engine, extension id, activation event,
   setting, runtime dependency, test script, and sole language id. The
   language contribution has the exact configuration path, and the sole
   grammar contribution has the exact language, root scope, and path above.
2. The grammar and language-configuration files parse as JSON, the grammar
   loads as `source.aloe`, and tokenization requires no Racket process,
   language server, VS Code instance, or network request.
3. Both styles of line comment, strings and all representative escape
   families, positive and negative integers and floats, and `#t`/`#f` receive
   exactly the required scopes.
4. Every identifier in both closed keyword sets receives its assigned scope.
   Similar, punctuated, or prefixed identifiers do not receive partial scopes.
5. Representative class/type names, `Some`, `None`, `T`, and `U` receive
   `entity.name.type.aloe`, while capitalized-looking text in strings, line
   comments, and block comments does not.
6. A nested multi-line block comment remains comment-scoped through its
   matching outer `|#`, ordinary tokenization resumes afterward, and
   unterminated string and block-comment sources retain their enclosing scope
   through end of document.
7. `#;` receives no comment scope. `call`, `new`, `self`, `quote`, `begin`,
   `len`, `append`, `starts-with?`, and `before?` receive none of the keyword
   or type scopes.
8. The language configuration is exactly the parsed value above. Compile its
   word pattern and prove punctuation-bearing Aloe identifiers are selected
   whole.
9. Existing hover-client tests continue to prove the exact server command,
   document selector, launch configuration, production boundary, and Node
   syntax. No old proof is deleted or weakened except for the manifest and
   dependency assertions this checkpoint necessarily supersedes.

## Required amendments to the existing tests

Update, rather than delete, these assertions in
`editors/vscode/test/000-hover-client.test.js`:

- `manifest has the exact extension identity and Aloe contribution` must
  expect the language configuration path and `grammars` as the third
  contribution key.
- `manifest has one pinned runtime dependency and only a Node test script`
  must expect exactly the two pinned development dependencies while retaining
  its exact runtime dependency and script assertions.
- `lockfile pins the root and language client without test or build tooling`
  must expect both root development dependencies and their two installed lock
  entries. It must continue to reject `@vscode/test-electron`, TypeScript, and
  bundlers.

Do not alter the assertions for server options, client options, launch
configuration, production JavaScript, or Node syntax except for a mechanical
test-name clarification if necessary. Do not make the old suite import the
production extension or start Racket.

## Human success checks

From `editors/vscode/`, install dependencies from the committed lockfile, run
`npm test`, and launch the existing Extension Development Host configuration.
Use built-in Dark+ and open `test/fixtures/highlighting.aloe`. Also open an
existing Aloe file such as `tests/editor/lsp/fixtures/point.aloe` or
`lib/string.aloe`.

Confirm:

- comments, strings, numbers, booleans, every present special form, section
  words, and capitalized names are visibly distinct where the source contains
  them;
- `Developer: Inspect Editor Tokens and Scopes` reports the exact required
  scope for any category whose theme colors are visually close;
- parenthesis matching and insertion, quote insertion, comment toggling, and
  whole-word selection of a punctuation-bearing selector work;
- with the normal Aloe server prerequisite available, Hover on the final
  `(Point new 1 2)` in the Point fixture retains editor-vscode 000's exact
  text and behavior; and
- after making Racket unavailable, or setting `aloe.racketPath` to the
  already specified nonexistent executable used by editor-vscode 000's
  failed-start check, lexical highlighting still appears even though the
  server cannot start. Restore the setting afterward.

This checkpoint does not change editor-vscode 000's accepted missing-Racket
notification or require a new server behavior.

## Verification and acceptance

Run:

```sh
cd editors/vscode
npm install
npm test
cd ../..
git diff --check
git status --short
```

Use `npm install` only inside `editors/vscode/`; do not create a repository-
root Node package. `node_modules/` remains ignored and must not appear in
`git status`. No Racket test is required for this client-only change, and the
Node suite must not invoke Racket.

The checkpoint is complete when the grammar tokenizes the fixture with the
required scopes, nested and unterminated regions behave as specified, the
manifest and exact language configuration are proven, the existing Node
suite remains green with only the named assertion amendments, both human
checks pass, `git diff --check` is clean, and every changed implementation
file is within the exact scope above.

Stop for review without committing. Do not issue or begin 001.

## Explicit non-goals and design-return conditions

- No semantic tokens, inlay hints, diagnostic coloring, or other LSP feature
- No tree-sitter, JavaScript Aloe reader, or parser beyond the test harness's
  Oniguruma engine
- No selector-position coloring, `self` keyword, constructor/class/type-
  parameter distinction, or kernel/library selector catalog
- No themes, snippets, formatters, indentation engine, rainbow-parenthesis
  feature, or wrap-the-preceding-form
- No GitHub Linguist, Shiki, Markdown injection, Marketplace publication, or
  Electron test runner
- No Neovim, Emacs, aloemacs, Gel, or another editor
- No Aloe syntax, evaluator, checker, Hover, completion, synchronization, or
  global-checkpoint change

If correct behavior appears to require production JavaScript, a language-
server change, a second parser, semantic tokens, a generated grammar, another
runtime dependency, a file outside the exact implementation scope, or a
second checkpoint, stop and return editor-highlighting 000 for design review.
