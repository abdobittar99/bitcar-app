// Chat paths: R1–R15 and allowed paths (contracts/firestore-security-rules.md, research D4/D10/D14/D17).
const { describe, it, beforeEach, after } = require('node:test');
const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc,
  collection,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  writeBatch,
  query,
  where,
  orderBy,
  limit,
  startAfter,
  documentId,
  serverTimestamp,
  increment,
  deleteField,
  Timestamp,
} = require('firebase/firestore');
const { authed, unauthed, seed, clear, cleanup } = require('./helpers');
const { ALICE, SELLER, OTHER, ADMIN, CID, NAMES, seedUsers, seedConversation } = require('./fixtures');

const PLACEHOLDER = 'BitCar user';

beforeEach(async () => {
  await clear();
  await seed((db) => seedUsers(db));
});

after(cleanup);

// First message: creates the conversation, the message and the rate-limit doc in one atomic write.
function firstSendBatch(db, { me = ALICE, other = SELLER, mid = 'first', text = 'Hello, is it available?', names, conv = {}, msg = {}, writeRateLimit = true } = {}) {
  const participants = [me, other].sort();
  const cid = `${participants[0]}_${participants[1]}`;
  const batch = writeBatch(db);
  batch.set(doc(db, 'conversations', cid), {
    participants,
    buyerId: me,
    sellerId: other,
    participantNames: names ?? { [me]: NAMES[me], [other]: NAMES[other] },
    createdAt: serverTimestamp(),
    lastMessage: { id: mid, text, senderId: me, deleted: false },
    lastMessageAt: serverTimestamp(),
    unreadCount: { [other]: 1, [me]: 0 },
    ...conv,
  });
  batch.set(doc(db, 'conversations', cid, 'messages', mid), {
    senderId: me,
    text,
    createdAt: serverTimestamp(),
    deleted: false,
    ...msg,
  });
  if (writeRateLimit) {
    batch.set(doc(db, 'chatRateLimits', me), { count: 1, windowStart: serverTimestamp() });
  }
  return batch;
}

// Next message in the existing A–S conversation (seedConversation).
function sendBatch(db, { me = ALICE, other = SELLER, mid = 'm3', text = 'Can I see it tomorrow?', rateLimit = 'create', msg = {}, conv = {} } = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'conversations', CID, 'messages', mid), {
    senderId: me,
    text,
    createdAt: serverTimestamp(),
    deleted: false,
    ...msg,
  });
  batch.update(doc(db, 'conversations', CID), {
    lastMessage: { id: mid, text, senderId: me, deleted: false },
    lastMessageAt: serverTimestamp(),
    [`unreadCount.${other}`]: increment(1),
    ...conv,
  });
  if (rateLimit === 'create') {
    batch.set(doc(db, 'chatRateLimits', me), { count: 1, windowStart: serverTimestamp() });
  } else if (rateLimit === 'increment') {
    batch.update(doc(db, 'chatRateLimits', me), { count: increment(1) });
  } else if (rateLimit === 'newWindow') {
    batch.set(doc(db, 'chatRateLimits', me), { count: 1, windowStart: serverTimestamp() });
  }
  return batch;
}

