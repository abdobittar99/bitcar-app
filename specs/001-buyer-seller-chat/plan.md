# Implementation Plan: Buyer–Seller Chat

**Branch**: `001-buyer-seller-chat` | **Date**: 2026-11-01 (rev. 4: message pagination; rev. 3: Firebase Spark + public profiles review) |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-buyer-seller-chat/spec.md`

## Summary

In-app chat between any two signed-in BitCar users, started from a car's details page, running entirely on the
Firebase **Spark** plan: Firebase Auth + Cloud Firestore + Security Rules, with no Cloud Functions and no push
notifications (deferred). One conversation per user pair is enforced by a deterministic document id
(`<smallerUid>_<largerUid>`), created lazily in the transaction that sends the first message. Messages live in a
subcollection; unread counts, read receipts and one-sided deletion are per-user maps on the conversation, so a single
conversations stream drives the list, badges and the app-bar red dot. Real-time updates use Firestore `snapshots()`
streams consumed by blocs through a `StreamSubscription` + internal events (the existing `SplashBloc` pattern).
Because there is no server code, every guarantee (participant-only access, sender identity, immutability, delete
semantics, 20 messages/minute, name integrity) is enforced by Security Rules that replace today's allow-all rule, and
is verified by an automated `@firebase/rules-unit-testing` suite that runs the project's real `firestore.rules` on the
Firestore emulator (`demo-bitcar`). Participant names are snapshotted at creation from `publicProfiles/{uid}`
(`displayName` only, rule-checked against the user's own `users.fullName`, synced on app open and on name change),
with a rule-enforced `"BitCar user"` placeholder when a profile does not exist yet, keeping `users` documents private.
Message history loads in batches of 20 (option A): a bounded live Firestore stream (`limit(20)`) keeps the newest
messages real-time, and older batches are one-time cursor reads (`startAfter`). Results are merged by message id
inside `ChatBloc`, and a center-anchored scroll view keeps the position when older or newer messages are added.

## Technical Context

**Language/Version**: Dart `^3.8.1` (Flutter); Node.js (20.x local) only for the rules test suite

**Primary Dependencies**: `flutter_bloc` ^9.1.1, `get_it` ^8.0.2, `firebase_core`, `firebase_auth` ^6.1.0,
`cloud_firestore` ^6.0.2, `intl` (message times). **No new pub package.** `firebase_messaging` stays declared and
unused (future push phase). Dev-only npm, isolated in `firestore_tests/`: `@firebase/rules-unit-testing`, `firebase`
(its peer); runner `node:test` (built in)

**Storage**: Cloud Firestore: `conversations`, `conversations/{cid}/messages`, `publicProfiles`, `chatRateLimits`; default
on-device persistence for offline reading

**Testing**: `flutter_test` unit tests with hand-written fakes (blocs, models, validator); automated rules tests on the
Firestore emulator (`firebase emulators:exec`, `demo-bitcar` project id); manual E2E in [quickstart.md](quickstart.md)

**Target Platform**: Android (only configured platform). Chat itself is platform-neutral (Firestore + Auth only)

**Project Type**: Mobile app (Flutter) + Firestore rules/indexes (no server code)

**Performance Goals**: Message visible to an online recipient (within the live window of 20) ≤ 3 s p95 (SC-003); existing conversation opens ≤ 2 s
(SC-006); read receipt ≤ 3 s (SC-005); older page of 20 ≤ 2 s p95 (SC-011). SC-004 deferred with push

**Constraints**: Firebase Spark only (no Cloud Functions, no server-sent FCM, no billing); sending needs a connection;
read-only offline; 1–1,000 chars; ≤ 20 messages/min/user; no Firebase imports above the data layer; no new pub
packages; deploy only `firestore:rules,firestore:indexes`

**Scale/Scope**: 2 new screens, 2 blocs, 1 feature module (`features/chat`), 13 use cases, 4 Firestore paths, 1 rules
test package; small changes to existing app files (entry points, profile sync, sign-out cleanup across the 7 Firestore
data classes) + 3 Firebase config files; 1 obsolete test deleted. Messages load 20 at a time (FR-037)

## Impact of the 2026-10-31 decisions on the system

| Area | Before (rev. 1) | Now (rev. 2) | Why |
|---|---|---|---|
| Server code | `onChatMessageCreated` Cloud Function | **None**; `functions/` untouched | Decision 3: Spark |
| Push notifications | FCM, permission prompt, tokens, tap routing | **Deferred**; spec US4 / FR-022–FR-025a / SC-004 marked deferred | Decision 3 |
| Live in-app delivery, list, unread, red dot, read receipts | Firestore streams | **Unchanged** | Already client-side |
| Enforcement | Rules + function | **Rules only** (they already carried all checks except names) | No server on Spark |
| Participant names | Function filled the missing name | `publicProfiles/{uid}` (`displayName` only, must equal `users.fullName`); names snapshotted at creation; placeholder only when no profile exists; all checked by rules | Decisions 5 + 6 without a function; approved in rev. 3 (research D14) |
| Profile feature | Untouched | `ProfileBloc` calls `SyncPublicProfile` after a name change | Rev. 3: sync on name change |
| Logout | `HomeBloc` removed device token | **No change** to `HomeBloc` | No tokens |
| Android manifest, cache keys | `POST_NOTIFICATIONS`, permission flag | **No change** | No push |
| Rules testing | Optional / manual | **Automated** suite in `firestore_tests/` on the real `firestore.rules` (R1–R20, E1–E13, S1–S2, allowed paths, wiring check) | Decision 4 + rev. 3 |
| `onCarDeleted` (existing) | Assumed deployed | Not deployable on Spark; app already cleans stale favorites client-side | Finding |
| Future push | Built now | Additive extension points only ([contracts/future-push-notifications.md](contracts/future-push-notifications.md)) | Decision 3 item 5 |

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Pre-design | Post-design (rev. 2) |
|---|---|---|---|
| I. Feature-first Clean Architecture | `lib/features/chat/` with shared `data`/`domain` and sub-features `conversations/`, `chat_room/` (same umbrella shape as `features/car/`); entities in `lib/entities/`, models in `lib/models/`; one use case per action | PASS | PASS |
| II. Inward dependencies, plain-Dart domain | Blocs use chat use cases + existing `GetCurrentUser`; Firestore/Auth only in `ChatRemoteDataSource`; domain uses `dart:async` and a plain `isFromCache`; `DocumentSnapshot` exception not extended | PASS | PASS |
| III. Unified error flow | Datasource throws `ErrorMapper.map(e)` / chat `AppException`s; streams mapped the same way; blocs → `appErrorCubit.showError`, reset loading flags | PASS | PASS |
| IV. Explicit DI & immutable state | Datasource/repo/use cases lazy singletons; `ConversationsBloc`, `ChatBloc` factories with `appErrorCubit`; `copyWith`; `BlocBuilder` / `BlocListener` | PASS | PASS |
| V. Consistency, reuse, simplicity | CLAUDE.md naming; reuse `AppButton`, `EmptyState`, `confirmDelete`, `AppErrorListener`, `GetCurrentUser`; validator in `core/validators/`; no speculative push code | PASS | PASS |
| No new packages without approval | No pub changes. npm dev dependencies in `firestore_tests/` approved by decision 4 | PASS | PASS |
| No named routes / no pushes from `app_root.dart` | Plain `Navigator.push` | PASS | PASS |
| Quality gates | `flutter analyze` clean, chat unit tests, rules suite green; no build output or `node_modules` committed | PASS | PASS |

**Scope note (approved)**: replacing the global allow-all rule also defines access for `users`, `cars`, `ads` and
favorites (decision #1, permissions audit E1–E13). No existing app code changes because of it.

## Decisions

### Resolved

| # | Decision | Outcome |
|---|---|---|
| 1 | Replace the global allow-all rule | Approved after permissions review (E1–E13; closes S1 self-promotion to admin, S2 public data) |
| 2 | Platforms | Android only now. Push-specific iOS design moved to the future push note |
| 3 | Firebase plan | **Stay on Spark**: no Cloud Functions, push deferred, everything else client + Firestore + rules |
| 4 | Rules tests | **Automated** with `@firebase/rules-unit-testing` + Emulator, in `firestore_tests/`, allowed and denied cases |
| 5 | Names | Snapshot at creation; uid is the identity; no sync on rename |
| 6 | Other users' data | Option B: `users` stays owner-only |
| 6a | Names without a function | `publicProfiles/{uid}` = `{ displayName }`: signed-in `get` of one doc, `list` denied; owner-only create/update; no other fields; `displayName == users.fullName`; synced on app open after sign-in and on name change |
| 6b | Missing seller profile vs. name forgery | Owner's rule adopted: if the profile exists the stored name must equal it, otherwise only `"BitCar user"` is accepted; a participant can later replace only their own placeholder with their own profile name (rules R11–R15) |
| 7 | Rules tests wiring | Tests load the real root `firestore.rules`; `config.test.js` asserts `firebase.json` points to it; cover `publicProfiles` (R16–R20) |
| 8 | Emulator | `demo-bitcar` project; two dedicated PowerShell terminals: **Flutter Terminal** (JDK 17: `flutter`, `dart`, Gradle) and **Firebase Emulator Terminal** (JDK 21 for that session only: emulator + rules tests); commands never cross terminals; global `JAVA_HOME`, `flutter config` and Gradle settings untouched |
| 9 | Spec | Notification requirements stay in the spec, marked deferred |
| 10 | Message pagination (2026-11-01, owner addition) | Batches of 20 (FR-037 to FR-044, SC-011). **Option A**: bounded live `limit(20)` window + one-time `startAfter` cursor reads; plain-Dart `MessageCursor` (not `startAfterDocument`); deletions outside the newest 20 appear on next open; no new package, no rule change, no new index (research D17) |
| 11 | Review findings F4–F6 (2026-11-01) | F4: "New messages" chip while scrolled up, sending jumps to newest (FR-045, FR-046). F5: opening marks all messages read (FR-015). F6: remaining notification wording marked deferred |
| 12 | Chat screen details (2026-11-01) | Approved as proposed: long-press delete, time/day-separator format, accessibility labels + text scaling, inquiry replaces draft, keyboard behavior (FR-047 to FR-051; UI contract "Chat screen details"). Uses existing `intl` and Flutter widgets only |
| 13 | Test gate (2026-11-02, analyze C1) | Default counter `test/widget_test.dart` replaced by Firebase-free `test/core/errors/app_error_listener_test.dart` (showError → SnackBar with the text; cubit back to `null`; `clear()` shows nothing). Final check runs the **whole** `flutter test`. Constitution unchanged |
| 14 | Sign-out cleanup (2026-11-02, analyze G1) | **Option A**: persistence kept; on sign-out `SessionGate` closes (streams cancelled, new operations refused, in-flight drained) → `terminate()` → `clearPersistence()` → `signOut()`; deferred-wipe marker completed at startup before `runApp`; failed wipe keeps Firestore blocked and sign-out still completes (on sign-out and at startup); unsynced-writes warning via `waitForPendingWrites()` with Cancel / Log out (FR-052, FR-053); verified on a real device (research D18) |
| 16 | chat-review CHK004/005/022/042 (2026-11-02) | Deleted messages count toward the 20; own sending/failed messages are extra and never the cursor (FR-037). Live window failure: loaded messages kept, one automatic retry after 3 s for retryable errors, then `ChatRetried` + Retry button; `permission`/`notFound`/`auth`/`validation` shown without Retry; single-subscription guard (FR-054, research D17). Quickstart rows ordered, Q26 added |
| 17 | Normal connectivity (2026-11-02, chat-review CHK013) | Option A: performance sessions are valid when a baseline probe (10 authenticated REST reads of one `cars` document in `nam5`, timed with `curl`) has median ≤ 400 ms and no failure; median/p95 recorded; otherwise the session is degraded. 400 ms derived from the slowest flow (~5 round trips + delivery < 3 s). Spec Assumptions, quickstart probe, T085 |
| 15 | Analysis medium issues (2026-11-02) | **U1** conversation listener first, messages listener restarts when own `clearedAt` changes; `clearedAt` passed to older batches. **U2** pending server timestamps arrive as `null` in 6.1.0 streams; own `lastReadAt`/`clearedAt` read as now. **U3** rate-limit transition never uses the device clock; denied new-window attempt → "too fast" message (D10). **U4/I2** already covered (T043, T047/T052). **N1** manual p95 measurement of SC-003/005/006/011 in T085. **I1 (a)** datasource returns models in Dart records; `ChatRepositoryImpl` builds all domain wrappers (D17) |

No open decisions remain. The plan is ready for owner approval, then `/speckit-tasks`.

## Project Structure

### Documentation (this feature)

```text
specs/001-buyer-seller-chat/
├── plan.md                 # This file
├── research.md             # Findings + decisions D1–D17
├── data-model.md           # Firestore schema, entities, models, state machines
├── quickstart.md           # Validation guide (Q1–Q22) + rules test commands
├── contracts/
│   ├── firestore-security-rules.md     # Rules contract, audit E1–E13, tests R1–R20
│   ├── chat-repository.md              # Domain contract + 13 use cases
│   ├── ui-screens-and-blocs.md         # Screens, navigation, bloc events/states
│   └── future-push-notifications.md    # Deferred design note (not implemented)
├── checklists/requirements.md
└── tasks.md                # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

