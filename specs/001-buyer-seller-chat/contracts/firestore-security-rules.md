# Contract: Firestore Security Rules

**Requirements**: FR-014a, FR-027, FR-027a, FR-032 to FR-034, SC-008 · **Research**: D9, D10, D13, D14

On the Spark plan there is no server code, so these rules are the **only** server-side enforcement for chat.
Every row below is covered by an automated test in `firestore_tests/` (see "Automated tests").

> **Prerequisite (approved by the owner 2026-10-31, subject to the permissions audit below)**: the current global rule
> `match /{document=**} { allow read, write: if true; }` must be removed. While it exists, every rule below is
> bypassed, because Firestore grants access if **any** matching rule allows it.

## Helpers

| Helper | Meaning |
|---|---|
| `signedIn()` | `request.auth != null` |
| `uid()` | `request.auth.uid` |
| `isParticipant(cid)` | `uid() in get(/conversations/$(cid)).data.participants` |
| `cidOf(a, b)` | `a < b ? a + '_' + b : b + '_' + a` |
| `onlyChanged(keys)` | `request.resource.data.diff(resource.data).affectedKeys().hasOnly(keys)` |
| `validText(t)` | `t is string && t.trim().size() >= 1 && t.size() <= 1000` |
| `placeholderName()` | the constant `'BitCar user'` |
| `expectedName(u)` | `exists(/publicProfiles/$(u)) ? get(/publicProfiles/$(u)).data.displayName : placeholderName()` |

## Chat paths

### `conversations/{cid}`

| Operation | Allowed when |
|---|---|
| `get` | `signedIn()` and (`uid()` in `resource.data.participants`, **or** the document does not exist and `cid` contains `uid()`) so the client can check existence before the first message |
| `list` | `signedIn()` and the query is constrained by `participants array-contains uid()` (rules check `uid() in resource.data.participants`) |
| `create` | `signedIn()`; `participants` is the sorted pair, has 2 distinct uids, contains `uid()`; `cid == cidOf(participants[0], participants[1])`; `buyerId == uid()`; `sellerId` is the other uid; `createdAt == request.time`; the first message `messages/{mid}` is created in the **same** transaction (`existsAfter`) |
| `update` (send) | participant; only `lastMessage`, `lastMessageAt`, `unreadCount` change; `lastMessageAt == request.time`; `unreadCount[other]` increases by exactly 1; own count unchanged; `lastMessage.senderId == uid()`; the referenced message exists after the write |
| `update` (mark read) | participant; only `unreadCount` and `lastReadAt` change; `unreadCount[uid()] == 0`; `lastReadAt[uid()] == request.time`; other participant's entries unchanged |
| `update` (delete message, research D19) | participant; `lastDeletedMessageId` changes and is a string `mid`, and besides it only `lastMessage` and `unreadCount` may change. `get(messages/mid)` shows it exists, `senderId == uid()` and `deleted == false`; `getAfter(messages/mid)` shows `deleted == true`. Own unread unchanged. `unreadCount[other]` must equal **exactly**: old − 1 if the message is newer than the other user's `lastReadAt` and `clearedAt` and old > 0, otherwise old. If `resource.lastMessage.id == mid`, `lastMessage` must equal `{id: mid, text: "", senderId: uid(), deleted: true}`; otherwise it must stay unchanged |
| `update` (delete conversation) | participant; only `clearedAt` and `unreadCount` change; `clearedAt[uid()] == request.time`; `unreadCount[uid()] == 0`; other participant's entries unchanged |
| `delete` | never (one-sided deletion is an update) |
| Immutable on every update | `participants`, `buyerId`, `sellerId`, `createdAt` |
| `participantNames` on create | keys are exactly the two participants, and for **each** participant `u`: `participantNames[u] == expectedName(u)`. So if `publicProfiles/u` exists the name must equal its `displayName`; if it does not exist, the **only** accepted value is `'BitCar user'` (decisions 5 + 6, research D14) |
| `update` (fill own name) | participant; only `participantNames` changes; the only affected key is `participantNames[uid()]`; its current value is `'BitCar user'`; the new value equals `get(/publicProfiles/$(uid())).data.displayName` (the profile must exist). Real names already stored are never changed (snapshot, decision 5), and nobody can touch the other participant's entry |

