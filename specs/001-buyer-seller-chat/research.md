# Phase 0 Research: Buyer–Seller Chat

**Feature**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md) · **Date**: 2026-11-01 (rev. 4: message pagination;
rev. 3: Spark plan + public profiles review)

All findings below were checked against the current code in this repository, not assumed.

## Revision 2 summary (owner decisions 3–6, 2026-10-31)

| Decision | Effect on the design |
|---|---|
| 3. Stay on Firebase **Spark**; no Cloud Functions; push deferred | Everything runs client ↔ Firestore. Removed: `onChatMessageCreated`, FCM token registry, notification permission flow, logout token cleanup, `NotificationRemoteDataSource`. All server-side guarantees move into Security Rules (they already were, except names; see D14) |
| 4. Automated rules tests with `@firebase/rules-unit-testing` + Emulator | New isolated Node test package `firestore_tests/` at repo root (D13); nothing added to Flutter |
| 5. Names snapshotted at creation; uid is the identity | `participantNames` written once when the conversation is created; never synced |
| 6. Option B: `users` docs stay private | Without a function, the creator cannot learn the seller's name from `users`. Solved with `publicProfiles/{uid}` (`displayName` only), approved in rev. 3 with the placeholder rule (D14) |
| Rev. 3 (owner review) | `displayName` must match `users.fullName`; sync on app open and on name change; placeholder `"BitCar user"` allowed only when no public profile exists; tests load the real `firestore.rules`; JDK 21 alongside 17 |
| Rev. 5 (2026-11-02, analyze C1/G1) | Default counter test replaced by a Firebase-free `AppErrorListener` test; full `flutter test` gate. Sign-out wipes the Firestore cache (option A) behind a `SessionGate`, with a pending-writes warning (D18) |
| Rev. 4 (2026-11-01, owner addition + option A) | Message history in batches of 20: a bounded live `limit(20)` window for the newest messages and one-time cursor reads (`startAfter`) for older batches; plain-Dart `MessageCursor`; merge by message id; "New messages" chip; opening marks all read (D17). Replaces "re-subscribe with `limit + 30`" |

## Codebase findings (verified)