describe('chat allowed paths', () => {
  it('first message creates the conversation with both profile names (within the rules access budget)', async () => {
    await assertSucceeds(firstSendBatch(await authed(ALICE)).commit());
  });

  it('first message uses the placeholder for a user without a public profile', async () => {
    await seed((db) => deleteDoc(doc(db, 'publicProfiles', SELLER)));
    const db = await authed(ALICE);
    await assertSucceeds(
      firstSendBatch(db, { names: { [ALICE]: NAMES[ALICE], [SELLER]: PLACEHOLDER } }).commit(),
    );
  });

  it('a participant can get a conversation that does not exist yet (open chat check)', async () => {
    await assertSucceeds(getDoc(doc(await authed(ALICE), 'conversations', CID)));
  });

  describe('with an existing conversation', () => {
    beforeEach(() => seed(seedConversation));

    it('participants can get the conversation and list their conversations', async () => {
      for (const me of [ALICE, SELLER]) {
        const db = await authed(me);
        await assertSucceeds(getDoc(doc(db, 'conversations', CID)));
        await assertSucceeds(
          getDocs(query(collection(db, 'conversations'), where('participants', 'array-contains', me), orderBy('lastMessageAt', 'desc'))),
        );
      }
    });

    it('sends a message (message + conversation update + rate-limit doc)', async () => {
      await assertSucceeds(sendBatch(await authed(ALICE)).commit());
    });

    it('allows the pagination queries (live window, older batch, with and without clearedAt)', async () => {
      const db = await authed(ALICE);
      const messages = collection(db, 'conversations', CID, 'messages');
      const cursorTime = Timestamp.fromMillis(Date.now() - 30 * 60 * 1000);
      const clearedAt = Timestamp.fromMillis(Date.now() - 2 * 60 * 60 * 1000);
      const base = [orderBy('createdAt', 'desc'), orderBy(documentId(), 'desc')];
      await assertSucceeds(getDocs(query(messages, ...base, limit(20))));
      await assertSucceeds(getDocs(query(messages, where('createdAt', '>', clearedAt), ...base, limit(20))));
      await assertSucceeds(getDocs(query(messages, ...base, startAfter(cursorTime, 'm2'), limit(20))));
      await assertSucceeds(
        getDocs(query(messages, where('createdAt', '>', clearedAt), ...base, startAfter(cursorTime, 'm2'), limit(20))),
      );
    });

    it('marks the conversation read', async () => {
      const db = await authed(ALICE);
      await assertSucceeds(
        updateDoc(doc(db, 'conversations', CID), {
          [`unreadCount.${ALICE}`]: 0,
          [`lastReadAt.${ALICE}`]: serverTimestamp(),
        }),
      );
    });

    it('deletes own message for everyone (message, preview and unread fix-up)', async () => {
      const db = await authed(SELLER);
      const batch = writeBatch(db);
      batch.update(doc(db, 'conversations', CID, 'messages', 'm2'), { deleted: true, text: '' });
      batch.update(doc(db, 'conversations', CID), {
        lastMessage: { id: 'm2', text: '', senderId: SELLER, deleted: true },
        [`unreadCount.${ALICE}`]: increment(-1),
      });
      await assertSucceeds(batch.commit());
    });

    it('deletes the conversation from own side only (clearedAt)', async () => {
      const db = await authed(ALICE);
      await assertSucceeds(
        updateDoc(doc(db, 'conversations', CID), {
          [`clearedAt.${ALICE}`]: serverTimestamp(),
          [`unreadCount.${ALICE}`]: 0,
        }),
      );
    });

    it('replaces own placeholder with own public profile name', async () => {
      await seed((db) =>
        updateDoc(doc(db, 'conversations', CID), { [`participantNames.${SELLER}`]: PLACEHOLDER }),
      );
      const db = await authed(SELLER);
      await assertSucceeds(updateDoc(doc(db, 'conversations', CID), { [`participantNames.${SELLER}`]: NAMES[SELLER] }));
    });

    it('starts a new rate-limit window after 60 s', async () => {
      await seed((db) =>
        setDoc(doc(db, 'chatRateLimits', ALICE), { count: 20, windowStart: Timestamp.fromMillis(Date.now() - 120 * 1000) }),
      );
      await assertSucceeds(sendBatch(await authed(ALICE), { rateLimit: 'newWindow' }).commit());
    });

    it('counts a message in the same window', async () => {
      await seed((db) => setDoc(doc(db, 'chatRateLimits', ALICE), { count: 5, windowStart: Timestamp.now() }));
      await assertSucceeds(sendBatch(await authed(ALICE), { rateLimit: 'increment' }).commit());
    });
  });
});

