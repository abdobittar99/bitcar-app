---

description: "Task list for Buyer–Seller Chat"
---

# Tasks: Buyer–Seller Chat

**Input**: Design documents from `specs/001-buyer-seller-chat/`

**Prerequisites**: [plan.md](plan.md) (rev. 5), [spec.md](spec.md), [research.md](research.md) (D1–D18),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Included. The plan requires them: unit/widget tests under `test/` (whole `flutter test` must pass,
constitution quality gate) and the automated Security Rules suite (`firestore_tests/`, plan decisions 4 and 7).

**Organization**: Tasks are grouped by user story. User Story 4 (notifications) is **deferred** and has no tasks.
Sign-out data cleanup (FR-014b, FR-052, FR-053) is a cross-cutting phase.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: User story from spec.md (US1, US2, US3, US5, US6)

## Rules that apply to every task

- **Two terminals** (plan decision 8): `flutter` / `dart` commands only in the **Flutter Terminal** (JDK 17);
  `firebase emulators:*` and `npm --prefix firestore_tests ...` only in the **Firebase Emulator Terminal** (JDK 21 set
  for that session, see quickstart). Never change global `JAVA_HOME`, `flutter config` or Gradle settings.
- **No new pub packages**; `pubspec.yaml` is not modified. The only new dependencies are the dev-only npm packages
  in `firestore_tests/` (decision 4).
- **Firebase imports** (`cloud_firestore`, `firebase_auth`) only in datasources (and `SearchRepositoryImpl`, which
  already uses Firestore) and the models in `lib/models/`. Domain files and `lib/core/session/` are plain Dart.
- **Session gate** (research D18): every Firestore future goes through `sessionGate.run(...)` and every Firestore
  stream through `sessionGate.watch(...)`.
- **Error flow**: datasource methods wrap Firebase calls in `try { } catch (e) { throw ErrorMapper.map(e); }`
  (rethrow `AppException`s created by the app code as they are); streams use `.handleError` with the same mapping;
  blocs `catch AppException`, call `appErrorCubit.showError(e.message)` and reset loading flags.
- **Imports** use `package:car_shop/...`. Blocs are `registerFactory`; datasources, repositories, use cases and
  `SessionGate` `registerLazySingleton` in [injection_container.dart](../../lib/core/di/injection_container.dart).
- `AppException({required String message, required ErrorType type})`; `ErrorType` values used: `auth`, `validation`,
  `notFound`, `permission`, `network`, `cache`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Rules test package, emulator wiring, and a passing baseline `flutter test`

- [X] T001 [P] Create `firestore_tests/package.json`: `"private": true`, `"type": "commonjs"`, script `"test": "node --test"`, devDependencies `@firebase/rules-unit-testing` and its peer `firebase` (pick mutually compatible current versions and pin them exactly). Then, in the **Firebase Emulator Terminal**, run `Push-Location firestore_tests; npm install; Pop-Location` (`npm --prefix firestore_tests install` fails with npm 10 on Windows) and keep the generated `firestore_tests/package-lock.json`
- [X] T002 [P] Create `firestore_tests/.gitignore` containing `node_modules/`
- [X] T003 [P] Add an `"emulators": { "firestore": { "port": 8080 } }` block to `firebase.json`; leave the `functions` and `firestore` sections unchanged (`"rules": "firestore.rules"`, `"indexes": "firestore.indexes.json"`)
- [X] T004 Create `firestore_tests/helpers.js`: `initializeTestEnvironment({ projectId: 'demo-bitcar', firestore: { rules: fs.readFileSync(path.resolve(__dirname, '..', 'firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 } })`; export helpers `authed(uid)`, `unauthed()`, `seed(async (db) => ...)` (via `withSecurityRulesDisabled`), `clear()` (`clearFirestore`), `cleanup()`. No copy of the rules file anywhere in `firestore_tests/`
- [X] T005 Create `firestore_tests/config.test.js` (node:test): parse `../firebase.json` and assert `firestore.rules === 'firestore.rules'`, that `../firestore.rules` exists, and that no `*.rules` file exists inside `firestore_tests/`
- [X] T006 [P] Delete the default counter template `test/widget_test.dart` and create `test/core/errors/app_error_listener_test.dart` (no Firebase, no `sl`): pump `BlocProvider<AppErrorCubit>(create: (_) => AppErrorCubit())` around `MaterialApp(builder: (context, child) => AppErrorListener(child: child!), home: const Scaffold())`. Cases: (1) `showError('Network error')` → after `pump()`, `find.text('Network error')` inside a `SnackBar` finds one widget; (2) after that, `cubit.state` is `null`; (3) `clear()` on a fresh cubit → `find.byType(SnackBar)` finds nothing. In the **Flutter Terminal** run `flutter test` (whole suite) and confirm it passes

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Security Rules, shared domain types, session gate, data skeleton, DI, test fakes

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Security Rules (tests first, then rules)

> Write T007–T009 first; they must fail against today's allow-all `firestore.rules`, then pass after T010.