**Why names cannot be forged**: on create, every name is computed by the rules from data the creator cannot
control (the other user's `publicProfiles` doc, writable only by that user and only with their own `users.fullName`),
or is the fixed placeholder when that doc is absent. A client cannot invent a name, cannot use the placeholder for a
user who has a public profile, and can later replace only **its own** placeholder, only with **its own** profile name.

### `conversations/{cid}/messages/{mid}`

| Operation | Allowed when |
|---|---|
| `get`, `list` | `isParticipant(cid)` |
| `create` | `isParticipant(cid)` **or** the conversation is being created in the same transaction with `uid()` as participant (`getAfter`); `senderId == uid()`; `validText(text)`; `deleted == false`; `createdAt == request.time`; keys exactly `senderId, text, createdAt, deleted`; **rate limit** (below) |
| `update` (delete for everyone) | `resource.data.senderId == uid()`; `resource.data.deleted == false`; only `deleted` and `text` change; `deleted == true`; `text == ""`; `getAfter(conversations/cid).lastDeletedMessageId == mid`, so a message cannot be deleted without the conversation update in the same commit (research D19) |
| `delete` | never |

### `chatRateLimits/{uid}`

| Operation | Allowed when |
|---|---|
| `get` | owner (`uid() == uid`) |
| `create` | owner; `count == 1`; `windowStart == request.time` |
| `update` | owner; either **new window** (`resource.data.windowStart + duration.value(60, 's') <= request.time`, `count == 1`, `windowStart == request.time`) or **same window** (`windowStart` unchanged, `count == resource.data.count + 1`, `count <= 20`) |
| `delete` | never |

Message `create` additionally requires `getAfter(/chatRateLimits/$(uid())).data` to show a valid transition from
`get(...)` (or a create): this ties every message to exactly one counted send, so a client cannot skip the counter.

### `publicProfiles/{uid}`

| Operation | Allowed when |
|---|---|
| `get` | `signedIn()` (one specific user's doc) |
| `list` | **never**: nobody can enumerate the collection (rules use separate `get` / `list` permissions) |
| `create`, `update` | owner only (`uid() == uid`); keys exactly `['displayName']` (no `email`, `phone`, `role` or any other field); `displayName is string`, trimmed size 1–100; **`displayName == getAfter(/users/$(uid())).data.fullName`** (matches the user's own private profile; `getAfter` also works when the profile and the public name are written in the same batch) |
| `delete` | never |

`users/{uid}.fullName` itself is chosen by its owner at registration and in profile edit (audit E1/E3), so the public
name is always the name the user chose for themselves; names are not unique, and the uid stays the identity.

No `users/{uid}/fcmTokens` rule is added in this version (push deferred; see
[future-push-notifications.md](future-push-notifications.md)).

## Existing collections: permissions audit (approved with review, 2026-10-31)

Owner decision #1: replace the catch-all, after reviewing current permissions. Every Firestore access in `lib/` and
`functions/` was traced. No screen reads Firestore before sign-in (intro, login and register only use Auth;
register writes `users/{uid}` right after the account is created, so it is already signed in).

| # | Code path (verified) | Operation | Who does it today | Proposed rule | Breaks anything? |
|---|---|---|---|---|---|
| E1 | `AuthRemoteDatasource.register` | create `users/{uid}` (`fullName, email, phone, role, id`) | the new user | owner; `role in ['buyer','seller']`; `id == uid` | No |
| E2 | `HomeRemoteDataSource.getCurrentUser`, `UserRemoteDatasource.getCurrentUserProfile` | get own `users/{uid}` | owner | owner | No |
| E3 | `UserRemoteDatasource.updateUser` | update own `users/{uid}` (writes full map incl. same `role`) | owner | owner; `role` and `id` unchanged | No |
| E4 | — | read **other** users' docs | nobody today | denied (decision 6, option B); chat reads names from `publicProfiles` instead | No |
| E5 | `FavoriteRemoteDataSource` (get ids, add, remove, batch delete of missing) | `users/{uid}/favorites/*` | owner | owner | No |
| E6 | `functions/index.js onCarDeleted` | deletes favorites of all users | Admin SDK, **but cannot be deployed on Spark** | not affected by rules; the client-side cleanup in E5 (`getFavCarsByIds` batch delete, owner-only) keeps working | No |
| E7 | `CarsRemoteDataSource.getInitialCars/getMoreCars/loadMoreCars/getMyCars/getCar`, `SearchRepositoryImpl.search`, `FavoriteRemoteDataSource.getFavCarsByIds` | read/query `cars` | any signed-in user | `signedIn()` | No |
| E8 | `CarsRemoteDataSource.addCar` (FAB shown to sellers only) | create `cars/{id}` | seller | `signedIn()`; `sellerId == uid()` | No |
| E9 | `CarsRemoteDataSource.updateCarDetails` via `CarFormBloc` (edit shown when `isOwner \|\| isAdmin`) | update `cars/{id}` | owner or admin | owner or admin; `sellerId` unchanged | No |
| E10 | `CarsRemoteDataSource.deleteCar` via `MyCarsBloc`, `CarsBloc`, `SearchBloc` (admin delete) | delete `cars/{id}` | owner or admin | owner or admin | No |
| E11 | `CarsRemoteDataSource.updateCar` (`UpdateCar` use case) | update writing full map incl. `createdAt` | **unused**: registered in DI and injected into `CarsBloc`, never called | covered by E9; if it is used later, its `createdAt: serverTimestamp()` overwrite should be reviewed | No |
| E12 | `FeedsRemoteDataSource.getAds` | read `ads` | any signed-in user | `signedIn()` | No |
| E13 | `FeedsRemoteDataSource.addAd/deleteAd` (UI shown to admins only) | create/delete `ads` | admin | admin | No |

`isAdmin()` = `get(/databases/$(database)/documents/users/$(uid())).data.role == 'admin'`.

### Security issues found during the audit

| # | Issue | Today | With the proposed rules |
|---|---|---|---|
| S1 | **Anyone can make themselves admin**: `register` and `updateUser` write `role` from the client, and nothing on the server checks it | Any client can write `role: 'admin'` | Blocked by E1/E3. New admins must be set from the Firebase console or Admin SDK (no app flow does this today) |
| S2 | **Everything is public, even to signed-out clients**: all users' email/phone, all favorites, write access to every car and ad | Open | Closed by the table above |

> Every row E1–E13 and both issues S1/S2 have automated allowed/denied tests in `firestore_tests/existing.rules.test.js`;
> the manual app walkthrough in [quickstart.md](../quickstart.md) confirms the screens still work.

## Acceptance (maps to SC-008)

| # | Actor | Action | Expected |
|---|---|---|---|
| R1 | Non-participant (any role, incl. admin) | get / list conversation or messages | denied |
| R2 | Non-participant | create message in existing conversation | denied |
| R3 | Participant | create message with `senderId` of the other user | denied |
| R4 | Participant | edit `text` of own non-deleted message to new text | denied (no editing) |
| R5 | Participant | delete other user's message | denied |
| R6 | Participant | set other user's `unreadCount` to any value, lower it by one with no message deleted, or change their `lastReadAt` / `clearedAt` | denied. **Open until the rules of research D19 are deployed**: lowering it by one is currently allowed |
| R7 | Signed-in user | create conversation for two other users | denied |
| R8 | Participant | 21st message within 60 s | denied |
| R9 | Signed-out client | any chat path | denied |
| R10 | Two clients | create the same conversation concurrently | exactly one create succeeds; the other transaction retries as update |
| R11 | Participant | create a conversation with a name that differs from the other user's `publicProfiles.displayName` | denied (no name spoofing) |
| R12 | Participant | create a conversation using `'BitCar user'` for a user who **has** a public profile | denied |
| R13 | Participant | create a conversation with an invented name for a user who has **no** public profile | denied (only the placeholder is accepted) |
| R14 | Participant | change a real name already stored in `participantNames`, or set the other participant's entry | denied (snapshot; own entry only) |
| R15 | Participant | replace own placeholder with a name different from own `publicProfiles.displayName` | denied |
| R16 | Signed-in user | write another user's `publicProfiles` doc | denied |
| R17 | Owner | write own `publicProfiles` with `email`, `phone`, `role` or any extra field | denied |
| R18 | Owner | write own `publicProfiles.displayName` different from own `users.fullName` | denied |
| R19 | Signed-in user | list `publicProfiles` (any query) | denied |
| R20 | Signed-out client | get a `publicProfiles` doc | denied |
| R21 | Participant | name a real message in `lastDeletedMessageId`, with or without lowering unread, without deleting it | denied |
| R22 | Participant | name an already deleted message, delete it again, or lower unread with the same id already stored | denied (no replay) |
| R23 | Participant | name the other user's message, a missing message, a message of another conversation, a non-string or a path | denied |
| R24 | Participant | delete a message with no conversation update, naming a different message, or two messages in one commit | denied |
| R25 | Participant | delete a message the recipient has seen (`lastReadAt` or `clearedAt`) and lower unread | denied |
| R26 | Participant | delete a message the recipient has not seen and leave unread unchanged, or lower it by 2, raise it, make it negative, or change own unread | denied |
| R27 | Participant | delete the latest message and keep its preview text, or delete an older one and rewrite the preview | denied |
| R28 | Participant | change any other field in the delete write, or set `lastDeletedMessageId` in a send or mark-read write | denied |
| R29 | Non-participant (any role, incl. admin) | run the whole delete write | denied |

Allowed-path tests are required as well, so a too-strict rule fails just like a too-loose one: create conversation +
first message (with profile names; with the placeholder when the other user has no profile), send, mark read, delete
own message, delete conversation, replace own placeholder with own profile name, signed-in `get` of one public
profile, create/refresh own public profile matching `users.fullName`, profile name change + public name in one batch,
start a new rate window after 60 s. The pagination queries of research D17 must also be allowed for a participant:
the live window (`orderBy createdAt desc, __name__ desc, limit 20`) and an older batch (`startAfter` cursor,
`limit 20`), each with and without `where createdAt > clearedAt`. The same queries by a non-participant are denied
(covered by R1).

Pagination needs **no rule change**: `list` on messages already depends only on `isParticipant(cid)`, and `delete`
is never allowed, so a cursor always points to an existing position.

## Automated tests (decision 4)

| Item | Value |
|---|---|
| Location | `firestore_tests/` at repo root (own `package.json`, isolated from Flutter and `functions/`) |
| Dev dependencies | `@firebase/rules-unit-testing`, `firebase` (its required peer). Runner: built-in `node:test` |
| Files | `config.test.js` (rules file wiring, below), `chat.rules.test.js` (R1–R15 + chat allowed paths + participant-only access by every role), `chat_delete.rules.test.js` (R6 unread count, R21–R29, allowed deletes, stale writes and the retry of research D19), `public_profiles.rules.test.js` (R16–R20 + allowed paths), `existing.rules.test.js` (E1–E13, S1, S2), `helpers.js` (test env, seed data with rules disabled, auth contexts for A, S, O, admin M, unauthenticated) |
| Rules under test | **The project's real `firestore.rules`**: `helpers.js` reads `path.resolve(__dirname, '..', 'firestore.rules')` and passes its content to `initializeTestEnvironment({ projectId: 'demo-bitcar', firestore: { rules } })`. No copy of the rules exists in `firestore_tests/` |
| Wiring check (`config.test.js`) | parses `firebase.json` and asserts `firestore.rules === "firestore.rules"` and `firestore.indexes === "firestore.indexes.json"`, that both files exist, and that the path loaded by `helpers.js` is the same file. Fails if anyone repoints or copies the rules |
| Project | `demo-bitcar` (Emulator-only demo project: no network calls, cannot touch `carshop-b79bc`) |
| Command | `firebase emulators:exec --only firestore --project demo-bitcar "npm --prefix firestore_tests test"` |
| Time-based cases | rate-limit window tests seed `windowStart` in the past via `withSecurityRulesDisabled` instead of waiting 60 s |
| Rules access budget | a transaction may perform at most 20 `get`/`exists`/`getAfter` document accesses; the conversation-create path uses about 5 distinct docs (2 public profiles, the conversation, the message, the rate-limit doc). A test asserts the full first-send transaction succeeds |
