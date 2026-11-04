# Contract: Chat Domain (repository + use cases)

**Layer**: `lib/features/chat/domain/` (plain Dart: `dart:async` only, no Flutter/Firebase imports)
**Implemented by**: `ChatRepositoryImpl` → `ChatRemoteDataSource` (Firestore + Auth). Rev. 2 (Spark): no messaging
datasource; push is deferred ([future-push-notifications.md](future-push-notifications.md)).

## `ChatRepository` (`domain/repositories/chat_repository.dart`)

| Method | Returns | Behavior | Errors (`AppException`) |
|---|---|---|---|
| `String get currentUserId` | uid | Signed-in uid | `auth` if signed out |
| `Future<void> syncPublicProfile(String displayName)` | – | Writes own `publicProfiles/{uid}` `{ displayName }` only if missing or different (research D14), and never when the read came from the cache, so no write is queued offline (FR-014b) | permission (name does not match `users.fullName`), network; callers treat it as best effort |
| `Future<ChatTarget> openChatWith({required String otherUserId})` | `ChatTarget` | Deterministic id; reads the conversation once (exists → new vs existing, FR-003/FR-004); if it does not exist, reads the other user's public profile (`displayName`, or `"BitCar user"` if absent) for the header and the creation snapshot. No write | `validation` if `otherUserId == currentUserId`; network/firestore |
| `Future<ChatTarget> getChatTarget(String conversationId)` | `ChatTarget` | Opening from the list (and, in a future phase, from a notification). One read of the conversation, no profile read and no write, so names never delay or block opening. `otherUserName` is the stored name, or the placeholder if absent. `ownNameIsPlaceholder` is true only when own stored name is the placeholder and the data came from the server | `notFound`, `permission` |
| `Future<void> fillOwnPlaceholderName(String conversationId)` | – | Reads own `publicProfiles/{uid}`; if it is missing or from the cache, does nothing; otherwise updates only `participantNames.<uid>` to its `displayName`, which is exactly what rules `isFillOwnName` allow (D14). Best effort: run by `ChatBloc` without waiting | network, permission |
| `Stream<ConversationsUpdate> watchConversations()` | stream | Current user's conversations ordered by `lastMessageAt` desc, filtered by `isVisibleInList`; cached data first | errors delivered on the stream |
| `Stream<MessagesUpdate> watchLatestMessages({required String conversationId, required int pageSize})` | stream | Bounded live window (research D17): listener on the newest `pageSize` messages after own `clearedAt` (`orderBy createdAt desc, __name__ desc, limit(pageSize)`), merged with the conversation doc listener to carry `otherLastReadAt`, own `unreadCount` and own `clearedAt`. The conversation doc is read first; the messages listener starts after its first snapshot and restarts when own `clearedAt` changes. Never listens without a limit | on the stream |
| `Future<MessagesPage> loadOlderMessages({required String conversationId, required MessageCursor before, DateTime? after, required int pageSize})` | `MessagesPage` | One-time read of the `pageSize` messages just older than `before` (`startAfter([Timestamp, id])`, same order, `createdAt > after` where `after` is own `clearedAt` from the latest `MessagesUpdate`); falls back to cache offline. `hasOlder` = false only if the **server** returned fewer than `pageSize` | network, permission |
| `String newMessageId(String conversationId)` | id | Local id generation, no network | – |
| `Future<void> sendMessage({required String conversationId, required String messageId, required String otherUserId, required String text})` | – | Transaction of research D4; on first message also creates the conversation with both name snapshots; idempotent for the same `messageId` | `validation` (rate limit: "You're sending messages too fast, try again shortly"; length), network, permission |
| `Future<void> markConversationRead(String conversationId)` | – | Own `unreadCount` → 0, own `lastReadAt` → server time; no-op if already 0 | network, permission |
| `Future<void> deleteMessage({required String conversationId, required String messageId})` | – | Delete for everyone + preview/unread fix-up (FR-027) | permission, network |
| `Future<void> deleteConversation(String conversationId)` | – | Own `clearedAt` → server time, own unread → 0 (FR-027a) | permission, network |

