# Contract: Screens, Navigation and Blocs

**Requirements**: User Stories 1–3, 5, 6, FR-004 to FR-009, FR-011 to FR-021, FR-026 to FR-031, FR-035 to FR-054
(User Story 4 deferred)

## Entry points (changes to existing UI)

| Where | Change | Visible when |
|---|---|---|
| `HomeLayout` app bar `actions` | New chat `IconButton` before the search icon; red dot overlay when `ConversationsState.totalUnread > 0` | Always for signed-in users (FR-026, FR-017) |
| `CarDetailsScreen` | New `AppButton` "Chat with Seller" (`Icons.chat_bubble_outline`) directly above the existing phone "Contact Seller" button, which is unchanged | `car.sellerId != currentUserId` (FR-006, edge case) |

`CarDetailsBloc` gets `currentUserId` by reusing the existing `GetCurrentUser` use case (constructor injection + DI).

| Existing bloc | Change |
|---|---|
| `HomeBloc` (`features/home/bloc/home_bloc.dart`) | Inject `HasPendingWrites`. `LogoutPressed` → if pending writes: `showUnsyncedWarning: true` (dialog in `HomeLayout`: Cancel → `LogoutCancelled`, Log out → `LogoutConfirmed`); else sign-out. Sign-out sets `isSigningOut: true` (blocking "Signing out…" view) and calls `LogOut` (gate close → `terminate` → `clearPersistence` → `signOut`, research D18). `if (isClosed) return;` before every emit after an `await` (FR-052, FR-053) |
| `ProfileBloc` (`features/profile/bloc/profile_bloc.dart`) | Inject `SyncPublicProfile`. In `_onUpdated`, after `updateUserProfile` succeeds and `fullName` changed, call `syncPublicProfile(result.fullName)` (sync point 2). If it throws `AppException`, show it via `appErrorCubit` but keep `isSuccess: true` (the profile itself was saved); sync point 1 repairs it on next app start |

## Screens (new)

| Screen (file) | Class | Opened by | Bloc |
|---|---|---|---|
| `conversations/ui/conversations_screen.dart` | `ConversationsScreen` | app-bar chat icon | `ConversationsBloc` via `BlocProvider.value` from `HomeLayout` |
| `chat_room/ui/chat_screen.dart` | `ChatScreen` | car details, list tile | `BlocProvider(create: (_) => sl<ChatBloc>()..add(ChatStarted(...)))` |

Feature-local widgets: `conversation_tile.dart` (name, preview, time, unread badge), `message_bubble.dart` (own vs other
alignment/colour, time, status icon, deleted placeholder, retry on failed), `message_input_bar.dart`
(`TextField` with 1,000-char counter + send button), `offline_banner.dart`, `message_list.dart`
(pagination list, below).

### Chat screen details (FR-047 to FR-051)

| Requirement | UI contract |
|---|---|
| FR-047 delete gesture | `message_bubble.dart`: `onLongPress` only on own, non-deleted messages → bottom sheet with "Delete" → `confirmDelete(context, title: 'Delete message', message: 'Delete this message for everyone?')` → `ChatMessageDeletePressed` |
| FR-048 time format | `intl` `DateFormat.jm()` in bubbles; day separator items in `message_list.dart` ("Today", "Yesterday", `DateFormat.yMMMd()`); list tile: `jm()` for today, `yMMMd()` otherwise. Times use the device's local time zone |
| FR-049 accessibility | `Semantics(label: ...)` on status icons ("Sending", "Sent", "Read", "Failed, tap to retry"), the red dot ("Unread messages"), the top pagination row; no fixed-height text containers, so system text scaling wraps instead of clipping |
| FR-050 draft | `ChatStarted.fromCar` always sets `draft` to the inquiry text, replacing any previous value |
| FR-051 keyboard | `Scaffold(resizeToAvoidBottomInset: true)` (default) with the input bar below the list; when the keyboard opens and the user was at the bottom, the list stays at the newest message |

