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
flutter test                               # whole suite (constitution gate): chat, session gate, app_error_listener
```

**Firebase Emulator Terminal (JDK 21, session only):**

```powershell
Push-Location firestore_tests; npm install; Pop-Location   # once (npm --prefix ... install fails on npm 10)
firebase emulators:exec --only firestore --project demo-bitcar "npm --prefix firestore_tests test"
```

- **Expected `npm audit` output in `firestore_tests/`**: "5 high severity vulnerabilities". They are two advisories
  in `@grpc/grpc-js@1.9.16` (GHSA-m9gg-hp2v-232j, GHSA-f596-whhp-79r4) counted on each dependent package. Both affect
  **gRPC servers** only; here the package is a **development dependency** used as a **client** to the local Firestore
  emulator, so they do not apply. The fixed versions are outside the range the Firestore SDK allows (`~1.9.0`).
  **Do not** run `npm audit fix --force` (it downgrades `firebase` to 9.x) and do not add `overrides`. Re-check after
  any Firebase JS SDK update (details: research D13).
- The rules suite runs fully offline against the emulator with the `demo-bitcar` demo project, so it cannot read or
  write the real `carshop-b79bc` project.
- It tests the project's real root `firestore.rules` (loaded by `firestore_tests/helpers.js`; no copy), and
  `config.test.js` fails if `firebase.json` stops pointing to that file.
- Coverage: R1–R15 (chat), R16–R20 (`publicProfiles`), allowed paths, E1–E13 + S1/S2 (existing collections), per
  [contracts/firestore-security-rules.md](contracts/firestore-security-rules.md). It must pass before any deploy.
- The old default counter test `test/widget_test.dart` is replaced by `test/core/errors/app_error_listener_test.dart`
  (no Firebase), so the whole `flutter test` run must be green.

## Deploy (Spark-compatible, after review)

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

- **Never run a bare `firebase deploy`**: `firebase.json` includes the `functions` codebase, which cannot be deployed on
  Spark.
- The CLI may offer to delete indexes missing from the root `firestore.indexes.json` (the existing `cars` indexes are in
  `project-root/firestore.indexes.json`). **Answer No.**

### Early rollout after batches B2 and B4 (owner decision 2026-11-02)

Every step that touches `carshop-b79bc` needs the owner's explicit approval **at that moment**.

1. Indexes only: `firebase deploy --only firestore:indexes`; wait until the `conversations` index shows **Enabled**
   in the Firebase console (Firestore → Indexes).
2. Review the rules diff and the green rules suite (B2) and the existing-feature regression (B4).
3. Back up the currently deployed rules (Firebase console → Firestore → Rules → copy into a dated local file outside
   `lib/`), so they can be restored.
4. Rules only: `firebase deploy --only firestore:rules`.
5. On the **real phone**: re-test sign-in, cars, favorites, search and profile before starting B6.

T087 still runs at the end to deploy the final versions.

### Test devices and data

- B4 regression and all sign-out checks run on the owner's real Android phone. Two-account chat scenarios use two
  real devices when possible, otherwise the phone plus an Android Emulator.
- Use dedicated test accounts only; never real users' conversations or data.
- Q19/Q22 histories (45, 40 and 100 messages) are created **from the app** with the test accounts, respecting the
  20 messages/minute limit (send in bursts of at most 20 per minute; 100 messages take about 5 minutes).

## Performance baseline probe (before measuring SC-003, SC-005, SC-006, SC-011)

Run in any PowerShell window on a computer connected to the **same network** as the test devices (no JDK, Flutter
or emulator needed). It defines "normal connectivity" for the session (spec Assumptions): median **≤ 400 ms**, no
failed request. Use a **test account** only; set the values as session variables, never write them to a file:

```powershell
$apiKey = "<api_key from android/app/google-services.json>"
$email  = "<test account email>"; $pass = "<test account password>"
$carId  = "<id of any existing cars document>"
$auth = Invoke-RestMethod -Method Post `
  -Uri "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey" `
  -ContentType "application/json" `
  -Body (@{ email = $email; password = $pass; returnSecureToken = $true } | ConvertTo-Json)
$url = "https://firestore.googleapis.com/v1/projects/carshop-b79bc/databases/(default)/documents/cars/$carId"
$runs = 1..10 | ForEach-Object {
  $code, $sec = (curl.exe -s -o NUL -w "%{http_code} %{time_total}" -H "Authorization: Bearer $($auth.idToken)" $url) -split ' '
  [pscustomobject]@{ Code = $code; Ms = [double]$sec * 1000 }
}
$failed = ($runs | Where-Object Code -ne '200').Count
$sorted = $runs.Ms | Sort-Object
"failed: $failed   median ms: {0:N0}   p95 ms: {1:N0}" -f (($sorted[4] + $sorted[5]) / 2), $sorted[9]
```

