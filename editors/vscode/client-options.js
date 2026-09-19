'use strict';

function createServerOptions(configuredPath) {
  return {
    command: configuredPath === undefined ? 'racket' : configuredPath,
    args: ['-l', 'aloe/lsp']
  };
}

function createClientOptions() {
  return {
    documentSelector: [{ scheme: 'file', language: 'aloe' }]
  };
}

module.exports = { createServerOptions, createClientOptions };
