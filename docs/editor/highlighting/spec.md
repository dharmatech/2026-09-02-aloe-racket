# VS Code lexical highlighting

**Status.** Design specification for the local `editor-highlighting` project.
This is not Aloe language law, an implementation checkpoint, or a global
checkpoint. A later checkpoint-manager conversation may issue the single
checkpoint **editor-highlighting 000** under
`docs/editor/highlighting/checkpoints/`. It must not issue 001 or put this
work under `docs/checkpoints/` or `docs/editor/vscode/checkpoints/`.

**Authority.** `SPEC.md` section 1 owns Aloe atoms and the capitalized-name
convention; sections 4 and 11 own the closed special-form set.
[`../vscode/spec.md`](../vscode/spec.md) owns the existing extension identity,
launch, lifecycle, Hover, and `aloe.racketPath`. Editor-vscode 000 is
implemented and reviewed. This specification amends only its prohibitions on
a TextMate grammar and language configuration, as named in section 8 below.
The VS Code syntax-highlighting and language-configuration guides own the
manifest contribution shapes. The Racket reader documentation is authority
for string escapes and reader comments; it does not supply another Aloe
keyword list.

---

## 1. Result and boundary

Extend the existing VS Code extension in `editors/vscode/` with one JSON
TextMate grammar and one declarative language configuration for language id
`aloe`. Opening a `.aloe` file colors lexical tokens immediately, including
when Racket is missing or the Aloe language server never starts.

Identity is `(editor-highlighting, 000)`, spoken **editor-highlighting 000**.
This is not editor-vscode 001. Documentation stays in
`docs/editor/highlighting/`; grammar, configuration, fixtures, tests, and npm
metadata stay in `editors/vscode/`. Do not create another extension or put
implementation under `aloe/`, `host/`, `docs/design/`, or the repository
root.

The implementation adds only this highlighting layer. It does not change
`extension.js`, `client-options.js`, Racket code, language-server behavior,
Hover, completion, document synchronization, or the extension's activation
event. In particular, it does not advertise or register a semantic-tokens
provider.

## 2. Extension contribution and files

Retain the existing extension identity and the one existing `aloe` language
contribution. Add `configuration` to that language entry:

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

The grammar file is JSON at
`editors/vscode/syntaxes/aloe.tmLanguage.json`. Its top-level `scopeName` is
`source.aloe`. There is no YAML source, conversion step, generated grammar,
injection grammar, embedded language, or second language id.

The implementation change may add or update only:

- `editors/vscode/package.json` and `package-lock.json`;
- `editors/vscode/language-configuration.json`;
- `editors/vscode/syntaxes/aloe.tmLanguage.json`;
- `editors/vscode/test/000-highlighting.test.js`;
- `editors/vscode/test/fixtures/highlighting.aloe`; and
- the existing `editors/vscode/test/000-hover-client.test.js` assertions
  named in section 8.

Do not rename, duplicate, or otherwise edit the existing production
JavaScript. The runtime dependency remains exactly
`vscode-languageclient: 9.0.1`. The extension version remains `0.0.1`, and
`npm test` remains the test command using Node's built-in runner.

## 3. Tokens and scopes

The grammar assigns the following ordinary TextMate scopes. These scopes are
chosen so built-in themes such as Dark+ can color the tokens without an Aloe
theme.

| Source token | TextMate scope |
|---|---|
| `;` line comment, including its delimiter | `comment.line.semicolon.aloe` |
| nested `#| ... |#` block comment, including delimiters | `comment.block.aloe` |
| double-quoted string, including quotes | `string.quoted.double.aloe` |
| a recognized escape within a string | `constant.character.escape.aloe` |
| integer or float literal | `constant.numeric.aloe` |
| `#t` or `#f` | `constant.language.boolean.aloe` |
| special form from section 3.1 | `keyword.control.aloe` |
| section word from section 3.2 | `keyword.other.aloe` |
| capitalized nominal name | `entity.name.type.aloe` |

Unmatched source retains only `source.aloe`. Parentheses do not need a custom
TextMate scope; bracket matching and VS Code's built-in bracket-pair
colorization come from the language configuration.

### 3.1 Special forms: closed set

Only these identifiers receive `keyword.control.aloe`:

```text
define define-class define-methods define-protocol fn let if cond load check case
```

The match is position-independent. TextMate highlighting does not attempt to
decide whether the identifier is in list-head or selector position.

### 3.2 Section words: closed set

Only these identifiers receive `keyword.other.aloe`:

```text
fields methods constructors type else
```

### 3.3 Capitalized nominal names

A complete identifier matching `[A-Z][A-Za-z0-9]*` receives
`entity.name.type.aloe`. This deliberately colors class and type names,
constructors such as `Some` and `None`, and type parameters such as `T` and
`U` alike. It is a visual convention, not a validity or type-checking rule.
The grammar does not attempt to distinguish those categories.

## 4. Lexical matching rules

Rules are ordered so comments and strings win over every token rule, floats
win over integers, and the two keyword groups win over capitalized names.
Only the escape rule is active inside a string. Only the recursively included
block-comment rule is active inside a block comment. Consequently keywords,
numbers, booleans, and capitalized names never receive their ordinary scopes
inside a comment or string.

