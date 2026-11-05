# Data Model: Buyer–Seller Chat

**Feature**: [spec.md](spec.md) · **Research**: [research.md](research.md) · **Date**: 2026-11-01 (rev. 4: message pagination; rev. 2: Spark plan)

Three levels, matching the constitution's model/entity separation:

1. **Firestore documents** (storage shape, owned by the chat datasource and guarded by Security Rules)
2. **Models** in `lib/models/` (`*Model extends *Entity`, `fromMap` / `toMap`, the only place Firestore types appear)
3. **Entities** in `lib/entities/` and domain wrappers in `features/chat/domain/model/` (plain Dart)

## 1. Firestore collections

```text
conversations/{cid}                      cid = "<smallerUid>_<largerUid>"
conversations/{cid}/messages/{mid}       mid = client-generated auto id
publicProfiles/{uid}                     public display name only (research D14)
chatRateLimits/{uid}                     sliding 60 s send window
```

Not created in this version (future push phase, see [contracts/future-push-notifications.md](contracts/future-push-notifications.md)):
`users/{uid}/fcmTokens/{token}`.

### `conversations/{cid}`

| Field | Type | Set by | Notes |
|---|---|---|---|
| `participants` | array\<string\> (2) | creator, immutable | Sorted uids; equals the two parts of `cid`. Used by the list query (`array-contains`) and rules |
| `buyerId` | string | creator, immutable | The user who started it (spec: inquirer) |
| `sellerId` | string | creator, immutable | Owner of the car it was started from |
| `participantNames` | map\<uid, string\> | creator writes both entries: each is the user's `publicProfiles.displayName`, or exactly `"BitCar user"` if that profile does not exist. A participant may later replace **only their own** placeholder with their own `displayName` | Snapshot at creation; real names never change afterwards (decision 5). The uid stays the identity; names are display-only (research D14) |
| `createdAt` | timestamp | creator | `serverTimestamp()` |
| `lastMessageAt` | timestamp | each send | `serverTimestamp()`; list order |
| `lastMessage` | map | each send / delete | `{ id, text, senderId, deleted }`; preview. On delete of the latest message: `deleted: true`, `text: ""` |
| `unreadCount` | map\<uid, int\> | send (+1 recipient), mark-read (own → 0), delete (−1 recipient if unread), clear (own → 0) | Badge + red dot (and the "N new messages" count for a future push phase) |
| `lastDeletedMessageId` | string, optional | each delete for everyone | Id of the message deleted in the same commit. Security Rules need it to find that message (research D19). Absent until the first delete; older conversations need no migration. Not read by the app: no model or entity field |
| `lastReadAt` | map\<uid, timestamp\> | mark-read (own) | Read receipts: message read when `createdAt <= lastReadAt[recipient]` |
| `clearedAt` | map\<uid, timestamp\> | delete conversation (own) | One-sided deletion (FR-027a). Absent = never cleared |

### `conversations/{cid}/messages/{mid}`

| Field | Type | Notes |
|---|---|---|
| `senderId` | string | Must equal `request.auth.uid` on create (FR-034) |
| `text` | string | 1–1,000 chars after trim; replaced by `""` on delete |
| `createdAt` | timestamp | `serverTimestamp()`; ordering |
| `deleted` | bool | `false` on create; sender may set to `true` once (FR-027) |

### `publicProfiles/{uid}`

| Field | Type | Notes |
|---|---|---|
| `displayName` | string | 1–100 chars; must equal the owner's `users/{uid}.fullName` (enforced by rules). Synced by the owner on app open after sign-in and after a name change. The only field: no email, phone or role |

### `chatRateLimits/{uid}`

| Field | Type | Notes |
|---|---|---|
| `windowStart` | timestamp | Start of current 60 s window (`request.time`) |
| `count` | int | Messages sent in the window, max 20 (FR-014a) |

### Index (root `firestore.indexes.json`)

| Collection | Fields | Query |
|---|---|---|
| `conversations` | `participants` ARRAY_CONTAINS, `lastMessageAt` DESC | User's conversations list |

Messages are queried (research D17) with `orderBy('createdAt', descending: true)` +
`orderBy(FieldPath.documentId, descending: true)` (+ optional `where createdAt > clearedAt`): a live `limit(20)` window
for the newest messages and one-time `startAfter([createdAt, id]).limit(20)` reads for older batches. The automatic
single-field `createdAt` index covers this; no composite index is needed.

Messages are never hard-deleted (FR-027 sets `deleted: true`, `text: ""`; rules deny `delete`), so a cursor always
points to an existing position and messages leaving the live window can stay on screen.

## 2. Entities (`lib/entities/`, plain Dart)

### `ConversationEntity` (`conversation.dart`)