- [X] T007 [P] Write `firestore_tests/existing.rules.test.js` covering every case E1–E13 and the S1/S2 fixes in [contracts/firestore-security-rules.md](contracts/firestore-security-rules.md) (existing `users`, `cars`, `ads`, favorites accesses), both allowed and denied
- [X] T008 [P] Write `firestore_tests/public_profiles.rules.test.js`: R16–R20 (write another user's doc; extra fields; `displayName` ≠ own `users.fullName`; `list` of `publicProfiles`; signed-out `get`) plus allowed paths: signed-in `get` of one doc, create/refresh own doc with `displayName` (1–100 chars) equal to own `users/{uid}.fullName`, and changing `users.fullName` + `publicProfiles.displayName` in one batch (`getAfter`)
- [X] T009 [P] Write `firestore_tests/chat.rules.test.js`: R1–R15 from the rules contract (include an **admin** user in the non-participant cases R1–R4), plus allowed paths: create conversation + first message (with profile names; with `"BitCar user"` when the other user has no profile), send, mark read, delete own message, delete conversation (`clearedAt`), replace own placeholder with own `displayName`, new rate window after 60 s (seed `windowStart` in the past via `seed`), the full first-send transaction within the rules access budget, and the pagination queries: `orderBy createdAt desc, __name__ desc, limit 20` and `startAfter([createdAt, id]).limit(20)`, each with and without `where createdAt > clearedAt` (allowed for a participant, denied for a non-participant)
- [X] T010 Replace the allow-all `firestore.rules` with the rules in [contracts/firestore-security-rules.md](contracts/firestore-security-rules.md): helpers (`uid()`, `isParticipant(cid)`, `validText`, `placeholderName()` = `'BitCar user'`, `expectedName(u)`), `conversations/{cid}` (create with `participantNames` rule, own-map-entry updates, fill-own-placeholder update), `messages/{mid}` (`get`/`list` participants; create: `senderId == uid()`, text 1–1,000 chars, `deleted == false`, `createdAt == request.time`, keys exactly `senderId, text, createdAt, deleted`, rate limit; update: sender only, once, only `deleted: true` + `text: ""`; `delete` never), `publicProfiles/{uid}` (get signed-in, list never, owner create/update with keys exactly `['displayName']`, 1–100 chars, `== getAfter(/users/uid).fullName`, delete never), `chatRateLimits/{uid}` (≤ 20 messages / 60 s), and the existing collections per E1–E13. In the **Firebase Emulator Terminal** run `firebase emulators:exec --only firestore --project demo-bitcar "npm --prefix firestore_tests test"` until all suites pass
- [X] T011 [P] Add to the **root** `firestore.indexes.json` the composite index `conversations`: `participants` ARRAY_CONTAINS + `lastMessageAt` DESCENDING. Do not modify `project-root/firestore.indexes.json`

### Shared Dart types

- [X] T012 [P] Create `lib/core/enums/message_status.dart`: `enum MessageStatus { sending, sent, read, failed }`
- [X] T013 [P] Create `lib/core/validators/chat_validator.dart`: class `ChatValidator` with `static const maxLength = 1000` and `static String? validate(String text)` that trims and returns `null` when the trimmed length is 1–1,000, otherwise `'Message cannot be empty'` / `'Message is too long (max 1,000 characters)'`
- [X] T014 [P] Create `lib/entities/conversation.dart` (`ConversationEntity`): `id`, `participantIds`, `buyerId`, `sellerId`, `otherUserId`, `otherUserName`, `lastMessageText`, `isLastMessageDeleted`, `lastMessageSenderId` (String?), `lastMessageAt` (DateTime?), `unreadCount` (int, 0 if absent), `otherLastReadAt` (DateTime?), `clearedAt` (DateTime?); getter `isVisibleInList => lastMessageAt != null && (clearedAt == null || lastMessageAt!.isAfter(clearedAt!))`
- [X] T015 [P] Create `lib/entities/message.dart` (`MessageEntity`): `id`, `conversationId`, `senderId`, `text`, `createdAt` (DateTime?, null only for local pending), `isDeleted`, `status` (`MessageStatus`); `copyWith`
- [X] T016 [P] Create plain-Dart wrappers in `lib/features/chat/domain/model/`: `conversations_update.dart` (`ConversationsUpdate{conversations, isFromCache}`), `messages_update.dart` (`MessagesUpdate{messages, otherLastReadAt, unreadCount, clearedAt, isFromCache}`), `messages_page.dart` (`MessagesPage{messages, hasOlder, isFromCache}`), `message_cursor.dart` (`MessageCursor{createdAt, messageId}`), `chat_target.dart` (`ChatTarget{conversationId, otherUserId, otherUserName, exists}`), plus `const messagesPageSize = 20` in `message_cursor.dart`
- [X] T017 Create `lib/models/conversation_model.dart` (`ConversationModel extends ConversationEntity`, depends on T014): `factory fromMap(Map<String, dynamic> map, String id, String currentUid)` converting `Timestamp` → `DateTime` and per-uid map lookups (`participantNames`, `unreadCount`, `lastReadAt`, `clearedAt`, `lastMessage{id,text,senderId,deleted}`); a map key that is **present with a `null` value** (own pending `serverTimestamp()` from a plain `update`; `snapshots()` in cloud_firestore 6.1.0 has no `serverTimestampBehavior`) is read as `DateTime.now()`; `static String idFor(String a, String b)` returning the two uids sorted and joined with `_`
- [X] T018 Create `lib/models/message_model.dart` (`MessageModel extends MessageEntity`, depends on T015): `factory fromMap(map, id, conversationId)` with `status: MessageStatus.sent` (read is applied later in `ChatState`); a `null` `createdAt` (not expected, sends are transactions) yields `status: MessageStatus.sending` and such a message is never used as a cursor; `static Map<String, dynamic> toCreateMap({required String senderId, required String text})` returning exactly `senderId`, `text`, `createdAt: FieldValue.serverTimestamp()`, `deleted: false`
- [X] T019 Create `lib/features/chat/domain/repositories/chat_repository.dart`: abstract `ChatRepository` with every method and signature in [contracts/chat-repository.md](contracts/chat-repository.md) (`currentUserId`, `syncPublicProfile`, `openChatWith`, `getChatTarget`, `watchConversations`, `watchLatestMessages`, `loadOlderMessages`, `newMessageId`, `sendMessage`, `markConversationRead`, `deleteMessage`, `deleteConversation`)

### Session gate (research D18, FR-053)

- [X] T020 [P] Create `test/core/session/session_gate_test.dart`: `run` executes while `open` and counts in-flight operations; `closeForSignOut()` refuses new `run`/`watch` calls with `AppException(type: ErrorType.auth)`, cancels every stream registered through `watch` (listeners get *done*, no error), and completes only after in-flight operations finish or 5 s pass (use `fakeAsync`); in `wipePending`, `run` calls `retryWipe` once, continues on success (state → `open`) and throws `AppException(type: ErrorType.cache, message: 'Previous session data could not be cleared. Please try again.')` on failure; `open()` restores normal operation
- [X] T021 Create `lib/core/session/session_gate.dart` (plain Dart, imports only `dart:async` and `core/errors`): class `SessionGate` with state enum `open | closing | wipePending`, `Future<T> run<T>(Future<T> Function() op)`, `Stream<T> watch<T>(Stream<T> Function() open)`, `Future<void> closeForSignOut({Duration drainTimeout = const Duration(seconds: 5)})`, `void markWipePending()`, `void open()`, `bool get isOpen`, and `Future<void> Function()? retryWipe` (behavior exactly as in research D18 and T020)
- [X] T022 Register `SessionGate` as `registerLazySingleton(() => SessionGate())` at the top of `init()` in `lib/core/di/injection_container.dart` (registration only; constructors receive it in T023)
- [X] T023 Inject `SessionGate` into `lib/features/auth/data/datasource/auth_remote_datasource.dart`, `lib/features/car/data/datasource/cars_remote_datasource.dart`, `lib/features/favorite/data/datasource/favorite_remote_datasource.dart`, `lib/features/feeds/data/datasource/feeds_remote_datasource.dart`, `lib/features/profile/data/datasource/user_remote_datasource.dart`, `lib/features/home/data/datasource/home_remote_datasource.dart` and `lib/features/search/data/repositories/search_repository_impl.dart` (constructor parameter + `sl()` in each registration in `injection_container.dart`); wrap every Firestore future in `sessionGate.run(() async { ... })` keeping the existing `try/catch ErrorMapper.map` inside. In `HomeRemoteDataSource`, `logOut`, `hasPendingWrites` and `completePendingWipe` (T076) manage the gate themselves and are not wrapped. No behavior change while signed in; `flutter analyze` and `flutter test` stay green

### Chat data layer skeleton

- [X] T024 Create `lib/features/chat/data/datasource/chat_remote_datasource.dart`: `ChatRemoteDataSource(this.firestore, this.auth, this.sessionGate)`; `static const placeholderName = 'BitCar user'`; `String get currentUserId` (throw `AppException(type: ErrorType.auth)` if signed out); `Future<void> syncPublicProfile(String displayName)` (read `publicProfiles/{uid}`, `set({'displayName': displayName})` only if missing or different); `Future<String> readPublicName(String uid)` (`displayName` or `placeholderName`); a stream helper `watchGuarded` (wraps `sessionGate.watch`; public for now only to avoid `unused_element`, review making it private once T034/T057 use it) that maps stream errors with an **explicit check, never a bare `catch`** (constitution III): `if (sessionGate.state == SessionGateState.closing || auth.currentUser == null)` the stream is closed quietly (end of session, nothing shown); in `wipePending` with a signed-in user the gate's "Previous session data could not be cleared" error is shown and no data loads; every other error is rethrown as `ErrorMapper.map(e)` and reaches the bloc (research D18 step 5). Every future via `sessionGate.run`, every stream via `watchGuarded`
- [X] T025 Create `lib/features/chat/data/repositories/chat_repository_impl.dart`: `ChatRepositoryImpl(this.dataSource) implements ChatRepository`; implement `currentUserId` and `syncPublicProfile`; other methods `throw UnimplementedError()` until their story task replaces them
- [X] T026 [P] Create use cases `lib/features/chat/domain/usecase/get_current_user_id.dart` (`GetCurrentUserId`, `String call()`) and `lib/features/chat/domain/usecase/sync_public_profile.dart` (`SyncPublicProfile`, `Future<void> call(String displayName)`)
- [X] T027 Add a `// Chat` section to `lib/core/di/injection_container.dart`: `registerLazySingleton(() => ChatRemoteDataSource(sl(), sl(), sl()))`, `registerLazySingleton<ChatRepository>(() => ChatRepositoryImpl(sl()))`, `GetCurrentUserId`, `SyncPublicProfile`

### Test support

- [X] T028 [P] Create `test/features/chat/fakes/fake_chat_repository.dart`: in-memory `FakeChatRepository implements ChatRepository` with `StreamController`s to push `ConversationsUpdate` / `MessagesUpdate` (and to close them, simulating sign-out), queued `MessagesPage` results for `loadOlderMessages`, configurable `AppException` per method, and call recorders (arguments + counts)
- [X] T029 [P] Create `test/features/chat/chat_validator_test.dart`: empty, whitespace-only, 1 char, exactly 1,000 after trim, 1,001 chars
- [X] T030 [P] Create `test/features/chat/models_test.dart`: `ConversationModel.idFor` order-independence, `fromMap` per-uid lookups, `isVisibleInList` with/without `clearedAt`, `MessageModel.toCreateMap` keys exactly `senderId, text, createdAt, deleted`

**Checkpoint**: Rules suite green; `flutter analyze` clean and whole `flutter test` green (Flutter Terminal)

---

## Phase 3: User Story 1 — Starting or resuming a conversation from a car (Priority: P1) 🎯 MVP

**Goal**: "Chat with Seller" opens the single conversation for the pair, pre-filled with the car inquiry, and the
first send creates the conversation (FR-001–FR-008, FR-010, FR-026, FR-050)

**Independent Test**: quickstart Q1–Q5 — A opens S's car → "Chat with Seller", sends the inquiry; another car of S
opens the same conversation with the new inquiry in the input; no conversation exists until the first send

### Tests for User Story 1

- [X] T031 [P] [US1] In `test/features/chat/chat_bloc_test.dart` add group `start`: `ChatStarted.fromCar` sets `draft` to `"Hello, I'm interested in your <brand> <model> (<year>). Is it still available?"` and replaces any previous draft (FR-050); `isNewConversation` true when `!target.exists` and no messages; self-chat `AppException` goes to `AppErrorCubit`; `ChatMessageSubmitted` with whitespace sends nothing; a valid submit adds a `sending` pending message and calls `sendMessage` with the id from `CreateMessageId`; `currentUserId` comes from `GetCurrentUserId` and marks which messages are own (`senderId == currentUserId`); the messages stream completing (*done*) emits no error, while a stream `AppException` **is** shown through `AppErrorCubit` (`_MessagesFailed`)

### Implementation for User Story 1

- [X] T032 [US1] In `chat_remote_datasource.dart` implement `openChatWith(otherUserId)` returning the record `({String conversationId, String otherUserId, String otherUserName, bool exists})` (no domain types in the datasource, constitution I): throw `AppException(message: "You can't chat with yourself", type: ErrorType.validation)` if equal to own uid; `cid = ConversationModel.idFor`; one `get` of `conversations/{cid}`; if it exists → `exists: true, otherUserName: participantNames[other]`, else `otherUserName = readPublicName(other)`; no writes (FR-002)
- [X] T033 [US1] In `chat_remote_datasource.dart` implement `newMessageId(cid)` (`collection('conversations').doc(cid).collection('messages').doc().id`) and `sendMessage(...)` as the transaction of research D4, writing field values exactly as the rules contract expects: read conversation, message doc and `chatRateLimits/{uid}`; if the message exists return (idempotent retry, FR-014); rate-limit transition **without using the device clock**: if the doc is missing → create `{count: 1, windowStart: serverTimestamp}`; if `count < 20` → same window (`count + 1`, `windowStart` unchanged); if `count == 20` → new window (`count: 1`, `windowStart: serverTimestamp`) and let the rules decide by `request.time`; if that new-window attempt fails with `permission-denied`, throw `AppException(message: "You're sending messages too fast, try again shortly", type: ErrorType.validation)` (FR-014a); create the conversation when missing (`participants` sorted, `buyerId` = uid, `sellerId` = other, `participantNames` from `readPublicName` for both, `createdAt` server time); write the message with `MessageModel.toCreateMap`; update `lastMessage {id, text, senderId, deleted: false}`, `lastMessageAt`, `unreadCount.<other>` +1, and the rate-limit doc
- [X] T034 [US1] In `chat_remote_datasource.dart` implement `watchLatestMessages(conversationId, pageSize)` through `watchGuarded` (then review making `watchGuarded` private, research D18 step 5), emitting the record `({List<MessageModel> messages, DateTime? otherLastReadAt, int unreadCount, DateTime? clearedAt, bool isFromCache})`. Order of listeners: (1) listen to the conversation doc (`snapshots(includeMetadataChanges: true)`); (2) on its first snapshot, start the `messages` listener ordered by `createdAt` desc + `FieldPath.documentId` desc, `limit(pageSize)`, plus `where createdAt > clearedAt[uid]` when set, also with metadata changes; (3) when `clearedAt[uid]` changes, cancel and restart the messages listener with the new value. Merge both into the record with a `StreamController` (messages oldest-first); cancel both listeners when the controller is cancelled; errors through the T024 helper. A not-yet-existing conversation emits an empty record. No listener without a limit
- [X] T035 [US1] In `chat_repository_impl.dart` implement `openChatWith` (record → `ChatTarget`), `newMessageId`, `sendMessage`, `watchLatestMessages` (record → `MessagesUpdate` with entities). All domain wrappers are built here, never in the datasource (constitution I)
- [X] T036 [P] [US1] Create use cases in `lib/features/chat/domain/usecase/`: `open_chat_with_seller.dart` (`OpenChatWithSeller`, `Future<ChatTarget> call(String sellerId)`), `create_message_id.dart` (`CreateMessageId`, `String call(String conversationId)`), `send_message.dart` (`SendMessage`, named `conversationId, messageId, otherUserId, text`), `watch_latest_messages.dart` (`WatchLatestMessages`, `Stream<MessagesUpdate> call(String conversationId, {int pageSize = messagesPageSize})`)
- [X] T037 [US1] Create `lib/features/chat/chat_room/bloc/chat_event.dart`, `chat_state.dart`, `chat_bloc.dart` per [contracts/ui-screens-and-blocs.md](contracts/ui-screens-and-blocs.md): abstract `ChatEvent`; inject `GetCurrentUserId` and keep `currentUserId` in `ChatState` (own vs other messages, own-only delete, read status for own messages); `ChatStarted.fromCar(CarEntity)` (resolve target, set inquiry draft, subscribe `WatchLatestMessages`); `ChatMessageSubmitted(text)` (validate with `ChatValidator`; add pending `sending` message; `SendMessage`; on `AppException` mark it `failed` and `showError`); private `_MessagesUpdated` (replace `liveMessages`, drop pending ids that arrived) and `_MessagesFailed`; stream *done* is a no-op; `ChatState` with `copyWith` and all fields of the contract (paging fields with defaults for now) and the `messages` getter (union by id, sorted by `(createdAt, id)`, pending last); keep the `StreamSubscription`, cancel it before re-subscribing and in `close()`; never `emit` from the listener callback
- [X] T038 [P] [US1] Create `lib/features/chat/chat_room/ui/message_input_bar.dart`: `TextField` with `maxLength: 1000` counter, initial text from `draft`, send `IconButton` disabled when the trimmed text is empty
- [X] T039 [P] [US1] Create `lib/features/chat/chat_room/ui/message_bubble.dart`: own messages right-aligned in the app's blue, others left in light grey; send time with `DateFormat.jm()` (FR-048); long text wraps fully
- [X] T040 [US1] Create `lib/features/chat/chat_room/ui/message_list.dart` (base): `CustomScrollView` with a `center` key and two `SliverList`s (older-than-center above, center and newer below; center = oldest message of the first live window); jump to the newest message on first build. Takes plain values and callbacks so a widget test can drive it
- [X] T041 [US1] Create `lib/features/chat/chat_room/ui/chat_screen.dart` (`ChatScreen`): `AppBar` title = `target.otherUserName`; when `isNewConversation`, hint "Start the conversation with <name>"; `message_list.dart` + `message_input_bar.dart`; `BlocBuilder<ChatBloc, ChatState>`
- [X] T042 [US1] Inject the existing `GetCurrentUser` into `lib/features/car/car_details/bloc/car_details_bloc.dart` and add `currentUserId` (String?) to `car_details_state.dart` `copyWith`; load it in `_onStarted` alongside the car; update the `CarDetailsBloc` registration in `injection_container.dart` to `CarDetailsBloc(getCarDetails: sl(), getCurrentUser: sl(), appErrorCubit: sl())`
- [X] T043 [US1] In `lib/features/car/car_details/ui/car_details_screen.dart` add `AppButton(text: 'Chat with Seller', icon: Icons.chat_bubble_outline, ...)` directly above the existing `'Contact Seller'` button (unchanged), shown only when `currentUserId != null && car.sellerId != currentUserId`; it pushes `ChatScreen` via `MaterialPageRoute` with `BlocProvider(create: (_) => sl<ChatBloc>()..add(ChatStarted.fromCar(car)))`
- [X] T044 [US1] Register in `injection_container.dart`: `OpenChatWithSeller`, `CreateMessageId`, `SendMessage`, `WatchLatestMessages` (lazy singletons) and `registerFactory(() => ChatBloc(...))` with named required dependencies and `appErrorCubit: sl()`

**Checkpoint**: Q1–Q5 pass; `flutter analyze` clean; whole `flutter test` green

---

## Phase 4: User Story 2 — Exchanging messages live (Priority: P1)

**Goal**: Live two-way messaging with sending/sent/read/failed, retry, rate limit, read marking, offline reading,
and history in batches of 20 (FR-011–FR-015, FR-014a/b, FR-037–FR-046, FR-048, FR-049, FR-051)

**Independent Test**: quickstart Q6, Q10–Q12, Q19–Q22, Q21a, Q26 on two devices / the emulator

### Tests for User Story 2

- [X] T045 [P] [US2] In `test/features/chat/chat_bloc_test.dart` add group `statuses`: pending → sent when its id arrives; own messages become `read` when `createdAt <= otherLastReadAt`, including messages in `loadedMessages`; `AppException` → `failed`, text kept; `ChatMessageRetried` re-sends the same id with no duplicate; rate-limit message shown; `MarkConversationRead` called when visible and `unreadCount > 0`, not while invisible; client pre-check refuses the 21st send within 60 s; pending messages are not counted in the 20 and never become the cursor, and a sent message appears once after its id arrives (FR-037). Group `stream errors` (FR-054, use `fakeAsync`): a `network` stream error keeps all loaded messages, sets `failedRetryable`, shows the error once and retries automatically **once** after 3 s; a second failure shows Retry without another automatic retry; `ChatRetried` re-subscribes exactly once (two quick `ChatRetried` → one `watchLatestMessages` call) and the new window merges without duplicates; a `permission` error sets `failedFatal`, no automatic retry, `ChatRetried` ignored; stream *done* changes nothing; `close()` cancels the retry timer
- [X] T046 [P] [US2] In `test/features/chat/chat_bloc_test.dart` add group `pagination`: messages pushed out of the live window move to `loadedMessages` and stay; union without duplicates across live/loaded/pending; order by `(createdAt, id)` with equal timestamps; two `ChatLoadOlderRequested` in a row → one `loadOlderMessages` call; cursor = oldest server-confirmed message overall; server batch < 20 → `hasOlder == false`; 40 messages → one extra empty call ends it; cache-only short batch keeps `hasOlder`, sets `olderBatchIncomplete`, and is re-requested on the next server update; error keeps messages, sets `olderLoadFailed`, retry uses the same cursor
- [X] T047 [P] [US2] Create `test/features/chat/message_list_test.dart` (widget test): adding older items keeps the top visible message at the same screen offset; adding a newer item while scrolled up keeps the offset and shows the "New messages" chip; at the bottom a newer item scrolls into view; `onReachTop` fires within 200 px of the top; top row shows progress / "Couldn't load older messages · Retry" / "Beginning of the conversation" with `Semantics` labels; day separators "Today" / "Yesterday" / date

### Implementation for User Story 2

- [X] T048 [US2] In `chat_remote_datasource.dart` implement `loadOlderMessages(conversationId, {required DateTime beforeCreatedAt, required String beforeMessageId, DateTime? after, required int pageSize})` through `sessionGate.run`: one-time `get()` ordered by `createdAt` desc + `FieldPath.documentId` desc, `startAfter([Timestamp.fromDate(beforeCreatedAt), beforeMessageId])`, `limit(pageSize)`, plus `where createdAt > after` when `after` (the user's `clearedAt` from the latest `MessagesUpdate`) is set; return the record `({List<MessageModel> messages, bool hasOlder, bool isFromCache})` with `isFromCache` from snapshot metadata and `hasOlder = isFromCache || docs.length == pageSize`. Never `startAfterDocument` (research D17)
- [X] T049 [US2] In `chat_remote_datasource.dart` implement `markConversationRead(cid)`: update `unreadCount.<uid>` = 0 and `lastReadAt.<uid>` = server time; no-op when already 0
- [X] T050 [US2] Implement both in `chat_repository_impl.dart` (`loadOlderMessages(cid, MessageCursor before, {DateTime? after, pageSize})` unpacks the cursor and builds `MessagesPage` from the record) and create use cases `lib/features/chat/domain/usecase/load_older_messages.dart` (`LoadOlderMessages`) and `mark_conversation_read.dart` (`MarkConversationRead`)
- [X] T051 [US2] Extend `chat_bloc.dart` / `chat_event.dart` / `chat_state.dart`: `ChatMessageRetried(messageId)`, `ChatVisibilityChanged(isVisible)`, `ChatLoadOlderRequested` (guard: ignore if `isLoadingOlder`, `!hasOlder` or no cursor; emit `isLoadingOlder: true` before the first `await`); window-slide handling in `_MessagesUpdated`; `otherLastReadAt` → `read` in the `messages` getter; `olderBatchIncomplete` re-request when an update is not from cache; keep `clearedAt` from the latest `MessagesUpdate` in state and pass it as `after` to `LoadOlderMessages`; mark-all-read when visible and `unreadCount > 0` (FR-015); `isOffline` from `isFromCache`; client rate pre-check (≤ 20 sends / 60 s); live window failure handling per the UI contract: `_MessagesFailed` clears the subscription, moves `liveMessages` into `loadedMessages`, sets `streamStatus` (`failedRetryable` for `network`/`firestore`/`unknown`/`platform`/`server`/`cache`, `failedFatal` for `permission`/`notFound`/`auth`/`validation`), schedules one automatic `ChatRetried` after 3 s (only if `!autoRetryUsed`; `Timer` cancelled in `close()`); `ChatRetried` guarded (status `failedRetryable` and no subscription), cancels any leftover subscription, re-subscribes, first update → `live` (FR-054); inject `LoadOlderMessages`, `MarkConversationRead` and update the DI registration
- [X] T052 [US2] Complete `message_list.dart`: older batches in the sliver above the center; top row (progress while `isLoadingOlder`, "Couldn't load older messages · Retry" when `olderLoadFailed`, "Beginning of the conversation" when `!hasOlder`; hidden offline with an incomplete batch; `Semantics` labels, FR-049); `ScrollController` sends `onReachTop` when `pixels <= minScrollExtent + 200`; within 100 px of the bottom new messages scroll into view, otherwise a "New messages" chip that scrolls to the bottom (FR-045); scroll to the bottom after send/retry (FR-046); day separators "Today" / "Yesterday" / `DateFormat.yMMMd()` (FR-048); stay at the newest message when the keyboard opens (FR-051); dispose the controller
- [X] T053 [P] [US2] In `message_bubble.dart` add status icons for own messages (sending, sent, read, failed) with `Semantics` labels "Sending", "Sent", "Read", "Failed, tap to retry"; tapping a failed message sends `ChatMessageRetried` (FR-013, FR-014, FR-049)
- [X] T054 [P] [US2] Create `lib/features/chat/chat_room/ui/offline_banner.dart` (plain-language "You're offline. Showing saved messages." bar) and show it in `chat_screen.dart` when `isOffline` (FR-014b)
- [X] T055 [US2] In `chat_screen.dart` add a `WidgetsBindingObserver` sending `ChatVisibilityChanged` on resume/pause, wire `message_list.dart` callbacks (`onReachTop`, `onRetryOlder` → `ChatLoadOlderRequested`), keep `Scaffold(resizeToAvoidBottomInset: true)` with the input bar below the list; add the live-updates banner under the app bar: `failedRetryable` → "Live updates stopped." + **Retry** (`ChatRetried`), progress while `retrying`; `failedFatal` → error text without Retry and send/delete disabled (FR-054)

**B7 device-test fixes (2026-11-04, owner approved; no task renumbering)**: rate-limit `count` written with
`FieldValue.increment(1)` and one send at a time per screen (research D4); no repeated older requests offline at the
end of the cache, and a "No more saved messages" row (FR-043); offline banner only after 2 s of cached data
(UI contract).

**Checkpoint**: Q6, Q10–Q12, Q19–Q22, Q21a pass; tests green

---

## Phase 5: User Story 3 — Conversations list, unread counts and red dot (Priority: P1)

**Goal**: App-bar entry with red dot, live conversations list, opening from the list, public-name sync
(FR-016–FR-019, FR-021, FR-026, FR-028–FR-030, research D14)

**Independent Test**: quickstart Q7–Q9, Q16, Q17, Q18a — S on home sees the red dot; on the list the conversation
jumps to the top with preview, time and badge; opening clears the badge

### Tests for User Story 3

- [X] T056 [P] [US3] Create `test/features/chat/conversations_bloc_test.dart`: `ConversationsStarted` calls `GetCurrentUser`, then subscribes at once and runs `SyncPublicProfile(user.fullName)` in parallel: a sync that never completes does not delay the subscription or the list; a sync `network` `AppException` is not shown; any other sync `AppException` is shown once, and in both cases the list keeps working with no unhandled exception; a sync failing after `close()` causes no error in the bloc; group `no user`: a `GetCurrentUser` `AppException` is shown once and the sync is skipped; with a uid from the auth session (`GetCurrentUserId`) the list still subscribes; without one nothing subscribes and `hasError: true`, `isLoading: false`; `ConversationsRetried` then repeats `GetCurrentUser` first, and on success subscribes and runs the skipped sync; if it fails again nothing subscribes; two quick retries make one attempt; `totalUnread` is the sum of `unreadCount`. Group `offline` (`fakeAsync`): cached data followed by server data within 2 s never sets `isOffline`; only cached data for 2 s sets it, and server data clears it at once; `close()` leaves no pending timer. Stream error → `hasError: true`, `isLoading: false`; stream *done* (sign-out) shows no error while a stream `AppException` is shown; `ConversationsRetried` after a stream failure re-subscribes exactly once and, if the sync already ran, does not run it again; `close()` cancels the subscription

### Implementation for User Story 3

- [X] T057 [US3] In `chat_remote_datasource.dart` implement `watchConversations()` through `_watchGuarded` (`where('participants', arrayContains: uid).orderBy('lastMessageAt', descending: true)`, `snapshots(includeMetadataChanges: true)` → record `({List<ConversationModel> conversations, bool isFromCache})`; with no signed-in user no query runs) and `getChatTarget(cid)` through `sessionGate.run`, returning the `openChatWith` record plus `bool ownNameIsPlaceholder` (one `get` of the conversation, with no profile read and no write; missing → `AppException(message: 'Conversation not found', type: ErrorType.notFound)`; `otherUserName` = stored `participantNames[other]`, or `placeholderName` if absent; `ownNameIsPlaceholder` is true only when own entry is `placeholderName` and the snapshot is not from the cache). Add `fillOwnPlaceholderName(cid)` through `sessionGate.run`: `get` own `publicProfiles` doc; missing, or from the cache → return without writing; otherwise update **only** `participantNames.<uid>` to its `displayName`, exactly what rules `isFillOwnName` allows (the rules are not changed). Change `syncPublicProfile` (T024): when the read is from the cache, return without writing, so no write is queued offline (FR-014b)
- [X] T058 [US3] Implement both in `chat_repository_impl.dart` (`watchConversations` builds `ConversationsUpdate` from the datasource record `({List<ConversationModel> conversations, bool isFromCache})` and filters by `isVisibleInList`; `getChatTarget` builds `ChatTarget` including `ownNameIsPlaceholder`, a new `ChatTarget` field that defaults to `false`, so `openChatWith` is unchanged; add `fillOwnPlaceholderName` to the `ChatRepository` contract and implementation) and create use cases `lib/features/chat/domain/usecase/watch_conversations.dart` (`WatchConversations`), `get_chat_target.dart` (`GetChatTarget`) and `fill_own_placeholder_name.dart` (`FillOwnPlaceholderName`); add `fillOwnPlaceholderName` to `FakeChatRepository`, and repository tests for the new mapping and pass-through
- [X] T059 [US3] Create `lib/features/chat/conversations/bloc/conversations_event.dart`, `conversations_state.dart`, `conversations_bloc.dart` per the UI contract: `ConversationsStarted`, `ConversationsRetried`, private `_ConversationsUpdated` / `_ConversationsFailed` / `_OfflineDelayElapsed`; stream *done* is a no-op; the sync runs unawaited in a private async method with its own `try/on AppException` (`ErrorType.network` → not shown; otherwise `appErrorCubit.showError`), so it can never be an unhandled exception and never touches the list state; `isOffline` true only after 2 s of cached data with no server update (`offlineBannerDelay`, same behavior as `ChatBloc`), cleared at once by a server update; state `isLoading`, `hasError`, `isOffline`, `conversations`, `totalUnread` with `copyWith`; constructor `getCurrentUser`, `getCurrentUserId`, `syncPublicProfile`, `watchConversations`, `appErrorCubit`; never subscribes without a valid uid (from `GetCurrentUser`, otherwise the auth session through `GetCurrentUserId`); `ConversationsRetried` repeats `GetCurrentUser` whenever the sync has not started yet; subscription and timer cancelled in `close()`; a sync finishing after `close()` shows nothing
- [X] T060 [P] [US3] Create `lib/features/chat/conversations/ui/conversation_tile.dart`: other user's name, preview ("This message was deleted" when `isLastMessageDeleted`), time (`DateFormat.jm()` today, `DateFormat.yMMMd()` earlier), unread badge, `Semantics` for the badge
- [X] T061 [US3] Create `lib/features/chat/conversations/ui/conversations_screen.dart`: loading indicator; `EmptyState(icon: Icons.chat_bubble_outline, title: 'No conversations yet', subtitle: 'Start a chat from any car page.')`; error `EmptyState` with `buttonText: 'Retry'` → `ConversationsRetried`; offline banner; tap → `ChatScreen` with `BlocProvider(create: (_) => sl<ChatBloc>()..add(ChatStarted.fromConversation(c.id)))`
- [X] T062 [US3] First add to `test/features/chat/chat_bloc_test.dart` (group `start`): `ChatStarted.fromConversation` uses `GetChatTarget`, leaves `draft` empty (FR-009) and subscribes; a `notFound` `AppException` is shown; with `ownNameIsPlaceholder` true, `FillOwnPlaceholderName` runs without delaying the subscription, even if it never completes; its `network` `AppException` is not shown, any other is shown once, and the chat keeps working in both cases; a fill failing after the bloc is closed shows nothing and is not an unhandled exception; with the flag false it is not called. Then in `chat_bloc.dart` implement `ChatStarted.fromConversation(cid)` (`GetChatTarget`, empty draft, subscribe `WatchLatestMessages`, then the unawaited fill in its own `try/on AppException` with the same error rule as the sync in T059); inject `GetChatTarget` and `FillOwnPlaceholderName`
- [X] T063 [US3] In `lib/features/home/ui/home_layout.dart` add `BlocProvider(create: (_) => sl<ConversationsBloc>()..add(ConversationsStarted()))` to `MultiBlocProvider`, and an app-bar chat `IconButton` before the search icon with a red dot overlay when `totalUnread > 0` (`BlocBuilder<ConversationsBloc, ConversationsState>`, `Semantics(label: 'Unread messages')`); it pushes `ConversationsScreen` with `BlocProvider.value(value: context.read<ConversationsBloc>())`
- [X] T064 [US3] First create `test/features/profile/profile_bloc_sync_test.dart` (fake `ProfileRepository` + fake `ChatRepository`): name changed → `syncPublicProfile(newName)` called once; name unchanged → not called; sync throws `AppException` → error shown **and** `isSuccess: true`. Then in `lib/features/profile/bloc/profile_bloc.dart` inject `SyncPublicProfile`; in `_onUpdated`, after `updateUserProfile` succeeds and `result.fullName != currentUser.fullName`, call `syncPublicProfile(result.fullName)` in its **own** `try/on AppException` that calls `appErrorCubit.showError` but still emits `isSuccess: true` (sync point 2)
- [X] T065 [US3] Register in `injection_container.dart`: `WatchConversations`, `GetChatTarget`, `FillOwnPlaceholderName`, `registerFactory(() => ConversationsBloc(...))`, the two new `ChatBloc` dependencies, and `syncPublicProfile: sl()` in the `ProfileBloc` registration

**Checkpoint**: Q7–Q9, Q16, Q17, Q18a pass; US1 and US2 still pass

---

## Phase 6: User Story 6 — Access restricted to participants (Priority: P1)

**Goal**: Prove that only participants can access a conversation, enforced by rules, not the UI (FR-032–FR-034)

**Independent Test**: quickstart Q15 plus the rules suite

- [X] T066 [US6] Final review of `firestore_tests/chat.rules.test.js` against FR-032–FR-034 (cases written in T009): non-participant (buyer, seller and **admin** roles) `get`/`list`/create/update on a conversation and its messages; a participant forging `senderId`; a participant deleting the other user's message; signed-out access. Add only what is missing; run the suite in the **Firebase Emulator Terminal**
- [ ] T067 [US6] Run quickstart Q15 with accounts O and M (admin) against the emulator or the deployed rules and report any deviation in the implementation notes

**Decision R6 (2026-11-04, owner approved; no new tasks, no renumbering)**: the T066 review found that a participant
can lower the other user's unread count with no message deleted. The fix of research D19 is part of T066: rules cases
R21–R29 and the changed delete rule, with the existing allowed-path delete test updated to the new write. Deploying
it needs the owner's explicit approval at that moment, and must happen before T069 is used on a device.

**Checkpoint**: SC-008 satisfied (0 non-participant accesses)

---

## Phase 7: User Story 5 — Deleting messages and conversations (Priority: P3)

**Goal**: Delete own message for everyone; delete a conversation from own side (FR-027, FR-027a, FR-047)

**Independent Test**: quickstart Q13, Q14

### Tests for User Story 5

- [ ] T068 [P] [US5] In `chat_bloc_test.dart` add group `delete` (`ChatMessageDeletePressed` calls `DeleteMessage` only for own messages; error → `showError`) and in `conversations_bloc_test.dart` add `ConversationDeletePressed` → `DeleteConversation`

### Implementation for User Story 5

- [ ] T069 [US5] In `chat_remote_datasource.dart` implement, through `sessionGate.run`, `deleteMessage(cid, mid)` as a transaction, per research D19 (needs the D19 rules deployed first): read the conversation and the message; missing message → `AppException(message: 'Message not found', type: ErrorType.notFound)`; already `deleted` → return with no write; otherwise in one commit: message `deleted: true`, `text: ""`; conversation `lastDeletedMessageId: mid`; if `lastMessage.id == mid` set `lastMessage` to `{id: mid, text: "", senderId: uid, deleted: true}`, and never touch it otherwise; if the recipient has not seen it (`createdAt` later than both `lastReadAt[other]` and `clearedAt[other]`) and `unreadCount[other] > 0`, write `unreadCount.<other>: FieldValue.increment(-1)`, and never touch it otherwise. A `permission-denied` is retried **once** with fresh reads, then mapped with `ErrorMapper`; and `deleteConversation(cid)`: `clearedAt.<uid>` = server time, `unreadCount.<uid>` = 0
- [ ] T070 [US5] Implement both in `chat_repository_impl.dart`; create use cases `lib/features/chat/domain/usecase/delete_message.dart` (`DeleteMessage`) and `delete_conversation.dart` (`DeleteConversation`)
- [ ] T071 [P] [US5] In `lib/shared/components/general_widget/confirm_delete_dialog.dart` add optional named `title` and `message` parameters defaulting to `'Delete car'` and `'Are you sure you want to delete this car?'` so existing callers are unchanged
- [ ] T072 [US5] In `message_bubble.dart` show "This message was deleted" for deleted messages; on long press of an own, non-deleted message open a bottom sheet with "Delete" → `confirmDelete(context, title: 'Delete message', message: 'Delete this message for everyone?')` → `ChatMessageDeletePressed`; no option on the other user's messages; disabled while offline (FR-047, FR-014b)
- [ ] T073 [US5] Add `ChatMessageDeletePressed` to `chat_bloc.dart` and `ConversationDeletePressed(cid)` to `conversations_bloc.dart`; in `conversation_tile.dart` long press → `confirmDelete(context, title: 'Delete conversation', message: 'This removes the conversation from your list only.')` → `ConversationDeletePressed`; inject `DeleteMessage` / `DeleteConversation` and update DI

**Checkpoint**: Q13, Q14 pass

---

## Phase 8: Sign-out data cleanup (FR-014b, FR-052, FR-053; research D18)

**Purpose**: Wipe the Firestore cache on sign-out without losing unsynced changes silently; complete an interrupted
sign-out at startup; keep Firestore blocked while a wipe is pending

**Independent Test**: quickstart Q23 (real device), Q24, Q25

- [ ] T074 [P] Create `test/features/home/home_bloc_logout_test.dart` with a fake `HomeRepository`: `LogoutPressed` with no pending writes → `LogOut` called, no warning; with pending writes → `showUnsyncedWarning: true` and `LogOut` **not** called; `LogoutCancelled` → warning cleared, still signed in, `LogOut` not called; `LogoutConfirmed` → `isSigningOut: true`, `LogOut` called; `LogOut` throwing `AppException` → `showError`, `isSigningOut: false`; no `emit` after `close()`
- [ ] T075 [P] Add `static const firestoreWipePending = 'firestore_wipe_pending';` to `lib/core/cache/cache_keys.dart`
- [ ] T076 In `lib/features/home/data/datasource/home_remote_datasource.dart` (already has `SessionGate` from T023): `Future<bool> hasPendingWrites()` = `firestore.waitForPendingWrites().timeout(const Duration(seconds: 3))` → `false` when it completes, `true` on `TimeoutException`; `Future<void> logOut()` = research D18 step 3 exactly: `sessionGate.closeForSignOut()` → `CacheHelper.saveData(key: CacheKeys.firestoreWipePending, value: true)` → `firestore.terminate()` → `firestore.clearPersistence()` → remove marker → `auth.signOut()` → `sessionGate.open()`; on a wipe failure: keep marker, `sessionGate.markWipePending()`, still `auth.signOut()`, then throw `AppException(type: ErrorType.cache, message: 'Signed out, but saved data could not be cleared yet. It will be cleared before the next sign-in.')`; `Future<void> completePendingWipe()` = if marker set: `terminate()` → `clearPersistence()` → remove marker → `auth.signOut()` → `open()`, else no-op; on failure keep the marker, `markWipePending()` **and still `auth.signOut()`** (the interrupted sign-out is completed, same as `logOut`; no throw at startup). `logOut`, `hasPendingWrites` and `completePendingWipe` do **not** go through `sessionGate.run` (they manage the gate)
- [ ] T077 Add `hasPendingWrites()` and `completePendingSignOut()` to `lib/features/home/domain/repositories/home_repository.dart` and `lib/features/home/data/repositories/home_repository_impl.dart`; create use cases `lib/features/home/domain/usecase/has_pending_writes.dart` (`HasPendingWrites`, `Future<bool> call()`) and `lib/features/home/domain/usecase/complete_pending_sign_out.dart` (`CompletePendingSignOut`, `Future<void> call()`)
- [ ] T078 Update `lib/features/home/bloc/home_event.dart` (`LogoutConfirmed`, `LogoutCancelled`), `home_state.dart` (`showUnsyncedWarning`, `isSigningOut` with `copyWith`) and `home_bloc.dart` (inject `HasPendingWrites`; `LogoutPressed` → check → warning or sign-out; `LogoutConfirmed` → sign-out; `LogoutCancelled` → clear warning; guard every `emit` after `await` with `if (isClosed) return;`)
- [ ] T079 In `lib/features/home/ui/home_layout.dart`: `BlocListener<HomeBloc, HomeState>` shows, when `showUnsyncedWarning`, an `AlertDialog` "Some changes haven't been saved to the server yet and will be lost. Log out anyway?" with **Cancel** (`LogoutCancelled`) and **Log out** (`LogoutConfirmed`); while `isSigningOut`, replace the body with a blocking progress view "Signing out…" (no app bar actions, no bottom navigation)
- [ ] T080 In `lib/core/di/injection_container.dart` register `HasPendingWrites`, `CompletePendingSignOut`, add `hasPendingWrites: sl()` to `HomeBloc`, and set `sl<SessionGate>().retryWipe = () => sl<HomeRemoteDataSource>().completePendingWipe();`. In `lib/main.dart`, after `await init();` and **before** `runApp`, add `await sl<CompletePendingSignOut>()();`
- [ ] T081 **Real Android device test** (Flutter Terminal: `flutter run` on the device): run quickstart Q23 (user A loads conversations, chats with older batches, favorites, profile → sign out → user O signs in, online and with airplane mode → none of A's data appears; no `permission-denied` snackbar; Firestore works for O after the wipe, confirming the plugin re-creates the instance after `terminate`), Q24 (pending-write warning: Cancel keeps the change, Log out discards it) and Q25 (kill during sign-out → completed at next start). Record the results in the implementation notes; if the instance is **not** re-created after `terminate`, stop and report before continuing

**Checkpoint**: Q23–Q25 pass on a real device; whole `flutter test` green

---

## Phase 9: Polish & Cross-Cutting Concerns

- [ ] T082 In the **Flutter Terminal** run `flutter analyze` and fix every new issue
- [ ] T083 In the **Flutter Terminal** run `flutter test` (the **whole** suite: `test/core/`, `test/features/`; all green, constitution quality gate)
- [ ] T084 In the **Firebase Emulator Terminal** run `firebase emulators:exec --only firestore --project demo-bitcar "npm --prefix firestore_tests test"` (all suites green)
- [ ] T085 Run the full quickstart end-to-end table (Q1–Q26, Q18a, Q21a) and the regression row Q18 (register, profile edit, favorites, search, my cars, admin edit/delete car and ad, sign-out). Then, at the start of the measurement session, run the baseline probe from quickstart "Performance baseline probe" (10 reads, record median and p95); continue only if the median is ≤ 400 ms with no failed request (spec Assumptions), otherwise record the session as degraded and repeat on a better network. Then measure, on two real devices, 20 trials each (60 fps screen recording of both devices or a stopwatch): SC-003 message visible ≤ 3 s, SC-005 "read" ≤ 3 s, SC-006 existing conversation open ≤ 2 s, SC-011 older batch ≤ 2 s; record every value and the p95 in the implementation notes. If any p95 misses its target, stop and analyse before T087. No timing code is added to the app. Finally, review the visual style of the new UI (conversations screen, conversation tile, chat screen, bubbles, input bar, offline banner, app-bar chat icon and red dot, "Chat with Seller" button, sign-out dialog and "Signing out…" view) side by side with existing BitCar screens (home, car details, profile): same app-bar style (white background, no elevation), the app's blues (`Color(0xFF0D47A1)`, `Color.fromARGB(255, 1, 37, 90)`), shared components (`AppButton`, `EmptyState`, `confirmDelete`, `AppErrorListener` snackbars) and font usage; record any mismatch and fix it before T087 (FR-035)
- [ ] T086 Confirm `git status` shows no `build/`, `node_modules/`, generated plugin registrants or `pubspec.yaml` changes
- [ ] T087 **After explicit owner approval only**: deploy with `firebase deploy --only firestore:rules,firestore:indexes` (never a bare `firebase deploy`; answer **No** if the CLI offers to delete indexes)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies
- **Foundational (Phase 2)**: depends on Setup (T004 before T007–T009); blocks all stories. T021 before T022–T024
- **US1 (Phase 3)**: after Foundational
- **US2 (Phase 4)**: after US1 (extends `ChatBloc`, `message_list.dart`, `message_bubble.dart`, datasource)
- **US3 (Phase 5)**: after Foundational; T062 needs `ChatBloc` from US1. Can run in parallel with US2 except shared files (`chat_remote_datasource.dart`, `chat_repository_impl.dart`, `chat_bloc.dart`, `injection_container.dart`)
- **US6 (Phase 6)**: after T010; independent of the Flutter stories
- **US5 (Phase 7)**: after US1 (bubble, bloc) and US3 (tile, conversations bloc)
- **Sign-out cleanup (Phase 8)**: after T021–T023 (gate in place) and US3 (`ConversationsBloc` stream to verify); T081 last in the phase
- **Polish (Phase 9)**: after all phases

### Within Each Phase

- Tests first (they must fail), then datasource → repository impl + use cases → bloc → UI → DI
- `chat_remote_datasource.dart`, `chat_repository_impl.dart`, `chat_bloc.dart`, `home_remote_datasource.dart` and
  `injection_container.dart` are shared files: tasks that touch them are sequential

## Parallel Examples

```text
# Setup
T001 package.json   T002 .gitignore   T003 firebase.json emulators   T006 app_error_listener_test

# Foundational
T007 existing.rules.test.js   T008 public_profiles.rules.test.js   T009 chat.rules.test.js   T011 indexes
T012 message_status   T013 chat_validator   T014 conversation entity   T015 message entity   T016 domain wrappers
T020 session_gate_test   T026 chat use cases   T028 fake repository   T029 validator test   T030 models test

# US1
T036 use cases   T038 message_input_bar   T039 message_bubble

# US2
T045 status tests   T046 pagination tests   T047 message_list widget test   then T053 bubble statuses   T054 offline banner

# US3
T056 conversations bloc test   T060 conversation_tile

# Sign-out cleanup
T074 home bloc logout test   T075 cache key
```

## Implementation Strategy

### MVP (User Story 1)

1. Phase 1 + Phase 2 (rules green, gate in place, whole `flutter test` green)
2. Phase 3 → validate Q1–Q5 → **stop and review**

### Incremental Delivery

1. US1: start/resume from car (MVP)
2. US2: live statuses, read receipts, pagination, offline
3. US3: conversations list, red dot, name sync
4. US6: security verification
5. US5: deletion
6. Sign-out cleanup, verified on a real device
7. Polish, then deploy rules/indexes only with owner approval

## Notes

- [P] = different files, no dependency on incomplete tasks
- User Story 4 (notifications) is deferred: no FCM, no permission prompt, no `firebase_messaging` import
- Commit after each task or logical group, only when the owner asks
- `checklists/chat-review.md` items are reviewer-owned; implementation does not tick them
