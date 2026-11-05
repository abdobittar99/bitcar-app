// Existing collections: permissions audit E1–E13 and fixes S1/S2 (contracts/firestore-security-rules.md).
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
  addDoc,
  writeBatch,
  query,
  where,
  orderBy,
  limit,
  documentId,
  serverTimestamp,
} = require('firebase/firestore');
const { authed, unauthed, seed, clear, cleanup } = require('./helpers');
const { ALICE, SELLER, OTHER, ADMIN, seedUsers, seedCarAndAd } = require('./fixtures');

beforeEach(async () => {
  await clear();
  await seed(async (db) => {
    await seedUsers(db);
    await seedCarAndAd(db);
    await setDoc(doc(db, 'users', ALICE, 'favorites', 'car1'), { createdAt: serverTimestamp() });
  });
});

after(cleanup);

const newUser = (id, role) => ({
  id,
  fullName: 'New User',
  email: `${id}@test.dev`,
  phone: '0791111111',
  role,
});

describe('E1 register: create own users doc', () => {
  it('allows a buyer or seller to create their own doc', async () => {
    const db = await authed('newbie');
    await assertSucceeds(setDoc(doc(db, 'users', 'newbie'), newUser('newbie', 'seller')));
  });
  it('S1: denies registering with role admin', async () => {
    const db = await authed('newbie');
    await assertFails(setDoc(doc(db, 'users', 'newbie'), newUser('newbie', 'admin')));
  });
  it('denies an id field that differs from the uid', async () => {
    const db = await authed('newbie');
    await assertFails(setDoc(doc(db, 'users', 'newbie'), newUser('someoneElse', 'buyer')));
  });
  it("denies creating another user's doc", async () => {
    const db = await authed('newbie');
    await assertFails(setDoc(doc(db, 'users', 'victim'), newUser('victim', 'buyer')));
  });
  it('S2: denies a signed-out client', async () => {
    const db = await unauthed();
    await assertFails(setDoc(doc(db, 'users', 'newbie'), newUser('newbie', 'buyer')));
  });
});

describe('E2/E4 read users docs', () => {
  it('allows reading own doc', async () => {
    await assertSucceeds(getDoc(doc(await authed(ALICE), 'users', ALICE)));
  });
  it("E4: denies reading another user's doc (buyer and admin)", async () => {
    await assertFails(getDoc(doc(await authed(ALICE), 'users', SELLER)));
    await assertFails(getDoc(doc(await authed(ADMIN), 'users', SELLER)));
  });
  it('denies listing users', async () => {
    await assertFails(getDocs(collection(await authed(ADMIN), 'users')));
  });
  it('S2: denies a signed-out client', async () => {
    await assertFails(getDoc(doc(await unauthed(), 'users', ALICE)));
  });
});

describe('E3 update own users doc', () => {
  it('allows the profile edit (full map, same role and id)', async () => {
    const db = await authed(ALICE);
    await assertSucceeds(
      updateDoc(doc(db, 'users', ALICE), {
        id: ALICE,
        fullName: 'Alice Renamed',
        email: `${ALICE}@test.dev`,
        phone: '0792222222',
        role: 'buyer',
      }),
    );
  });
  it('S1: denies changing own role to admin', async () => {
    await assertFails(updateDoc(doc(await authed(ALICE), 'users', ALICE), { role: 'admin' }));
  });
  it('denies changing the id field', async () => {
    await assertFails(updateDoc(doc(await authed(ALICE), 'users', ALICE), { id: 'x' }));
  });
  it("denies updating another user's doc", async () => {
    await assertFails(updateDoc(doc(await authed(OTHER), 'users', ALICE), { fullName: 'Hacked' }));
  });
});

describe('E5 favorites', () => {
  it('allows the owner to list, add, remove and batch-delete favorites', async () => {
    const db = await authed(ALICE);
    await assertSucceeds(getDocs(collection(db, 'users', ALICE, 'favorites')));
    await assertSucceeds(
      setDoc(doc(db, 'users', ALICE, 'favorites', 'car2'), { createdAt: serverTimestamp() }),
    );
    await assertSucceeds(deleteDoc(doc(db, 'users', ALICE, 'favorites', 'car2')));
    const batch = writeBatch(db);
    batch.delete(doc(db, 'users', ALICE, 'favorites', 'car1'));
    await assertSucceeds(batch.commit());
  });
  it("denies reading or writing another user's favorites", async () => {
    const db = await authed(OTHER);
    await assertFails(getDocs(collection(db, 'users', ALICE, 'favorites')));
    await assertFails(
      setDoc(doc(db, 'users', ALICE, 'favorites', 'car9'), { createdAt: serverTimestamp() }),
    );
    await assertFails(deleteDoc(doc(db, 'users', ALICE, 'favorites', 'car1')));
  });
  it('S2: denies a signed-out client', async () => {
    await assertFails(getDocs(collection(await unauthed(), 'users', ALICE, 'favorites')));
  });
});