describe('chat denied paths', () => {
  describe('with an existing conversation', () => {
    beforeEach(() => seed(seedConversation));

    it('R1: non-participants (buyer and admin) cannot get or list the conversation or its messages', async () => {
      for (const outsider of [OTHER, ADMIN]) {
        const db = await authed(outsider);
        const messages = collection(db, 'conversations', CID, 'messages');
        await assertFails(getDoc(doc(db, 'conversations', CID)));
        await assertFails(getDoc(doc(db, 'conversations', CID, 'messages', 'm1')));
        await assertFails(getDocs(messages));
        await assertFails(getDocs(query(messages, orderBy('createdAt', 'desc'), orderBy(documentId(), 'desc'), limit(20))));
        await assertFails(
          getDocs(query(collection(db, 'conversations'), where('participants', 'array-contains', ALICE))),
        );
      }
    });

    it('R2: a non-participant cannot add a message', async () => {
      const db = await authed(OTHER);
      await assertFails(sendBatch(db, { me: OTHER, other: SELLER }).commit());
      await assertFails(
        setDoc(doc(db, 'conversations', CID, 'messages', 'x'), { senderId: OTHER, text: 'hi', createdAt: serverTimestamp(), deleted: false }),
      );
    });

    it("R3: a participant cannot send with the other user's senderId", async () => {
      await assertFails(sendBatch(await authed(ALICE), { msg: { senderId: SELLER } }).commit());
    });

    it('R4: a participant cannot edit the text of a message', async () => {
      await assertFails(updateDoc(doc(await authed(ALICE), 'conversations', CID, 'messages', 'm1'), { text: 'edited' }));
    });

    it("R5: a participant cannot delete the other user's message", async () => {
      const db = await authed(ALICE);
      await assertFails(updateDoc(doc(db, 'conversations', CID, 'messages', 'm2'), { deleted: true, text: '' }));
      await assertFails(deleteDoc(doc(db, 'conversations', CID, 'messages', 'm2')));
    });

    it("R6: a participant cannot reset or change the other user's unread, lastReadAt or clearedAt", async () => {
      const db = await authed(SELLER);
      const ref = doc(db, 'conversations', CID);
      await assertFails(updateDoc(ref, { [`unreadCount.${ALICE}`]: 0, [`lastReadAt.${SELLER}`]: serverTimestamp() }));
      await assertFails(updateDoc(ref, { [`unreadCount.${SELLER}`]: 0, [`lastReadAt.${ALICE}`]: serverTimestamp() }));
      await assertFails(updateDoc(ref, { [`clearedAt.${ALICE}`]: serverTimestamp(), [`unreadCount.${SELLER}`]: 0 }));
    });

    it('R8: the 21st message within 60 s is refused (same window and early new window)', async () => {
      await seed((db) => setDoc(doc(db, 'chatRateLimits', ALICE), { count: 20, windowStart: Timestamp.now() }));
      const db = await authed(ALICE);
      await assertFails(sendBatch(db, { rateLimit: 'increment' }).commit());
      await assertFails(sendBatch(db, { rateLimit: 'newWindow' }).commit());
    });

    it('a message without a counted rate-limit write is refused', async () => {
      await assertFails(sendBatch(await authed(ALICE), { rateLimit: 'none' }).commit());
    });

    it('the conversation preview cannot differ from the message text', async () => {
      await assertFails(
        sendBatch(await authed(ALICE), { conv: { lastMessage: { id: 'm3', text: 'fake preview', senderId: ALICE, deleted: false } } }).commit(),
      );
    });

    it('R10: a second create of the same conversation is refused (only one create succeeds)', async () => {
      await assertFails(firstSendBatch(await authed(SELLER), { me: SELLER, other: ALICE, mid: 'dup' }).commit());
    });

    it('R14: a real stored name cannot be changed, and the other entry cannot be set', async () => {
      const db = await authed(ALICE);
      const ref = doc(db, 'conversations', CID);
      await assertFails(updateDoc(ref, { [`participantNames.${ALICE}`]: 'Alice Changed' }));
      await assertFails(updateDoc(ref, { [`participantNames.${SELLER}`]: 'Not Sam' }));
    });

    it('R15: own placeholder cannot be replaced by a name other than own public profile', async () => {
      await seed((db) =>
        updateDoc(doc(db, 'conversations', CID), { [`participantNames.${SELLER}`]: PLACEHOLDER }),
      );
      const db = await authed(SELLER);
      await assertFails(updateDoc(doc(db, 'conversations', CID), { [`participantNames.${SELLER}`]: 'BitCar Official' }));
    });

    it('participants, buyerId, sellerId and createdAt are immutable; conversations cannot be deleted', async () => {
      const db = await authed(ALICE);
      const ref = doc(db, 'conversations', CID);
      await assertFails(updateDoc(ref, { participants: [ALICE, OTHER] }));
      await assertFails(updateDoc(ref, { buyerId: SELLER }));
      await assertFails(updateDoc(ref, { createdAt: serverTimestamp() }));
      await assertFails(updateDoc(ref, { participantNames: deleteField() }));
      await assertFails(deleteDoc(ref));
    });
  });

  it('R7: a user cannot create a conversation between two other users', async () => {
    const db = await authed(OTHER);
    const batch = writeBatch(db);
    batch.set(doc(db, 'conversations', CID), {
      participants: [ALICE, SELLER],
      buyerId: ALICE,
      sellerId: SELLER,
      participantNames: { [ALICE]: NAMES[ALICE], [SELLER]: NAMES[SELLER] },
      createdAt: serverTimestamp(),
      lastMessage: { id: 'x', text: 'hi', senderId: ALICE, deleted: false },
      lastMessageAt: serverTimestamp(),
      unreadCount: { [SELLER]: 1, [ALICE]: 0 },
    });
    batch.set(doc(db, 'conversations', CID, 'messages', 'x'), { senderId: ALICE, text: 'hi', createdAt: serverTimestamp(), deleted: false });
    await assertFails(batch.commit());
  });

  it('a conversation cannot be created without its first message', async () => {
    const db = await authed(ALICE);
    await assertFails(
      setDoc(doc(db, 'conversations', CID), {
        participants: [ALICE, SELLER],
        buyerId: ALICE,
        sellerId: SELLER,
        participantNames: { [ALICE]: NAMES[ALICE], [SELLER]: NAMES[SELLER] },
        createdAt: serverTimestamp(),
        lastMessage: { id: 'ghost', text: 'hi', senderId: ALICE, deleted: false },
        lastMessageAt: serverTimestamp(),
        unreadCount: { [SELLER]: 1, [ALICE]: 0 },
      }),
    );
  });

  it('a self-conversation is refused', async () => {
    const db = await authed(ALICE);
    await assertFails(firstSendBatch(db, { me: ALICE, other: ALICE }).commit());
  });

  it('R9: a signed-out client cannot use any chat path', async () => {
    await seed(seedConversation);
    const db = await unauthed();
    await assertFails(getDoc(doc(db, 'conversations', CID)));
    await assertFails(getDocs(collection(db, 'conversations', CID, 'messages')));
    await assertFails(firstSendBatch(db).commit());
    await assertFails(getDoc(doc(db, 'chatRateLimits', ALICE)));
  });

  it('an outsider cannot read whether a conversation of others exists', async () => {
    await assertFails(getDoc(doc(await authed(OTHER), 'conversations', CID)));
  });

  it("R11: the other user's name must equal their public profile", async () => {
    const db = await authed(ALICE);
    await assertFails(firstSendBatch(db, { names: { [ALICE]: NAMES[ALICE], [SELLER]: 'Trusted Dealer' } }).commit());
  });

  it('the creator cannot fake their own name either', async () => {
    const db = await authed(ALICE);
    await assertFails(firstSendBatch(db, { names: { [ALICE]: 'BitCar Support', [SELLER]: NAMES[SELLER] } }).commit());
  });

  it('R12: the placeholder cannot be used for a user who has a public profile', async () => {
    const db = await authed(ALICE);
    await assertFails(firstSendBatch(db, { names: { [ALICE]: NAMES[ALICE], [SELLER]: PLACEHOLDER } }).commit());
  });

  it('R13: an invented name is refused for a user without a public profile', async () => {
    await seed((db) => deleteDoc(doc(db, 'publicProfiles', SELLER)));
    const db = await authed(ALICE);
    await assertFails(firstSendBatch(db, { names: { [ALICE]: NAMES[ALICE], [SELLER]: 'Sam Seller' } }).commit());
  });

  it("a user cannot read or write another user's rate-limit doc", async () => {
    await seed((db) => setDoc(doc(db, 'chatRateLimits', ALICE), { count: 3, windowStart: Timestamp.now() }));
    const db = await authed(OTHER);
    await assertFails(getDoc(doc(db, 'chatRateLimits', ALICE)));
    await assertFails(setDoc(doc(db, 'chatRateLimits', ALICE), { count: 1, windowStart: serverTimestamp() }));
  });

  it('message text must be 1–1,000 characters after trim', async () => {
    const db = await authed(ALICE);
    await assertFails(firstSendBatch(db, { text: '   ' }).commit());
    await assertFails(firstSendBatch(db, { text: 'x'.repeat(1001) }).commit());
    await assertSucceeds(firstSendBatch(db, { text: 'x'.repeat(1000) }).commit());
  });
});
