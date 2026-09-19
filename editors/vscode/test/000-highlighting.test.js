'use strict';

const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const oniguruma = require('vscode-oniguruma');
const textmate = require('vscode-textmate');

const extensionRoot = path.resolve(__dirname, '..');
const fixturePath = path.join(extensionRoot, 'test', 'fixtures', 'highlighting.aloe');
const grammarPath = path.join(extensionRoot, 'syntaxes', 'aloe.tmLanguage.json');

function read(relativePath) {
  return readFileSync(path.join(extensionRoot, relativePath), 'utf8');
}

function readJson(relativePath) {
  return JSON.parse(read(relativePath));
}

let grammarPromise;

function loadGrammar() {
  if (!grammarPromise) {
    grammarPromise = (async () => {
      const wasm = readFileSync(require.resolve('vscode-oniguruma/release/onig.wasm'));
      await oniguruma.loadWASM(
        wasm.buffer.slice(wasm.byteOffset, wasm.byteOffset + wasm.byteLength)
      );

      const rawGrammar = textmate.parseRawGrammar(readFileSync(grammarPath, 'utf8'), grammarPath);
      const registry = new textmate.Registry({
        onigLib: Promise.resolve({
          createOnigScanner: patterns => new oniguruma.OnigScanner(patterns),
          createOnigString: source => new oniguruma.OnigString(source)
        }),
        loadGrammar: async scopeName => scopeName === 'source.aloe' ? rawGrammar : null
      });

      return registry.loadGrammar('source.aloe');
    })();
  }

  return grammarPromise;
}

function tokenize(source, grammar) {
  let ruleStack = textmate.INITIAL;

  return source.split(/\r\n|\r|\n/).map((line, lineIndex) => {
    const result = grammar.tokenizeLine(line, ruleStack);
    ruleStack = result.ruleStack;
    return {
      line,
      lineIndex,
      tokens: result.tokens.map(token => ({
        text: line.slice(token.startIndex, token.endIndex),
        startIndex: token.startIndex,
        endIndex: token.endIndex,
        scopes: token.scopes
      }))
    };
  });
}

function findLine(document, fragment) {
  const line = document.find(candidate => candidate.line.includes(fragment));
  assert.ok(line, `missing fixture line containing ${JSON.stringify(fragment)}`);
  return line;
}

function tokenAt(document, lineFragment, needle, occurrence = 0) {
  const line = findLine(document, lineFragment);
  let index = -1;
  let fromIndex = 0;

  for (let found = 0; found <= occurrence; found += 1) {
    index = line.line.indexOf(needle, fromIndex);
    assert.notEqual(index, -1, `missing ${JSON.stringify(needle)} in ${JSON.stringify(line.line)}`);
    fromIndex = index + needle.length;
  }

  const token = line.tokens.find(candidate => (
    candidate.startIndex <= index && candidate.endIndex > index
  ));
  assert.ok(token, `no token covers ${JSON.stringify(needle)} in ${JSON.stringify(line.line)}`);
  assert.equal(token.text, line.line.slice(token.startIndex, token.endIndex));
  return token;
}

function assertScoped(document, lineFragment, needle, scope, occurrence = 0) {
  const token = tokenAt(document, lineFragment, needle, occurrence);
  const expected = scope === 'constant.character.escape.aloe'
    ? ['source.aloe', 'string.quoted.double.aloe', scope]
    : ['source.aloe', scope];

  if (scope === 'comment.block.aloe') {
    assert.equal(token.scopes[0], 'source.aloe');
    assert.ok(token.scopes.length >= 2);
    assert.ok(token.scopes.slice(1).every(candidate => candidate === scope));
  } else {
    assert.deepEqual(
      token.scopes,
      expected,
      `${JSON.stringify(needle)} has the wrong complete scope stack`
    );
  }
  return token;
}

function assertOnlySource(document, lineFragment, needle, occurrence = 0) {
  const token = tokenAt(document, lineFragment, needle, occurrence);
  assert.deepEqual(token.scopes, ['source.aloe']);
}

test('grammar and language configuration parse and the source.aloe grammar loads', async () => {
  const grammarJson = readJson('syntaxes/aloe.tmLanguage.json');
  const configuration = readJson('language-configuration.json');
  const grammar = await loadGrammar();

  assert.equal(grammarJson.scopeName, 'source.aloe');
  assert.ok(grammar);
  assert.deepEqual(configuration, {
    comments: {
      lineComment: ';',
      blockComment: ['#|', '|#']
    },
    brackets: [['(', ')']],
    autoClosingPairs: [
      { open: '(', close: ')', notIn: ['string', 'comment'] },
      { open: '"', close: '"', notIn: ['string', 'comment'] }
    ],
    surroundingPairs: [
      ['(', ')'],
      ['"', '"']
    ],
    wordPattern: '[^\\s()\\[\\]{}"\'`,;]+'
  });
});

