---

description: "Task list for Buyer–Seller Chat"
---

# Tasks: Buyer–Seller Chat

**Input**: Design documents from `specs/001-buyer-seller-chat/`

**Prerequisites**: [plan.md](plan.md) (rev. 4), [spec.md](spec.md), [research.md](research.md) (D1–D17),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Included. The plan requires them: chat unit/widget tests (`test/features/chat/`) and the automated
Security Rules suite (`firestore_tests/`, plan decisions 4 and 7, constitution quality gates).

**Organization**: Tasks are grouped by user story. User Story 4 (notifications) is **deferred** and has no tasks.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: User story from spec.md (US1, US2, US3, US5, US6)

## Rules that apply to every task

- **Two terminals** (plan decision 8): `flutter` / `dart` commands only in the **Flutter Terminal** (JDK 17);
  `firebase emulators:*` and `npm --prefix firestore_tests ...` only in the **Firebase Emulator Terminal** (JDK 21 set
  for that session, see quickstart). Never change global `JAVA_HOME`, `flutter config` or Gradle settings.
- **No new pub packages**; `pubspec.yaml` is not modified. The only new dependencies are the dev-only npm packages
  in `firestore_tests/` (decision 4).
- **Firebase imports** (`cloud_firestore`, `firebase_auth`) only in `chat_remote_datasource.dart` and the models in
  `lib/models/`. Domain files (`lib/entities/`, `features/chat/domain/`) are plain Dart.
- **Error flow**: datasource methods wrap Firebase calls in `try { } catch (e) { throw ErrorMapper.map(e); }`
  (rethrow `AppException`s created by the chat code as they are); streams use `.handleError` with the same mapping;
  blocs `catch AppException`, call `appErrorCubit.showError(e.message)` and reset loading flags.
- **Imports** use `package:car_shop/...`. Blocs are `registerFactory`; datasource, repository and use cases
  `registerLazySingleton` in [injection_container.dart](../../lib/core/di/injection_container.dart).
- `AppException({required String message, required ErrorType type})`; `ErrorType` values used: `auth`, `validation`,
  `notFound`, `permission`, `network`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Rules test package and emulator wiring (no Flutter changes)