| Finding | Evidence | Impact on plan |
|---|---|---|
| `firebase_messaging` is declared in `pubspec.yaml` but never imported in `lib/` | `pubspec.yaml` | Stays unused in this version; not removed (removing packages is outside this feature). It is the package a future push phase would use |
| A Cloud Functions codebase exists (`functions/index.js`, trigger `onCarDeleted`) | `functions/`, `firebase.json` | **On Spark, functions cannot be deployed**, so `onCarDeleted` is presumably not running. The app already compensates: `FavoriteRemoteDataSource.getFavCarsByIds` deletes favorites of missing cars. Chat adds nothing to `functions/` |
| `firebase.json` has a `functions` section with a `predeploy` lint | `firebase.json` | A bare `firebase deploy` would try to deploy functions and fail on Spark. Always deploy with `--only firestore:rules,firestore:indexes` |
| `firestore.rules` allows all reads and writes to everyone | `firestore.rules` | Replaced (decision #1, audit E1–E13 in the rules contract) |
| `firebase.json` points to root `firestore.indexes.json` (empty); existing `cars` indexes live in `project-root/firestore.indexes.json` | both files | Chat index goes in the root file; the mismatch is flagged, not fixed |
| No `emulators` block in `firebase.json` | `firebase.json` | Add a Firestore emulator entry for the rules tests (D13) |
| Only Android has a Firebase config file | `android/app/google-services.json`, no iOS plist | Chat itself is platform-neutral Firestore; nothing platform-specific is needed now |
| Local tooling: Firebase CLI 15.3.0, Node 20.20, OpenJDK 17 | `firebase --version`, `node --version`, `java -version` | Recent Firebase CLI versions require **JDK 21+** for the emulators; the owner will install JDK 21 alongside JDK 17 (D13) |
| `ProfileBloc._onUpdated` builds a new `UserEntity` with the edited `fullName` and calls `UpdateUserProfile` | `profile_bloc.dart` | Hook point for syncing the public name after a name change (D14) |
| The only stream-consuming bloc is `SplashBloc` (`StreamSubscription` → internal event → `close()` cancels) | `splash_bloc.dart` | Chat blocs follow the same pattern (D5) |
| Blocs are provided in `HomeLayout` or per screen; pushed screens get parent blocs via `BlocProvider.value` | `home_layout.dart` | `ConversationsBloc` in `HomeLayout`, `ChatBloc` per screen (D6) |
| `GetCurrentUser` (home) returns `UserEntity` (id, fullName, role), already reused across features | DI container | Reused for the own-car check and to publish the user's public name |
| Shared widgets: `EmptyState`, `AppButton`, `confirmDelete` (hard-coded car texts), `AppErrorListener` | `shared/components/general_widget/` | Reused; `confirmDelete` gets optional title/message |
| `test/widget_test.dart` is the default counter template (pumps `MyApp`, expects a counter) | file content | Always fails; replaced by `test/core/errors/app_error_listener_test.dart` (rev. 5) so the full `flutter test` gate can pass |
| No `bloc_test`, `mocktail`, `bloc_concurrency`, `fake_cloud_firestore` | `pubspec.yaml` | Dart tests use `flutter_test` + hand-written fakes |

## Decisions

### D1. Conversation identity: deterministic document id

- **Decision**: `conversations/{cid}`, `cid = "<smallerUid>_<largerUid>"`.
- **Rationale**: One conversation per pair (FR-001, SC-002) guaranteed by the database: concurrent creators target the
  same document and only one create can succeed. Opening from a car is a single `get` by id.
- **Alternatives**: Auto-id + query (race creates duplicates); lookup collection (extra write, same race).

### D2. Lazy creation inside the first-send transaction

- **Decision**: Opening "Chat with Seller" writes nothing; the conversation is created in the transaction that writes
  the first message (FR-002: no empty conversations).

### D3. Messages as a subcollection; per-user state as maps on the conversation

- **Decision**: `conversations/{cid}/messages/{mid}`; per-participant maps on the conversation: `unreadCount`,
  `lastReadAt`, `clearedAt`.
- **Rationale**: Read receipts from `lastReadAt[recipient]` (one write per read session); unread badges and the red dot
  come from the single conversations stream; one-sided deletion is `clearedAt[uid]`.
- **Alternatives**: Per-message read flags (N writes); per-user fan-out collections (duplicate writes, needs a server to
  stay consistent, which Spark does not give us).

### D4. Sending: client-generated id + transaction (idempotent retry)

- **Decision**: The bloc creates the message id locally; `SendMessage` runs a transaction that reads the conversation,
  the message doc and the sender's rate-limit doc; creates the conversation if missing; returns success if the message
  already exists; otherwise writes the message, `lastMessage`, `lastMessageAt`, `unreadCount[recipient] + 1`, and the
  rate-limit doc.
- **Rationale**: Retry with the same id never duplicates (FR-014). Transactions need a connection, matching FR-014b.
- **Concurrent sends (found in B7 device testing, 2026-11-04)**: same-window rate-limit updates use
  `FieldValue.increment(1)`. An absolute `count + 1` from a stale read is refused by the rules with
  `permission-denied`, which the client does not retry (reproduced on the emulator: 1 of 5 concurrent sends
  succeeded; with `increment`, 5 of 5). The bloc also sends one message at a time per screen, which keeps the send
  order and avoids competing transactions. Trade-off: on a very slow connection queued messages wait their turn
  and stay `sending` longer.
- **States**: `sending`/`failed` are local bloc state; `sent` = present in the server-confirmed stream; `read` = derived
  from `lastReadAt`.

### D5. Streams in BLoC: `StreamSubscription` + internal events (SplashBloc pattern)

- **Decision**: Datasources expose `snapshots(includeMetadataChanges: true)` streams mapped to models, errors mapped with
  `ErrorMapper.map`. Blocs subscribe on a public event (cancelling any previous subscription), forward data and errors
  as private events, and cancel in `close()`. Messages: a bounded live window of 20 plus one-time cursor reads for older batches (D17).
- **Rationale**: Same as the only existing stream pattern; no new package (`emit.forEach` with clean restarts needs
  `bloc_concurrency`).
- **Domain purity**: Snapshot metadata becomes a plain `bool isFromCache`; no Firestore type crosses the repository.

### D6. Bloc placement

- `ConversationsBloc`: factory, provided once in `HomeLayout` (like `FavoriteBloc`); one listener feeds the app-bar red
  dot and the conversations screen. On sign-out its listener is cancelled first by `SessionGate.closeForSignOut()`,
  before `terminate()` and `signOut()` (D18); the bloc itself is closed later, when the auth stream disposes
  `HomeLayout`.
- `ChatBloc`: factory, created per `ChatScreen`, closed when the screen pops.

### D7. Notifications: deferred, with explicit extension points (decision 3)

- **This version**: no push, no Cloud Functions, no FCM code, no permission prompt. New messages are still delivered
  live while the app is open (FR-012, FR-017, FR-019 to FR-021).
- **Why the current design does not need rework later**: everything a future push phase needs already exists or is
  additive. Details in [contracts/future-push-notifications.md](contracts/future-push-notifications.md):
  - The message create event (`conversations/{cid}/messages/{mid}`) is the natural trigger for a future function.
  - The conversation already stores what a notification needs: recipient (`participants`), sender name
    (`participantNames`), unread count for "N new messages" (`unreadCount`), and the conversation id for tap routing.
  - Device tokens would be a new subcollection `users/{uid}/fcmTokens` with its own owner-only rule: no change to chat
    documents.
  - Client: a future `NotificationRemoteDataSource` plugs into the existing `ChatRepository` (new methods only);
    `ConversationsBloc` gains a tap stream; `ChatScreen` is already openable by conversation id (`GetChatTarget`).
- **Not added now** (decision 3 item 7): no `fcmTokens` rule, no channel config, no manifest permission, no placeholder
  classes.

### D8. Logout integration

- **Decision**: **No change to `HomeBloc` or the logout flow** in this version (the previous token-cleanup step is
  removed with push). Logout already disposes `HomeLayout`, which closes `ConversationsBloc` and cancels its stream.

### D9. Security rules (approved 2026-10-31, after permissions review)

- Replace the global allow-all rule with explicit rules for all collections; audit rows E1–E13 and issues S1 (self
  promotion to admin) and S2 (public data) in [contracts/firestore-security-rules.md](contracts/firestore-security-rules.md).
- On Spark, rules are the **only** server-side enforcement: participant-only access, sender identity, immutability,
  delete semantics, rate limit and name integrity are all enforced there.

### D10. Rate limit (20 messages / minute / user) enforced by rules

- **Decision**: `chatRateLimits/{uid}` = `{ windowStart, count }` updated in the send transaction; a message create is
  only allowed together with a valid counter transition (`getAfter()`). The client pre-checks to show the error
  instantly; the rule is authoritative (FR-014a). Works on Spark (no function).
- **No device clock in the transition (rev. 5, analysis U3)**: the client never decides from its own clock whether
  the 60 s window is over. `count < 20` → same window (`count + 1`), which the rules accept at any time;
  `count == 20` → new window (`count: 1`, `windowStart: serverTimestamp`), which the rules accept only if
  `request.time >= windowStart + 60 s`. A `permission-denied` on that new-window attempt is mapped to the
  "You're sending messages too fast, try again shortly" error and the message stays `failed` for retry. Clock skew
  therefore cannot cause a wrong or generic error.
- **Known property of fixed windows**: up to about 40 messages can pass around the boundary of two consecutive windows
  (20 at the end of one, 20 at the start of the next). Accepted; a sliding window would need a much heavier rule.

### D11. Platforms

- Chat uses only Firestore and Auth, so it is platform-neutral. Android is the only configured platform today. The
  earlier "Android-only push, iOS-ready" design is moved into the future push document.

### D12. Offline read (FR-014b)

- Firestore's default on-device persistence; `isFromCache` drives an "Offline" banner. Send fails offline (transaction);
  delete, clear and mark-read are disabled while offline.
- After sign-out, all chat queries are scoped to the signed-in uid, so a previous user's cached chats are never queried.
  `clearPersistence()` is not used (it would require terminating the shared Firestore singleton).

### D13. Testing approach (decision 4)

- **Dart**: `flutter_test` unit tests with hand-written fakes for both blocs, models and the validator (no new pub
  packages).
- **Security rules**: automated tests with `@firebase/rules-unit-testing` against the Firestore emulator.
  - **Location**: new top-level folder `firestore_tests/` with its own `package.json`, next to the files it tests
    (`firestore.rules`, `firebase.json`). Not in `functions/` (that codebase is for deployable functions, which Spark
    cannot deploy, and its predeploy lint should stay unrelated). Not in `test/` (Flutter's Dart test directory).
  - **Dependencies (dev only, npm, isolated in that folder)**: `@firebase/rules-unit-testing` and its required peer
    `firebase`. Test runner: Node's built-in `node:test` + `node:assert` (no Jest/Mocha). Exact versions pinned at
    implementation to a mutually compatible pair.
  - **Run**: `firebase emulators:exec --only firestore --project demo-bitcar "npm --prefix firestore_tests test"`. A
    `demo-*` project id keeps tests fully offline, never touching the real project.
  - **Config**: add an `emulators.firestore` block (port 8080) to `firebase.json`; `firestore_tests/.gitignore` ignores
    `node_modules/`.
  - **Coverage**: every allowed/denied case R1–R20 (chat + `publicProfiles`) and E1–E13 + S1/S2 (existing
    collections), see the rules contract.
  - **Real rules file**: the suite loads the project's own `firestore.rules` (resolved from the repo root, never copied),
    and `config.test.js` asserts that `firebase.json` points to that same file (`"rules": "firestore.rules"`, verified
    in the current `firebase.json`).
  - **JDK (owner decision 2026-10-31)**: JDK 21 is installed **next to** JDK 17. Only the emulator command uses it, by
    setting `JAVA_HOME` and `PATH` for that terminal session (see quickstart). Flutter and Gradle keep their current JDK
    configuration; nothing global is changed.
  - **Pinned versions (B1, 2026-11-02)**: `@firebase/rules-unit-testing` 5.0.2 + `firebase` 12.19.0 (peer `^12`,
    Node ≥ 20). 6.0.0 was not used because it requires Node ≥ 24.12 (local Node is 20.20).
  - **Known `npm audit` findings, accepted for the local test environment (owner decision 2026-11-02, option A)**:

    | Advisory | CVSS | Affected / patched | Scope |
    |---|---|---|---|
    | GHSA-m9gg-hp2v-232j (CVE-2026-101916) | 7.4 | `@grpc/grpc-js` < 1.13.6 and 1.14.0–1.14.4 / fixed in 1.13.6, 1.14.5 | **gRPC servers** only: `getAuthContext` when server credentials use `requireClientCertificate: false` |
    | GHSA-f596-whhp-79r4 (CVE-2026-101915) | 3.7 | same ranges / same fixes | **gRPC servers** only: a crashing method handler's error message is sent to the client |

    - Installed: one copy, `@grpc/grpc-js@1.9.16`, pulled in by `firebase@12.19.0` → `@firebase/firestore@4.17.2`
      (`"~1.9.0"`), also via `@firebase/firestore-compat`. `npm audit` reports "5 high" because it counts the same two
      advisories on every dependent (`@grpc/grpc-js`, `@firebase/firestore`, `@firebase/firestore-compat`, `firebase`,
      `@firebase/rules-unit-testing`).
    - Why it does not apply: these are **development dependencies** in `firestore_tests/` only, never part of the
      Flutter app or any deployment. The Firestore SDK uses `@grpc/grpc-js` as a **client** to reach the local Firestore
      emulator (`127.0.0.1:8080`, project `demo-bitcar`); nothing in this project runs a gRPC server with it.
    - Why it is not fixed now: the patched versions (≥ 1.13.6) are **outside the range the Firestore SDK declares**
      (`~1.9.0`, still the same in the latest `@firebase/firestore` 4.19.0 / `firebase` 13.1.0), and 1.9.16 is the last
      1.9.x release. `npm audit fix --force` would downgrade to `firebase` 9.14.0 and is not used; `npm overrides` are
      not used either (an untested SDK/grpc combination for no security gain here). `package.json` and
      `package-lock.json` are unchanged.
    - **Re-evaluate** whenever the Firebase JS SDK (`firebase`, `@firebase/rules-unit-testing`) or Node is updated:
      run `npm ls @grpc/grpc-js` and `npm audit` inside `firestore_tests/`, and check whether the SDK's declared range
      now includes a patched `@grpc/grpc-js`.

### D14. Participant names via `publicProfiles` (approved 2026-10-31, rev. 3)

- **Problem**: Option B keeps `users/{uid}` private (email, phone). Without a function, the conversation creator needs
  another way to learn the seller's name, and decision 5 requires both names to be snapshotted **at creation**.
- **Decision**: `publicProfiles/{uid}` = `{ displayName }` only.
  - **Read**: a signed-in user may `get` one specific doc; `list` is denied, so the collection cannot be enumerated.
  - **Write**: owner only; exactly one field `displayName` (no email, phone, role or anything else); 1–100 chars;
    rules require `displayName == getAfter(/users/{uid}).fullName`, so the public name always matches the user's own
    private profile.
  - **Sync points** (use case `SyncPublicProfile`):
    1. App opened after sign-in: `ConversationsBloc` on `ConversationsStarted` (from `HomeLayout`), using the name from
       `GetCurrentUser`. Creates the doc for users who registered before this feature. Runs in parallel with the
       list subscription and never delays it; connection errors are not shown and the next app open repeats it; a
       read from the cache writes nothing, so no write is queued offline (owner decision before B8, FR-014b).
       If `GetCurrentUser` fails the name is unknown, so this sync does not start, even if the list subscribed with
       the uid from the auth session. It runs after the next successful `GetCurrentUser`: on `ConversationsRetried`
       (the Retry button of the list error state) or on the next app open. Until then the user's public name stays
       as it was (missing, or the previous value), and sending still works with the placeholder rule below.
    2. Name changed: `ProfileBloc._onUpdated`, after `UpdateUserProfile` succeeds and the name differs. If the sync
       fails, the profile save still counts as successful, the error is shown through `AppErrorCubit`, and sync 1 repairs
       it on the next app start.
- **Placeholder rule (owner's proposal, adopted)**: when creating a conversation, for each participant:
  - if `publicProfiles/{uid}` **exists**, the stored name **must equal** its `displayName`;
  - if it **does not exist**, the **only** accepted value is the fixed placeholder `"BitCar user"`.
  - Later, a participant may replace **only their own** placeholder, **only with their own** profile name. `GetChatTarget`
    itself does not write: when it reports a placeholder from server data, `ChatBloc` runs `FillOwnPlaceholderName`
    without waiting, so opening is never delayed or blocked, and the stored or placeholder name is shown meanwhile
    (owner decision before B8). Real names already stored never change (snapshot).
  - Result: a client can never write an invented name, cannot use the placeholder for someone who has a profile, and
    cannot touch the other participant's entry. Rules contract cases R11–R15.
- **Why the sender's own name is also checked**: the creator's own entry follows the same rule, so it cannot be faked
  either; normally it is a real name because sync 1 runs before any chat can be opened.
- **Rules cost**: `exists` + `get` on the same doc count once; the create path stays far below the 20-document limit
  for transactions.
- **Alternatives**: Option A (expose all `users` docs, rejected by decision 6); names only added by each participant
  later (seller unknown until they reply); seller name stored in `cars` (touches the car feature).

### D15. Inquiry text and validation

- Fixed English template `"Hello, I'm interested in your <brand> <model> (<year>). Is it still available?"` only when
  the chat opens from a car (FR-007 to FR-009). Text 1–1,000 chars after trim, checked by `ChatValidator` and rules.

### D16. Firebase Spark plan compliance

| Capability used | Spark? |
|---|---|
| Firebase Auth (existing) | Yes |
| Cloud Firestore reads/writes, transactions, realtime listeners, offline persistence | Yes (within free daily quotas) |
| Firestore Security Rules and composite indexes (deploy with `--only firestore:rules,firestore:indexes`) | Yes |
| Firebase Emulator Suite (local) | Yes (no billing involved) |
| Cloud Functions, Cloud Messaging sending from a server | **Not used** |

- **Quota awareness**: the chat costs one listener for the conversations list (in `HomeLayout`), one bounded listener
  (20 messages) plus the conversation doc for the open chat, one-time reads of up to 20 per older batch, and one
  transaction (~4 reads, ~4 writes) per message. Messages load 20 at a time (D17).

### D17. Message pagination: bounded live window + cursor-based older batches (rev. 4, option A, FR-037 to FR-046)

Owner decision 2026-11-01 (option A): the newest messages use a **bounded** Firestore stream (`limit(20)`); older
messages use cursor-based one-time reads. No listener ever runs over the conversation history without a limit.

- **Query order**: every messages query orders by `createdAt` **and** `FieldPath.documentId` in the same direction,
  plus `where('createdAt', '>', clearedAt)` when the user cleared the conversation (FR-027a). The document id breaks
  ties between equal server timestamps, so the order is stable and a cursor never skips or repeats a message
  (FR-039, FR-040). The automatic single-field `createdAt` index covers this; no composite index.
- **Live window (FR-037, FR-044)** — `watchLatestMessages`: one listener on
  `orderBy(createdAt desc, __name__ desc).limit(20)`, `snapshots(includeMetadataChanges: true)`. It delivers new
  messages, deletions and changes for the newest 20 in real time.
  - **Messages leaving the window**: when new messages arrive, the oldest messages drop out of the `limit(20)`
    result. The bloc **keeps** them on screen (they move from the live source to the loaded-once source) instead of
    removing them; a message disappears from the screen only if it is no longer in any source, which never happens
    because messages are never hard-deleted.
  - **Conversation state in the same update**: the datasource also listens to the conversation document and adds the
    other user's `lastReadAt`, the user's own `unreadCount` and own `clearedAt` to each update (merged with a plain
    `StreamController`; no `rxdart`). Both listeners are cancelled together.
  - **Listener order (rev. 5, analysis U1)**: the conversation listener starts first; the messages listener starts
    after its first snapshot with the current `clearedAt[uid]`, and is cancelled and restarted when that value
    changes. Older batches receive the same `clearedAt` from the bloc as `after`, so the datasource stays stateless.
  - **Pending server timestamps (rev. 5, analysis U2)**: `snapshots()` in cloud_firestore 6.1.0 has no
    `serverTimestampBehavior` (only `get()` via `GetOptions`), so a pending `serverTimestamp()` arrives as `null`.
    Sends are transactions and never appear locally before commit, so this only affects the user's own
    `lastReadAt` / `clearedAt` written with plain `update`: a present key with `null` is read as `DateTime.now()`.
    A message with `null` `createdAt` (not expected) stays `sending` and is never a cursor.
  - **Local unsent messages (rev. 5, CHK005)**: `pendingMessages` are never part of a Firestore query, so they do
    not count toward `limit(20)` and are never the cursor (the cursor is the oldest **server-confirmed** message).
    When the sent message's id arrives in the live window, the pending copy is dropped (same id, FR-037, FR-039).
    Deleted messages are normal documents (`deleted: true`), so they count toward the 20 (CHK004).
  - **Live window failure and retry (rev. 5, CHK022, FR-054)**: Firestore listeners recover from short network drops
    by themselves (cached data, `isFromCache` → offline banner, no error). An error on the stream is terminal for
    that listener, so `_MessagesFailed` clears the subscription and keeps every loaded message (`liveMessages` move to
    `loadedMessages`, so nothing disappears). Classification by `AppException.type`:
    **retryable** = `network`, `firestore`, `unknown`, `platform`, `server`, `cache`; **not retryable** =
    `permission`, `notFound`, `auth`, `validation`. A retryable failure triggers **one** automatic retry after 3 s,
    then shows Retry; a non-retryable one shows the error without Retry. `ChatRetried` is ignored unless the status
    is `failedRetryable` and no subscription exists; it cancels any leftover subscription before subscribing again,
    so at most one live-window listener exists. The new window's messages are merged by id (live > loaded >
    pending), so nothing is duplicated; the cursor is unchanged. A stream closed because the session ended (D18) is
    *done*, not an error, and shows nothing.
  - **Records, not domain types (rev. 5, analysis I1)**: the datasource returns models in Dart records; the
    repository impl builds `MessagesUpdate` / `MessagesPage` / `ChatTarget` / `ConversationsUpdate`.
- **Older batches (FR-038)** — `loadOlderMessages(before: cursor)`: a one-time `get()` on
  `orderBy(createdAt desc, __name__ desc).startAfter([Timestamp, messageId]).limit(20)`.
  - **Cursor**: plain-Dart `MessageCursor { DateTime createdAt; String messageId }`, the **oldest server-confirmed
    message loaded overall** (live window or earlier batches), not the oldest message in the live window. This
    leaves no gap and no overlap between the window and the first older batch (CHK021).
  - **`startAfter([values])` instead of `startAfterDocument`**: same result, but `startAfterDocument` needs a
    `DocumentSnapshot`, which would have to travel through the repository and bloc. The constitution forbids
    extending that exception to new code, so the cursor stays plain Dart and only the datasource builds the
    `Timestamp` (CHK020).
- **End of history (FR-038, FR-043c)**: a batch from the server with fewer than 20 messages sets `hasOlder = false`.
  For an exact multiple of 20, one extra request returns 0 and ends it without an error. The first state comes from
  the live window: fewer than 20 there means no older messages.
- **Offline (FR-043, FR-014b)**: `get()` falls back to the device cache. A batch that comes **only from the cache** with
  fewer than 20 does not end the history: `hasOlder` stays true, the bloc sets `olderBatchIncomplete`, and the
  offline banner shows. When the live window reports server data again (`isFromCache == false`), the bloc requests
  that same batch again (through the normal guard), so loading resumes after reconnecting.
- **Merge without duplicates (FR-039, FR-040)**: `ChatState` keeps three id-keyed maps: `liveMessages` (current
  `limit(20)` result), `loadedMessages` (older batches + messages that left the window) and `pendingMessages`
  (local sending/failed). Displayed list = union by id, priority live > loaded > pending (a pending message is dropped
  once its id arrives), sorted by `(createdAt, id)`.
- **Read state live for all loaded messages (FR-015, FR-044)**: `MessageModel` delivers own messages as `sent`; the
  state getter turns an own message into `read` when `createdAt <= otherLastReadAt`, using the latest value from the
  live window update. Messages in older batches therefore still turn "read" live.
- **Deletions outside the window (FR-044)**: an older message deleted by its sender keeps its old text on the other
  participant's open screen and shows the placeholder the next time the conversation is opened. This is the accepted
  trade-off of option A.
- **Mark read (FR-015, F5)**: when the window update shows own `unreadCount > 0` and the screen is visible, the bloc
  calls `MarkConversationRead` (own unread → 0, `lastReadAt` → server time). That marks **all** messages read,
  including ones not loaded yet.
- **One request at a time (FR-042)**: `ChatLoadOlderRequested` returns immediately when `isLoadingOlder`, `!hasOlder`
  or no cursor; otherwise it emits `isLoadingOlder: true` before the first `await`, so a second event arriving at once
  sees the flag. No `bloc_concurrency`.
- **Errors (FR-043b)**: a failed batch keeps every loaded message, sets `olderLoadFailed: true`,
  `isLoadingOlder: false`, and calls `appErrorCubit.showError`; retry sends `ChatLoadOlderRequested` again with the same
  cursor (the cursor only moves after a successful batch).
- **Scroll behavior (FR-041, FR-045, FR-046)**: the list is a `CustomScrollView` with a `center` key and two
  `SliverList`s. The center is the oldest message of the first window. Older batches go into the sliver **above**
  the center and new messages into the sliver **below** it. Adding items to either side never moves the content on
  screen, which covers both "older messages added" and "new message while scrolled up". When the user is within
  about 100 px of the bottom, new messages scroll into view automatically; otherwise a "New messages" chip appears
  and tapping it scrolls to the bottom. Sending or retrying scrolls to the bottom. Flutter only, no package.
- **Cost (Spark)**: opening a chat reads 20 messages + the conversation doc; each older batch reads up to 20 once;
  the live window re-reads only changed documents.
- **Alternatives considered**:
  - **Anchored head listener without a limit + a live listener per older page** (previous rev. 4 draft): kept
    deletions live everywhere, but the head had no limit and every page stayed a listener. Rejected by the owner
    (option B).
  - **Re-subscribe with a growing `limit`**: re-reads every loaded message on each step. Rejected.
  - **Offset-based pages**: Firestore has no efficient offset, and offsets shift as messages arrive. Rejected.
  - **`startAfterDocument`**: rejected only because of the domain-purity rule above; functionally equivalent.

### D18. Sign-out cleanup of the Firestore cache (rev. 5, option A, FR-014b, FR-052)

Owner decision 2026-11-02: keep Firestore persistence (offline reading after restart stays, existing features
unchanged) and wipe it on sign-out with `terminate()` + `clearPersistence()`; warn before losing unsynced writes.

**Verified facts (cloud_firestore 6.1.0, `pubspec.lock`; plugin source in the local pub cache)**

| Fact | Evidence | Consequence |
|---|---|---|
| Persistence is on today (Android default, 100 MB); no `Settings` are set anywhere | `injection_container.dart`, `main.dart`; `FlutterFirebaseFirestorePlugin.getSettingsFromPigeon` | Previous user's documents stay on disk after `signOut()` |
| `terminate()` terminates the native instance **and removes it from the plugin cache**; the next call builds a new native instance with the same settings | `FlutterFirebaseFirestorePlugin.java` `terminate` (L435–449), `getFirestoreFromPigeon` (L318–336) | The Dart `FirebaseFirestore.instance` held by GetIt stays usable after cleanup; no DI re-registration. **To be confirmed on a device (task)** because the generic API doc says other methods throw after `terminate` |
| `clearPersistence()` only works on an instance that has not started | `firestore.dart` doc (L95–107) | **No** Firestore call may happen between `terminate()` and `clearPersistence()`; otherwise it fails with `failed-precondition` |
| `clearPersistence()` deletes files but does not securely overwrite them | same doc | FR-014b ("not shown") is met; forensic erasure is out of scope and documented |
| `terminate()` does not cancel pending writes; `clearPersistence()` drops them | `firestore.dart` doc (L293–309) | Pending writes must be detected **before** cleanup |
| `waitForPendingWrites()` resolves when all current writes are acknowledged, and **immediately when there are none**, online or offline | `firestore.dart` doc (L311–314) | Reliable pending-write detection that does not depend on connectivity |
| Chat sends use transactions, which never queue offline | D4 | Chat messages are never "pending writes"; queued writes come from existing features (`set`/`update`/`add` in favorites, profile, cars, ads) and chat `update`s (mark read, clear) |
| Sign-out today: `HomeRemoteDataSource.logOut()` = `auth.signOut()` only; `SplashBloc` (auth stream) switches `AppRoot` to `LoginScreen`, which disposes `HomeLayout` and all its blocs | `home_remote_datasource.dart`, `splash_bloc.dart`, `app_root.dart` | Bloc disposal happens **after** sign-out, too late to stop listeners before cleanup |
| User data kept outside Firestore: `CacheHelper` holds only `intro_seen`; `FavoriteRepositoryImpl._cachedIds` is reset by `FavoriteBloc._onStarted` (`refresh()`) before any display | `cache_keys.dart`, `favorite_repository_impl.dart`, `favorite_bloc.dart` | No extra clearing needed for `CacheHelper`; favorites cache already safe |
| Firestore is used directly by 7 data classes: auth, cars, favorite, feeds, home, profile datasources and `SearchRepositoryImpl` | `grep FirebaseFirestore lib/` | All of them must respect the session gate below |

**Design**

1. **`SessionGate`** (`lib/core/session/session_gate.dart`, plain Dart, no Firebase): states `open`, `closing`,
   `wipePending`.
   - `Future<T> run<T>(Future<T> Function() op)`: every Firestore future in every data class goes through it. When the
     gate is not `open` it throws `AppException(type: ErrorType.auth, message: 'Signing out, please wait')` (or, in
     `wipePending`, first tries `retryWipe` once and continues only if it succeeds). It counts in-flight operations.
   - `Stream<T> watch<T>(Stream<T> Function() open)`: every Firestore stream goes through it; the gate keeps the
     subscriptions so it can cancel them.
   - `Future<void> closeForSignOut()`: state → `closing` (new operations rejected), cancels every registered stream
     (the bloc subscriptions receive *done*, not an error), then waits for in-flight operations (max 5 s; after that
     they are abandoned and fail harmlessly once the instance is terminated).
   - `Future<void> Function()? retryWipe`: set at DI time to the home datasource's wipe method.
   - `open()` after a successful wipe.
2. **Pending-write check before sign-out** (`HasPendingWrites` use case → `HomeRemoteDataSource.hasPendingWrites()`):
   `waitForPendingWrites().timeout(3 s)`; completes → no unsynced writes; times out → unsynced writes exist. A slow
   network can produce a false "unsynced" warning, never a missed one (safe side).
3. **Sign-out sequence** (`HomeRemoteDataSource.logOut()`, after the user confirmed if needed):
   1. `sessionGate.closeForSignOut()` (streams cancelled, no new operations, in-flight drained)
   2. `CacheHelper` marker `firestore_wipe_pending = true`
   3. `firestore.terminate()`
   4. `firestore.clearPersistence()`
   5. marker removed
   6. `auth.signOut()` (last, so listeners never see a signed-out state → no `permission-denied`)
   7. `sessionGate.open()`
   - If step 3 or 4 fails: the marker stays, the gate goes to `wipePending`, and `auth.signOut()` still runs (the
     session ends). While `wipePending`, every Firestore operation first retries the wipe through `retryWipe` and is
     refused with `AppException(type: ErrorType.cache, message: 'Previous session data could not be cleared. Please
     try again.')` if it fails again. Sign-in calls `AuthRemoteDatasource`, which goes through the gate too, so a new
     user cannot reach Firestore before the wipe succeeds.
4. **Startup completion** (`CompletePendingSignOut` use case, called in `main.dart` after `init()` and **before
   `runApp`**, so before any Firestore access): if the marker is set → `terminate()` (harmless on an unstarted
   instance) → `clearPersistence()` → remove marker → `auth.signOut()` (completes a sign-out that was interrupted,
   e.g. app killed) → gate `open`; on failure the marker stays, the gate starts in `wipePending` **and
   `auth.signOut()` still runs**, so the interrupted sign-out is always completed (same rule as step 3).
5. **No `permission-denied` after sign-out**: listeners are cancelled in step 3.1, before `signOut()`. As a second
   line, every chat stream goes through `ChatRemoteDataSource._watchGuarded` (which wraps `sessionGate.watch`), and
   its error handling decides with an **explicit check** (no bare `catch`, constitution III), approved 2026-11-03:

   | Situation when a stream error arrives | Result |
   |---|---|
   | Gate state `closing` (sign-out in progress) | stream closed quietly (*done*), nothing shown |
   | No signed-in user (`auth.currentUser == null`) | stream closed quietly (*done*), nothing shown |
   | Gate state `wipePending` **and** a signed-in user | error shown: `AppException(type: ErrorType.cache, message: 'Previous session data could not be cleared. Please try again.')`; no data is loaded |
   | Any other error | mapped with `ErrorMapper.map` and shown |

   The check is `sessionGate.state == SessionGateState.closing || auth.currentUser == null`. It is intentionally not
   `!sessionGate.isOpen`: that would also close streams quietly in `wipePending`, so a user who signs in after a
   failed wipe would see an empty screen without explanation. Blocs treat stream *done* as no-op.
   The helper became private (`_watchGuarded`) at T034, once `watchLatestMessages` used it; T057 uses it the same
   way from inside the datasource.
6. **UI during sign-out**: `HomeBloc` emits `isSigningOut: true`; `HomeLayout` replaces its body with a blocking
   progress view, so no new user action starts Firestore work. `HomeBloc` checks `isClosed` before emitting after
   the sign-out (the auth stream disposes `HomeLayout`).
7. **Warning dialog (FR-052)**: `LogoutPressed` → `HasPendingWrites`; if true → state `showUnsyncedWarning` →
   `BlocListener` shows "Some changes haven't been saved to the server yet and will be lost. Log out anyway?" with
   **Cancel** (`LogoutCancelled`, stays signed in) and **Log out** (`LogoutConfirmed`). If false → sign-out directly.

**Alternatives considered**: B (persistence off) rejected by the owner (breaks offline reading after restart,
FR-014b, and changes existing screens); wiping inside `logOut()` without a gate (listeners and in-flight calls can
restart the instance between `terminate` and `clearPersistence`); wiping after `signOut()` (listeners first receive
`permission-denied`, and the login screen is already usable).

### D19. Proof of deletion for the unread count (decision R6, owner approved 2026-11-04)

**Finding (T066 review)**: rule `isDeleteMessageUpdate` lets a participant lower the other user's `unreadCount` by one
with no message deleted, and repeat it down to 0. Reproduced on the emulator. Only the conversation's two participants
can do it, so FR-032 and SC-008 hold, but contract case R6 did not: its test changed `lastReadAt` in the same write and
was refused for that other reason.

**Decision**: every delete for everyone writes `lastDeletedMessageId: mid` on the conversation in the same commit as the
message, and the rules on both documents check each other.

**Why the field is needed**: rules cannot see the other writes of a commit or search a collection; `get()` and
`getAfter()` need a full document path, and a conversation update otherwise carries no message id when the deleted
message is not the latest. `lastMessage.id` cannot serve, since it must keep naming the latest message. The only way
to avoid a new field is to drop the unread adjustment, which the owner rejected.

**How `get()` and `getAfter()` work here**: in one transaction or batch, `get()` returns the state before the whole
commit and `getAfter()` the state as if all its writes succeeded, and the commit is all-or-nothing. A refused rule on
either document therefore refuses both writes.

**Conditions**:

| Requirement | Enforced by |
|---|---|
| No unread change without a real delete in this conversation | Conversation rule: `lastDeletedMessageId` must change; the path is built from `cid`; `get` shows `deleted == false`, `getAfter` shows `deleted == true` |
| Caller may delete that message | Both rules: `senderId == uid()` |
| Each message counts once | `deleted == false` before the commit; a deleted message can never pass again |
| Unread falls only for an unseen message | Exact value: old − 1 if `createdAt` is later than the other user's `lastReadAt` and `clearedAt` and old > 0, otherwise old |
| The field and the count cannot change separately | Every other update branch excludes `lastDeletedMessageId`, and this branch requires it to change |
| Message and conversation change together | Message rule: `getAfter(conversation).lastDeletedMessageId == mid` |
| Preview cannot keep deleted text | Latest message: `lastMessage` must equal the deleted form; older message: must stay unchanged |

**Preventing reuse or tampering of the id**: it proves nothing by itself. Keeping the stored value fails the "must
change" condition; naming a message that is already deleted, belongs to someone else, is missing, or is in another
conversation fails its conditions; deleting a second message in the commit fails the message rule, which requires its
own id. The stale value left on the conversation grants nothing, since that message is already deleted.

**Why `clearedAt` counts as seen**: a clear sets the user's unread to 0 without moving `lastReadAt`. Without this check,
deleting a message from before the clear would lower the count of newer messages the user has not seen.

**Stale writes**: the rules compare with the current data, and Firestore answers `permission-denied` before its
contention check, so the transaction does not retry by itself (research D4). If the recipient reads the chat or a new
message arrives between the read and the commit, the delete is refused. `deleteMessage` retries **once** with fresh
reads; a real denial simply fails twice.

**Verification (2026-11-04, emulator, experimental rules copy outside the project)**: 32 attacks refused, 7 legitimate
deletes allowed including the full transaction, and other conversation writes still pass next to the new field. Of the
existing rules tests, the only failure is the delete test using the old write shape. The retry was then tested as a
JavaScript copy of the T069 steps (`chat_delete.rules.test.js`); the Dart code belongs to T069. The project's rules
suite then passed 165/165 on the emulator.

**Status: closed in production on 2026-11-04**. Deployed with the owner's explicit approval from commit `e94300a`
(ruleset `f5ae6bcf-a13c-4bc3-b047-4e565cda37d7`); the released rules read back identical to `firestore.rules`. The
owner then passed the device check and Q15 with accounts O and M (admin) against the deployed rules.

**Limits accepted**: a sender may still lower the count by deleting their own unseen message, which is the feature. The
exact-value check means a client bug is refused rather than silently miscounting.

**Spark**: rules only; no Cloud Functions, no index, no migration (the field is optional).

**Alternatives**: drop the adjustment (the count could include a deleted message; rejected); only document the
behavior (the gap stays; rejected); a marker document per deletion (more writes and another collection, no extra
guarantee).
