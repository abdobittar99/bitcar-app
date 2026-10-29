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

### User Story 4 - Notifications when outside the app (Priority: P2)

When the app is in the background or closed, a user receives a device notification for each new
message, showing the sender's name and a preview of the text. Tapping the notification opens that
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
conversation; verify O never sees it and cannot read, send or delete anything in it, and receives no
notifications for it.

**Acceptance Scenarios**:

1. **Given** a conversation between A and S, **When** any other user, including an admin, uses the app,
   **Then** that conversation, its messages and its notifications are never available to them.
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
- Double tap or two devices trying to start the same conversation at once: only one conversation
  exists.
- A message exceeding the maximum length cannot be sent; long messages are shown fully wrapped.
- A long history opens on the most recent messages; older ones stay reachable by scrolling.
- The same account is signed in on two devices: reading a conversation on one device clears its
  unread count on the other.
- A message is deleted while the recipient has not read it yet: it no longer counts as unread, and any
  notification already shown is not retracted.
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
- **FR-009**: When opened from the conversations list or a notification, the input MUST be empty.

**Messaging**

- **FR-010**: Participants MUST be able to send text messages of 1 to 1,000 characters; empty or
  whitespace-only messages MUST NOT be sent.
- **FR-011**: Messages MUST be shown in chronological order with their send time, the user's own
  messages visually distinct from the other participant's.
- **FR-012**: While the app is open, new messages MUST be delivered live without manual refresh, on
  every screen.
- **FR-013**: Each message the user sends MUST show its state: sending, sent, read, or failed.
- **FR-014**: A failed message MUST keep its text and offer retry; retrying MUST NOT create duplicates.

**Unread counts & read receipts**

- **FR-015**: A received message MUST be counted as unread until the recipient views it in the open
  conversation; it then MUST be marked read, and the sender MUST see it as "read".
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

**Notifications**

- **FR-022**: When the app is in the background or closed, the recipient MUST receive a device
  notification per new message, showing the sender's name and a text preview.
- **FR-023**: Tapping a notification MUST open the related conversation, after sign-in if required.
- **FR-024**: Notifications MUST be sent only to devices where a participant is currently signed in;
  signing out MUST stop notifications for that account on that device.
- **FR-025**: If notification permission is denied, all other chat behavior MUST still work.

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

**Security & privacy**

- **FR-032**: Only a conversation's two participants MUST be able to see it, read, send or delete
  messages in it, or receive its notifications; this MUST be enforced by the system, not only by
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
- **Notification registration**: The link between a signed-in user and a device that may receive
  their chat notifications; removed on sign-out.
- **Car (existing)**: Supplies the owner identity and the brand, model and year for the inquiry text.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can go from a car's details page to a sent inquiry message in under 15 seconds
  and 2 taps.
- **SC-002**: 100% of contact attempts for the same pair of users, from any car, repeated taps or
  different devices, lead to the same single conversation.
- **SC-003**: Under normal connectivity, a new message reaches the recipient's open app (conversation,
  list update or red dot) within 3 seconds in 95% of cases.
- **SC-004**: Under normal connectivity, a recipient whose app is in the background or closed receives
  the notification within 10 seconds in 95% of cases.
- **SC-005**: The sender sees "read" within 3 seconds of the recipient viewing the message in 95% of
  cases.
- **SC-006**: An existing conversation opens with its most recent messages within 2 seconds under
  normal connectivity.
- **SC-007**: Unread counts and the red dot are correct (no stale or missing indicators) in 100% of
  tested scenarios.
- **SC-008**: 0 cases where a non-participant can read, send or delete messages, or receive
  notifications, for a conversation during security testing.
- **SC-009**: 100% of failed messages keep their text and can be resent once connectivity returns.
- **SC-010**: All existing app flows covered by regression testing behave as before the feature.

## Assumptions

- Messages are text only; images, attachments, voice notes, message editing, blocking and reporting
  are out of scope for this version.
- Deleting a conversation only affects the deleting user's side (FR-027a); there is no way to delete
  a conversation for both participants.
- The project owner has approved adding the new dependency required for device notifications
  (constitution: new packages need owner approval).
- Within a conversation, "buyer" means the user who started it and "seller" the car owner; no new
  roles are introduced and admins participate as ordinary users.
- The inquiry text is a fixed English template, matching the app's current English UI.
- Notifications show the message preview; privacy-hiding of previews on the lock screen follows the
  device's own settings.
- Conversations and non-deleted messages are kept indefinitely.
- The existing sign-in system is reused; no separate chat account is needed.
- Users normally have internet connectivity; offline sending beyond failed/retry (FR-014) is not
  required.