describe('E7 read cars', () => {
  it('allows signed-in reads used by the app', async () => {
    const db = await authed(OTHER);
    await assertSucceeds(getDoc(doc(db, 'cars', 'car1')));
    await assertSucceeds(getDocs(query(collection(db, 'cars'), orderBy('createdAt', 'desc'), limit(10))));
    await assertSucceeds(
      getDocs(query(collection(db, 'cars'), where('sellerId', '==', SELLER), orderBy('createdAt', 'desc'))),
    );
    await assertSucceeds(getDocs(query(collection(db, 'cars'), where(documentId(), 'in', ['car1']))));
  });
  it('S2: denies a signed-out client', async () => {
    await assertFails(getDoc(doc(await unauthed(), 'cars', 'car1')));
  });
});

describe('E8 create car', () => {
  it('allows creating a car with own sellerId', async () => {
    const db = await authed(SELLER);
    await assertSucceeds(setDoc(doc(db, 'cars', 'car2'), { brand: 'kia', sellerId: SELLER, createdAt: serverTimestamp() }));
  });
  it("denies creating a car with someone else's sellerId", async () => {
    const db = await authed(OTHER);
    await assertFails(setDoc(doc(db, 'cars', 'car3'), { brand: 'kia', sellerId: SELLER, createdAt: serverTimestamp() }));
  });
  it('S2: denies a signed-out client', async () => {
    await assertFails(setDoc(doc(await unauthed(), 'cars', 'car4'), { sellerId: SELLER }));
  });
});

describe('E9/E11 update car', () => {
  it('allows the owner to update (partial and full-map update)', async () => {
    const db = await authed(SELLER);
    await assertSucceeds(updateDoc(doc(db, 'cars', 'car1'), { price: 14000, updatedAt: serverTimestamp() }));
    await assertSucceeds(
      updateDoc(doc(db, 'cars', 'car1'), {
        brand: 'toyota',
        model: 'corolla',
        year: 2020,
        price: 13500,
        sellerId: SELLER,
        createdAt: serverTimestamp(),
      }),
    );
  });
  it('allows an admin to update', async () => {
    await assertSucceeds(updateDoc(doc(await authed(ADMIN), 'cars', 'car1'), { price: 12000 }));
  });
  it('denies a non-owner non-admin', async () => {
    await assertFails(updateDoc(doc(await authed(OTHER), 'cars', 'car1'), { price: 1 }));
  });
  it('denies changing sellerId (owner and admin)', async () => {
    await assertFails(updateDoc(doc(await authed(SELLER), 'cars', 'car1'), { sellerId: OTHER }));
    await assertFails(updateDoc(doc(await authed(ADMIN), 'cars', 'car1'), { sellerId: OTHER }));
  });
});

describe('E10 delete car', () => {
  it('allows the owner to delete', async () => {
    await assertSucceeds(deleteDoc(doc(await authed(SELLER), 'cars', 'car1')));
  });
  it('allows an admin to delete', async () => {
    await assertSucceeds(deleteDoc(doc(await authed(ADMIN), 'cars', 'car1')));
  });
  it('denies a non-owner non-admin', async () => {
    await assertFails(deleteDoc(doc(await authed(OTHER), 'cars', 'car1')));
  });
});

describe('E12/E13 ads', () => {
  const ad = { image: 'a.png', whatsappLink: 'https://wa.me/2', order: 2, expiryDate: '2030-01-01T00:00:00.000' };
  it('allows any signed-in user to read ads', async () => {
    await assertSucceeds(getDocs(collection(await authed(ALICE), 'ads')));
  });
  it('S2: denies a signed-out client', async () => {
    await assertFails(getDocs(collection(await unauthed(), 'ads')));
  });
  it('allows an admin to add and delete ads', async () => {
    const db = await authed(ADMIN);
    await assertSucceeds(addDoc(collection(db, 'ads'), ad));
    await assertSucceeds(deleteDoc(doc(db, 'ads', 'ad1')));
  });
  it('denies non-admins adding or deleting ads', async () => {
    const db = await authed(SELLER);
    await assertFails(addDoc(collection(db, 'ads'), ad));
    await assertFails(deleteDoc(doc(db, 'ads', 'ad1')));
  });
});

// E6 (functions/onCarDeleted) uses the Admin SDK, which bypasses rules and cannot be deployed on Spark: nothing to test.