## Use cases (`domain/usecase/`, one action each, single `call`)

| File | Class | `call` signature |
|---|---|---|
| `sync_public_profile.dart` | `SyncPublicProfile` | `Future<void> call(String displayName)`; used by `ConversationsBloc` (app open) and `ProfileBloc` (name change) |
| `open_chat_with_seller.dart` | `OpenChatWithSeller` | `Future<ChatTarget> call(String sellerId)` |
| `get_chat_target.dart` | `GetChatTarget` | `Future<ChatTarget> call(String conversationId)` |
| `fill_own_placeholder_name.dart` | `FillOwnPlaceholderName` | `Future<void> call(String conversationId)`; used by `ChatBloc` |
| `watch_conversations.dart` | `WatchConversations` | `Stream<ConversationsUpdate> call()` |
| `watch_latest_messages.dart` | `WatchLatestMessages` | `Stream<MessagesUpdate> call(String conversationId, {int pageSize = 20})` |
| `load_older_messages.dart` | `LoadOlderMessages` | `Future<MessagesPage> call(String conversationId, MessageCursor before, {DateTime? after, int pageSize = 20})` |
| `create_message_id.dart` | `CreateMessageId` | `String call(String conversationId)` |
| `send_message.dart` | `SendMessage` | `Future<void> call({conversationId, messageId, otherUserId, text})` |
| `mark_conversation_read.dart` | `MarkConversationRead` | `Future<void> call(String conversationId)` |
| `delete_message.dart` | `DeleteMessage` | `Future<void> call({conversationId, messageId})` |
| `delete_conversation.dart` | `DeleteConversation` | `Future<void> call(String conversationId)` |
| `get_current_user_id.dart` | `GetCurrentUserId` | `String call()` |

13 use cases (`FillOwnPlaceholderName` added before B8, so the name fill never blocks opening and its errors reach a bloc). Rev. 4 (pagination, option A) replaced `WatchMessages` (growing `limit`) with `WatchLatestMessages`
(bounded live window) and `LoadOlderMessages` (one-time cursor read).

Removed in rev. 2 (push deferred): `RequestNotificationPermission`, `RegisterDeviceToken`, `UnregisterDeviceToken`,
`WatchNotificationTaps`.

## Datasource responsibilities (data layer)

| Class | File | Wraps | Rules |
|---|---|---|---|
| `ChatRemoteDataSource` | `data/datasource/chat_remote_datasource.dart` | `FirebaseFirestore`, `FirebaseAuth` | All Firestore paths, queries and transactions (`conversations`, `messages`, `publicProfiles`, `chatRateLimits`); messages queries ordered by `createdAt` + document id: a live `limit(20)` window and `startAfter([Timestamp, id])` reads built from the cursor's plain values (no `DocumentSnapshot` leaves the datasource; research D17); returns `ConversationModel`/`MessageModel` inside Dart records and **never** imports `features/chat/domain/` (the repository impl builds `ChatTarget`, `MessagesUpdate`, `MessagesPage`, `ConversationsUpdate`; constitution I); rate-limit transitions never use the device clock (research D10); every `Future` in `try { } catch (e) { throw ErrorMapper.map(e); }` inside `sessionGate.run`; streams via the private `_watchGuarded` (wraps `sessionGate.watch`): closed quietly when the gate is `closing` or no user is signed in; with `wipePending` and a signed-in user the error "Previous session data could not be cleared" is shown and no data loads; any other error is mapped with `ErrorMapper` (research D18 step 5) |

## Error mapping

`ErrorMapper.mapFirestore` maps `not-found` to "Requested car not found", which is wrong for chat. The chat
datasource throws its own `AppException`s for chat cases (rate limit, conversation not found, self chat) before the
mapper is reached, so the existing mapper is not changed.
