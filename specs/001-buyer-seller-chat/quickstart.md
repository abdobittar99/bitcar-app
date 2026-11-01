# Quickstart: Validating Buyer–Seller Chat

**Feature**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md) · Rev. 3 (Firebase Spark, push deferred, public profiles)

How to prove the feature works end to end. Implementation details are in `tasks.md` (next phase).

## Prerequisites

- Flutter SDK matching `sdk: ^3.8.1`; `flutter pub get` (this feature adds **no** pub packages).
- Firebase CLI (15.3.0 installed) logged in to project `carshop-b79bc` (`.firebaserc`); the project stays on **Spark**.
- Node.js (20.x installed) for the rules tests.
- **Two dedicated PowerShell terminals** (owner decision; JDK 21 is installed next to JDK 17):

  | Terminal | JDK | Use it for | Never use it for |
  |---|---|---|---|
  | **Flutter Terminal** | 17 (current default) | `flutter`, `dart`, Gradle commands | Firebase Emulator, rules tests |
  | **Firebase Emulator Terminal** | 21, set for that session only | `firebase emulators:*`, `npm --prefix firestore_tests ...` | `flutter`, `dart`, Gradle |

  Set up the Firebase Emulator Terminal each time it is opened (adjust the path to the JDK 21 install folder):

  ```powershell
  $env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21"   # example path
  $env:Path = "$env:JAVA_HOME\bin;$env:Path"
  java -version                                                 # should report 21
  ```

  Nothing is written to the global `JAVA_HOME`, system environment variables, `flutter config`, or Gradle settings
  (`gradle.properties`, `org.gradle.java.home`).
- Two Android devices or emulators, each signed in to a different account.
- Test accounts: **A** (buyer), **S** (seller owning ≥ 2 cars), **O** (another user), **M** (admin, role set in the console).

## Local verification

**Flutter Terminal (JDK 17):**

```powershell
flutter analyze                            # no new issues (constitution gate)
flutter test test/features/chat            # chat unit + widget tests (blocs incl. pagination, message list, models, validator)
```

**Firebase Emulator Terminal (JDK 21, session only):**

```powershell
npm --prefix firestore_tests install       # once
firebase emulators:exec --only firestore --project demo-bitcar "npm --prefix firestore_tests test"
```

- The rules suite runs fully offline against the emulator with the `demo-bitcar` demo project, so it cannot read or
  write the real `carshop-b79bc` project.
- It tests the project's real root `firestore.rules` (loaded by `firestore_tests/helpers.js`; no copy), and
  `config.test.js` fails if `firebase.json` stops pointing to that file.
- Coverage: R1–R15 (chat), R16–R20 (`publicProfiles`), allowed paths, E1–E13 + S1/S2 (existing collections), per
  [contracts/firestore-security-rules.md](contracts/firestore-security-rules.md). It must pass before any deploy.
- `test/widget_test.dart` is the default counter template and fails independently of this feature.

## Deploy (Spark-compatible, after review)

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

- **Never run a bare `firebase deploy`**: `firebase.json` includes the `functions` codebase, which cannot be deployed on
  Spark.
- The CLI may offer to delete indexes missing from the root `firestore.indexes.json` (the existing `cars` indexes are in
  `project-root/firestore.indexes.json`). **Answer No.**

## End-to-end scenarios (app against the real project after deploy, or the emulator)