- [ ] T001 [P] Create `firestore_tests/package.json`: `"private": true`, `"type": "commonjs"`, script `"test": "node --test"`, devDependencies `@firebase/rules-unit-testing` and its peer `firebase` (pick mutually compatible current versions and pin them exactly). Then, in the **Firebase Emulator Terminal**, run `npm --prefix firestore_tests install` and keep the generated `firestore_tests/package-lock.json`
- [ ] T002 [P] Create `firestore_tests/.gitignore` containing `node_modules/`
- [ ] T003 [P] Add an `"emulators": { "firestore": { "port": 8080 } }` block to `firebase.json`; leave the `functions` and `firestore` sections unchanged (`"rules": "firestore.rules"`, `"indexes": "firestore.indexes.json"`)
- [ ] T004 Create `firestore_tests/helpers.js`: `initializeTestEnvironment({ projectId: 'demo-bitcar', firestore: { rules: fs.readFileSync(path.resolve(__dirname, '..', 'firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 } })`; export helpers `authed(uid)`, `unauthed()`, `seed(async (db) => ...)` (via `withSecurityRulesDisabled`), `clear()` (`clearFirestore`), `cleanup()`. No copy of the rules file anywhere in `firestore_tests/`
- [ ] T005 Create `firestore_tests/config.test.js` (node:test): parse `../firebase.json` and assert `firestore.rules === 'firestore.rules'`, that `../firestore.rules` exists, and that no `*.rules` file exists inside `firestore_tests/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Security Rules, shared domain types, datasource/repository skeleton, DI, test fakes

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Security Rules (tests first, then rules)

> Write T006–T008 first; they must fail against today's allow-all `firestore.rules`, then pass after T009.

- [ ] T006 [P] Write `firestore_tests/existing.rules.test.js` covering every case E1–E13 and the S1/S2 fixes in [contracts/firestore-security-rules.md](contracts/firestore-security-rules.md) (existing `users`, `cars`, `ads`, favorites accesses), both allowed and denied
- [ ] T007 [P] Write `firestore_tests/public_profiles.rules.test.js`: R16–R20 (write another user's doc; extra fields; `displayName` ≠ own `users.fullName`; `list` of `publicProfiles`; signed-out `get`) plus allowed paths: signed-in `get` of one doc, create/refresh own doc with `displayName` (1–100 chars) equal to own `users/{uid}.fullName`, and changing `users.fullName` + `publicProfiles.displayName` in one batch (`getAfter`)
- [ ] T008 [P] Write `firestore_tests/chat.rules.test.js`: R1–R15 from the rules contract (include an **admin** user in the non-participant cases R1–R4), plus allowed paths: create conversation + first message (with profile names; with `"BitCar user"` when the other user has no profile), send, mark read, delete own message, delete conversation (`clearedAt`), replace own placeholder with own `displayName`, new rate window after 60 s (seed `windowStart` in the past via `seed`), the full first-send transaction within the rules access budget, and the pagination queries: `orderBy createdAt desc, __name__ desc, limit 20` and `startAfter([createdAt, id]).limit(20)`, each with and without `where createdAt > clearedAt` (allowed for a participant, denied for a non-participant)
- [ ] T009 Replace the allow-all `firestore.rules` with the rules in [contracts/firestore-security-rules.md](contracts/firestore-security-rules.md): helpers (`uid()`, `isParticipant(cid)`, `validText`, `placeholderName()` = `'BitCar user'`, `expectedName(u)`), `conversations/{cid}` (create with `participantNames` rule, own-map-entry updates, fill-own-placeholder update), `messages/{mid}` (`get`/`list` participants; create: `senderId == uid()`, text 1–1,000 chars, `deleted == false`, `createdAt == request.time`, keys exactly `senderId, text, createdAt, deleted`, rate limit; update: sender only, once, only `deleted: true` + `text: ""`; `delete` never), `publicProfiles/{uid}` (get signed-in, list never, owner create/update with keys exactly `['displayName']`, 1–100 chars, `== getAfter(/users/uid).fullName`, delete never), `chatRateLimits/{uid}` (≤ 20 messages / 60 s), and the existing collections per E1–E13. In the **Firebase Emulator Terminal** run `firebase emulators:exec --only firestore --project demo-bitcar "npm --prefix firestore_tests test"` until all suites pass
- [ ] T010 [P] Add to the **root** `firestore.indexes.json` the composite index `conversations`: `participants` ARRAY_CONTAINS + `lastMessageAt` DESCENDING. Do not modify `project-root/firestore.indexes.json`

### Shared Dart types

- [ ] T011 [P] Create `lib/core/enums/message_status.dart`: `enum MessageStatus { sending, sent, read, failed }`
- [ ] T012 [P] Create `lib/core/validators/chat_validator.dart`: class `ChatValidator` with `static const maxLength = 1000` and `static String? validate(String text)` that trims and returns `null` when the trimmed length is 1–1,000, otherwise `'Message cannot be empty'` / `'Message is too long (max 1,000 characters)'`
- [ ] T013 [P] Create `lib/entities/conversation.dart` (`ConversationEntity`): `id`, `participantIds`, `buyerId`, `sellerId`, `otherUserId`, `otherUserName`, `lastMessageText`, `isLastMessageDeleted`, `lastMessageSenderId` (String?), `lastMessageAt` (DateTime?), `unreadCount` (int, 0 if absent), `otherLastReadAt` (DateTime?), `clearedAt` (DateTime?); getter `isVisibleInList => lastMessageAt != null && (clearedAt == null || lastMessageAt!.isAfter(clearedAt!))`
- [ ] T014 [P] Create `lib/entities/message.dart` (`MessageEntity`): `id`, `conversationId`, `senderId`, `text`, `createdAt` (DateTime?, null only for local pending), `isDeleted`, `status` (`MessageStatus`); `copyWith`
- [ ] T015 [P] Create plain-Dart wrappers in `lib/features/chat/domain/model/`: `conversations_update.dart` (`ConversationsUpdate{conversations, isFromCache}`), `messages_update.dart` (`MessagesUpdate{messages, otherLastReadAt, unreadCount, isFromCache}`), `messages_page.dart` (`MessagesPage{messages, hasOlder, isFromCache}`), `message_cursor.dart` (`MessageCursor{createdAt, messageId}`), `chat_target.dart` (`ChatTarget{conversationId, otherUserId, otherUserName, exists}`), plus `const messagesPageSize = 20` in `message_cursor.dart`
- [ ] T016 Create `lib/models/conversation_model.dart` (`ConversationModel extends ConversationEntity`, depends on T013): `factory fromMap(Map<String, dynamic> map, String id, String currentUid)` converting `Timestamp` → `DateTime` and per-uid map lookups (`participantNames`, `unreadCount`, `lastReadAt`, `clearedAt`, `lastMessage{id,text,senderId,deleted}`); `static String idFor(String a, String b)` returning the two uids sorted and joined with `_`
- [ ] T017 Create `lib/models/message_model.dart` (`MessageModel extends MessageEntity`, depends on T014): `factory fromMap(map, id, conversationId)` with `status: MessageStatus.sent` (read is applied later in `ChatState`); `static Map<String, dynamic> toCreateMap({required String senderId, required String text})` returning exactly `senderId`, `text`, `createdAt: FieldValue.serverTimestamp()`, `deleted: false`
- [ ] T018 Create `lib/features/chat/domain/repositories/chat_repository.dart`: abstract `ChatRepository` with every method and signature in [contracts/chat-repository.md](contracts/chat-repository.md) (`currentUserId`, `syncPublicProfile`, `openChatWith`, `getChatTarget`, `watchConversations`, `watchLatestMessages`, `loadOlderMessages`, `newMessageId`, `sendMessage`, `markConversationRead`, `deleteMessage`, `deleteConversation`)

### Data layer skeleton

- [ ] T019 Create `lib/features/chat/data/datasource/chat_remote_datasource.dart`: `ChatRemoteDataSource(this.firestore, this.auth)` (same constructor style as `FavoriteRemoteDataSource`); `static const placeholderName = 'BitCar user'`; `String get currentUserId` (throw `AppException(type: ErrorType.auth)` if signed out); `Future<void> syncPublicProfile(String displayName)` (read `publicProfiles/{uid}`, `set({'displayName': displayName})` only if missing or different); `Future<String> readPublicName(String uid)` (`displayName` or `placeholderName`). Every Firestore call wrapped with `ErrorMapper.map`
- [ ] T020 Create `lib/features/chat/data/repositories/chat_repository_impl.dart`: `ChatRepositoryImpl(this.dataSource) implements ChatRepository`; implement `currentUserId` and `syncPublicProfile`; other methods `throw UnimplementedError()` until their story task replaces them
- [ ] T021 [P] Create use cases `lib/features/chat/domain/usecase/get_current_user_id.dart` (`GetCurrentUserId`, `String call()`) and `lib/features/chat/domain/usecase/sync_public_profile.dart` (`SyncPublicProfile`, `Future<void> call(String displayName)`)
- [ ] T022 Add a `// Chat` section to `lib/core/di/injection_container.dart`: `registerLazySingleton(() => ChatRemoteDataSource(sl(), sl()))`, `registerLazySingleton<ChatRepository>(() => ChatRepositoryImpl(sl()))`, `GetCurrentUserId`, `SyncPublicProfile`