test('comments, strings, escapes, numbers, and booleans have their required scopes', async () => {
  const document = tokenize(readFileSync(fixturePath, 'utf8'), await loadGrammar());

  assertScoped(document, '; line comment:', ';', 'comment.line.semicolon.aloe');
  assertScoped(document, ';; conventional comment:', ';;', 'comment.line.semicolon.aloe');

  const stringToken = assertScoped(
    document,
    'plain define Point',
    'define',
    'string.quoted.double.aloe'
  );
  for (const forbidden of [
    'keyword.control.aloe',
    'entity.name.type.aloe',
    'constant.language.boolean.aloe',
    'constant.numeric.aloe'
  ]) {
    assert.equal(stringToken.scopes.includes(forbidden), false);
  }
  assertScoped(document, '"plain define Point', '"', 'string.quoted.double.aloe');
  assertScoped(document, '"plain define Point', '"', 'string.quoted.double.aloe', 1);

  for (const escape of ['\\n', '\\123', '\\x4F', '\\u03bb', '\\U0001F642', '\\"', '\\\\']) {
    const lineFragment = ['\\123', '\\x4F', '\\u03bb', '\\U0001F642'].includes(escape)
      ? 'numeric '
      : 'simple ';
    assertScoped(document, lineFragment, escape, 'constant.character.escape.aloe');
  }
  assertScoped(document, '"continued\\', '\\', 'constant.character.escape.aloe');
  assertScoped(document, 'line define Point', 'Point', 'string.quoted.double.aloe');

  for (const number of ['0', '42', '+7', '-3', '0.0', '1.', '-0.25', '+.5', '1e3', '-2E-4']) {
    assertScoped(document, '0 42 +7', number, 'constant.numeric.aloe');
  }
  for (const boolean of ['#t', '#f']) {
    assertScoped(document, '#t #f', boolean, 'constant.language.boolean.aloe');
  }
});

test('closed keyword sets and complete-token boundaries are enforced', async () => {
  const document = tokenize(readFileSync(fixturePath, 'utf8'), await loadGrammar());

  for (const keyword of [
    'define', 'define-class', 'define-methods', 'define-protocol', 'fn', 'let',
    'if', 'cond', 'load', 'check', 'case'
  ]) {
    assertScoped(document, 'define define-class', keyword, 'keyword.control.aloe');
  }
  for (const keyword of ['fields', 'methods', 'constructors', 'type', 'else']) {
    assertScoped(document, 'fields methods', keyword, 'keyword.other.aloe');
  }

  for (const ordinary of [
    'call', 'new', 'self', 'quote', 'begin', 'len', 'append', 'starts-with?', 'before?'
  ]) {
    assertOnlySource(document, 'call new self', ordinary);
  }
  for (const nearMiss of [
    'define-class?', 'my-Point', '#true', 'Some?', '123abc', '+12foo', 'Point.part'
  ]) {
    assertOnlySource(document, 'define-class? my-Point', nearMiss);
  }
  assertOnlySource(document, 'define-class? my-Point', 'Point');
  assertOnlySource(document, 'define-class? my-Point', 'Point', 1);
  assertOnlySource(document, 'define-class? my-Point', 'define', 1);

  for (const part of ['#', ';']) {
    const datumComment = tokenAt(document, '#; (define', part);
    assert.deepEqual(datumComment.scopes, ['source.aloe']);
    assert.equal(datumComment.scopes.some(scope => scope.startsWith('comment.')), false);
  }
});

test('capitalized names are scoped only in ordinary source regions', async () => {
  const document = tokenize(readFileSync(fixturePath, 'utf8'), await loadGrammar());

  for (const name of [
    'Point', 'Int', 'Float', 'Bool', 'String', 'Symbol', 'Mirror', 'Signature',
    'Some', 'None', 'T', 'U', 'Tree2'
  ]) {
    assertScoped(document, 'Point Int Float', name, 'entity.name.type.aloe');
  }

  for (const [line, needle] of [
    ['; line comment:', 'Point'],
    ['plain define Point', 'Point'],
    ['outer define Point', 'Point'],
    ['inner methods Some', 'Some']
  ]) {
    const token = tokenAt(document, line, needle);
    assert.equal(token.scopes.includes('entity.name.type.aloe'), false);
  }
});

test('nested and unterminated regions preserve state and resume correctly', async () => {
  const grammar = await loadGrammar();
  const document = tokenize(readFileSync(fixturePath, 'utf8'), grammar);

  assertScoped(document, 'outer define Point', 'define', 'comment.block.aloe');
  assertScoped(document, 'inner methods Some', 'methods', 'comment.block.aloe');
  assertScoped(document, 'nested body', 'body', 'comment.block.aloe');
  assertScoped(document, 'outer tail constructors', 'constructors', 'comment.block.aloe');
  assertScoped(document, '|# (define after Point)', '|#', 'comment.block.aloe');
  assertScoped(document, '|# (define after Point)', 'define', 'keyword.control.aloe');
  assertScoped(document, '|# (define after Point)', 'Point', 'entity.name.type.aloe');

  const unterminatedString = tokenize('"open define Point\nstill #t 12', grammar);
  assertScoped(unterminatedString, 'still #t 12', '#t', 'string.quoted.double.aloe');
  assert.equal(
    tokenAt(unterminatedString, 'still #t 12', '#t').scopes.includes('constant.language.boolean.aloe'),
    false
  );

  const unterminatedComment = tokenize('#| open define Point\nstill #f 12', grammar);
  assertScoped(unterminatedComment, 'still #f 12', '#f', 'comment.block.aloe');
  assert.equal(
    tokenAt(unterminatedComment, 'still #f 12', '#f').scopes.includes('constant.language.boolean.aloe'),
    false
  );
});

test('word pattern selects punctuation-bearing Aloe identifiers whole', () => {
  const { wordPattern } = readJson('language-configuration.json');
  const pattern = new RegExp(wordPattern, 'g');
  const identifiers = ['starts-with?', 'before?', 'define-class', 'empty?', '+', '<='];

  for (const identifier of identifiers) {
    assert.deepEqual(identifier.match(pattern), [identifier]);
  }
  assert.deepEqual(
    '(starts-with? before? define-class empty? + <=)'.match(pattern),
    identifiers
  );
});