### `message_list.dart` (FR-037 to FR-046)

- `CustomScrollView` with a `center` key and two `SliverList`s. The center is the oldest message of the first live
  window. Older batches go into the sliver above the center; the first window and every newer message go into the
  sliver below it. Adding items on either side never moves the content on screen (FR-041, FR-045). On first build
  the view jumps to the bottom (newest message).
- New message while the user is within about 100 px of the bottom: scroll to it. Otherwise: keep the position and
  show a "New messages" chip above the input bar; tapping it scrolls to the bottom and hides it (FR-045).
- Sending or retrying a message scrolls to the bottom (FR-046).
- One extra item above the oldest message (the top of the screen): a small progress indicator while
  `isLoadingOlder`, a "Couldn't load older messages · Retry" row when `olderLoadFailed` (retry →
  `ChatLoadOlderRequested`), a "Beginning of the conversation" label when `!hasOlder`, and nothing otherwise.
- A `ScrollController` listener sends `ChatLoadOlderRequested` when the view is within 200 px of the top
  (`pixels <= minScrollExtent + 200`). The bloc guard drops repeats (FR-042). The controller is disposed with the
  widget.
- Takes plain values and callbacks (older messages, newer messages, flags, `onReachTop`, `onRetryOlder`), so a widget
  test can drive it without a bloc.

Navigation is plain `Navigator.push(MaterialPageRoute(...))` as elsewhere; back returns to the previous screen
(FR-029). `app_root.dart` is not touched. (A future push phase adds notification-tap routing here; see
[future-push-notifications.md](future-push-notifications.md).)

## `ConversationsBloc` (`conversations/bloc/`)

| Event | Kind | Effect |
|---|---|---|
| `ConversationsStarted` | public | `GetCurrentUser` → `SyncPublicProfile(user.fullName)` (sync point 1: app opened after sign-in; failure shown via `AppErrorCubit`, chat continues); subscribe `WatchConversations` |
| `ConversationDeletePressed(cid)` | public | `DeleteConversation` |
| `ConversationsRetried` | public | Re-subscribe after an error |
| `_ConversationsUpdated(update)` | internal | Emit list, `isFromCache`, `totalUnread` |
| `_ConversationsFailed(error)` | internal | `appErrorCubit.showError`, `hasError: true`, `isLoading: false` |

State (`ConversationsState`, `copyWith`): `isLoading`, `hasError`, `isOffline`, `conversations`, `totalUnread`.
`close()` cancels the subscription.

## `ChatBloc` (`chat_room/bloc/`)