### Test support

- [ ] T023 [P] Create `test/features/chat/fakes/fake_chat_repository.dart`: in-memory `FakeChatRepository implements ChatRepository` with `StreamController`s to push `ConversationsUpdate` / `MessagesUpdate`, queued `MessagesPage` results for `loadOlderMessages`, configurable `AppException` per method, and call recorders (arguments + counts)
- [ ] T024 [P] Create `test/features/chat/chat_validator_test.dart`: empty, whitespace-only, 1 char, exactly 1,000 after trim, 1,001 chars
- [ ] T025 [P] Create `test/features/chat/models_test.dart`: `ConversationModel.idFor` order-independence, `fromMap` per-uid lookups, `isVisibleInList` with/without `clearedAt`, `MessageModel.toCreateMap` keys exactly `senderId, text, createdAt, deleted`

**Checkpoint**: Rules suite green; shared types compile (`flutter analyze` in the Flutter Terminal)

---

## Phase 3: User Story 1 — Starting or resuming a conversation from a car (Priority: P1) 🎯 MVP

**Goal**: "Chat with Seller" opens the single conversation for the pair, pre-filled with the car inquiry, and the
first send creates the conversation (FR-001–FR-008, FR-010, FR-026, FR-050)

**Independent Test**: quickstart Q1–Q5 — A opens S's car → "Chat with Seller", sends the inquiry; another car of S
opens the same conversation with the new inquiry in the input; no conversation exists until the first send

### Tests for User Story 1

- [ ] T026 [P] [US1] In `test/features/chat/chat_bloc_test.dart` add group `start`: `ChatStarted.fromCar` sets `draft` to `"Hello, I'm interested in your <brand> <model> (<year>). Is it still available?"` and replaces any previous draft (FR-050); `isNewConversation` true when `!target.exists` and no messages; self-chat `AppException` goes to `AppErrorCubit`; `ChatMessageSubmitted` with whitespace sends nothing; a valid submit adds a `sending` pending message and calls `sendMessage` with the id from `CreateMessageId`

### Implementation for User Story 1