Keyword, boolean, numeric, and capitalized-name matches must consume one
complete reader token. For this grammar, a token boundary is start or end of
input, whitespace, or one of the Racket datum delimiters:

```text
( ) [ ] { } " ' ` , ;
```

Do not use `\b`: it would split Aloe identifiers such as `define-class` and
`starts-with?`. A punctuation character not listed above remains part of the
identifier for boundary purposes. Thus `define-class?`, `my-Point`, `#true`,
and `Some?` must not be partially colored as `define-class`, `Point`, `#t`,
or `Some`.

The numeric rule recognizes the ordinary decimal spellings used by Aloe:

- integer: optional `+` or `-`, then one or more decimal digits;
- float: optional `+` or `-`, then either a decimal point with digits on at
  least one side or decimal digits followed by `e` or `E`; either form may
  have an exponent with an optional sign and required digits.

Both receive `constant.numeric.aloe`. A full-token boundary is required, so a
numeric prefix in a symbol is not colored. The grammar is a highlighter, not
a second Racket numeric reader; radix, exactness, rational, complex, and
special-infinity syntax need not be recognized in 000.

A string begins and ends with `"` and may span lines as the Racket reader
allows. Its inner escape rule recognizes the Racket reader's simple escapes
(`a b t n v f r e " ' \\`), one-to-three-digit octal escape, one-to-two-digit
`x` escape, one-to-four-digit `u` escape, one-to-eight-digit `U` escape, and
an escaped LF, CR, or CRLF newline. Longer alternatives take precedence where
one is a prefix of another. This rule must consume an escaped quote so that
it does not terminate the string. Invalid escape spelling need not receive
the escape sub-scope; the surrounding text remains within the string until
an unescaped closing quote or end of document.

A semicolon begins a line comment and colors through the physical end of
line. Both `;` and the conventional `;;` therefore work. A `#|` begins a
`comment.block.aloe` region ending at its matching `|#`; the block rule
includes itself so nesting and multi-line comments work. Unterminated strings
and block comments keep their scope through end of document rather than
breaking tokenization.

`#;` S-expression comments are intentionally not recognized in 000. Correctly
finding the end of the following datum would require a reader-like recursive
grammar covering every datum form and would turn this extension into a second
parser. Racket still accepts `#;`; it simply remains lexically uncolored.

The following are also deliberately ordinary `source.aloe` identifiers:
`call`, `new`, `self`, `quote`, `begin`, field names, and kernel or library
selectors such as `len`, `append`, `starts-with?`, and `before?`.

## 5. Language configuration

`editors/vscode/language-configuration.json` is declarative JSON with this
exact content, apart from insignificant whitespace:

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

The word pattern uses the same delimiter set as section 4. In particular,
double-click, word navigation, and completion replacement treat
`starts-with?`, `before?`, `define-class`, `empty?`, `+`, and `<=` as whole
words. Use `wordPattern`; do not add a setting for or mutate the user's
`editor.wordSeparators`.

There are no square/curly bracket pairs, single-quote pair, comment
continuation rule, folding markers, `onEnterRules`, or indentation rules.
This project does not attempt Lisp indentation or formatting.

## 6. Automated proof

The grammar tests use Microsoft's `vscode-textmate` `9.3.2` with
`vscode-oniguruma` `2.0.1`, both exact extension-local `devDependencies`.
The committed lockfile records them. They are test-only; no tokenizer is
loaded by `extension.js`, and the extension has no new runtime dependency.

`editors/vscode/test/000-highlighting.test.js` uses `node:test` and loads
`vscode-oniguruma/release/onig.wasm`, the JSON grammar, and `source.aloe`
through a `vscode-textmate.Registry`. It tokenizes
`test/fixtures/highlighting.aloe` one line at a time while carrying the
returned rule stack between lines. Tests inspect token text and scope stacks;
snapshotting colored pixels or merely parsing the grammar JSON is not enough.
Small inline source arrays in the test file may cover mutually exclusive
end-of-document states such as an unterminated string and an unterminated
block comment; they use the same loaded grammar and tokenization helper.

At minimum the automated tests prove:

1. The manifest retains the existing identity, setting, activation event,
   runtime dependency, and language id; the language entry references
   `./language-configuration.json`; and the sole grammar contribution has the
   exact language, root scope, and path from section 2.
2. The grammar and configuration files parse as JSON, the grammar loads as
   `source.aloe`, and no Racket process, language server, VS Code instance, or
   network access is needed to tokenize the fixture.
3. Both `;` and `;;` comments, strings containing representative simple,
   octal, hexadecimal/Unicode, quote, backslash, and continued-line escapes,
   positive and negative integers/floats, and `#t`/`#f` receive the scopes in
   section 3.
4. Every identifier in the closed special-form and section-word sets receives
   exactly its assigned keyword scope. Similar or prefixed identifiers do not.
5. Representative class/type names, `Some`, `None`, `T`, and `U` receive
   `entity.name.type.aloe`, while capitalized-looking text in strings, line
   comments, and block comments does not.