| Event | Kind | Effect |
|---|---|---|
| `ChatStarted.fromCar(car)` | public | `OpenChatWithSeller(car.sellerId)`; set input draft to the inquiry text (FR-007); subscribe live window (`WatchLatestMessages`, 20) |
| `ChatStarted.fromConversation(cid)` | public | `GetChatTarget(cid)`; empty draft (FR-009); subscribe live window (`WatchLatestMessages`, 20) |
| `ChatMessageSubmitted(text)` | public | Validate (trim, 1–1,000; client rate pre-check); add optimistic `sending` message with `CreateMessageId`; `SendMessage`; on `AppException` → mark `failed` + `showError` |
| `ChatMessageRetried(messageId)` | public | Re-send the same id (FR-014) |
| `ChatMessageDeletePressed(messageId)` | public | `DeleteMessage` after UI confirmation |
| `ChatLoadOlderRequested` | public | Sent when the list reaches the top, and by the retry action. Ignored if `isLoadingOlder`, `!hasOlder` or no cursor (FR-042). Otherwise emits `isLoadingOlder: true, olderLoadFailed: false` **before** the first `await`, then `LoadOlderMessages(cid, oldestCursor)`. Success: add to `loadedMessages`, move the cursor to the oldest loaded server-confirmed message, set `hasOlder` (stays true for a cache-only short batch, with `olderBatchIncomplete: true`). `AppException`: `olderLoadFailed: true`, `showError`, cursor unchanged (FR-043b). Always `isLoadingOlder: false` at the end |
| `ChatVisibilityChanged(isVisible)` | public | From app lifecycle; mark-read only while visible |
| `_MessagesUpdated(update)` | internal | Live window emission: messages that were in `liveMessages` but are no longer in the window move to `loadedMessages` (kept on screen); replace `liveMessages`; drop pending messages whose id arrived; store `otherLastReadAt`; on the first emission set `hasOlder` (= window has 20) and the cursor; if `olderBatchIncomplete` and the update is from the server → re-send `ChatLoadOlderRequested`; if visible and `unreadCount > 0` → `MarkConversationRead` (FR-015, FR-020) |
| `_MessagesFailed(error)` | internal | Live window error (terminal for that listener): clear the subscription; move `liveMessages` into `loadedMessages` (nothing disappears); `showError` once; `isLoading: false`; `streamStatus` = `failedRetryable` for `network`/`firestore`/`unknown`/`platform`/`server`/`cache`, `failedFatal` for `permission`/`notFound`/`auth`/`validation`. For `failedRetryable`, schedule **one** automatic `ChatRetried` after 3 s (timer cancelled in `close()`) (FR-054) |
| `ChatRetried` | public | Retry button or the automatic retry. Ignored unless `streamStatus == failedRetryable` and no subscription exists. Emits `streamStatus: retrying`, cancels any leftover subscription, subscribes `WatchLatestMessages` again; the first update sets `streamStatus: live` and is merged by id (no duplicates, cursor unchanged). A new failure → `_MessagesFailed` again (no further automatic retry) |

State (`ChatState`, `copyWith`): `isLoading`, `isOffline`, `target` (`ChatTarget?`), `isNewConversation`
(`!target.exists && messages.isEmpty`, FR-004), `liveMessages`, `loadedMessages`, `pendingMessages` (each an
id-keyed map of `MessageEntity`), `otherLastReadAt`, `draft`, `oldestCursor`, `hasOlder`, `isLoadingOlder`,
`olderLoadFailed`, `olderBatchIncomplete`, `isVisible`, `currentUserId`, `streamStatus`
(`enum ChatStreamStatus { live, retrying, failedRetryable, failedFatal }`, declared in `chat_state.dart`), and
`autoRetryUsed` (bool).

Getter `messages`: union by id (live > loaded > pending), own messages marked `read` when
`createdAt <= otherLastReadAt` (FR-044), sorted by `(createdAt, id)`, local pending/failed last (FR-039, FR-040).
The bloc holds exactly one subscription (the live window); `close()` cancels it. Batch size is the constant
`messagesPageSize = 20`.

## UI states (FR-019, FR-030, FR-031)

| Situation | UI |
|---|---|
| List loading | `CircularProgressIndicator` |
| No conversations | `EmptyState(icon: Icons.chat_bubble_outline, title: 'No conversations yet', subtitle: 'Start a chat from any car page.')` |
| List error | `EmptyState` with "Retry" button → `ConversationsRetried` |
| New conversation | Header hint "Start the conversation with <name>" above the empty message area |
| Offline | `offline_banner.dart` at the top; send shows failed state; delete actions disabled |
| Live updates failed (FR-054) | Loaded messages stay. `failedRetryable`: banner under the app bar "Live updates stopped." with **Retry** (`ChatRetried`), progress while `retrying`. `failedFatal`: banner with the error text and no Retry; sending and deleting disabled |
| Older messages loading / failed / beginning reached | Top row of `message_list.dart` (progress / "Retry" / "Beginning of the conversation"); offline with a cache-only page → offline banner, no "beginning" label |
| Errors | Always via `AppErrorCubit` / `AppErrorListener` snackbar |
| Delete confirmation | Existing `confirmDelete(context)` extended with optional `title` and `message` parameters (defaults keep current car texts) |
