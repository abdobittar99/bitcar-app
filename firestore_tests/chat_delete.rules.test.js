// Delete for everyone: proof of deletion for the unread count, R6 and R21–R29
// (contracts/firestore-security-rules.md, research D19).
const { describe, it, beforeEach, after } = require('node:test');
const assert = require('node:assert/strict');
const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  collection,
  writeBatch,
  runTransaction,
  serverTimestamp,
  increment,
  Timestamp,
} = require('firebase/firestore');
const { authed, seed, clear, cleanup } = require('./helpers');
const { ALICE, SELLER, OTHER, ADMIN, SELLER2, CID, NAMES, seedUsers } = require('./fixtures');

const start = Date.now();
const minutes = (n) => Timestamp.fromMillis(start + n * 60000); // negative: in the past
const conversation = (db, cid = CID) => doc(db, 'conversations', cid);
const message = (db, id, cid = CID) => doc(db, 'conversations', cid, 'messages', id);
const deletedPreview = (id, sender) => ({ id, text: '', senderId: sender, deleted: true });
const markDeleted = (batch, db, id) => batch.update(message(db, id), { deleted: true, text: '' });

// a1, a2 from alice; s1, s2 from the seller, s2 is the latest; `gone` from the seller is already deleted.
// Each user has 2 unread messages, and nobody has read or cleared anything.
async function seedChat(extra = {}) {
  await seed(async (db) => {
    await seedUsers(db);
    await setDoc(conversation(db), {
      participants: [ALICE, SELLER],
      buyerId: ALICE,
      sellerId: SELLER,
      participantNames: { [ALICE]: NAMES[ALICE], [SELLER]: NAMES[SELLER] },
      createdAt: minutes(-60),
      lastMessage: { id: 's2', text: 'text s2', senderId: SELLER, deleted: false },
      lastMessageAt: minutes(-10),
      unreadCount: { [ALICE]: 2, [SELLER]: 2 },
      ...extra,
    });
    for (const [id, sender, at] of [['a1', ALICE, -40], ['a2', ALICE, -30], ['s1', SELLER, -20], ['s2', SELLER, -10]]) {
      await setDoc(message(db, id), { senderId: sender, text: `text ${id}`, createdAt: minutes(at), deleted: false });
    }
    await setDoc(message(db, 'gone'), { senderId: SELLER, text: '', createdAt: minutes(-50), deleted: true });
  });
}

async function snapshot() {
  let result;
  await seed(async (db) => {
    const conv = (await getDoc(conversation(db))).data();
    const messages = (await getDocs(collection(db, 'conversations', CID, 'messages'))).docs.map((d) => [d.id, d.data()]);
    result = { conv, messages };
  });
  return result;
}

const unreadOf = async (uid) => (await snapshot()).conv.unreadCount[uid];
const isDeleted = async (id) => Object.fromEntries((await snapshot()).messages)[id].deleted;

// Same reads and writes as ChatRemoteDataSource.deleteMessage will use (task T069).
function deleteMessage(db, me, other, id, { between } = {}) {
  const state = { attempts: 0 };
  const run = runTransaction(db, async (tx) => {
    state.attempts += 1;
    const conv = (await tx.get(conversation(db))).data();
    const msgSnap = await tx.get(message(db, id));
    if (between && state.attempts === 1) await between();
    const msg = msgSnap.data();
    if (msg.deleted) return;

    const seenAt = (field) => conv[field]?.[other];
    const unseen = (!seenAt('lastReadAt') || msg.createdAt.toMillis() > seenAt('lastReadAt').toMillis())
      && (!seenAt('clearedAt') || msg.createdAt.toMillis() > seenAt('clearedAt').toMillis());

    const update = { lastDeletedMessageId: id };
    if (conv.lastMessage.id === id) update.lastMessage = deletedPreview(id, me);
    if (unseen && conv.unreadCount[other] > 0) update[`unreadCount.${other}`] = increment(-1);
    tx.update(message(db, id), { deleted: true, text: '' });
    tx.update(conversation(db), update);
  });
  return { run, state };
}

// What T069 adds around the transaction: one more attempt, with fresh reads, after permission-denied.
async function deleteWithOneRetry(db, me, other, id, options) {
  try {
    await deleteMessage(db, me, other, id, options).run;
  } catch (e) {
    if (e.code !== 'permission-denied') throw e;
    await deleteMessage(db, me, other, id).run;
  }
}