- [ ] T027 [US1] In `chat_remote_datasource.dart` implement `openChatWith(otherUserId)`: throw `AppException(message: "You can't chat with yourself", type: ErrorType.validation)` if equal to own uid; `cid = ConversationModel.idFor`; one `get` of `conversations/{cid}`; if it exists → `ChatTarget(exists: true, otherUserName: participantNames[other])`, else `otherUserName = readPublicName(other)`; no writes (FR-002)
- [ ] T028 [US1] In `chat_remote_datasource.dart` implement `newMessageId(cid)` (`collection('conversations').doc(cid).collection('messages').doc().id`) and `sendMessage(...)` as the transaction of research D4, writing field values exactly as the rules contract expects: read conversation, message doc and `chatRateLimits/{uid}`; if the message exists return (idempotent retry, FR-014); if the 60 s window is full (20 messages) throw `AppException(message: "You're sending messages too fast, try again shortly", type: ErrorType.validation)` (FR-014a); create the conversation when missing (`participants` sorted, `buyerId` = uid, `sellerId` = other, `participantNames` from `readPublicName` for both, `createdAt` server time); write the message with `MessageModel.toCreateMap`; update `lastMessage {id, text, senderId, deleted: false}`, `lastMessageAt`, `unreadCount.<other>` +1, and the rate-limit doc
- [ ] T029 [US1] In `chat_remote_datasource.dart` implement `watchLatestMessages(conversationId, pageSize)`: listen to the conversation doc and to `messages` ordered by `createdAt` desc + `FieldPath.documentId` desc, `limit(pageSize)`, plus `where createdAt > clearedAt[uid]` when set, both with `snapshots(includeMetadataChanges: true)`; merge them with a `StreamController` into `MessagesUpdate` (messages oldest-first, `otherLastReadAt`, own `unreadCount`, `isFromCache`); cancel both listeners when the controller is cancelled; `.handleError` → `ErrorMapper.map`. A not-yet-existing conversation emits an empty update. No listener without a limit
- [ ] T030 [US1] In `chat_repository_impl.dart` implement `openChatWith`, `newMessageId`, `sendMessage`, `watchLatestMessages` (models → entities)
- [ ] T031 [P] [US1] Create use cases in `lib/features/chat/domain/usecase/`: `open_chat_with_seller.dart` (`OpenChatWithSeller`, `Future<ChatTarget> call(String sellerId)`), `create_message_id.dart` (`CreateMessageId`, `String call(String conversationId)`), `send_message.dart` (`SendMessage`, named `conversationId, messageId, otherUserId, text`), `watch_latest_messages.dart` (`WatchLatestMessages`, `Stream<MessagesUpdate> call(String conversationId, {int pageSize = messagesPageSize})`)
- [ ] T032 [US1] Create `lib/features/chat/chat_room/bloc/chat_event.dart`, `chat_state.dart`, `chat_bloc.dart` per [contracts/ui-screens-and-blocs.md](contracts/ui-screens-and-blocs.md): abstract `ChatEvent`; `ChatStarted.fromCar(CarEntity)` (resolve target, set inquiry draft, subscribe `WatchLatestMessages`); `ChatMessageSubmitted(text)` (validate with `ChatValidator`; add pending `sending` message; `SendMessage`; on `AppException` mark it `failed` and `showError`); private `_MessagesUpdated` (replace `liveMessages`, drop pending ids that arrived) and `_MessagesFailed`; `ChatState` with `copyWith` and all fields of the contract (paging fields with defaults for now) and the `messages` getter (union by id, sorted by `(createdAt, id)`, pending last); keep the `StreamSubscription`, cancel it before re-subscribing and in `close()`; never `emit` from the listener callback
- [ ] T033 [P] [US1] Create `lib/features/chat/chat_room/ui/message_input_bar.dart`: `TextField` with `maxLength: 1000` counter, initial text from `draft`, send `IconButton` disabled when the trimmed text is empty
- [ ] T034 [P] [US1] Create `lib/features/chat/chat_room/ui/message_bubble.dart`: own messages right-aligned in the app's blue, others left in light grey; send time with `DateFormat.jm()` (FR-048); long text wraps fully
- [ ] T035 [US1] Create `lib/features/chat/chat_room/ui/message_list.dart` (base): `CustomScrollView` with a `center` key and two `SliverList`s (older-than-center above, center and newer below; center = oldest message of the first live window); jump to the newest message on first build. Takes plain values and callbacks so a widget test can drive it
- [ ] T036 [US1] Create `lib/features/chat/chat_room/ui/chat_screen.dart` (`ChatScreen`): `AppBar` title = `target.otherUserName`; when `isNewConversation`, hint "Start the conversation with <name>"; `message_list.dart` + `message_input_bar.dart`; `BlocBuilder<ChatBloc, ChatState>`
- [ ] T037 [US1] Inject the existing `GetCurrentUser` into `lib/features/car/car_details/bloc/car_details_bloc.dart` and add `currentUserId` (String?) to `car_details_state.dart` `copyWith`; load it in `_onStarted` alongside the car; update the `CarDetailsBloc` registration in `injection_container.dart` to `CarDetailsBloc(getCarDetails: sl(), getCurrentUser: sl(), appErrorCubit: sl())`
- [ ] T038 [US1] In `lib/features/car/car_details/ui/car_details_screen.dart` add `AppButton(text: 'Chat with Seller', icon: Icons.chat_bubble_outline, ...)` directly above the existing `'Contact Seller'` button (unchanged), shown only when `car.sellerId != state.currentUserId`; it pushes `ChatScreen` via `MaterialPageRoute` with `BlocProvider(create: (_) => sl<ChatBloc>()..add(ChatStarted.fromCar(car)))`
- [ ] T039 [US1] Register in `injection_container.dart`: `OpenChatWithSeller`, `CreateMessageId`, `SendMessage`, `WatchLatestMessages` (lazy singletons) and `registerFactory(() => ChatBloc(...))` with named required dependencies and `appErrorCubit: sl()`