New files:

```text
lib/
├── core/
│   ├── enums/message_status.dart                       # sending | sent | read | failed
│   ├── session/session_gate.dart                       # SessionGate: open | closing | wipePending (research D18)
│   └── validators/chat_validator.dart                  # trim, 1–1,000 chars
├── entities/
│   ├── conversation.dart                               # ConversationEntity
│   └── message.dart                                    # MessageEntity
├── models/
│   ├── conversation_model.dart                         # ConversationModel (+ idFor)
│   └── message_model.dart                              # MessageModel
└── features/chat/
    ├── data/
    │   ├── datasource/chat_remote_datasource.dart      # Firestore + Auth (only Firebase-aware class)
    │   └── repositories/chat_repository_impl.dart
    ├── domain/
    │   ├── model/{conversations_update,messages_update,messages_page,message_cursor,chat_target}.dart
    │   ├── repositories/chat_repository.dart
    │   └── usecase/                                    # 12 files, see contracts/chat-repository.md
    ├── conversations/
    │   ├── bloc/conversations_{bloc,event,state}.dart
    │   └── ui/{conversations_screen,conversation_tile}.dart
    └── chat_room/
        ├── bloc/chat_{bloc,event,state}.dart
        └── ui/{chat_screen,message_list,message_bubble,message_input_bar,offline_banner}.dart
lib/features/home/domain/usecase/
├── has_pending_writes.dart                             # HasPendingWrites
└── complete_pending_sign_out.dart                      # CompletePendingSignOut (startup)

test/core/
├── errors/app_error_listener_test.dart                 # replaces the default counter test/widget_test.dart
└── session/session_gate_test.dart                      # gate states, refusal, stream cancel, drain, wipe retry
test/features/home/home_bloc_logout_test.dart           # warning flow: cancel / confirm / no pending writes
test/features/profile/profile_bloc_sync_test.dart       # sync point 2: called on name change only; failure keeps isSuccess

test/features/chat/
├── conversations_bloc_test.dart
├── chat_bloc_test.dart                                 # incl. pagination: window slide keeps messages, merge/dedup, order, single request, end, error/retry, offline batch, read state for older messages, mark-all-read
├── message_list_test.dart                              # widget test: position kept for older and newer inserts, "New messages" chip, jump on send, top row states
├── models_test.dart
├── chat_validator_test.dart
└── fakes/fake_chat_repository.dart

firestore_tests/                                        # Node, dev-only, not part of the Flutter app
├── package.json                                        # devDeps: @firebase/rules-unit-testing, firebase; "test": "node --test"
├── package-lock.json                                   # generated by npm install, committed
├── .gitignore                                          # node_modules/
├── helpers.js                                          # loads ../firestore.rules, test env, seeding, auth contexts
├── config.test.js                                      # firebase.json → firestore.rules wiring
├── chat.rules.test.js                                  # R1–R15 + chat allowed paths
├── public_profiles.rules.test.js                       # R16–R20 + allowed paths
└── existing.rules.test.js                              # E1–E13, S1, S2
```

