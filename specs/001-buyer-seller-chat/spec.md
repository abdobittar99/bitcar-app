# Feature Specification: Buyer–Seller Chat

**Feature Branch**: `001-buyer-seller-chat`

**Created**: 2026-10-28

**Status**: Draft

**Input**: User description: "Add an in-app conversations feature to BitCar so a buyer can contact a
seller directly about cars listed for sale, with conversation and message history preserved. One
conversation per buyer–seller pair, reused across all of that seller's cars; a contact button on the
car details page and a conversations entry in the app bar; a conversations list screen and a chat
screen; when started from a car, a fixed inquiry text identifying the car is placed in the message
input; empty, loading, sending, receiving and error states; only participants may read or send
messages; existing functionality must be preserved." (original request written in Arabic)

## Clarifications

### Session 2026-10-28

- Q: Should the existing phone-call "Contact Seller" button stay or be replaced? → A: Keep it and add
  a separate in-app "Chat with Seller" action next to it.
- Q: Who may start a conversation? → A: Any signed-in user (buyer, seller or admin) on a car they do
  not own; admins act as ordinary participants.
- Review of assumptions → The following move into scope: notifications, unread counters, read
  receipts, message deletion, and new messages always arriving live while the app is open (the
  conversations list updates, an open conversation shows the message, and elsewhere in the app the
  conversations entry shows a red dot).
- Q: How does deleting a message work? → A: Delete for everyone; both participants see a
  "This message was deleted" placeholder in its place.
- Review of assumptions → A user may delete a whole conversation, but only from their own side; the
  other participant keeps it. Message editing stays out of scope. Notification previews show message
  text, with lock-screen hiding following device settings. The owner approves adding the new
  dependency needed for device notifications.

### Session 2026-10-30

- Q: Can users open their previous conversations and read messages while offline, even after
  restarting the app? → A: Yes, read-only: the list and previously loaded messages are shown;
  sending requires a connection.
- Q: When several messages arrive while the app is closed, one notification per message or one per
  conversation? → A: One notification per conversation, replaced by the latest message and showing
  the number of new messages.
- Q: Should there be a limit on how many messages a user can send in a short time? → A: Yes, 20
  messages per minute per user; beyond that, sending is refused with a "sending too fast, try again
  shortly" message.
- Q: When does the app ask for permission to send notifications? → A: On first use of chat: the
  first time the user opens the conversations screen or sends their first message, whichever comes
  first.
- Q: Can a user turn off read receipts so the other participant does not know they read a message?
  → A: No; read receipts are always on for everyone in this version.

### Session 2026-10-31 (planning decisions affecting scope)

- Decision → The project stays on the free Firebase plan, with no server-side functions. **Device
  push notifications are deferred to a future phase**: User Story 4, FR-022 to FR-025a and SC-004
  are out of scope for this version. Everything else, including live in-app delivery, the
  conversations list, unread counts, the red dot and read receipts, stays in scope. The design must
  allow notifications to be added later without redesigning the chat.
- Decision → Participant names are stored as a snapshot when the conversation is created and are not
  updated when a user later changes their name; the user id remains the identity. Other users'
  private profile data (email, phone) stays private.

### Session 2026-11-01 (owner addition)

- Decision → **Message history is loaded in batches of 20.** Opening a conversation loads only the 20
  most recent messages; scrolling to the top loads the next 20 older ones, until the oldest message is
  reached. Batches must never duplicate or reorder messages, the user's scroll position must be kept
  when older messages are added, only one older batch may load at a time, and loading, error and
  "no older messages" states must be shown (FR-037 to FR-044, SC-011).
- Review decision (option A) → Only the **20 most recent messages are kept live**; older messages
  are loaded once each. Read state stays live for every loaded message; a deletion of a message
  outside the 20 most recent appears the next time the conversation is opened (FR-044).
- Review decision (F4) → A new message arriving while the user is reading older messages must not
  move the screen; a "New messages" indicator is shown instead. Sending a message brings the user
  to the newest message (FR-045, FR-046).
- Review decision (F5) → Opening a conversation marks **all** its messages as read, including ones
  not loaded on screen yet (FR-015).
