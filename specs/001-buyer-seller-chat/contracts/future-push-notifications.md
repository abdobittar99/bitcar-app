# Design Note: Future Push Notifications (NOT implemented in this version)

**Status**: Deferred (owner decision 3, 2026-10-31: stay on Firebase Spark, no Cloud Functions).
**Spec**: User Story 4, FR-022 to FR-025a, SC-004 (marked deferred). **Research**: D7.

This note records how push can be added later **without redesigning the chat**. Nothing below is built, configured or
added as a dependency now.

## Why no rework will be needed

| Future need | Already in the current design |
|---|---|
| A trigger per new message | Each message is its own document: `conversations/{cid}/messages/{mid}` (a future `onDocumentCreated` trigger) |
| Recipient | `conversations/{cid}.participants` minus `senderId` |
| Sender name for the title | `participantNames[senderId]` snapshot |
| "N new messages" in one notification per conversation | `unreadCount[recipient]` is updated in the same transaction as the message |
| Open the right chat on tap | `ChatScreen` already opens by conversation id via `GetChatTarget` |
| Respect privacy | Only participants are in `participants`; rules already deny everyone else |

## What a future phase would add (additive only)

| Area | Addition |
|---|---|
| Firebase plan | Blaze (required to deploy Cloud Functions) |
| Backend | `onChatMessageCreated` in `functions/index.js`; payload with Android `notification.tag = cid` (one replaceable notification per conversation), iOS `apns-collapse-id = cid`; delete invalid tokens |
| Firestore | `users/{uid}/fcmTokens/{token}` `{ token, platform, updatedAt }` + owner-only rule |
| Flutter data | `NotificationRemoteDataSource` (uses the already-declared `firebase_messaging`): permission once, token register/refresh/delete, initial message + `onMessageOpenedApp` |
| Flutter domain | New use cases: `RequestNotificationPermission`, `RegisterDeviceToken`, `UnregisterDeviceToken`, `WatchNotificationTaps`; new methods on `ChatRepository` (no existing signature changes) |
| Flutter presentation | `ConversationsBloc` subscribes to taps and exposes `pendingConversationId` (a `BlocListener` in `HomeLayout` opens `ChatScreen`); `HomeBloc` logout calls `UnregisterDeviceToken` |
| Android | `POST_NOTIFICATIONS` permission in `AndroidManifest.xml` |
| iOS (optional) | `GoogleService-Info.plist`, APNs key, Push + Background Modes capabilities |

No existing chat document field, rule, use case signature or screen would need to change.