Modified files:

| File | Change |
|---|---|
| `lib/core/di/injection_container.dart` | Register `ChatRemoteDataSource`, `ChatRepository`, 13 use cases, `ConversationsBloc` and `ChatBloc` factories; add `getCurrentUser` to `CarDetailsBloc`; add `syncPublicProfile` to `ProfileBloc` |
| `lib/features/profile/bloc/profile_bloc.dart` | Inject `SyncPublicProfile`; call it after a successful name change (best effort, error via `AppErrorCubit`) |
| `lib/features/home/ui/home_layout.dart` | Provide `ConversationsBloc`; app-bar chat icon with red dot (`BlocBuilder`) |
| `lib/features/car/car_details/bloc/car_details_{bloc,state}.dart` | Inject existing `GetCurrentUser`; expose `currentUserId` |
| `lib/features/car/car_details/ui/car_details_screen.dart` | "Chat with Seller" button above the unchanged phone button |
| `lib/shared/components/general_widget/confirm_delete_dialog.dart` | Optional `title`/`message` with current defaults |
| `firestore.rules` | Replace allow-all with the rules contract |
| `firestore.indexes.json` (root) | `conversations`: `participants` ARRAY_CONTAINS + `lastMessageAt` DESC |
| `firebase.json` | Add `emulators.firestore` (port 8080) for the test suite; `functions` section left as is |
| `test/widget_test.dart` | **Deleted** (default counter template; replaced by `test/core/errors/app_error_listener_test.dart`) |
| `lib/main.dart` | After `init()`, before `runApp`: `await sl<CompletePendingSignOut>()()` (research D18 step 4) |
| `lib/core/cache/cache_keys.dart` | `firestoreWipePending = 'firestore_wipe_pending'` |
| `lib/features/home/data/datasource/home_remote_datasource.dart` | `hasPendingWrites()`, sign-out sequence (gate close → marker → `terminate` → `clearPersistence` → marker off → `signOut` → gate open), `completePendingWipe()` |
| `lib/features/home/domain/repositories/home_repository.dart`, `data/repositories/home_repository_impl.dart` | `hasPendingWrites`, `completePendingSignOut` |
| `lib/features/home/bloc/home_{bloc,event,state}.dart` | `LogoutPressed` → pending check; `LogoutConfirmed`, `LogoutCancelled`; `showUnsyncedWarning`, `isSigningOut`; `isClosed` guard |
| `lib/features/home/ui/home_layout.dart` | Also: blocking "Signing out…" view while `isSigningOut`; unsynced-changes dialog (`BlocListener`) |
| `lib/features/{auth,car,favorite,feeds,profile}/data/datasource/*_remote_datasource.dart`, `lib/features/search/data/repositories/search_repository_impl.dart` | Inject `SessionGate`; wrap every Firestore future in `gate.run(...)` (no behavior change while signed in) |