**Checkpoint**: Q1–Q5 pass; `flutter analyze` clean; `flutter test test/features/chat` green

---

## Phase 4: User Story 2 — Exchanging messages live (Priority: P1)

**Goal**: Live two-way messaging with sending/sent/read/failed, retry, rate limit, read marking, offline reading,
and history in batches of 20 (FR-011–FR-015, FR-014a/b, FR-037–FR-046, FR-048, FR-049, FR-051)

**Independent Test**: quickstart Q6, Q10–Q12, Q19–Q22, Q21a on two devices

### Tests for User Story 2

- [ ] T040 [P] [US2] In `test/features/chat/chat_bloc_test.dart` add group `statuses`: pending → sent when its id arrives; own messages become `read` when `createdAt <= otherLastReadAt`, including messages in `loadedMessages`; `AppException` → `failed`, text kept; `ChatMessageRetried` re-sends the same id with no duplicate; rate-limit message shown; `MarkConversationRead` called when visible and `unreadCount > 0`, not while invisible; client pre-check refuses the 21st send within 60 s
- [ ] T041 [P] [US2] In `test/features/chat/chat_bloc_test.dart` add group `pagination`: messages pushed out of the live window move to `loadedMessages` and stay; union without duplicates across live/loaded/pending; order by `(createdAt, id)` with equal timestamps; two `ChatLoadOlderRequested` in a row → one `loadOlderMessages` call; cursor = oldest server-confirmed message overall; server batch < 20 → `hasOlder == false`; 40 messages → one extra empty call ends it; cache-only short batch keeps `hasOlder`, sets `olderBatchIncomplete`, and is re-requested on the next server update; error keeps messages, sets `olderLoadFailed`, retry uses the same cursor
- [ ] T042 [P] [US2] Create `test/features/chat/message_list_test.dart` (widget test): adding older items keeps the top visible message at the same screen offset; adding a newer item while scrolled up keeps the offset and shows the "New messages" chip; at the bottom a newer item scrolls into view; `onReachTop` fires within 200 px of the top; top row shows progress / "Couldn't load older messages · Retry" / "Beginning of the conversation"; day separators "Today" / "Yesterday" / date

### Implementation for User Story 2