async function readAll(db, uid) {
  await updateDoc(conversation(db), { [`unreadCount.${uid}`]: 0, [`lastReadAt.${uid}`]: serverTimestamp() });
}

async function sendFromAlice(db) {
  const batch = writeBatch(db);
  batch.set(message(db, 'new'), { senderId: ALICE, text: 'hi', createdAt: serverTimestamp(), deleted: false });
  batch.update(conversation(db), {
    lastMessage: { id: 'new', text: 'hi', senderId: ALICE, deleted: false },
    lastMessageAt: serverTimestamp(),
    [`unreadCount.${SELLER}`]: increment(1),
  });
  batch.set(doc(db, 'chatRateLimits', ALICE), { count: 1, windowStart: serverTimestamp() });
  await batch.commit();
}

beforeEach(async () => {
  await clear();
  await seedChat();
});

after(cleanup);

describe('allowed deletes', () => {
  it('latest unseen message: preview cleared, unread down by one', async () => {
    const db = await authed(SELLER);
    const batch = writeBatch(db);
    markDeleted(batch, db, 's2');
    batch.update(conversation(db), { lastDeletedMessageId: 's2', lastMessage: deletedPreview('s2', SELLER), [`unreadCount.${ALICE}`]: 1 });
    await assertSucceeds(batch.commit());
    assert.equal(await unreadOf(ALICE), 1);
    assert.deepEqual((await snapshot()).conv.lastMessage, deletedPreview('s2', SELLER));
  });

  it('older unseen message: preview untouched', async () => {
    const db = await authed(SELLER);
    const batch = writeBatch(db);
    markDeleted(batch, db, 's1');
    batch.update(conversation(db), { lastDeletedMessageId: 's1', [`unreadCount.${ALICE}`]: 1 });
    await assertSucceeds(batch.commit());
    assert.equal((await snapshot()).conv.lastMessage.text, 'text s2');
  });

  for (const [label, field] of [['read', 'lastReadAt'], ['hidden by a clear of the conversation', 'clearedAt']]) {
    it(`message the recipient has ${label}: unread unchanged`, async () => {
      await seedChat({ [field]: { [ALICE]: minutes(-15) } });
      const db = await authed(SELLER);
      const batch = writeBatch(db);
      markDeleted(batch, db, 's1');
      batch.update(conversation(db), { lastDeletedMessageId: 's1' });
      await assertSucceeds(batch.commit());
      assert.equal(await unreadOf(ALICE), 2);
    });
  }

  it('unread already 0: stays 0', async () => {
    await seedChat({ unreadCount: { [ALICE]: 0, [SELLER]: 0 } });
    const db = await authed(SELLER);
    const batch = writeBatch(db);
    markDeleted(batch, db, 's1');
    batch.update(conversation(db), { lastDeletedMessageId: 's1' });
    await assertSucceeds(batch.commit());
    assert.equal(await unreadOf(ALICE), 0);
  });

  it('as a transaction, the way T069 runs it', async () => {
    await assertSucceeds(deleteMessage(await authed(SELLER), SELLER, ALICE, 's2').run);
    assert.equal(await unreadOf(ALICE), 1);
    assert.equal(await isDeleted('s2'), true);
  });

  it('two messages one after the other each count once', async () => {
    const db = await authed(SELLER);
    await assertSucceeds(deleteMessage(db, SELLER, ALICE, 's2').run);
    await assertSucceeds(deleteMessage(db, SELLER, ALICE, 's1').run);
    assert.equal(await unreadOf(ALICE), 0);
  });

  it('send, mark read and clear keep working next to the new field', async () => {
    await seedChat({ lastDeletedMessageId: 'gone' });
    const db = await authed(ALICE);
    await assertSucceeds(sendFromAlice(db));
    await assertSucceeds(readAll(db, ALICE));
    await assertSucceeds(updateDoc(conversation(db), { [`unreadCount.${ALICE}`]: 0, [`clearedAt.${ALICE}`]: serverTimestamp() }));
  });
});

