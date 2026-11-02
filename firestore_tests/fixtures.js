// Seed data shared by the rules tests. Written with rules disabled.
const { doc, setDoc, Timestamp } = require('firebase/firestore');

const ALICE = 'alice'; // buyer
const SELLER = 'seller'; // seller, owns car1
const OTHER = 'other'; // unrelated buyer
const ADMIN = 'admin'; // admin role
const CID = `${ALICE}_${SELLER}`; // sorted pair id

const NAMES = {
  [ALICE]: 'Alice Buyer',
  [SELLER]: 'Sam Seller',
  [OTHER]: 'Olivia Other',
  [ADMIN]: 'Mia Admin',
};

function userDoc(id, role) {
  return { id, fullName: NAMES[id], email: `${id}@test.dev`, phone: '0790000000', role };
}

async function seedUsers(db, { withProfiles = [ALICE, SELLER] } = {}) {
  await setDoc(doc(db, 'users', ALICE), userDoc(ALICE, 'buyer'));
  await setDoc(doc(db, 'users', SELLER), userDoc(SELLER, 'seller'));
  await setDoc(doc(db, 'users', OTHER), userDoc(OTHER, 'buyer'));
  await setDoc(doc(db, 'users', ADMIN), userDoc(ADMIN, 'admin'));
  for (const id of withProfiles) {
    await setDoc(doc(db, 'publicProfiles', id), { displayName: NAMES[id] });
  }
}

async function seedCarAndAd(db) {
  await setDoc(doc(db, 'cars', 'car1'), {
    brand: 'toyota',
    model: 'corolla',
    year: 2020,
    price: 15000,
    sellerId: SELLER,
    createdAt: Timestamp.now(),
  });
  await setDoc(doc(db, 'ads', 'ad1'), {
    image: 'assets/ads/1.png',
    whatsappLink: 'https://wa.me/1',
    order: 1,
    expiryDate: '2030-01-01T00:00:00.000',
  });
}

// An existing A–S conversation with two messages (m1 from alice, m2 from seller).
async function seedConversation(db) {
  const t1 = Timestamp.fromMillis(Date.now() - 60 * 60 * 1000);
  const t2 = Timestamp.fromMillis(Date.now() - 30 * 60 * 1000);
  await setDoc(doc(db, 'conversations', CID), {
    participants: [ALICE, SELLER],
    buyerId: ALICE,
    sellerId: SELLER,
    participantNames: { [ALICE]: NAMES[ALICE], [SELLER]: NAMES[SELLER] },
    createdAt: t1,
    lastMessage: { id: 'm2', text: 'Yes, still available', senderId: SELLER, deleted: false },
    lastMessageAt: t2,
    unreadCount: { [ALICE]: 1, [SELLER]: 0 },
  });
  await setDoc(doc(db, 'conversations', CID, 'messages', 'm1'), {
    senderId: ALICE,
    text: 'Is it available?',
    createdAt: t1,
    deleted: false,
  });
  await setDoc(doc(db, 'conversations', CID, 'messages', 'm2'), {
    senderId: SELLER,
    text: 'Yes, still available',
    createdAt: t2,
    deleted: false,
  });
}

module.exports = {
  ALICE,
  SELLER,
  OTHER,
  ADMIN,
  CID,
  NAMES,
  seedUsers,
  seedCarAndAd,
  seedConversation,
};