- [ ] T043 [US2] In `chat_remote_datasource.dart` implement `loadOlderMessages(conversationId, before, pageSize)`: one-time `get()` ordered by `createdAt` desc + `FieldPath.documentId` desc, `startAfter([Timestamp.fromDate(before.createdAt), before.messageId])`, `limit(pageSize)`, plus the `clearedAt` filter; return `MessagesPage` with `isFromCache` from snapshot metadata and `hasOlder = isFromCache || docs.length == pageSize`. Never `startAfterDocument` (research D17)
- [ ] T044 [US2] In `chat_remote_datasource.dart` implement `markConversationRead(cid)`: update `unreadCount.<uid>` = 0 and `lastReadAt.<uid>` = server time; no-op when already 0
- [ ] T045 [US2] Implement both in `chat_repository_impl.dart` and create use cases `lib/features/chat/domain/usecase/load_older_messages.dart` (`LoadOlderMessages`) and `mark_conversation_read.dart` (`MarkConversationRead`)
- [ ] T046 [US2] Extend `chat_bloc.dart` / `chat_event.dart` / `chat_state.dart`: `ChatMessageRetried(messageId)`, `ChatVisibilityChanged(isVisible)`, `ChatLoadOlderRequested` (guard: ignore if `isLoadingOlder`, `!hasOlder` or no cursor; emit `isLoadingOlder: true` before the first `await`); window-slide handling in `_MessagesUpdated`; `otherLastReadAt` → `read` in the `messages` getter; `olderBatchIncomplete` re-request when an update is not from cache; mark-all-read when visible and `unreadCount > 0` (FR-015); `isOffline` from `isFromCache`; client rate pre-check (≤ 20 sends / 60 s); inject `LoadOlderMessages`, `MarkConversationRead` and update the DI registration
- [ ] T047 [US2] Complete `message_list.dart`: older batches in the sliver above the center; top row (progress while `isLoadingOlder`, "Couldn't load older messages · Retry" when `olderLoadFailed`, "Beginning of the conversation" when `!hasOlder`; hidden offline with an incomplete batch); `ScrollController` sends `onReachTop` when `pixels <= minScrollExtent + 200`; within 100 px of the bottom new messages scroll into view, otherwise a "New messages" chip that scrolls to the bottom (FR-045); scroll to the bottom after send/retry (FR-046); day separators "Today" / "Yesterday" / `DateFormat.yMMMd()` (FR-048); stay at the newest message when the keyboard opens (FR-051); dispose the controller
- [ ] T048 [P] [US2] In `message_bubble.dart` add status icons for own messages (sending, sent, read, failed) with `Semantics` labels "Sending", "Sent", "Read", "Failed, tap to retry"; tapping a failed message sends `ChatMessageRetried` (FR-013, FR-014, FR-049)
- [ ] T049 [P] [US2] Create `lib/features/chat/chat_room/ui/offline_banner.dart` (plain-language "You're offline. Showing saved messages." bar) and show it in `chat_screen.dart` when `isOffline` (FR-014b)
- [ ] T050 [US2] In `chat_screen.dart` add a `WidgetsBindingObserver` sending `ChatVisibilityChanged` on resume/pause, wire `message_list.dart` callbacks (`onReachTop`, `onRetryOlder` → `ChatLoadOlderRequested`), keep `Scaffold(resizeToAvoidBottomInset: true)` with the input bar below the list

**Checkpoint**: Q6, Q10–Q12, Q19–Q22, Q21a pass; tests green

---

## Phase 5: User Story 3 — Conversations list, unread counts and red dot (Priority: P1)

**Goal**: App-bar entry with red dot, live conversations list, opening from the list, public-name sync
(FR-016–FR-019, FR-021, FR-026, FR-028–FR-030, research D14)

**Independent Test**: quickstart Q7–Q9, Q16, Q17, Q18a — S on home sees the red dot; on the list the conversation
jumps to the top with preview, time and badge; opening clears the badge

### Tests for User Story 3

- [ ] T051 [P] [US3] Create `test/features/chat/conversations_bloc_test.dart`: `ConversationsStarted` calls `GetCurrentUser` then `SyncPublicProfile(user.fullName)` then subscribes; a sync `AppException` is shown but the subscription still starts; `totalUnread` is the sum of `unreadCount`; `isOffline` follows `isFromCache`; stream error → `hasError: true`, `isLoading: false`; `ConversationsRetried` re-subscribes; `close()` cancels

### Implementation for User Story 3