Not modified: `AndroidManifest.xml`, `functions/index.js`, `pubspec.yaml`, `.specify/memory/constitution.md`.

**Structure Decision**: Single Flutter app, existing feature-first layout; `features/chat/` mirrors the `features/car/`
umbrella. Firebase config stays in the existing root files referenced by `firebase.json`. The rules test package lives
beside them in `firestore_tests/`, outside `lib/`, `test/` and `functions/`, so it adds nothing to the Flutter build or to
a future functions deployment.

## Layer responsibilities

| Layer | Responsibility |
|---|---|
| Data: `ChatRemoteDataSource` | Deterministic ids; conversation get; list query; messages queries (live `limit(20)` window merged with the conversation doc; one-time older reads with `startAfter` cursor; ordered by `createdAt` + document id, after `clearedAt`); send transaction (create-if-missing with name snapshots, idempotent message, unread +1, rate-limit doc); mark-read; delete message (+ preview/unread fix-up); clear conversation; fill own missing name; `publicProfiles` upsert/read; `snapshots(includeMetadataChanges: true)` → models; error mapping |
| Data: `ChatRepositoryImpl` | Implements `ChatRepository`; models → entities; `isVisibleInList` filtering |
| Domain | Entities, wrappers (incl. `MessageCursor`, `MessagesPage`), repository contract, 12 single-action use cases; no Flutter/Firebase |
| Presentation: `ConversationsBloc` (HomeLayout scope) | Syncs own public name on app open, conversations stream, red-dot total, offline flag, delete conversation |
| Presentation: `ProfileBloc` (existing) | Syncs own public name after a successful name change |
| Presentation: `ChatBloc` (screen scope) | Target resolution, inquiry draft, live-window subscription, older batch reads, merge by id (window slide keeps messages), read state from `otherLastReadAt`, single-request guard, paging states, optimistic send/retry, mark-all-read while visible, delete message |
| Presentation: `message_list.dart` | Center-anchored scroll view (position kept for older and newer inserts), reach-top detection, top row (loading / retry / beginning), "New messages" chip, jump to newest on send |
| Firestore | Rules (all enforcement), composite index |

