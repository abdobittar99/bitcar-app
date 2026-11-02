// Shared setup for the Security Rules tests.
// Always loads the project's real root firestore.rules (no copy) and talks to
// the local Firestore emulator under the demo project id, never the real project.
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'demo-bitcar';
const RULES_PATH = path.resolve(__dirname, '..', 'firestore.rules');

let testEnv;

async function getEnv() {
  if (!testEnv) {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: fs.readFileSync(RULES_PATH, 'utf8'),
        host: '127.0.0.1',
        port: 8080,
      },
    });
  }
  return testEnv;
}

// Firestore client acting as a signed-in user with the given uid.
async function authed(uid) {
  return (await getEnv()).authenticatedContext(uid).firestore();
}

// Firestore client acting as a signed-out client.
async function unauthed() {
  return (await getEnv()).unauthenticatedContext().firestore();
}

// Writes test data with rules disabled: seed(async (db) => { ... }).
async function seed(fn) {
  await (await getEnv()).withSecurityRulesDisabled(async (context) => {
    await fn(context.firestore());
  });
}

async function clear() {
  await (await getEnv()).clearFirestore();
}

async function cleanup() {
  if (testEnv) {
    await testEnv.cleanup();
    testEnv = undefined;
  }
}

module.exports = {
  PROJECT_ID,
  RULES_PATH,
  authed,
  unauthed,
  seed,
  clear,
  cleanup,
};