- [ ] T052 [US3] In `chat_remote_datasource.dart` implement `watchConversations()` (`where('participants', arrayContains: uid).orderBy('lastMessageAt', descending: true)`, `snapshots(includeMetadataChanges: true)` → `ConversationModel`) and `getChatTarget(cid)` (`get`; missing → `AppException(message: 'Conversation not found', type: ErrorType.notFound)`; if own `participantNames` entry is `placeholderName` and own `publicProfiles` doc exists, update only `participantNames.<uid>` to own `displayName`)
- [ ] T053 [US3] Implement both in `chat_repository_impl.dart` (`watchConversations` filters by `isVisibleInList`) and create use cases `lib/features/chat/domain/usecase/watch_conversations.dart` (`WatchConversations`) and `get_chat_target.dart` (`GetChatTarget`)
- [ ] T054 [US3] Create `lib/features/chat/conversations/bloc/conversations_event.dart`, `conversations_state.dart`, `conversations_bloc.dart` per the UI contract: `ConversationsStarted`, `ConversationsRetried`, private `_ConversationsUpdated` / `_ConversationsFailed`; state `isLoading`, `hasError`, `isOffline`, `conversations`, `totalUnread` with `copyWith`; constructor `getCurrentUser`, `syncPublicProfile`, `watchConversations`, `appErrorCubit`; subscription cancelled in `close()`
- [ ] T055 [P] [US3] Create `lib/features/chat/conversations/ui/conversation_tile.dart`: other user's name, preview ("This message was deleted" when `isLastMessageDeleted`), time (`DateFormat.jm()` today, `DateFormat.yMMMd()` earlier), unread badge, `Semantics` for the badge
- [ ] T056 [US3] Create `lib/features/chat/conversations/ui/conversations_screen.dart`: loading indicator; `EmptyState(icon: Icons.chat_bubble_outline, title: 'No conversations yet', subtitle: 'Start a chat from any car page.')`; error `EmptyState` with `buttonText: 'Retry'` → `ConversationsRetried`; offline banner; tap → `ChatScreen` with `BlocProvider(create: (_) => sl<ChatBloc>()..add(ChatStarted.fromConversation(c.id)))`
- [ ] T057 [US3] In `chat_bloc.dart` implement `ChatStarted.fromConversation(cid)` (`GetChatTarget`, empty draft, subscribe `WatchLatestMessages`); inject `GetChatTarget`
- [ ] T058 [US3] In `lib/features/home/ui/home_layout.dart` add `BlocProvider(create: (_) => sl<ConversationsBloc>()..add(ConversationsStarted()))` to `MultiBlocProvider`, and an app-bar chat `IconButton` before the search icon with a red dot overlay when `totalUnread > 0` (`BlocBuilder<ConversationsBloc, ConversationsState>`, `Semantics(label: 'Unread messages')`); it pushes `ConversationsScreen` with `BlocProvider.value(value: context.read<ConversationsBloc>())`
- [ ] T059 [US3] In `lib/features/profile/bloc/profile_bloc.dart` inject `SyncPublicProfile`; in `_onUpdated`, after `updateUserProfile` succeeds and `result.fullName != currentUser.fullName`, call `syncPublicProfile(result.fullName)` in its **own** `try/on AppException` that calls `appErrorCubit.showError` but still emits `isSuccess: true` (sync point 2)
- [ ] T060 [US3] Register in `injection_container.dart`: `WatchConversations`, `GetChatTarget`, `registerFactory(() => ConversationsBloc(...))`, the new `ChatBloc` dependency, and `syncPublicProfile: sl()` in the `ProfileBloc` registration

**Checkpoint**: Q7–Q9, Q16, Q17, Q18a pass; US1 and US2 still pass

---

## Phase 6: User Story 6 — Access restricted to participants (Priority: P1)

**Goal**: Prove that only participants can access a conversation, enforced by rules, not the UI (FR-032–FR-034)

**Independent Test**: quickstart Q15 plus the rules suite

- [ ] T061 [US6] Review `firestore_tests/chat.rules.test.js` against FR-032–FR-034 and add any missing denied case: non-participant (buyer, seller and **admin** roles) `get`/`list`/create/update on a conversation and its messages; a participant forging `senderId`; a participant deleting the other user's message; signed-out access. Run the suite in the **Firebase Emulator Terminal**
- [ ] T062 [US6] Run quickstart Q15 with accounts O and M (admin) against the emulator or the deployed rules and record the result in `specs/001-buyer-seller-chat/quickstart.md` notes if anything deviates

**Checkpoint**: SC-008 satisfied (0 non-participant accesses)

---

## Phase 7: User Story 5 — Deleting messages and conversations (Priority: P3)

**Goal**: Delete own message for everyone; delete a conversation from own side (FR-027, FR-027a, FR-047)

**Independent Test**: quickstart Q13, Q14

### Tests for User Story 5

- [ ] T063 [P] [US5] In `chat_bloc_test.dart` add group `delete` (`ChatMessageDeletePressed` calls `DeleteMessage` only for own messages; error → `showError`) and in `conversations_bloc_test.dart` add `ConversationDeletePressed` → `DeleteConversation`

### Implementation for User Story 5