describe('refused, and nothing changes', () => {
  const refused = (name, who, build, setup) => it(name, async () => {
    if (setup) await setup();
    const before = await snapshot();
    const db = await authed(who);
    const batch = writeBatch(db);
    build(batch, db);
    await assertFails(batch.commit());
    assert.deepEqual(await snapshot(), before);
  });

  const lowerAlice = { [`unreadCount.${ALICE}`]: 1 };

  // R6
  refused('R6: unread lowered with no message and no id', SELLER, (b, db) => {
    b.update(conversation(db), lowerAlice);
  });
  refused('R6: unread lowered from 1 to 0 with no message', SELLER, (b, db) => {
    b.update(conversation(db), { [`unreadCount.${ALICE}`]: 0 });
  }, () => seedChat({ unreadCount: { [ALICE]: 1, [SELLER]: 0 } }));

  // R21
  refused('R21: real message named, not deleted, unread lowered', SELLER, (b, db) => {
    b.update(conversation(db), { lastDeletedMessageId: 's1', ...lowerAlice });
  });
  refused('R21: real message named, not deleted, nothing else', SELLER, (b, db) => {
    b.update(conversation(db), { lastDeletedMessageId: 's1' });
  });

  // R22
  refused('R22: already deleted message named', SELLER, (b, db) => {
    b.update(conversation(db), { lastDeletedMessageId: 'gone', ...lowerAlice });
  });
  refused('R22: already deleted message deleted again', SELLER, (b, db) => {
    markDeleted(b, db, 'gone');
    b.update(conversation(db), { lastDeletedMessageId: 'gone', ...lowerAlice });
  });
  refused('R22: same id already stored, unread lowered again', SELLER, (b, db) => {
    b.update(conversation(db), lowerAlice);
  }, () => seedChat({ lastDeletedMessageId: 's1' }));

  // R23
  refused("R23: other user's message named", SELLER, (b, db) => {
    b.update(conversation(db), { lastDeletedMessageId: 'a1', ...lowerAlice });
  });
  refused("R23: other user's message deleted", SELLER, (b, db) => {
    markDeleted(b, db, 'a1');
    b.update(conversation(db), { lastDeletedMessageId: 'a1', ...lowerAlice });
  });
  refused('R23: missing message named', SELLER, (b, db) => {
    b.update(conversation(db), { lastDeletedMessageId: 'ghost', ...lowerAlice });
  });
  refused('R23: id is not a string', SELLER, (b, db) => {
    b.update(conversation(db), { lastDeletedMessageId: 5, ...lowerAlice });
  });
  refused('R23: id is a path', SELLER, (b, db) => {
    b.update(conversation(db), { lastDeletedMessageId: 's1/x', ...lowerAlice });
  });
  it('R23: own message of another conversation cannot be used as proof in this one', async () => {
    const other = `${SELLER}_${SELLER2}`;
    await seed(async (db) => {
      await setDoc(conversation(db, other), {
        participants: [SELLER, SELLER2],
        buyerId: SELLER,
        sellerId: SELLER2,
        participantNames: { [SELLER]: NAMES[SELLER], [SELLER2]: NAMES[SELLER2] },
        createdAt: minutes(-60),
        lastMessage: { id: 'x', text: 'x', senderId: SELLER, deleted: false },
        lastMessageAt: minutes(-5),
        unreadCount: { [SELLER]: 0, [SELLER2]: 1 },
      });
      await setDoc(message(db, 'x', other), { senderId: SELLER, text: 'x', createdAt: minutes(-5), deleted: false });
    });
    const db = await authed(SELLER);
    const batch = writeBatch(db);
    markDeleted(batch, db, 's1');
    batch.update(message(db, 'x', other), { deleted: true, text: '' });
    batch.update(conversation(db), { lastDeletedMessageId: 'x', ...lowerAlice });
    await assertFails(batch.commit());
    assert.equal(await unreadOf(ALICE), 2);
  });

  // R24
  refused('R24: message deleted with no conversation update', SELLER, (b, db) => {
    markDeleted(b, db, 's1');
  });
  refused('R24: message deleted, conversation names a different one', SELLER, (b, db) => {
    markDeleted(b, db, 's1');
    b.update(conversation(db), { lastDeletedMessageId: 's2', lastMessage: deletedPreview('s2', SELLER), ...lowerAlice });
  });
  refused('R24: two messages deleted for one count', SELLER, (b, db) => {
    markDeleted(b, db, 's1');
    markDeleted(b, db, 's2');
    b.update(conversation(db), { lastDeletedMessageId: 's2', lastMessage: deletedPreview('s2', SELLER), ...lowerAlice });
  });
  refused('R24: message marked deleted but its text kept', SELLER, (b, db) => {
    b.update(message(db, 's1'), { deleted: true });
    b.update(conversation(db), { lastDeletedMessageId: 's1', ...lowerAlice });
  });

  // R25
  for (const [label, field] of [['read', 'lastReadAt'], ['hidden by a clear', 'clearedAt']]) {
    refused(`R25: unread lowered for a message the recipient has ${label}`, SELLER, (b, db) => {
      markDeleted(b, db, 's1');
      b.update(conversation(db), { lastDeletedMessageId: 's1', ...lowerAlice });
    }, () => seedChat({ [field]: { [ALICE]: minutes(-15) } }));
  }

  // R26
  refused('R26: unseen message, unread left unchanged', SELLER, (b, db) => {
    markDeleted(b, db, 's1');
    b.update(conversation(db), { lastDeletedMessageId: 's1' });
  });
  refused('R26: unread lowered by two', SELLER, (b, db) => {
    markDeleted(b, db, 's1');
    b.update(conversation(db), { lastDeletedMessageId: 's1', [`unreadCount.${ALICE}`]: 0 });
  });
  refused('R26: unread raised', SELLER, (b, db) => {
    markDeleted(b, db, 's1');
    b.update(conversation(db), { lastDeletedMessageId: 's1', [`unreadCount.${ALICE}`]: 3 });
  });
  refused('R26: unread made negative', SELLER, (b, db) => {
    markDeleted(b, db, 's1');
    b.update(conversation(db), { lastDeletedMessageId: 's1', [`unreadCount.${ALICE}`]: -1 });
  }, () => seedChat({ unreadCount: { [ALICE]: 0, [SELLER]: 0 } }));
  refused('R26: own unread changed in the same write', SELLER, (b, db) => {
    markDeleted(b, db, 's1');
    b.update(conversation(db), { lastDeletedMessageId: 's1', ...lowerAlice, [`unreadCount.${SELLER}`]: 0 });
  });

  // R27
  refused('R27: latest message deleted, preview text kept', SELLER, (b, db) => {
    markDeleted(b, db, 's2');
    b.update(conversation(db), { lastDeletedMessageId: 's2', ...lowerAlice });
  });
  refused('R27: latest message deleted, preview partly cleared', SELLER, (b, db) => {
    markDeleted(b, db, 's2');
    b.update(conversation(db), { lastDeletedMessageId: 's2', 'lastMessage.deleted': true, ...lowerAlice });
  });
  refused('R27: older message deleted, preview rewritten', SELLER, (b, db) => {
    markDeleted(b, db, 's1');
    b.update(conversation(db), { lastDeletedMessageId: 's1', lastMessage: deletedPreview('s2', SELLER), ...lowerAlice });
  });

  // R28
  refused('R28: another field changed in the delete write', SELLER, (b, db) => {
    markDeleted(b, db, 's1');
    b.update(conversation(db), { lastDeletedMessageId: 's1', ...lowerAlice, lastMessageAt: serverTimestamp() });
  });
  refused('R28: id set by a send write', ALICE, (b, db) => {
    b.set(message(db, 'new'), { senderId: ALICE, text: 'hi', createdAt: serverTimestamp(), deleted: false });
    b.update(conversation(db), {
      lastDeletedMessageId: 'a1',
      lastMessage: { id: 'new', text: 'hi', senderId: ALICE, deleted: false },
      lastMessageAt: serverTimestamp(),
      [`unreadCount.${SELLER}`]: increment(1),
    });
    b.set(doc(db, 'chatRateLimits', ALICE), { count: 1, windowStart: serverTimestamp() });
  });
  refused('R28: id set by a mark-read write', ALICE, (b, db) => {
    b.update(conversation(db), { lastDeletedMessageId: 'a1', [`unreadCount.${ALICE}`]: 0, [`lastReadAt.${ALICE}`]: serverTimestamp() });
  });

  // R29
  for (const [role, outsider] of [['buyer', OTHER], ['seller', SELLER2], ['admin', ADMIN]]) {
    refused(`R29: non-participant with the ${role} role runs the whole delete`, outsider, (b, db) => {
      markDeleted(b, db, 's1');
      b.update(conversation(db), { lastDeletedMessageId: 's1', ...lowerAlice });
    });
  }

  it('R22: the same message deleted twice counts once', async () => {
    const db = await authed(SELLER);
    const first = writeBatch(db);
    markDeleted(first, db, 's1');
    first.update(conversation(db), { lastDeletedMessageId: 's1', ...lowerAlice });
    await assertSucceeds(first.commit());

    const again = writeBatch(db);
    markDeleted(again, db, 's1');
    again.update(conversation(db), { lastDeletedMessageId: 's1', [`unreadCount.${ALICE}`]: 0 });
    await assertFails(again.commit());
    assert.equal(await unreadOf(ALICE), 1);
  });
});