| Field | Type | Derived from |
|---|---|---|
| `id` | String | doc id |
| `participantIds` | List\<String\> | `participants` |
| `buyerId`, `sellerId` | String | same |
| `otherUserId` | String | participant ≠ current uid |
| `otherUserName` | String | `participantNames[otherUserId]` (may be the placeholder `"BitCar user"`) |
| `lastMessageText` | String | `lastMessage.text` |
| `isLastMessageDeleted` | bool | `lastMessage.deleted` |
| `lastMessageSenderId` | String? | `lastMessage.senderId` |
| `lastMessageAt` | DateTime? | `lastMessageAt` |
| `unreadCount` | int | `unreadCount[currentUid]` (0 if absent) |
| `otherLastReadAt` | DateTime? | `lastReadAt[otherUserId]` |
| `clearedAt` | DateTime? | `clearedAt[currentUid]` |

Computed: `isVisibleInList => lastMessageAt != null && (clearedAt == null || lastMessageAt.isAfter(clearedAt))`.

### `MessageEntity` (`message.dart`)

| Field | Type | Notes |
|---|---|---|
| `id` | String | |
| `conversationId` | String | |
| `senderId` | String | |
| `text` | String | |
| `createdAt` | DateTime? | null only for local pending messages |
| `isDeleted` | bool | |
| `status` | `MessageStatus` | see state machine |

### `MessageStatus` enum (`lib/core/enums/message_status.dart`)

`sending`, `sent`, `read`, `failed`. Only meaningful for the current user's own messages.

## 3. Domain wrappers (`features/chat/domain/model/`)

Built **only in `ChatRepositoryImpl`** (constitution I, analysis I1). The datasource returns models inside Dart
records, e.g. `({List<MessageModel> messages, DateTime? otherLastReadAt, int unreadCount, DateTime? clearedAt, bool
isFromCache})`, and never imports `features/chat/domain/`.

| Class (file) | Fields | Purpose |
|---|---|---|
| `ConversationsUpdate` (`conversations_update.dart`) | `List<ConversationEntity> conversations`, `bool isFromCache` | One emission of the list stream; `isFromCache` drives the offline banner (FR-014b) |
| `MessagesUpdate` (`messages_update.dart`) | `List<MessageEntity> messages`, `DateTime? otherLastReadAt`, `int unreadCount`, `DateTime? clearedAt`, `bool isFromCache` | One emission of the live window (newest 20) together with the conversation's read state (other user's `lastReadAt`, own `unreadCount`) |
| `MessagesPage` (`messages_page.dart`) | `List<MessageEntity> messages`, `bool hasOlder`, `bool isFromCache` | Result of one older-batch read. `hasOlder` is false only when the **server** returned fewer than 20 |
| `MessageCursor` (`message_cursor.dart`) | `DateTime createdAt`, `String messageId` | Plain-Dart cursor: the oldest server-confirmed message loaded overall (research D17); the datasource maps it to `startAfter([Timestamp, id])` |
| `ChatTarget` (`chat_target.dart`) | `String conversationId`, `String otherUserId`, `String otherUserName`, `bool exists` | Result of opening a chat from a car or the conversations list (FR-003, FR-004) |

## 4. Models (`lib/models/`)

| Model | Extends | Responsibilities |
|---|---|---|
| `ConversationModel` (`conversation_model.dart`) | `ConversationEntity` | `fromMap(map, id, currentUid)`: `Timestamp` → `DateTime`, map lookups per uid. `snapshots()` in cloud_firestore 6.1.0 has **no** `serverTimestampBehavior` option, so an own pending `serverTimestamp()` (only `lastReadAt[uid]` / `clearedAt[uid]`, written with plain `update`) arrives as a present key with `null` value and is read as `DateTime.now()`. Sends are transactions, so `createdAt` / `lastMessageAt` are never pending locally; `static String idFor(String a, String b)` |
| `MessageModel` (`message_model.dart`) | `MessageEntity` | `fromMap(map, id, cid)` with status `sent` for server-confirmed messages; `toCreateMap()` with `serverTimestamp()`. `read` is applied in `ChatState` from the latest `otherLastReadAt` (`createdAt <= otherLastReadAt`), so it stays live for older batches too (FR-044) |

## 5. Validation rules (from requirements)