- [ ] T064 [US5] In `chat_remote_datasource.dart` implement `deleteMessage(cid, mid)` as a transaction: message `deleted: true`, `text: ""`; if `lastMessage.id == mid` set `lastMessage.deleted: true`, `lastMessage.text: ""`; if the recipient had not read it (`createdAt > lastReadAt[other]`) decrement `unreadCount.<other>` (never below 0); and `deleteConversation(cid)`: `clearedAt.<uid>` = server time, `unreadCount.<uid>` = 0
- [ ] T065 [US5] Implement both in `chat_repository_impl.dart`; create use cases `lib/features/chat/domain/usecase/delete_message.dart` (`DeleteMessage`) and `delete_conversation.dart` (`DeleteConversation`)
- [ ] T066 [P] [US5] In `lib/shared/components/general_widget/confirm_delete_dialog.dart` add optional named `title` and `message` parameters defaulting to `'Delete car'` and `'Are you sure you want to delete this car?'` so existing callers are unchanged
- [ ] T067 [US5] In `message_bubble.dart` show "This message was deleted" for deleted messages; on long press of an own, non-deleted message open a bottom sheet with "Delete" → `confirmDelete(context, title: 'Delete message', message: 'Delete this message for everyone?')` → `ChatMessageDeletePressed`; no option on the other user's messages; disabled while offline (FR-047, FR-014b)
- [ ] T068 [US5] Add `ChatMessageDeletePressed` to `chat_bloc.dart` and `ConversationDeletePressed(cid)` to `conversations_bloc.dart`; in `conversation_tile.dart` long press → `confirmDelete(context, title: 'Delete conversation', message: 'This removes the conversation from your list only.')` → `ConversationDeletePressed`; inject `DeleteMessage` / `DeleteConversation` and update DI

**Checkpoint**: Q13, Q14 pass

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T069 In the **Flutter Terminal** run `flutter analyze` and fix every new issue
- [ ] T070 In the **Flutter Terminal** run `flutter test test/features/chat` (all green). `test/widget_test.dart` is the pre-existing broken counter template and is out of scope
- [ ] T071 In the **Firebase Emulator Terminal** run `firebase emulators:exec --only firestore --project demo-bitcar "npm --prefix firestore_tests test"` (all suites green)
- [ ] T072 Run the full quickstart end-to-end table (Q1–Q22, Q21a) and the regression row Q18 (register, profile edit, favorites, search, my cars, admin edit/delete car and ad)
- [ ] T073 Confirm `git status` shows no `build/`, `node_modules/`, generated plugin registrants or `pubspec.yaml` changes
- [ ] T074 **After explicit owner approval only**: deploy with `firebase deploy --only firestore:rules,firestore:indexes` (never a bare `firebase deploy`; answer **No** if the CLI offers to delete indexes)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies
- **Foundational (Phase 2)**: depends on Setup (T004 before T006–T008); blocks all stories
- **US1 (Phase 3)**: after Foundational
- **US2 (Phase 4)**: after US1 (extends `ChatBloc`, `message_list.dart`, `message_bubble.dart`, datasource)
- **US3 (Phase 5)**: after Foundational; T057 needs `ChatBloc` from US1. Can run in parallel with US2 except shared files (`chat_remote_datasource.dart`, `chat_repository_impl.dart`, `chat_bloc.dart`, `injection_container.dart`)
- **US6 (Phase 6)**: after T009; independent of the Flutter stories
- **US5 (Phase 7)**: after US1 (bubble, bloc) and US3 (tile, conversations bloc)
- **Polish (Phase 8)**: after all stories

### Within Each Story

- Tests first (they must fail), then datasource → repository impl + use cases → bloc → UI → DI
- `chat_remote_datasource.dart`, `chat_repository_impl.dart`, `chat_bloc.dart` and `injection_container.dart` are
  shared files: tasks that touch them are sequential

## Parallel Examples

```text
# Setup
T001 package.json   T002 .gitignore   T003 firebase.json emulators

# Foundational
T006 existing.rules.test.js   T007 public_profiles.rules.test.js   T008 chat.rules.test.js   T010 indexes
T011 message_status   T012 chat_validator   T013 conversation entity   T014 message entity   T015 domain wrappers
T023 fake repository   T024 validator test   T025 models test

# US1
T031 use cases   T033 message_input_bar   T034 message_bubble

# US2
T040 status tests   T041 pagination tests   T042 message_list widget test   then T048 bubble statuses   T049 offline banner

# US3
T051 conversations bloc test   T055 conversation_tile
```

## Implementation Strategy

### MVP (User Story 1)

1. Phase 1 + Phase 2 (rules green, shared types)
2. Phase 3 → validate Q1–Q5 → **stop and review**

### Incremental Delivery

1. US1: start/resume from car (MVP)
2. US2: live statuses, read receipts, pagination, offline
3. US3: conversations list, red dot, name sync
4. US6: security verification
5. US5: deletion
6. Polish, then deploy rules/indexes only with owner approval

## Notes

- [P] = different files, no dependency on incomplete tasks
- User Story 4 (notifications) is deferred: no FCM, no permission prompt, no `firebase_messaging` import
- Commit after each task or logical group, only when the owner asks
- `checklists/chat-review.md` items are reviewer-owned; implementation does not tick them