- `failed` must be 0; any non-200 response makes the session degraded.
- Record the median and p95 next to the SC measurements (T085).
- The database is in `nam5` (United States), so the probe includes the full network path to it.

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
| Q18 | Regression: register (buyer/seller), profile edit, favorites, search, my cars, admin edit/delete car and ad | Behave as before | FR-036, SC-010, audit E1–E13 |
| Q18a | Sign in as any user, check `publicProfiles/{uid}` in the console | Doc exists with only `displayName`, equal to the user's `fullName` | sync point 1 |
| Q19 | Seed an A–S conversation with 45 messages; A opens it | Newest 20 shown, newest at the bottom; scroll to top → progress row, 20 more above; again → last 5 and "Beginning of the conversation"; no further requests | FR-037, FR-038, FR-043c |
| Q20 | While reading in the middle, reach the top; note the top visible message | It stays at the same screen position after the batch is added; no message appears twice; order by time | FR-039–FR-041, SC-011 |
| Q21 | Fling repeatedly at the top during loading; meanwhile S sends a message, deletes one of the newest 20 and one older message | One request per batch; while A is scrolled up the screen does not move and a "New messages" chip appears; the new message appears once; the deleted recent message turns into the placeholder at once; the deleted older message shows the placeholder after A reopens the chat; A's older own messages still turn "read" live | FR-039, FR-042, FR-044, FR-045 |
| Q21a | A scrolled up; A sends a message. Then S sends 25 messages while A's chat is closed; A opens it | Sending jumps to the newest message. On opening, only 20 are loaded but the unread badge clears and S sees all 25 as read | FR-046, FR-015 |
| Q22 | Conversation with exactly 40 messages; then, on a device that has not received the whole history (clear the app's data, sign in, open the 100-message conversation, load one older batch, leave it), airplane mode, reopen and scroll up | 40: one extra empty request ends with the "beginning" label, no error. Offline: only the cached messages shown (a device that sent or received the whole history has all of it cached and shows all of it), offline banner, "No more saved messages" row, no "beginning" label, no repeating progress indicator; reconnect → loading continues. Older-batch failure + Retry is covered by unit tests (T046), not run manually | FR-043, edge cases |
| Q23 | **Real Android device** (not only an emulator): sign in as A; open the conversations list, two chats (scroll older batches), favorites and profile; sign out; sign in as O on the same device; repeat with airplane mode on before signing in as O | O never sees A's conversations, messages, favorites or profile, online or offline; no `permission-denied` snackbar during sign-out; Firestore works normally for O after sign-in (new instance after `terminate`) | FR-014b, FR-053, research D18 |
| Q24 | Airplane mode; A toggles a favorite (queued write); A taps Logout | Warning dialog; **Cancel** keeps A signed in and the favorite syncs after reconnect; **Log out** signs out and the change is discarded. With no pending writes, Logout signs out directly | FR-052 |
| Q25 | Kill the app during sign-out (after "Signing out…" appears); reopen | Sign-out completes and data is removed before any screen with user data appears; the login screen is shown | FR-053 |
| Q26 | **Not run manually** (owner decision 2026-11-02): the app is not connected to the Firestore emulator in this phase, so the "stop the emulator, then Retry" check and access-removal check cannot be done by hand | Covered by unit tests: `chat_bloc_test.dart` group `stream errors` (T045): loaded messages kept, one automatic retry after 3 s, Retry re-subscribes once without duplicates, `permission` errors shown without Retry | FR-054, research D17 |

Notification scenarios (former Q10–Q15) are deferred with User Story 4.