- Review decision (F6) → Remaining notification wording outside User Story 4 and FR-022 to FR-025a
  is marked deferred.
- Review decision (UI details) → Approved as proposed: long-press to delete own message; time and
  day-separator format; accessibility labels and text scaling; inquiry text replaces any previous
  draft; the keyboard never hides the newest message or the input (FR-047 to FR-051).

### Session 2026-11-02 (analysis review)

- Decision → Data kept on the device for offline reading stays enabled; on sign-out it is fully
  removed before anyone can use the app again, so a next user on the same device never sees the
  previous user's data, online or offline (FR-014b unchanged).
- Decision → If some changes have not been saved to the server yet when the user signs out, the
  app warns them; they can cancel and stay signed in, or confirm and lose those changes (FR-052).
- Review decision (chat-review CHK004/CHK005) → Deleted messages count toward the 20 loaded messages;
  the user's own sending/failed messages are shown in addition and never affect the limit or where
  older batches start (FR-037).
- Review decision (chat-review CHK022) → A failed live chat update keeps loaded messages and offers
  Retry when retrying can help; access errors are shown without Retry (FR-054).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Starting or resuming a conversation from a car (Priority: P1)

A signed-in user viewing a car they do not own taps "Chat with Seller". In the conversation, this
user is the inquirer ("buyer") and the car's owner is the "seller". If the two have no conversation
yet, a new one opens. If they already have one (about this car or any other car), that conversation
opens with all previous messages. In both cases the message input is pre-filled with a fixed inquiry
text identifying the car (brand, model, year), which the user can edit before sending.

**Why this priority**: This is the core value of the feature, and it is where the
one-conversation-per-pair rule is enforced.

**Independent Test**: As user A, open a car owned by user S, tap "Chat with Seller" and send the
pre-filled message; then open another car of S and tap "Chat with Seller" again. The same
conversation opens, showing the first message, with the new car's inquiry text in the input.

**Acceptance Scenarios**:

1. **Given** user A has no conversation with S, **When** A taps "Chat with Seller" on one of S's cars,
   **Then** a conversation with S opens, clearly shown as new (no previous messages), and the input
   contains the inquiry text for that car.
2. **Given** A already has a conversation with S, **When** A taps "Chat with Seller" on any of S's
   cars, **Then** the existing conversation opens with its full history and no second conversation
   is created.
3. **Given** the pre-filled inquiry text, **When** A edits it and sends, **Then** the sent message
   contains exactly the text A confirmed.
4. **Given** A opened a new conversation but left without sending, **When** either user opens their
   conversations list, **Then** no empty conversation appears.
5. **Given** the car details page, **When** it is shown, **Then** the existing phone-call
   "Contact Seller" button is still present and works as before, next to "Chat with Seller".

---

### User Story 2 - Exchanging messages live (Priority: P1)

Both participants can open a conversation, read previous messages in chronological order, send text
messages, and see the other participant's new messages appear immediately. Sent and received
messages are visually distinct, and the sender can see whether each message was sent and read.

**Why this priority**: Without reliable two-way live messaging and preserved history, the contact
action delivers no value.

**Independent Test**: With users A and S signed in on two devices, both open the same conversation;
each sends messages and sees the other's messages appear in order without leaving the screen, and
the sender sees each message change to "read".

**Acceptance Scenarios**:

1. **Given** an open conversation with history, **When** it loads, **Then** messages are shown oldest
   to newest with the most recent visible, each with its send time, and the user's own messages are
   visually distinct.
2. **Given** an open conversation, **When** the user sends a non-empty message, **Then** it appears
   immediately as "sending", then "sent" once delivered, then "read" once the other participant has
   seen it.
3. **Given** an open conversation, **When** the other participant sends a message, **Then** it appears
   immediately without refreshing, and it counts as read by the user.
4. **Given** sending fails, **When** the failure is detected, **Then** the message is marked "failed",
   a clear error is shown, its text is kept, and the user can retry without creating duplicates.
5. **Given** an empty or whitespace-only input, **When** the user tries to send, **Then** nothing is
   sent.