6. A nested multi-line block comment stays comment-scoped through its matching
   outer `|#`, and ordinary tokenization resumes afterward. An unterminated
   string and block comment each remain scoped through the end of its test
   source.
7. `#;` receives no comment scope. `call`, `new`, `self`, `quote`, `begin`,
   `len`, `append`, `starts-with?`, and `before?` receive none of the keyword
   or type scopes.
8. The language configuration has the exact comment, bracket, auto-closing,
   surrounding-pair, and word-pattern decisions from section 5. Compiling the
   word pattern and applying it proves that punctuation-bearing Aloe
   identifiers are selected whole.
9. The existing hover-client tests still prove the exact server command,
   document selector, launch configuration, production boundary, and Node
   syntax. No old proof is deleted or weakened except the manifest assertions
   explicitly superseded in section 8.

Tests may use helper functions inside `000-highlighting.test.js`; do not add a
production tokenizer module. Do not add `@vscode/test-electron`, an Electron
harness, TypeScript, a compiler, a bundler, or a repository-root Node package.

## 7. Human acceptance

From `editors/vscode/`, install from the committed lockfile, run `npm test`,
and launch the existing Extension Development Host configuration. Open
`test/fixtures/highlighting.aloe` using built-in Dark+ for the complete token
survey; also open an existing program such as
[`../../../tests/editor/lsp/fixtures/point.aloe`](../../../tests/editor/lsp/fixtures/point.aloe)
or [`../../../lib/string.aloe`](../../../lib/string.aloe).

Confirm comments, strings, numbers, booleans, all present special forms, and
capitalized names are visibly distinct where the file contains them. Use
`Developer: Inspect Editor Tokens and Scopes` for any category whose theme
colors are visually close, and confirm the scope from section 3. Confirm
parenthesis matching and pair insertion, quote insertion, comment toggling,
and whole-word selection of a punctuation-bearing selector.

With the ordinary Aloe server prerequisite restored, hover the final
`(Point new 1 2)` in the point fixture and confirm the editor-vscode 000 Hover
text and behavior are unchanged. Then make Racket unavailable (or set
`aloe.racketPath` to the already specified nonexistent executable for the
existing failed-start check), reload, and confirm lexical highlighting still
appears even though the server cannot start. Restore the setting afterward.

## 8. Amendments to editor-vscode 000

This project supersedes only the following sentences or clauses in
`docs/editor/vscode/spec.md`:

- Section 1's statement that attaching Hover is the extension's only language
  feature, and its contribution list, now also permit this one lexical grammar
  and language configuration.
- Section 3's sentence that the manifest contributes no grammar or language
  configuration is replaced by section 2 here. Its bans on snippets, themes,
  commands, menus, keybindings, and debug adapters remain.
- Section 7's requirement that automated tests prove the manifest contributes
  none of the excluded editor features now permits and must prove exactly the
  grammar and language configuration in section 2 here.
- Section 8's non-goal for a TextMate grammar and bracket configuration is
  removed. Its semantic-grammar, theme, snippet, and wrap-form exclusions
  remain.

No launch, Hover, server, failure, lifecycle, dependency, or document-selector
sentence in that specification is otherwise amended.

Update these assertions in
`editors/vscode/test/000-hover-client.test.js` rather than deleting the tests:

- `manifest has the exact extension identity and Aloe contribution` must
  expect the language configuration path and `grammars` as the third
  contribution key.
- `manifest has one pinned runtime dependency and only a Node test script`
  must expect exactly the two pinned test-only development dependencies from
  section 6 instead of asserting that `devDependencies` is absent. Its runtime
  dependency and script assertions remain.
- `lockfile pins the root and language client without test or build tooling`
  must expect those two root development dependencies and their lock entries.
  It continues to reject `@vscode/test-electron`, TypeScript, and bundlers.

All other editor-vscode 000 tests and both original Hover/launch hand proofs
remain in force. Do not edit
`docs/editor/vscode/checkpoints/000-hover-client.md`.

## 9. Verification and non-goals

The later implementation slice runs:

```sh
cd editors/vscode
npm test
cd ../..
git diff --check
git status --short
```

No Racket test is required for this client-only change, and the tokenizer
suite must not invoke Racket. The single checkpoint is complete when the
headless token scopes, manifest/configuration assertions, existing Node suite,
and human checks are green. Stop for review; do not issue or begin 001.

Out of scope:

- LSP semantic tokens, inlay hints, diagnostics coloring, or another LSP
  capability;
- tree-sitter, WASM parsers other than the test harness's Oniguruma engine, or
  a JavaScript Aloe reader;
- selector-position coloring, `self` highlighting, constructor/class/type-
  parameter distinctions, or a kernel/library selector catalog;
- themes, snippets, formatters, Lisp indentation, rainbow-paren features, or
  wrap-the-preceding-form;
- GitHub Linguist, Shiki, Markdown injection, Marketplace publication, or an
  Electron test runner;
- Neovim, Emacs, aloemacs, Gel, or another editor; and
- changes to Aloe syntax, `aloe/*.rkt`, Hover, completion, document sync, or
  the global Aloe checkpoint spine.