| # | Steps | Expected | Covers |
|---|---|---|---|
| Q1 | A opens a car of S → "Chat with Seller" | Chat opens marked new; header shows S's name; input holds "Hello, I'm interested in your <brand> <model> (<year>). Is it still available?"; phone button still present | US1, FR-004/007, FR-026 |
| Q2 | A leaves without sending; A and S open their lists | No conversation listed | FR-002 |
| Q3 | A sends the inquiry; opens another car of S → "Chat with Seller" | Same conversation with first message; new inquiry text in input; one conversation in both lists | FR-001/003, SC-002 |
| Q4 | Double-tap send / two devices start the same chat | One conversation, no duplicate messages | edge case, FR-014 |
| Q5 | S opens own car | No "Chat with Seller" button | edge case |
| Q6 | Both inside the chat; exchange messages | Appear within 3 s, ordered, own vs other distinct; A sees sending → sent → read | US2, FR-011–FR-013, SC-003/005 |
| Q7 | S on the home tab; A sends | Red dot on the app-bar chat icon | FR-017/021 |
| Q8 | S on the conversations screen; A sends | Conversation jumps to top; preview, time, unread badge update | FR-019 |
| Q9 | S opens the conversation | Badge cleared; red dot gone if no other unread; A sees "read" | FR-015/016 |
| Q10 | Airplane mode; send | Message marked failed with a clear error; retry after reconnect sends once | FR-014, SC-009 |
| Q11 | Kill app, airplane mode, reopen | List and loaded messages shown with offline banner; delete disabled | FR-014b |
| Q12 | Send 21 messages within a minute | 21st refused with "You're sending messages too fast…"; works again after the window | FR-014a |
| Q13 | A deletes own message | Both see "This message was deleted"; preview updates if latest; no delete option on S's messages | US5, FR-027 |
| Q14 | A deletes the conversation; S sends a new message | Gone from A's list, intact on S's; reappears for A with only the new message | FR-027a |
| Q15 | O and M (admin) use the app | Never see the A–S conversation; direct reads denied (R1) | US6, FR-032, SC-008 |
| Q16 | S changes their name in Edit Profile (no restart); A opens the existing A–S chat; O then starts a new chat with S | `publicProfiles/S` updated immediately; A–S keeps the old name (snapshot); the new O–S chat shows the new name | decision 5, sync point 2 |
| Q17 | A seller who has not opened the updated app receives a first message | A sees "BitCar user"; when the seller opens the app (profile synced) and then the chat, their real name replaces the placeholder for both | research D14, sync point 1 |
| Q18a | Sign in as any user, check `publicProfiles/{uid}` in the console | Doc exists with only `displayName`, equal to the user's `fullName` | sync point 1 |
| Q19 | Seed an A–S conversation with 45 messages; A opens it | Newest 20 shown, newest at the bottom; scroll to top → progress row, 20 more above; again → last 5 and "Beginning of the conversation"; no further requests | FR-037, FR-038, FR-043c |
| Q20 | While reading in the middle, reach the top; note the top visible message | It stays at the same screen position after the batch is added; no message appears twice; order by time | FR-039–FR-041, SC-011 |
| Q21 | Fling repeatedly at the top during loading; meanwhile S sends a message, deletes one of the newest 20 and one older message | One request per batch; while A is scrolled up the screen does not move and a "New messages" chip appears; the new message appears once; the deleted recent message turns into the placeholder at once; the deleted older message shows the placeholder after A reopens the chat; A's older own messages still turn "read" live | FR-039, FR-042, FR-044, FR-045 |
| Q21a | A scrolled up; A sends a message. Then S sends 25 messages while A's chat is closed; A opens it | Sending jumps to the newest message. On opening, only 20 are loaded but the unread badge clears and S sees all 25 as read | FR-046, FR-015 |
| Q22 | Conversation with exactly 40 messages; then airplane mode in a 100-message conversation and scroll up | 40: one extra empty request ends with the "beginning" label, no error. Offline: cached messages shown, offline banner, no "beginning" label; reconnect → loading continues. Force a failure (e.g. emulator stopped) → loaded messages kept, error snackbar, Retry loads the same batch | FR-043, edge cases |
| Q18 | Regression: register (buyer/seller), profile edit, favorites, search, my cars, admin edit/delete car and ad | Behave as before | FR-036, SC-010, audit E1–E13 |

Notification scenarios (former Q10–Q15) are deferred with User Story 4.
