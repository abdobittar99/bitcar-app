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
| `test/widget_test.dart` is the default counter template | file content | Pre-existing failure; not a baseline |
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
  dot and the conversations screen. Closed when `HomeLayout` is disposed (logout).
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
       `GetCurrentUser`. Creates the doc for users who registered before this feature.
    2. Name changed: `ProfileBloc._onUpdated`, after `UpdateUserProfile` succeeds and the name differs. If the sync
       fails, the profile save still counts as successful, the error is shown through `AppErrorCubit`, and sync 1 repairs
       it on the next app start.
- **Placeholder rule (owner's proposal, adopted)**: when creating a conversation, for each participant:
  - if `publicProfiles/{uid}` **exists**, the stored name **must equal** its `displayName`;
  - if it **does not exist**, the **only** accepted value is the fixed placeholder `"BitCar user"`.
  - Later, a participant may replace **only their own** placeholder, **only with their own** profile name (done when they
    open the conversation via `GetChatTarget`). Real names already stored never change (snapshot).
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
    other user's `lastReadAt` and the user's own `unreadCount` to each `MessagesUpdate` (merged with a plain
    `StreamController`; no `rxdart`). Both listeners are cancelled together.
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