6. **Given** a conversation with 45 messages visible to the user, **When** they open it, **Then** only
   the 20 most recent are loaded, with the newest visible at the bottom.
7. **Given** that conversation is open, **When** the user scrolls to the top of the loaded messages,
   **Then** a loading indicator appears at the top and the next 20 older messages are added above;
   scrolling to the top again adds the remaining 5, and a "beginning of the conversation" indicator
   replaces further loading.
8. **Given** older messages are being added, **When** they appear, **Then** the message the user was
   looking at stays at the same place on screen, every message appears exactly once, and all
   messages stay in send-time order.
9. **Given** an older batch is loading, **When** the user keeps scrolling at the top, **Then** no second
   request starts and no batch is loaded twice.
10. **Given** loading an older batch fails, **When** the failure is detected, **Then** the already loaded
    messages stay visible, a clear error is shown, and a retry action at the top loads that same batch.

---

### User Story 3 - Conversations list, unread counts and new-message indicator (Priority: P1)

Every signed-in user can open the conversations screen from an entry in the main app bar. The list
shows each conversation's other participant, latest message preview, time and number of unread
messages, ordered by most recent activity. While the user is anywhere else in the app, the app bar
entry shows a red dot when at least one conversation has unread messages.

**Why this priority**: Sellers have no other entry point to reply, and users need to notice new
messages without checking manually.

**Independent Test**: As user S with several conversations, have another user send a message while
S is (a) on the home screen: the red dot appears; (b) on the conversations screen: that conversation
moves to the top with an updated preview and unread count; (c) inside that conversation: the message
appears directly and no unread count is added.

**Acceptance Scenarios**:

1. **Given** a signed-in user, **When** they tap the conversations entry in the app bar, **Then** the
   conversations screen opens.
2. **Given** a user with no conversations, **When** the screen opens, **Then** an empty state explains
   there are no conversations yet and that they can chat with a seller from a car's page.
3. **Given** the user is on the conversations screen, **When** a new message arrives, **Then** its
   conversation moves to the top and its preview, time and unread count update immediately.
4. **Given** the user is elsewhere in the app (not on the conversations screen or in that
   conversation), **When** a new message arrives, **Then** the app bar conversations entry shows a red
   dot.
5. **Given** a conversation with unread messages, **When** the user opens it, **Then** its unread count
   is cleared, and the red dot disappears once no conversation has unread messages.
6. **Given** the list is loading or fails to load, **When** the screen is shown, **Then** a loading
   indicator or a clear error with retry is displayed.
7. **Given** the user opened a conversation from the list, **When** they go back, **Then** they return
   to the updated list.

---

### User Story 4 - Notifications when outside the app (Priority: P2) — DEFERRED

> **Deferred to a future phase (Session 2026-10-31).** Kept here as the agreed behavior for that phase;
> not part of this version's acceptance.

When the app is in the background or closed, a user receives a device notification for new messages,
showing the sender's name and a preview of the text. Each conversation has at most one notification,
updated with the latest message and the number of new messages. Tapping the notification opens that
conversation.

**Why this priority**: Notifications make replies timely, but the in-app chat is usable without them.

**Independent Test**: With S's app closed, A sends a message; S receives a notification, taps it, and
lands in the conversation with A, where the message is visible and marked read.

**Acceptance Scenarios**:

1. **Given** the recipient's app is in the background or closed, **When** a new message is sent to
   them, **Then** they receive a notification with the sender's name and message preview.
2. **Given** a notification, **When** the user taps it, **Then** the app opens directly on that
   conversation (after sign-in if required).
3. **Given** the recipient's app is open in the foreground, **When** a new message arrives, **Then** no
   device notification is shown; the in-app behavior of User Story 3 applies instead.
4. **Given** the user has denied notification permission, **When** messages arrive, **Then** no
   notification is shown and all in-app chat behavior still works.
5. **Given** the user has signed out on a device, **When** messages are sent to that account,
   **Then** that device shows no notifications for it.
6. **Given** the recipient already has a notification for a conversation, **When** more messages
   arrive in it, **Then** that same notification is updated to the latest message and shows the number
   of new messages (e.g. "3 new messages") instead of adding new notifications.

---

