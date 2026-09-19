'use strict';

const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const extensionRoot = path.resolve(__dirname, '..');

function read(relativePath) {
  return readFileSync(path.join(extensionRoot, relativePath), 'utf8');
}

function readJson(relativePath) {
  return JSON.parse(read(relativePath));
}

test('manifest has the exact extension identity and Aloe contribution', () => {
  const manifest = readJson('package.json');

  assert.equal(manifest.name, 'aloe-language-client');
  assert.equal(manifest.displayName, 'Aloe');
  assert.equal(manifest.publisher, 'aloe-local');
  assert.equal(`${manifest.publisher}.${manifest.name}`, 'aloe-local.aloe-language-client');
  assert.equal(manifest.version, '0.0.1');
  assert.equal(manifest.main, './extension.js');
  assert.deepEqual(manifest.engines, { vscode: '^1.82.0' });
  assert.equal(manifest.type, undefined);
  assert.deepEqual(manifest.activationEvents, ['onLanguage:aloe']);
  assert.deepEqual(manifest.contributes.languages, [
    {
      id: 'aloe',
      aliases: ['Aloe'],
      extensions: ['.aloe'],
      configuration: './language-configuration.json'
    }
  ]);
  assert.deepEqual(manifest.contributes.grammars, [
    {
      language: 'aloe',
      scopeName: 'source.aloe',
      path: './syntaxes/aloe.tmLanguage.json'
    }
  ]);

  assert.deepEqual(Object.keys(manifest.contributes).sort(), [
    'configuration',
    'grammars',
    'languages'
  ]);
  assert.deepEqual(
    Object.keys(manifest.contributes.configuration.properties),
    ['aloe.racketPath']
  );
  assert.deepEqual(
    manifest.contributes.configuration.properties['aloe.racketPath'],
    {
      type: 'string',
      default: 'racket',
      scope: 'machine',
      description: 'The Racket executable used to start the Aloe language server.'
    }
  );
});

test('manifest has one pinned runtime dependency and only a Node test script', () => {
  const manifest = readJson('package.json');

  assert.deepEqual(manifest.dependencies, { 'vscode-languageclient': '9.0.1' });
  assert.equal(manifest.dependencies.vscode, undefined);
  assert.deepEqual(manifest.devDependencies, {
    'vscode-oniguruma': '2.0.1',
    'vscode-textmate': '9.3.2'
  });
  assert.deepEqual(manifest.scripts, { test: 'node --test' });
  assert.equal(manifest.scripts.build, undefined);
  assert.equal(manifest.scripts['vscode:prepublish'], undefined);
});

test('lockfile pins the root and language client without test or build tooling', () => {
  const manifest = readJson('package.json');
  const lock = readJson('package-lock.json');
  const root = lock.packages[''];

  assert.equal(root.name, manifest.name);
  assert.equal(root.version, manifest.version);
  assert.deepEqual(root.dependencies, { 'vscode-languageclient': '9.0.1' });
  assert.deepEqual(root.devDependencies, {
    'vscode-oniguruma': '2.0.1',
    'vscode-textmate': '9.3.2'
  });
  assert.equal(
    lock.packages['node_modules/vscode-languageclient'].version,
    '9.0.1'
  );
  assert.equal(
    lock.packages['node_modules/vscode-oniguruma'].version,
    '2.0.1'
  );
  assert.equal(
    lock.packages['node_modules/vscode-textmate'].version,
    '9.3.2'
  );

  const packageNames = Object.keys(lock.packages);
  for (const excluded of [
    'node_modules/@vscode/test-electron',
    'node_modules/typescript',
    'node_modules/esbuild',
    'node_modules/webpack',
    'node_modules/rollup'
  ]) {
    assert.equal(packageNames.includes(excluded), false);
  }
});

test('server options preserve opaque commands and exact child arguments', () => {
  const optionsModule = require('../client-options');
  const { createServerOptions } = optionsModule;

  const defaults = createServerOptions(undefined);
  const configured = createServerOptions('/opt/Racket 8.14/bin/racket');
  const empty = createServerOptions('');
  const another = createServerOptions(undefined);

  assert.deepEqual(Object.keys(optionsModule).sort(), [
    'createClientOptions',
    'createServerOptions'
  ]);
  assert.deepEqual(defaults, {
    command: 'racket',
    args: ['-l', 'aloe/lsp']
  });
  assert.deepEqual(configured, {
    command: '/opt/Racket 8.14/bin/racket',
    args: ['-l', 'aloe/lsp']
  });
  assert.equal(empty.command, '');
  assert.deepEqual(Object.keys(configured).sort(), ['args', 'command']);
  for (const excluded of [
    'transport',
    'options',
    'shell',
    'cwd',
    'env',
    'runtime',
    'module',
    'run',
    'debug'
  ]) {
    assert.equal(Object.hasOwn(configured, excluded), false);
  }
  assert.notEqual(defaults.args, another.args);
  defaults.args.push('changed');
  assert.deepEqual(another.args, ['-l', 'aloe/lsp']);
});

test('client options select only local Aloe files', () => {
  const { createClientOptions } = require('../client-options');
  const options = createClientOptions();

  assert.deepEqual(options, {
    documentSelector: [{ scheme: 'file', language: 'aloe' }]
  });
  assert.deepEqual(Object.keys(options), ['documentSelector']);
});

test('development launch has one bare Extension Host configuration', () => {
  const launch = readJson('.vscode/launch.json');

  assert.equal(launch.configurations.length, 1);
  const configuration = launch.configurations[0];
  assert.equal(configuration.type, 'extensionHost');
  assert.equal(configuration.request, 'launch');
  assert.deepEqual(configuration.args, [
    '--extensionDevelopmentPath=${workspaceFolder}'
  ]);
  assert.deepEqual(Object.keys(configuration).sort(), [
    'args',
    'name',
    'request',
    'type'
  ]);
});

test('production files preserve the thin-client boundary', () => {
  assert.match(read('.gitignore'), /^node_modules\/$/m);

  const optionsSource = read('client-options.js');
  for (const forbidden of [
    "require('vscode')",
    'vscode-languageclient',
    'child_process',
    'readFile',
    'writeFile'
  ]) {
    assert.equal(optionsSource.includes(forbidden), false);
  }

  const extensionSource = read('extension.js');
  assert.match(extensionSource, /require\('\.\/client-options'\)/);
  assert.match(extensionSource, /createServerOptions\(racketPath\)/);
  assert.match(extensionSource, /createClientOptions\(\)/);
  for (const forbidden of [
    'TransportKind',
    '--stdio',
    "require('child_process')",
    'PLTCOLLECTS',
    'aloe/lsp.rkt',
    'Point new',
    'class-info-methods',
    'signature-catalog',
    'expression-query'
  ]) {
    assert.equal(extensionSource.includes(forbidden), false);
  }
});

test('production JavaScript passes the Node syntax checker', () => {
  for (const file of ['client-options.js', 'extension.js']) {
    const result = spawnSync(process.execPath, ['--check', path.join(extensionRoot, file)], {
      encoding: 'utf8'
    });
    assert.equal(result.status, 0, result.stderr);
  }
});