## Stream lifecycle

| Stream | Opened | Closed |
|---|---|---|
| Conversations (`participants array-contains uid`) | `ConversationsStarted` when `HomeLayout` builds | **Sign-out:** first by `SessionGate.closeForSignOut()` (before `terminate` and `signOut`, research D18); later `ConversationsBloc.close()` when `HomeLayout` is disposed |
| Messages live window (`limit(20)`) + conversation doc | `ChatStarted`; again on `ChatRetried` (or the single automatic retry 3 s after a retryable failure), only when no subscription exists | `ChatBloc.close()` when `ChatScreen` pops; on a stream error (subscription cleared, loaded messages kept, FR-054); on sign-out, first by `SessionGate.closeForSignOut()` |

Older batches are one-time `Future` reads, not streams. Each bloc keeps its `StreamSubscription`, cancels the old one
before subscribing again, forwards data and errors as private events (never `emit` from a listener callback), and
cancels it in `close()`. No listener runs without a limit.

**Sign-out order (D18):** (1) `SessionGate.closeForSignOut()` cancels every Firestore listener registered through
`watch` (the blocs receive *done*, not an error) and refuses new operations; (2) `terminate()` → `clearPersistence()`;
(3) `auth.signOut()`; (4) the auth stream switches `AppRoot` to `LoginScreen`, and disposing `HomeLayout` closes its
blocs. Step 4 is an additional, later stage: by then no listener is active, so bloc disposal only releases the
already-finished subscriptions.