### User Story 5 - Deleting messages and conversations (Priority: P3)

A user can delete a message they sent for both participants; a "This message was deleted"
placeholder takes its place. A user can also delete a whole conversation from their own side only;
the other participant keeps it unchanged.

**Why this priority**: Useful for correcting mistakes and tidying the list, but not needed to
communicate.

**Independent Test**: User A deletes one of their sent messages and verifies both devices show the
placeholder; then A deletes the whole conversation and verifies it disappears from A's list while S
still sees it with full history.

**Acceptance Scenarios**:

1. **Given** a message the user sent, **When** they delete it and confirm, **Then** on both
   participants' devices its text is replaced by "This message was deleted", and the conversation
   preview shows the placeholder if it was the latest message.
2. **Given** a message sent by the other participant, **When** the user views it, **Then** no option to
   delete it is offered.
3. **Given** a conversation in the user's list, **When** they delete it and confirm, **Then** it
   disappears from their list and its history is no longer shown to them, while the other
   participant's conversation and history are unchanged.
4. **Given** a user deleted a conversation with S, **When** S sends a new message or the user contacts
   S again, **Then** the same conversation reappears for the user showing only messages sent after
   the deletion.

---

### User Story 6 - Access restricted to participants (Priority: P1)

Only the two participants of a conversation can see it, read its messages, send messages, or delete
messages in it. Signed-out users cannot use the feature at all.

**Why this priority**: Messages are private; a leak would be a serious privacy failure.

**Independent Test**: With three accounts (A, S, other user O, including an admin), create an A–S
conversation; verify O never sees it and cannot read, send or delete anything in it. (Receiving no
notifications for it is deferred with User Story 4.)

**Acceptance Scenarios**:

1. **Given** a conversation between A and S, **When** any other user, including an admin, uses the app,
   **Then** that conversation and its messages are never available to them (and, once notifications
   exist, its notifications; deferred).
2. **Given** a non-participant, **When** they attempt to read, send or delete messages in that
   conversation, **Then** the system rejects the attempt, not only the UI.

---

### Edge Cases

- A user views their own car: "Chat with Seller" is not offered (no self-conversation); the phone
  button behaves as today.
- Two users who each own cars contact each other about different cars: they still share one
  conversation; the inquirer and owner roles are those of whoever started it.
- The car a conversation started from is later edited or deleted: the conversation and history remain;
  past inquiry texts are unchanged.
- The other participant's account cannot be loaded: the conversation opens with history and a neutral
  placeholder name.
- Connection is lost while the app is open: loaded messages stay visible, a clear connection error is
  shown, and missed messages, unread counts and the red dot catch up once the connection returns.
- The app is opened with no connection: the conversations list and previously loaded messages are
  shown from the device (FR-014b) with an offline indication; sending fails per FR-014.
- Double tap or two devices trying to start the same conversation at once: only one conversation
  exists.
- A user sends more than 20 messages within one minute (across all conversations): the extra messages
  are refused per FR-014a, and sending works again once the rate drops below the limit.
- A message exceeding the maximum length cannot be sent; long messages are shown fully wrapped.
- A long history opens on the 20 most recent messages; older ones load 20 at a time by scrolling up
  (FR-037 to FR-044).
- A conversation has exactly 20, or a multiple of 20, messages: one last request finds no older
  messages, and the "beginning of the conversation" indicator is shown without an error.
- A new message arrives, or the user sends or deletes a message, while an older batch is loading: the
  new or changed message appears once, in the right place, and the older batch is still added
  correctly.
- A message among the 20 most recent is deleted by its sender: it changes to the deletion placeholder
  immediately. A deleted message outside the 20 most recent keeps its old text on the other
  participant's open screen and shows the placeholder the next time the conversation is opened
  (FR-027, FR-044).
- The user is reading older messages when new messages arrive: the screen does not move, and a
  "New messages" indicator appears; tapping it, or sending a message, brings the user to the newest
  message (FR-045, FR-046).
- A conversation has more than 20 unread messages: opening it marks all of them read, even those not
  loaded on screen yet (FR-015).
