# Contract: Chat Domain (repository + use cases)

**Layer**: `lib/features/chat/domain/` (plain Dart: `dart:async` only, no Flutter/Firebase imports)
**Implemented by**: `ChatRepositoryImpl` → `ChatRemoteDataSource` (Firestore + Auth). Rev. 2 (Spark): no messaging
datasource; push is deferred ([future-push-notifications.md](future-push-notifications.md)).

## `ChatRepository` (`domain/repositories/chat_repository.dart`)

| Method | Returns | Behavior | Errors (`AppException`) |
|---|---|---|---|
| `String get currentUserId` | uid | Signed-in uid | `auth` if signed out |
| `Future<void> syncPublicProfile(String displayName)` | – | Writes own `publicProfiles/{uid}` `{ displayName }` only if missing or different (research D14) | permission (name does not match `users.fullName`), network; callers treat it as best effort |
| `Future<ChatTarget> openChatWith({required String otherUserId})` | `ChatTarget` | Deterministic id; reads the conversation once (exists → new vs existing, FR-003/FR-004); if it does not exist, reads the other user's public profile (`displayName`, or `"BitCar user"` if absent) for the header and the creation snapshot. No write | `validation` if `otherUserId == currentUserId`; network/firestore |
| `Future<ChatTarget> getChatTarget(String conversationId)` | `ChatTarget` | Opening from the list (and, in a future phase, from a notification); if own entry in `participantNames` is the placeholder and own public profile exists, replaces it with own `displayName` (D14) | `notFound`, `permission` |
| `Stream<ConversationsUpdate> watchConversations()` | stream | Current user's conversations ordered by `lastMessageAt` desc, filtered by `isVisibleInList`; cached data first | errors delivered on the stream |
| `Stream<MessagesUpdate> watchLatestMessages({required String conversationId, required int pageSize})` | stream | Bounded live window (research D17): listener on the newest `pageSize` messages after own `clearedAt` (`orderBy createdAt desc, __name__ desc, limit(pageSize)`), merged with the conversation doc listener to carry `otherLastReadAt` and own `unreadCount`. Never listens without a limit | on the stream |
| `Future<MessagesPage> loadOlderMessages({required String conversationId, required MessageCursor before, required int pageSize})` | `MessagesPage` | One-time read of the `pageSize` messages just older than `before` (`startAfter([Timestamp, id])`, same order, after own `clearedAt`); falls back to cache offline. `hasOlder` = false only if the **server** returned fewer than `pageSize` | network, permission |
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
| `watch_conversations.dart` | `WatchConversations` | `Stream<ConversationsUpdate> call()` |
| `watch_latest_messages.dart` | `WatchLatestMessages` | `Stream<MessagesUpdate> call(String conversationId, {int pageSize = 20})` |
| `load_older_messages.dart` | `LoadOlderMessages` | `Future<MessagesPage> call(String conversationId, MessageCursor before, {int pageSize = 20})` |
| `create_message_id.dart` | `CreateMessageId` | `String call(String conversationId)` |
| `send_message.dart` | `SendMessage` | `Future<void> call({conversationId, messageId, otherUserId, text})` |
| `mark_conversation_read.dart` | `MarkConversationRead` | `Future<void> call(String conversationId)` |
| `delete_message.dart` | `DeleteMessage` | `Future<void> call({conversationId, messageId})` |
| `delete_conversation.dart` | `DeleteConversation` | `Future<void> call(String conversationId)` |
| `get_current_user_id.dart` | `GetCurrentUserId` | `String call()` |

12 use cases. Rev. 4 (pagination, option A) replaced `WatchMessages` (growing `limit`) with `WatchLatestMessages`
(bounded live window) and `LoadOlderMessages` (one-time cursor read).

Removed in rev. 2 (push deferred): `RequestNotificationPermission`, `RegisterDeviceToken`, `UnregisterDeviceToken`,
`WatchNotificationTaps`.

## Datasource responsibilities (data layer)

| Class | File | Wraps | Rules |
|---|---|---|---|
| `ChatRemoteDataSource` | `data/datasource/chat_remote_datasource.dart` | `FirebaseFirestore`, `FirebaseAuth` | All Firestore paths, queries and transactions (`conversations`, `messages`, `publicProfiles`, `chatRateLimits`); messages queries ordered by `createdAt` + document id: a live `limit(20)` window and `startAfter` reads built from `MessageCursor` (no `DocumentSnapshot` leaves the datasource; research D17); maps to `ConversationModel`/`MessageModel`; every `Future` in `try { } catch (e) { throw ErrorMapper.map(e); }`; streams use `.handleError` with the same mapping |

## Error mapping

`ErrorMapper.mapFirestore` maps `not-found` to "Requested car not found", which is wrong for chat. The chat
datasource throws its own `AppException`s for chat cases (rate limit, conversation not found, self chat) before the
mapper is reached, so the existing mapper is not changed.