## Message pagination (FR-037 to FR-046, option A)

A bounded live stream for the newest messages plus cursor-based one-time reads for older ones. Full rationale and
alternatives: research D17.

| Requirement | How it is met |
|---|---|
| FR-037 first 20 | Live window: listener on `orderBy(createdAt desc, __name__ desc).limit(20)`, merged with the conversation doc (`otherLastReadAt`, own `unreadCount`). Never a listener without a limit |
| FR-038 next 20 until the oldest | `ChatLoadOlderRequested` → `LoadOlderMessages`: one-time `get()` with `startAfter([createdAt, id]).limit(20)` from the oldest server-confirmed message loaded overall; a server batch with fewer than 20 ends the history. Queries keep `where createdAt > clearedAt` (FR-027a) |
| FR-039 no duplicates | `liveMessages`, `loadedMessages`, `pendingMessages` are id-keyed maps; displayed list = union by id (live > loaded > pending); messages pushed out of the window move to `loadedMessages` instead of disappearing |
| FR-040 order | Sorted by `(createdAt, id)`, the same keys as the Firestore order, so the cursor and the screen agree even when timestamps are equal |
| FR-041 / FR-045 scroll position | `CustomScrollView` with a `center` key: older batches above the center, newer messages below it; inserts on either side do not move the visible content. Scrolled-up user gets a "New messages" chip |
| FR-046 jump on send | Sending or retrying scrolls to the newest message |
| FR-042 one request at a time | Bloc guard: ignore while `isLoadingOlder` / `!hasOlder` / no cursor; the flag is emitted before the first `await`. No `bloc_concurrency` |
| FR-043 states | Top row: progress / error + retry (same cursor; error also via `AppErrorCubit`) / "Beginning of the conversation"; a cache-only short batch shows the offline banner and is re-requested when the window reports server data |
| FR-044 live scope | Newest 20: fully live. Read state: live for every loaded message (derived from `otherLastReadAt`). Deletion of an older message: shown on next open |
| FR-015 mark all read | Visible screen + own `unreadCount > 0` → `MarkConversationRead` (unread 0, `lastReadAt` = now), which covers messages not loaded yet |

`startAfterDocument` was considered: it works, but needs a `DocumentSnapshot` that would travel through the repository
and bloc, which the constitution forbids for new code.

Domain purity: the cursor is the plain-Dart `MessageCursor(createdAt, messageId)`. The datasource alone converts it to
`Timestamp` + document id; the existing `DocumentSnapshot` exception is not extended. Rules, indexes and `pubspec.yaml`
are unchanged by this addition.

## Complexity Tracking

No constitution violations. Cross-feature edits are limited to the documented entry points (home app bar, car details),
the public-name sync in `ProfileBloc`, the approved rules replacement, and the sign-out cleanup (decision 14).

| Cross-cutting change | Why it is needed | Simpler alternative rejected because |
|---|---|---|
| `SessionGate` (plain Dart, `lib/core/session/`) injected into all 7 Firestore data classes | FR-053 / owner condition: no Firestore operation may run during sign-out cleanup, and none may run while a failed wipe is pending | Relying on bloc disposal: `HomeLayout` is disposed only **after** `signOut()`, and in-flight calls could restart the instance between `terminate` and `clearPersistence` |
| Startup call in `main.dart` before `runApp` | Deferred wipe must run before any Firestore access or user session | Running it in `SplashBloc`: the auth stream and `HomeLayout` may touch Firestore first |

Constitution check for these: Firebase stays in datasources (`HomeRemoteDataSource`); the gate has no Firebase or
Flutter imports; blocs use use cases only (`HasPendingWrites`, `LogOut`); errors are `AppException` through
`AppErrorCubit`; the full `flutter test` gate is kept (decision 13).