- No connection while scrolling up: older messages already kept on the device are shown; for the
  rest, the offline indication is shown instead of the "beginning of the conversation" indicator,
  and loading continues once the connection returns.
- The user had deleted the conversation on their side (FR-027a): batches stop at the first message
  after that deletion; earlier history is never loaded.
- The same account is signed in on two devices: reading a conversation on one device clears its
  unread count on the other.
- A user signs out while offline with unsaved changes: they are warned and may cancel (FR-052). After
  sign-out, a second user signing in on the same device, even offline, sees none of the first
  user's conversations, messages or other data (FR-014b, FR-053).
- Live updates of an open conversation fail: loaded messages stay; a fixable failure offers Retry
  after one automatic attempt, and retrying never shows a message twice; losing access to the
  conversation shows the error without Retry (FR-054).
- The app is closed in the middle of signing out: on the next start, sign-out is completed and the
  device data removed before anything is shown (FR-053).
- A message is deleted while the recipient has not read it yet: it no longer counts as unread. (Any
  notification already shown is not retracted; deferred with notifications.)
- A user deletes a conversation that has unread messages: its unread count is cleared and it no
  longer contributes to the red dot.
- The other participant deletes a message from a conversation the user had deleted on their side:
  nothing changes for the user, since that earlier history is already hidden from them.

## Requirements *(mandatory)*

### Functional Requirements

**Conversation rules**

- **FR-001**: The system MUST keep at most one conversation per pair of users, regardless of how many
  cars are discussed or which of them starts it.
- **FR-002**: When a user contacts a car owner they have no conversation with, the system MUST open a
  new conversation; it MUST appear in either participant's list only after its first message is sent.
- **FR-003**: When a conversation already exists for the pair, the system MUST open it with its history
  instead of creating a new one.
- **FR-004**: The chat screen MUST make clear whether the conversation is new (no messages yet) or
  existing (history shown).
- **FR-005**: The system MUST preserve all non-deleted messages and show them each time the
  conversation is reopened.
- **FR-006**: Any signed-in user (buyer, seller or admin) MUST be able to start a conversation from the
  details page of a car they do not own; starting a conversation from elsewhere is not offered.

**Car context**

