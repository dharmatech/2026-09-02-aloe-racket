'use strict';

const vscode = require('vscode');
const { LanguageClient } = require('vscode-languageclient/node');
const { createServerOptions, createClientOptions } = require('./client-options');

let activation;
let client;

function launchFailurePrefix(racketPath) {
  return `Launching server using command ${racketPath} failed.`;
}

function isLaunchFailure(error, racketPath) {
  return typeof error === 'string' && error.startsWith(launchFailurePrefix(racketPath));
}

class AloeLanguageClient extends LanguageClient {
  constructor(serverOptions, clientOptions) {
    super('aloe', 'Aloe', serverOptions, clientOptions);
    this.racketPath = serverOptions.command;
  }

  error(message, data, showNotification = true) {
    const connectionFailure = "Aloe client: couldn't create connection to server.";
    if (message === connectionFailure && isLaunchFailure(data, this.racketPath)) {
      super.error(message, data, false);
      return;
    }
    super.error(message, data, showNotification);
  }
}

async function activateOnce() {
  const racketPath = vscode.workspace
    .getConfiguration('aloe')
    .get('racketPath', 'racket');
  const serverOptions = createServerOptions(racketPath);
  const startingClient = new AloeLanguageClient(
    serverOptions,
    createClientOptions()
  );

  try {
    await startingClient.start();
    client = startingClient;
  } catch (error) {
    if (!isLaunchFailure(error, racketPath)) {
      throw error;
    }
    void vscode.window.showErrorMessage(
      `Aloe could not start Racket: "${racketPath}". ` +
      'Install Racket or set aloe.racketPath to a working executable.'
    );
  }
}

function activate() {
  if (activation === undefined) {
    activation = activateOnce();
  }
  return activation;
}

async function deactivate() {
  if (client === undefined) {
    return;
  }

  const runningClient = client;
  try {
    await runningClient.stop();
  } finally {
    if (client === runningClient) {
      client = undefined;
    }
  }
}

module.exports = { activate, deactivate };
