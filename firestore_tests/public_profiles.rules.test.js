// publicProfiles: R16–R20 and allowed paths (contracts/firestore-security-rules.md, research D14).
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
} = require('firebase/firestore');
const { authed, unauthed, seed, clear, cleanup } = require('./helpers');
const { ALICE, SELLER, OTHER, NAMES, seedUsers } = require('./fixtures');

beforeEach(async () => {
  await clear();
  // ALICE and SELLER have public profiles; OTHER has none yet.
  await seed((db) => seedUsers(db));
});

after(cleanup);

describe('publicProfiles allowed paths', () => {
  it('allows a signed-in user to get one public profile', async () => {
    await assertSucceeds(getDoc(doc(await authed(OTHER), 'publicProfiles', SELLER)));
  });
  it('allows the owner to create their profile matching users.fullName', async () => {
    const db = await authed(OTHER);
    await assertSucceeds(setDoc(doc(db, 'publicProfiles', OTHER), { displayName: NAMES[OTHER] }));
  });
  it('allows the owner to refresh (rewrite) their matching profile', async () => {
    const db = await authed(ALICE);
    await assertSucceeds(setDoc(doc(db, 'publicProfiles', ALICE), { displayName: NAMES[ALICE] }));
  });
  it('allows a name change of users and publicProfiles in one batch', async () => {
    const db = await authed(ALICE);
    const batch = writeBatch(db);
    batch.update(doc(db, 'users', ALICE), { fullName: 'Alice Renamed' });
    batch.set(doc(db, 'publicProfiles', ALICE), { displayName: 'Alice Renamed' });
    await assertSucceeds(batch.commit());
  });
  it('allows syncing the public name after users.fullName was changed', async () => {
    await seed((db) => updateDoc(doc(db, 'users', ALICE), { fullName: 'Alice New' }));
    await assertSucceeds(updateDoc(doc(await authed(ALICE), 'publicProfiles', ALICE), { displayName: 'Alice New' }));
  });
});

describe('publicProfiles denied paths', () => {
  it("R16: denies writing another user's public profile", async () => {
    const db = await authed(OTHER);
    await assertFails(setDoc(doc(db, 'publicProfiles', SELLER), { displayName: NAMES[SELLER] }));
    await assertFails(setDoc(doc(db, 'publicProfiles', SELLER), { displayName: 'Scammer' }));
  });
  it('R17: denies extra fields (email, phone, role, anything else)', async () => {
    const db = await authed(OTHER);
    for (const extra of [{ email: 'x@y.z' }, { phone: '079' }, { role: 'admin' }, { avatar: 'a.png' }]) {
      await assertFails(setDoc(doc(db, 'publicProfiles', OTHER), { displayName: NAMES[OTHER], ...extra }));
    }
  });
  it('R18: denies a displayName that differs from own users.fullName', async () => {
    const db = await authed(OTHER);
    await assertFails(setDoc(doc(db, 'publicProfiles', OTHER), { displayName: 'BitCar Support' }));
    await assertFails(updateDoc(doc(await authed(ALICE), 'publicProfiles', ALICE), { displayName: 'Admin' }));
  });
  it('denies an empty or missing displayName', async () => {
    const db = await authed(OTHER);
    await assertFails(setDoc(doc(db, 'publicProfiles', OTHER), { displayName: '   ' }));
    await assertFails(setDoc(doc(db, 'publicProfiles', OTHER), {}));
  });
  it('R19: denies listing public profiles (any query)', async () => {
    const db = await authed(ALICE);
    await assertFails(getDocs(collection(db, 'publicProfiles')));
    await assertFails(getDocs(query(collection(db, 'publicProfiles'), where('displayName', '==', NAMES[SELLER]))));
  });
  it('R20: denies a signed-out get', async () => {
    await assertFails(getDoc(doc(await unauthed(), 'publicProfiles', SELLER)));
  });
  it('denies deleting a public profile (even the owner)', async () => {
    await assertFails(deleteDoc(doc(await authed(ALICE), 'publicProfiles', ALICE)));
  });
});