| Rule | Where enforced |
|---|---|
| Text trimmed length 1–1,000 (FR-010) | `ChatValidator` (client) and rules |
| Sender = signed-in user (FR-034) | rules |
| Only participants read/write (FR-032) | rules |
| No self-conversation (edge case) | UI hides button; rules require two distinct uids |
| `participantNames[u]` equals `publicProfiles/u.displayName` if it exists, else exactly `"BitCar user"`; later only own placeholder → own `displayName` | rules |
| `publicProfiles/{uid}`: owner-written, only `displayName` (1–100 chars), equal to own `users.fullName`; `get` for signed-in users, `list` denied | rules |
| ≤ 20 messages / 60 s / user (FR-014a) | rules via `chatRateLimits` (authoritative) + client pre-check |
| Only sender deletes, once; text emptied (FR-027) | rules |
| A delete is one commit of message + conversation; each message lowers unread at most once, only if the recipient had not seen it (research D19) | rules, through `lastDeletedMessageId` |
| `participants`, `buyerId`, `sellerId`, `createdAt` immutable | rules |
| A user may change only their own `lastReadAt`, `clearedAt`, and reset only their own `unreadCount` | rules |

## 6. State transitions

### Message (sender's view)

```text
          tap send                    server confirms (in stream)        recipient opens chat
 (none) ───────────► sending ─────────────────────────────► sent ─────────────────────────► read
                        │  transaction error / offline
                        ▼
                      failed ──── retry (same id) ────► sending
                                                         
 sent | read ── sender deletes ──► deleted (text "", placeholder shown to both)
```

### Conversation (per user)

```text
 not existing ── first message sent ──► visible
 visible ── user deletes conversation ──► hidden (clearedAt[uid] = now; other user unaffected)
 hidden ── any new message in the pair ──► visible (only messages after clearedAt shown)
```

### Message history paging (per open chat screen, FR-037 to FR-044)

```text
 opening ── window emits ──► idle(hasOlder = window has 20)
 idle(hasOlder) ── reach top ──► loadingOlder        (further "reach top" ignored, FR-042)
 loadingOlder ── 20 from server ──► idle(hasOlder = true, cursor = oldest loaded)
 loadingOlder ── < 20 from server ──► reachedBeginning   (indicator shown, no more requests)
 loadingOlder ── < 20 from cache only ──► idle(hasOlder = true, olderBatchIncomplete) + offline banner
 idle(olderBatchIncomplete) ── window back on server data ──► loadingOlder (same cursor)
 loadingOlder ── error ──► olderFailed               (loaded messages kept; error shown; retry at top)
 olderFailed ── retry ──► loadingOlder               (same cursor)
```

### Live window status (`ChatStreamStatus`, FR-054)

```text
 live ── stream error, retryable type ──► failedRetryable ── 3 s (once) / Retry ──► retrying ── first update ──► live
 live ── stream error, permission | notFound | auth | validation ──► failedFatal   (no Retry)
 retrying ── error ──► failedRetryable (Retry only, no more automatic retry) | failedFatal
 any ── session ended (stream done, D18) ──► no change, nothing shown
```

On every failure the live messages move to the loaded-once source, so the screen keeps them.

### Message sources inside `ChatState` (FR-039, FR-044)

```text
 live window (limit 20, live) ── message pushed out by newer ones ──► loaded (kept, no longer live)
 older batch read ──► loaded
 local send ──► pending ── id arrives in live window ──► live (pending copy dropped)
```

Batch size is a constant `messagesPageSize = 20` (spec FR-037/FR-038).

### Session gate and sign-out (research D18, FR-014b, FR-052, FR-053)

```text
 open ── LogoutConfirmed / no pending writes ──► closing   (streams cancelled, new operations refused,
                                                          in-flight drained ≤ 5 s)
 closing ── wipe OK and auth.signOut() OK ──► open         (marker removed after signOut)
 closing ── wipe fails, auth.signOut() OK ──► wipePending  (marker kept; a wipe retry can open the gate)
 closing ── auth.signOut() fails ──► wipePending           (marker kept; retry refused, no Firestore until restart)
 wipePending ── any Firestore operation ──► retry wipe only, never signOut ── OK ──► open
                                                    └── fails or refused ──► operation refused (ErrorType.cache)
 app start with marker set ──► wipe + signOut before runApp ──► open | wipePending
```

Local device key (SharedPreferences via `CacheHelper`): `CacheKeys.firestoreWipePending = 'firestore_wipe_pending'`
(bool). Set before the "Signing out…" view and before the gate closes; if it cannot be saved, the sign-out is cancelled. On sign-out and at startup it is removed only after both the wipe and `signOut()`
succeed; the wipe retry removes it after its wipe succeeds, since the sign-out already finished.

### Unread count (per user, per conversation)

```text
 +1 when the other participant sends (not when user is inside the chat: mark-read follows immediately)
 −1 when the other participant deletes a message the user has not seen (never below 0)
  0 when the user opens the chat (mark-read) or deletes the conversation
```

"Not seen" means `createdAt` is later than both the user's `lastReadAt` and `clearedAt`: the unread count only counts
messages after a clear, so an older message must not lower it (research D19).