- **FR-007**: When opened from a car's details page, the message input MUST be pre-filled with a fixed
  inquiry text identifying the car by brand, model and year (e.g. "Hello, I'm interested in your
  <brand> <model> (<year>). Is it still available?").
- **FR-008**: The inquiry text MUST be editable and MUST NOT be sent without the user's explicit send
  action.
- **FR-009**: When opened from the conversations list, the input MUST be empty. (The same applies to
  opening from a notification, deferred with User Story 4.)

**Messaging**

- **FR-010**: Participants MUST be able to send text messages of 1 to 1,000 characters; empty or
  whitespace-only messages MUST NOT be sent.
- **FR-011**: Messages MUST be shown in chronological order with their send time, the user's own
  messages visually distinct from the other participant's.
- **FR-012**: While the app is open, new messages MUST be delivered live without manual refresh, on
  every screen.
- **FR-013**: Each message the user sends MUST show its state: sending, sent, read, or failed.
- **FR-014**: A failed message MUST keep its text and offer retry; retrying MUST NOT create duplicates.
- **FR-014a**: The system MUST refuse messages beyond 20 per minute per sending user, enforced by the
  system and not only the UI; the refused message MUST be kept as failed with a plain-language
  "You're sending messages too fast, try again shortly" error and can be retried later.
- **FR-014b**: Without a connection, including after an app restart, the user MUST still be able to
  open the conversations list and read previously loaded messages, with a visible offline
  indication; sending, deleting and other changes require a connection. Data kept on the device MUST
  belong only to the signed-in user and MUST NOT be shown after sign-out.

**Message history loading (Session 2026-11-01)**

- **FR-037**: Opening a conversation MUST load only the 20 most recent messages visible to the user
  (all of them if there are fewer), showing the newest at the bottom. Deleted messages, shown with
  the "This message was deleted" placeholder, count toward these 20. The user's own messages that
  are still sending or have failed exist only on the device: they are shown in addition to the 20,
  do not count toward the limit, never decide where the next older batch starts, and once a send
  succeeds the device copy and the saved message MUST appear as one message, never two.
- **FR-038**: When the user scrolls to the top of the loaded messages, the system MUST load the next
  20 older messages and show them above, repeating on each further scroll to the top until the
  oldest message visible to the user (FR-027a) has been loaded.
- **FR-039**: Every message MUST appear exactly once, whether it came from the first batch, an older
  batch, live delivery, or the user's own sending or retrying.
- **FR-040**: All loaded messages MUST be shown in send-time order (oldest to newest) across all
  batches and live messages.
- **FR-041**: Adding older messages MUST NOT move the content the user is looking at: the message at
  the top of the screen before loading MUST stay at the same screen position after the older batch
  is added.
- **FR-042**: At most one older-messages request MAY run at a time per conversation screen; scrolling
  to the top again while a batch is loading MUST NOT start another request or load the same batch
  twice.
- **FR-043**: The chat screen MUST show (a) a loading indicator at the top while an older batch
  loads; (b) on failure, the already loaded messages, a plain-language error through the app's
  existing error display (FR-031), and a retry action at the top that requests the same batch; (c)
  once the oldest message is loaded, a "beginning of the conversation" indicator, with no further
  requests. Without a connection, the screen MUST NOT claim the beginning was reached unless it is
  known; it shows the offline indication (FR-014b) instead, and at the end of the messages kept on
  the device a plain-language row saying no more saved messages are available until the connection
  returns (owner decision 2026-11-04).
- **FR-044**: While the conversation is open, the 20 most recent messages MUST stay live: new
  messages, deletions (FR-027) and read-state changes appear without reloading. Read state (FR-015)
  MUST stay live for every loaded message. Older messages are loaded once: a deletion of a message
  outside the 20 most recent MUST appear at the latest the next time the conversation is opened.
- **FR-045**: When a new message arrives while the user is viewing the newest messages, it MUST be
  shown directly at the bottom. When the user has scrolled away from the newest messages, the
  content they are looking at MUST NOT move; instead a "New messages" indicator MUST appear, and
  tapping it MUST bring the user to the newest message.
- **FR-046**: When the user sends a message (or retries a failed one), the screen MUST bring them to
  the newest message.
- **FR-054**: If live updates of an open conversation stop because of an error, the screen MUST keep
  showing the messages already loaded and show a clear error. When retrying can fix the cause
  (connection or service problems), the app MUST try once more automatically and then offer a
  **Retry** action; a successful retry MUST resume live updates without duplicating or losing loaded
  messages. When retrying cannot fix the cause (no access to the conversation, conversation not
  found, signed out), the error MUST be shown without Retry. Short connection drops that the app
  recovers from by itself MUST show the offline indication (FR-014b), not an error.

**Unread counts & read receipts**

- **FR-015**: A received message MUST be counted as unread until the recipient opens the conversation.
  Opening the conversation (and receiving messages while it is open on screen) MUST mark **all** its
  messages read, including messages not loaded on screen yet, and the sender MUST see them as
  "read". Read receipts are always on and cannot be turned off by users.
- **FR-016**: Each conversation in the list MUST show the number of unread messages for the user; the
  count MUST clear when the user opens the conversation.
- **FR-017**: The app bar conversations entry MUST show a red dot whenever at least one conversation
  has unread messages and the user is not on the conversations screen; it MUST disappear when none
  remain.
- **FR-018**: Read state and unread counts MUST be consistent across all devices where the user is
  signed in.

**In-app arrival behavior**

- **FR-019**: When a new message arrives and the user is on the conversations screen, the list MUST
  update immediately (order, preview, time, unread count).
- **FR-020**: When a new message arrives and the user is in that conversation, it MUST appear directly
  and be marked read, with no unread count or red dot added for it.
- **FR-021**: When a new message arrives and the user is elsewhere in the app, the red dot of FR-017
  MUST appear; no device notification is shown while the app is in the foreground.

**Notifications — DEFERRED (Session 2026-10-31; not in this version's scope)**

- **FR-022**: When the app is in the background or closed, the recipient MUST receive a device
  notification for new messages, showing the sender's name and a text preview. There MUST be at most
  one notification per conversation, replaced by the latest message and showing the number of new
  messages since the user last opened that conversation.
- **FR-023**: Tapping a notification MUST open the related conversation, after sign-in if required.
- **FR-024**: Notifications MUST be sent only to devices where a participant is currently signed in;
  signing out MUST stop notifications for that account on that device.
- **FR-025**: If notification permission is denied, all other chat behavior MUST still work.
- **FR-025a**: The app MUST ask for notification permission only on the user's first use of chat:
  the first time they open the conversations screen or send their first message, whichever comes
  first. It MUST NOT ask at app launch or sign-in, and MUST NOT ask again on the same device after
  the user has answered.

**Conversations list & navigation**

- **FR-026**: The main app bar MUST provide an entry to the conversations screen for every signed-in
  user. The car details page MUST add a "Chat with Seller" action next to the existing phone-call
  "Contact Seller" button, which MUST remain unchanged.
- **FR-027**: Users MUST be able to delete messages they sent, after confirmation, for both
  participants; the message text MUST be replaced on both sides by a "This message was deleted"
  placeholder, with no time limit. Messages cannot be edited.
- **FR-027a**: Users MUST be able to delete a whole conversation, after confirmation, from their own
  side only: it disappears from their list and its earlier history is hidden from them, while the
  other participant's conversation and history are unaffected. If a new message is later exchanged
  between the pair, the same conversation (FR-001) reappears for the user showing only messages sent
  after their deletion.
- **FR-028**: The conversations screen MUST list only the user's own conversations with the other
  participant's name, latest message preview, time and unread count, ordered by most recent activity.
- **FR-029**: Tapping a conversation MUST open it; going back MUST return to the updated list.
- **FR-030**: The conversations screen MUST show an empty state, and loading and error (with retry)
  states as appropriate.
- **FR-031**: Connection, sending and deletion errors MUST be shown through the app's existing error
  display, in plain language.

**Chat screen details (Session 2026-11-01)**

- **FR-047**: Deleting a message (FR-027) MUST be started by a long press on one of the user's own
  messages, which offers a "Delete" option, followed by a confirmation dialog. A long press on the
  other participant's message MUST NOT offer deletion.
- **FR-048**: Each message MUST show its send time as hour and minutes (e.g. "3:45 PM"). Messages
  from different days MUST be separated by a day label: "Today", "Yesterday", or the date. In the
  conversations list, the latest message time MUST show the hour and minutes for today and the date
  for earlier days.
- **FR-049**: Message status icons (sending, sent, read, failed), the app bar red dot, and the
  loading / retry / "beginning of the conversation" row MUST have spoken labels for screen readers,
  and chat text MUST follow the device's text-size setting without being cut off.
- **FR-050**: When the chat is opened from a car's details page, the inquiry text for that car MUST
  replace any text previously in the message input.
- **FR-051**: When the keyboard opens, the newest message MUST stay visible and the keyboard MUST NOT
  cover the message input.

**Sign-out (Session 2026-11-02)**

- **FR-052**: When the user signs out while some of their changes (in any part of the app) have not
  yet been saved to the server, the app MUST warn them that these changes will be lost and offer
  **Cancel** (stay signed in, changes kept) and **Log out** (sign out, changes discarded). Changes
  MUST NOT be discarded without this warning. Without unsaved changes, sign-out proceeds directly.
- **FR-053**: Signing out MUST remove all of the user's data kept on the device before the app can be
  used again; if that removal fails, no account (the same or another) MUST be able to load data until
  it succeeds. This makes FR-014b hold online and offline.

**Security & privacy**

- **FR-032**: Only a conversation's two participants MUST be able to see it, read, send or delete
  messages in it (or, once notifications exist, receive its notifications; deferred); this MUST be enforced by the system, not only by
  the UI. Admins have no special access to other users' conversations.
- **FR-033**: Only signed-in users MUST be able to use any part of the feature.
- **FR-034**: A message's sender MUST be the signed-in user who sent it and MUST NOT be alterable by
  the client; only the sender may delete a message for the other participant.

**Consistency with the existing app**

- **FR-035**: New screens and controls MUST follow BitCar's existing visual style.
- **FR-036**: Existing functionality (car details including phone contact, favorites, search, my cars,
  profile, admin actions) MUST keep working unchanged apart from the additions described here.

### Key Entities *(include if feature involves data)*

- **Conversation**: The single thread between two users. Attributes: inquirer and car owner
  (participants), creation time, last activity time, latest message preview, unread count per
  participant, and for each participant the point from which history is visible to them (set when
  they delete the conversation). Unique per pair of users.
- **Message**: One text in a conversation. Attributes: conversation, sender, text, send time, state
  (sending / sent / read / failed as seen by the sender), deleted status.
- **Participant**: An existing BitCar user (name, role) in a conversation; any role may participate.
- **Notification registration** *(deferred with notifications)*: The link between a signed-in user and a device that may receive
  their chat notifications; removed on sign-out.
- **Car (existing)**: Supplies the owner identity and the brand, model and year for the inquiry text.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can go from a car's details page to a sent inquiry message in under 15 seconds
  and 2 taps.
- **SC-002**: 100% of contact attempts for the same pair of users, from any car, repeated taps or
  different devices, lead to the same single conversation.
- **SC-003**: Under normal connectivity (see Assumptions), a new message reaches the recipient's open app (conversation,
  list update or red dot) within 3 seconds in 95% of cases.
- **SC-004** *(deferred with notifications)*: Under normal connectivity (see Assumptions), a recipient whose app is in the background or closed receives
  the notification within 10 seconds in 95% of cases.
- **SC-005**: Under normal connectivity (see Assumptions), the sender sees "read" within 3 seconds of
  the recipient viewing the message in 95% of cases.
- **SC-006**: An existing conversation opens with its most recent messages within 2 seconds under
  normal connectivity (see Assumptions).
- **SC-007**: Unread counts and the red dot are correct (no stale or missing indicators) in 100% of
  tested scenarios.
- **SC-008**: 0 cases where a non-participant can read, send or delete messages for a conversation
  during security testing (receiving its notifications: deferred with notifications).
- **SC-009**: 100% of failed messages keep their text and can be resent once connectivity returns.
- **SC-010**: All existing app flows covered by regression testing behave as before the feature.
- **SC-011**: Under normal connectivity (see Assumptions), each older batch of 20 messages appears within 2 seconds of
  reaching the top in 95% of cases, and in 100% of tested scenarios (long histories, exact multiples
  of 20, messages arriving or deleted during loading, rapid repeated scrolling) messages are never
  duplicated, missing or out of order and the visible message does not jump.

## Assumptions

- Messages are text only; images, attachments, voice notes, message editing, blocking, reporting and
  a setting to turn off read receipts are out of scope for this version.
- Deleting a conversation only affects the deleting user's side (FR-027a); there is no way to delete
  a conversation for both participants.
- *(Deferred with notifications)* The project owner approved adding the dependency needed for device
  notifications; it is not used in this version, which adds no new package.
- Within a conversation, "buyer" means the user who started it and "seller" the car owner; no new
  roles are introduced and admins participate as ordinary users.
- The inquiry text is a fixed English template, matching the app's current English UI.
- *(Deferred with notifications)* Notifications show the message preview; privacy-hiding of previews
  on the lock screen follows the device's own settings.
- Conversations and non-deleted messages are kept indefinitely.
- The existing sign-in system is reused; no separate chat account is needed.
- Users normally have internet connectivity; offline sending beyond failed/retry (FR-014) is not
  required.
- **Normal connectivity (performance test network)**, used by SC-003, SC-005, SC-006 and SC-011: the
  test device uses a stable Wi-Fi or 4G connection. Before each measurement session, a baseline
  probe runs from a computer on the same network: 10 consecutive reads of one small document in the
  app's database (hosted in the United States, location `nam5`). The session counts as normal
  connectivity when the probe median is **≤ 400 ms** with no failed request; the probe median and
  p95 are recorded with the results. Sessions above that are recorded as degraded and are not used
  to judge these success criteria. (The 400 ms bound follows from the targets: the slowest flow,
  sending, needs about five round trips plus delivery, which stays under 3 seconds at 400 ms.)
