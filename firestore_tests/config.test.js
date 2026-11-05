// Wiring check: the tests must exercise the same rules file that firebase.json deploys.
// Runs without the emulator.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

test('firebase.json points Firestore to the root rules and indexes files', () => {
  const config = JSON.parse(fs.readFileSync(path.join(root, 'firebase.json'), 'utf8'));
  assert.equal(config.firestore.rules, 'firestore.rules');
  assert.equal(config.firestore.indexes, 'firestore.indexes.json');
});

test('the root firestore.rules and firestore.indexes.json files exist', () => {
  assert.ok(fs.existsSync(path.join(root, 'firestore.rules')));
  assert.ok(fs.existsSync(path.join(root, 'firestore.indexes.json')));
});

test('helpers.js loads exactly the root firestore.rules', () => {
  const { RULES_PATH } = require('./helpers');
  assert.equal(RULES_PATH, path.join(root, 'firestore.rules'));
});

test('no copy of a rules file lives inside firestore_tests', () => {
  const copies = fs
    .readdirSync(__dirname, { recursive: true })
    .map(String)
    .filter((file) => !file.startsWith('node_modules'))
    .filter((file) => file.endsWith('.rules'));
  assert.deepEqual(copies, []);
});
