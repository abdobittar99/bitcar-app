// US1 send flow as a transaction: the same reads and writes, in the same order, as
// ChatRemoteDataSource.openChatWith / sendMessage (tasks T032/T033, research D4/D10/D14).
const { describe, it, beforeEach, after } = require('node:test');
const assert = require('node:assert/strict');
const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  deleteDoc,
  getDocs,
  collection,
  runTransaction,
  serverTimestamp,
  increment,
} = require('firebase/firestore');
const { authed, seed, clear, cleanup } = require('./helpers');
const { ALICE, SELLER, CID, NAMES, seedUsers } = require('./fixtures');

const PLACEHOLDER = 'BitCar user';

beforeEach(async () => {
  await clear();
  await seed((db) => seedUsers(db));
});

after(cleanup);

async function publicNameIn(tx, db, uid) {
  const snap = await tx.get(doc(db, 'publicProfiles', uid));
  return snap.exists() ? snap.data().displayName : PLACEHOLDER;
}

// Mirror of ChatRemoteDataSource.sendMessage.
function sendMessage(db, me, other, mid, text) {
  const cid = [me, other].sort().join('_');
  const convRef = doc(db, 'conversations', cid);
  const msgRef = doc(db, 'conversations', cid, 'messages', mid);
  const rateRef = doc(db, 'chatRateLimits', me);
  return runTransaction(db, async (tx) => {
    const conv = await tx.get(convRef);
    if (conv.exists() && (await tx.get(msgRef)).exists()) return;
    const rate = await tx.get(rateRef);
    const names = conv.exists()
      ? null
      : { [me]: await publicNameIn(tx, db, me), [other]: await publicNameIn(tx, db, other) };

    const lastMessage = { id: mid, text, senderId: me, deleted: false };
    if (names) {
      tx.set(convRef, {
        participants: [me, other].sort(),
        buyerId: me,
        sellerId: other,
        participantNames: names,
        createdAt: serverTimestamp(),
        lastMessage,
        lastMessageAt: serverTimestamp(),
        unreadCount: { [other]: 1, [me]: 0 },
      });
    } else {
      tx.update(convRef, {
        lastMessage,
        lastMessageAt: serverTimestamp(),
        [`unreadCount.${other}`]: increment(1),
      });
    }
    tx.set(msgRef, { senderId: me, text, createdAt: serverTimestamp(), deleted: false });

    const count = rate.exists() ? rate.data().count : 0;
    if (!rate.exists()) {
      tx.set(rateRef, { count: 1, windowStart: serverTimestamp() });
    } else if (count < 20) {
      tx.update(rateRef, { count: count + 1 });
    } else {
      tx.set(rateRef, { count: 1, windowStart: serverTimestamp() });
    }
  });
}

async function readAll() {
  let conv;
  let messages;
  await seed(async (db) => {
    conv = (await getDoc(doc(db, 'conversations', CID))).data();
    messages = (await getDocs(collection(db, 'conversations', CID, 'messages'))).docs.map((d) => d.id).sort();
  });
  return { conv, messages };
}

describe('US1 send transaction', () => {
  it('the first message creates the conversation with the inquiry text', async () => {
    const inquiry = "Hello, I'm interested in your toyota corolla (2020). Is it still available?";
    await assertSucceeds(sendMessage(await authed(ALICE), ALICE, SELLER, 'first', inquiry));

    const { conv, messages } = await readAll();
    assert.deepEqual(conv.participants, [ALICE, SELLER]);
    assert.equal(conv.buyerId, ALICE);
    assert.equal(conv.sellerId, SELLER);
    assert.deepEqual(conv.participantNames, { [ALICE]: NAMES[ALICE], [SELLER]: NAMES[SELLER] });
    assert.equal(conv.lastMessage.text, inquiry);
    assert.deepEqual(conv.unreadCount, { [SELLER]: 1, [ALICE]: 0 });
    assert.deepEqual(messages, ['first']);
  });

  it('opening an existing conversation reuses it: a second message updates, never re-creates', async () => {
    const db = await authed(ALICE);
    await assertSucceeds(sendMessage(db, ALICE, SELLER, 'first', 'Hello'));
    await assertSucceeds(sendMessage(db, ALICE, SELLER, 'second', 'Another car of yours?'));

    const { conv, messages } = await readAll();
    assert.deepEqual(messages, ['first', 'second']);
    assert.equal(conv.lastMessage.id, 'second');
    assert.equal(conv.unreadCount[SELLER], 2);
  });

  it('a retry with the same message id writes nothing new (idempotent)', async () => {
    const db = await authed(ALICE);
    await assertSucceeds(sendMessage(db, ALICE, SELLER, 'first', 'Hello'));
    await assertSucceeds(sendMessage(db, ALICE, SELLER, 'first', 'Hello'));

    const { conv, messages } = await readAll();
    assert.deepEqual(messages, ['first']);
    assert.equal(conv.unreadCount[SELLER], 1);
  });

  it('the seller replying uses the same conversation (one per pair)', async () => {
    await assertSucceeds(sendMessage(await authed(ALICE), ALICE, SELLER, 'first', 'Hello'));
    await assertSucceeds(sendMessage(await authed(SELLER), SELLER, ALICE, 'reply', 'Yes, available'));

    const { conv, messages } = await readAll();
    assert.deepEqual(messages, ['first', 'reply']);
    assert.equal(conv.buyerId, ALICE);
    assert.deepEqual(conv.unreadCount, { [SELLER]: 1, [ALICE]: 1 });
  });

  it('two first messages at the same time still give one conversation with both messages', async () => {
    const [alice, seller] = [await authed(ALICE), await authed(SELLER)];
    await Promise.all([
      sendMessage(alice, ALICE, SELLER, 'fromAlice', 'Hello'),
      sendMessage(seller, SELLER, ALICE, 'fromSeller', 'Hi there'),
    ]);

    const { conv, messages } = await readAll();
    assert.deepEqual(messages, ['fromAlice', 'fromSeller']);
    assert.ok([ALICE, SELLER].includes(conv.buyerId));
  });

  it('a seller without a public profile is stored with the placeholder name', async () => {
    await seed(async (db) => {
      await deleteDoc(doc(db, 'publicProfiles', SELLER));
    });
    await assertSucceeds(sendMessage(await authed(ALICE), ALICE, SELLER, 'first', 'Hello'));

    const { conv } = await readAll();
    assert.equal(conv.participantNames[SELLER], PLACEHOLDER);
  });

  it('reading a message of a conversation that does not exist is refused (why the read order matters)', async () => {
    const db = await authed(ALICE);
    await assertFails(getDoc(doc(db, 'conversations', CID, 'messages', 'any')));
  });

  it('a user outside the pair cannot send into it', async () => {
    await assertSucceeds(sendMessage(await authed(ALICE), ALICE, SELLER, 'first', 'Hello'));
    const other = await authed('other');
    await assertFails(
      runTransaction(other, async (tx) => {
        const convRef = doc(other, 'conversations', CID);
        await tx.get(convRef);
        tx.update(convRef, {
          lastMessage: { id: 'x', text: 'spam', senderId: 'other', deleted: false },
          lastMessageAt: serverTimestamp(),
        });
      }),
    );
  });
});