// Why T069 needs one retry on top of the transaction's own retries (research D19).
describe('another write between the reads and the commit', () => {
  it('the rules still pass: the transaction retries by itself', async () => {
    const db = await authed(SELLER);
    const aliceDb = await authed(ALICE);
    // Deleting an older message does not depend on the new message from alice.
    const { run, state } = deleteMessage(db, SELLER, ALICE, 's1', { between: () => sendFromAlice(aliceDb) });
    await assertSucceeds(run);
    assert.equal(state.attempts, 2);
    assert.equal(await isDeleted('s1'), true);
    assert.equal(await unreadOf(ALICE), 1);
  });

  it('the rules refuse the stale write: the error ends the transaction with no retry', async () => {
    const db = await authed(SELLER);
    const aliceDb = await authed(ALICE);
    // Alice reads the chat, so the message no longer counts as unseen.
    const { run, state } = deleteMessage(db, SELLER, ALICE, 's1', { between: () => readAll(aliceDb, ALICE) });
    await assert.rejects(run, (e) => e.code === 'permission-denied');
    assert.equal(state.attempts, 1);
    assert.equal(await isDeleted('s1'), false);
    assert.equal(await unreadOf(ALICE), 0);
  });

  it('a newer message makes the preview write stale in the same way', async () => {
    const db = await authed(SELLER);
    const aliceDb = await authed(ALICE);
    const { run, state } = deleteMessage(db, SELLER, ALICE, 's2', { between: () => sendFromAlice(aliceDb) });
    await assert.rejects(run, (e) => e.code === 'permission-denied');
    assert.equal(state.attempts, 1);
    assert.equal(await isDeleted('s2'), false);
  });

  it('one retry with fresh reads deletes once and leaves the count right', async () => {
    const db = await authed(SELLER);
    const aliceDb = await authed(ALICE);
    await assertSucceeds(deleteWithOneRetry(db, SELLER, ALICE, 's1', { between: () => readAll(aliceDb, ALICE) }));
    assert.equal(await isDeleted('s1'), true);
    assert.equal(await unreadOf(ALICE), 0);
  });

  it('the retry keeps the newer preview after a new message', async () => {
    const db = await authed(SELLER);
    const aliceDb = await authed(ALICE);
    await assertSucceeds(deleteWithOneRetry(db, SELLER, ALICE, 's2', { between: () => sendFromAlice(aliceDb) }));
    assert.equal(await isDeleted('s2'), true);
    assert.equal((await snapshot()).conv.lastMessage.id, 'new');
  });

  it('a real denial stays denied after the retry', async () => {
    const db = await authed(SELLER);
    await assert.rejects(deleteWithOneRetry(db, SELLER, ALICE, 'a1'), (e) => e.code === 'permission-denied');
    assert.equal(await isDeleted('a1'), false);
    assert.equal(await unreadOf(ALICE), 2);
  });

  it('a retry after the delete already succeeded writes nothing more', async () => {
    const db = await authed(SELLER);
    await assertSucceeds(deleteMessage(db, SELLER, ALICE, 's1').run);
    await assertSucceeds(deleteWithOneRetry(db, SELLER, ALICE, 's1'));
    assert.equal(await unreadOf(ALICE), 1);
  });
});
