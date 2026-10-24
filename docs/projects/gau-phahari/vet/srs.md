# Software Requirements Specification (SRS)
## Gau-Prahari — Farmer–Veterinarian Review System

**Version:** 1.0  
**Status:** Ready for implementation  
**Target platforms:** Flutter Android and Flutter Web  
**Backend:** Firebase Authentication and Cloud Firestore  
**Implementation agent:** OpenAI Codex

---

# 1. Project Overview

## 1.1 Purpose

Gau-Prahari is an AI-IoT application intended to support early detection of bovine mastitis. The existing application allows a farmer to select a cow, collect or import collar telemetry, record milk measurements, and view an AI-generated analysis result.

This feature introduces a communication workflow through which a farmer can submit an AI prediction and its supporting data to a selected veterinarian for review.

The veterinarian can inspect the submitted report, add an assessment or advice, ask follow-up questions, and communicate with the farmer through a request-specific message thread.

The implementation must integrate with the existing Flutter application and support both Android and web.

## 1.2 Goals

1. Allow farmers to request a veterinarian's review from the existing prediction-result screen.
2. Allow farmers to select a registered veterinarian.
3. Submit an immutable snapshot of the prediction and the available supporting health data.
4. Provide veterinarians with a dashboard of requests assigned to them.
5. Support two-way, append-only messaging for each review request.
6. Track review progress using defined statuses.
7. Allow farmers to view their current and historical review requests.
8. Use Firebase for real accounts, request storage, and real-time updates.
9. Preserve the existing isolated demo mode.
10. Keep the feature minimal, modular, and compatible with the existing Android and web applications.

## 1.3 Non-goals

The MVP must not implement:

- Push notifications.
- Video calls, voice calls, or file attachments in conversations.
- A general-purpose chat system outside review requests.
- Veterinarian appointment scheduling.
- Payments or billing.
- Manual veterinarian approval or verification workflows.
- A new AI model or changes to existing prediction logic.
- Automatic medical diagnosis by the veterinarian messaging feature.
- Offline submission or offline message synchronization.
- A wholesale redesign of the application.
- A migration of all existing demo users and records into Firebase.
- A new database for storing information already handled by the existing app.

---

# 2. Existing Application Context

Codex must inspect the current repository and working tree before implementation. The following project structure and behavior have been identified and must be verified against the current checkout.

## 2.1 Relevant existing components

| Component | Existing responsibility | Required integration |
|---|---|---|
| `lib/main.dart` | Application initialization, providers, authentication routing | Add Firebase initialization and the smallest necessary routing/provider changes |
| `lib/features/auth/` | Authentication entities, models, repository and login UI | Add real Firebase authentication while retaining isolated demo mode |
| `lib/features/cow_selection/` | Cow selection and cow profile information | Reuse cow data for report snapshots |
| `lib/features/analysis/presentation/screens/analysis_result_screen.dart` | Displays AI analysis and report-sharing actions | Add the Request Veterinarian Review action |
| `lib/features/analysis/domain/entities/analysis_result.dart` | Prediction, probability, risk level, factors, recommendation and timestamp | Include the existing result in the snapshot |
| `lib/features/milk_tester/domain/entities/milk_measurement.dart` | Milk temperature, pH, conductivity, SCC, fat, SNF and timestamp | Include available milk-test data |
| `lib/features/collar_import/domain/entities/collar_telemetry.dart` | Collar telemetry history and derived measurements | Include the available historical telemetry |
| Existing report-sharing functionality | Shares the clinical report, including the existing WhatsApp workflow | Preserve without behavioral regressions |

The existing app uses Provider-based state management and has a demo authentication repository backed by SharedPreferences. Existing users and screens must not be assumed to be Firebase users.

## 2.2 Architecture constraint

Use the existing architecture and naming conventions.

Prefer an additive structure resembling:

```text
lib/
  core/
    firebase/
      firebase_initializer.dart

  features/
    auth/
      data/
        repositories/
          firebase_auth_repository.dart

    vet_review/
      domain/
        entities/
          vet_profile.dart
          review_request.dart
          review_message.dart
        repositories/
          vet_review_repository.dart

      data/
        models/
          review_request_model.dart
          review_message_model.dart
        repositories/
          firestore_vet_review_repository.dart

      presentation/
        screens/
          veterinarian_login_screen.dart
          veterinarian_dashboard_screen.dart
          veterinarian_review_detail_screen.dart
          farmer_review_requests_screen.dart
          create_review_request_screen.dart

        widgets/
          review_request_card.dart
          review_status_badge.dart
          review_message_bubble.dart
```

This is a suggested organization, not permission to duplicate existing abstractions. Reuse suitable existing folders, repositories, models, and widgets where practical.

Do not introduce a second state-management framework.

---

# 3. User Roles and Authentication

## 3.1 Roles

The system supports two real Firebase account roles:

- **Farmer**
- **Veterinarian**

A user's role is selected during registration. Veterinarian accounts can self-register, and all registered accounts with the Veterinarian role appear in the veterinarian directory.

There is no manual approval workflow in the MVP.

## 3.2 Authentication requirements

**AUTH-01:** Real accounts must authenticate using Firebase Authentication with email and password.

**AUTH-02:** Registration must provide fields for name, email, password, password confirmation, and role.

**AUTH-03:** Registration must validate required fields and reject invalid email addresses, passwords that fail the configured Firebase policy, and mismatched password confirmation.

**AUTH-04:** On successful registration, create the corresponding Firestore user profile.

**AUTH-05:** The stored role must determine which real application area the user can access.

**AUTH-06:** Provide a separate veterinarian login screen, consistent with the existing application's design.

**AUTH-07:** A veterinarian login screen must not grant veterinarian access merely because the user selected that screen. Firebase authentication must succeed, and the stored account role must be Veterinarian.

**AUTH-08:** If a farmer signs in through the veterinarian login screen, display an appropriate error and do not open the veterinarian dashboard. Apply the equivalent restriction to veterinarian accounts entering the farmer-only area.

**AUTH-09:** Existing demo mode must remain available through a separate **Try Demo** entry point.

**AUTH-10:** Demo authentication and demo records must remain isolated from real Firebase users and review requests.

**AUTH-11:** Signing out must clear the active session and return the user to the appropriate login or entry screen.

**AUTH-12:** On application restart, restore the Firebase session when valid and route the user according to their stored role.

**AUTH-13:** Do not create a production bypass that allows arbitrary email/password combinations to authenticate.

## 3.3 User profile model

Firestore collection: `users`

Document ID: Firebase Authentication UID.

Suggested fields:

```json
{
  "uid": "firebase-auth-uid",
  "name": "Example User",
  "email": "user@example.com",
  "role": "farmer",
  "createdAt": "server timestamp"
}
```

For a veterinarian, `role` is `veterinarian`.

The example is illustrative. Use Firestore `Timestamp` values rather than storing actual timestamps as strings.

The client must not be able to change its own role after registration. Role updates must be restricted by security rules and trusted administrative mechanisms.

## 3.4 Veterinarian profile directory

Use the existing `users` collection with a role-filtered query unless the implementation establishes a compelling need for a separate public directory.

The directory must expose only the minimum information necessary for selection:

- Veterinarian UID.
- Display name.
- Email address, if needed by the interface.
- Optional professional designation if the existing data supports it.

Do not expose passwords, authentication tokens, private account metadata, or unrelated farmer data.

---

# 4. Functional Requirements

## 4.1 Farmer workflow: request a review

**FR-01:** Add a clearly visible **Request Veterinarian Review** action to the existing `AnalysisResultScreen`.

**FR-02:** Keep the existing report-sharing and Done/Select Next Animal actions functional.

**FR-03:** When the farmer taps the new action, open a screen or dialog that allows them to select a veterinarian from the registered veterinarian directory.

**FR-04:** Display the selected veterinarian's name before submission.

**FR-05:** Display a concise explanation of which information will be shared, including cow details, AI prediction, milk-test data, collar history, and available historical health records.

**FR-06:** Allow the farmer to review and confirm submission.

**FR-07:** Before submitting, construct an immutable snapshot from the actual data available at the time of submission.

**FR-08:** Create a new review request for each submitted prediction. Multiple requests for the same cow are permitted.

**FR-09:** On successful submission, show confirmation and provide a route to the submitted request.

**FR-10:** Prevent accidental duplicate submissions caused by repeated taps while a submission is in progress.

**FR-11:** If no veterinarians are available, allow the farmer to save the report as a local draft and submit it later.

**FR-12:** If network connectivity or Firestore operations fail, show an actionable error. Do not report successful submission unless the request has actually been persisted.

## 4.2 Report snapshot requirements

Each submitted request must contain a snapshot of the data available at submission time.

The snapshot must include:

### A. Cow profile

Use fields available from the existing `Cow` entity:

- Cow ID.
- Tag number.
- Name, if available.
- Breed.
- Age.
- Lactation stage.
- Current status.

### B. AI analysis

Use the existing `AnalysisResult` entity:

- Prediction.
- Probability or confidence value.
- Risk level.
- Contributing factors.
- Recommended action.
- Analysis timestamp.

Preserve the meaning and units of existing fields. Do not fabricate missing values.

### C. Milk measurements

Use the existing `MilkMeasurement` entity:

- Cow ID.
- Milk temperature.
- pH.
- Electrical conductivity.
- Somatic cell count (SCC), if available.
- Fat percentage, if available.
- Solids-not-fat (SNF), if available.
- Measurement timestamp.

### D. Collar data

Include the available `CollarHistory` data:

- Cow ID.
- Available timestamped records.
- Activity measurements.
- Skin temperature.
- Ambient temperature.
- Humidity.
- Temperature-humidity index (THI).
- Existing derived summary metrics where available.

Preserve timestamps and units.

### E. Historical health records

Include all historical health records available for that cow at submission time, including relevant previous analysis and measurement records accessible to the current application.

Codex must inspect the actual repository to identify where such history is stored. If the application currently has no historical health-record repository, do not invent a data source. Include the history that genuinely exists and document any unavailable category.

**FR-13:** The snapshot must be self-contained enough for the veterinarian to review the submitted case even if the farmer's current cow data or latest prediction changes later.

**FR-14:** Later changes to the cow profile, collar readings, milk measurements, prediction, or historical records must not modify an already submitted snapshot.

**FR-15:** Do not copy unrelated cows' records into the snapshot.

**FR-16:** Store snapshot data in a consistent, Firestore-compatible structure. Convert existing entities to plain maps or explicit model representations, and normalize unsupported values before writing.

**FR-17:** If the snapshot exceeds Firestore document-size limits, do not silently truncate it. Use an appropriate subcollection or another explicitly designed storage strategy, preserving snapshot immutability.

## 4.3 Draft behavior

**FR-18:** When no veterinarian is available, allow the farmer to save a draft.

**FR-19:** A draft must remain separate from submitted review requests and must not appear in a veterinarian's dashboard.

**FR-20:** Drafts may be stored locally for the signed-in farmer, using an existing local persistence mechanism where suitable.

**FR-21:** The draft must retain the intended report snapshot so the farmer does not have to repeat the analysis merely because a veterinarian was unavailable.

**FR-22:** When a veterinarian becomes available, the farmer can select one and submit the saved draft.

**FR-23:** A draft becomes a submitted review request only after successful persistence to Firestore.

**FR-24:** Drafts must not be uploaded under a demo identity or shared across real accounts on the same device.

## 4.4 Farmer review-request list

**FR-25:** Provide a **My Review Requests** screen accessible to farmers.

**FR-26:** Show submitted requests and drafts, with drafts clearly distinguished.

**FR-27:** Submitted request cards must display:

- Cow tag or identifier.
- Prediction label.
- Assigned veterinarian.
- Submission date.
- Current status.
- Whether new veterinarian activity is available, if it can be determined reliably.

**FR-28:** Tapping a submitted request opens its detail screen.

**FR-29:** The detail screen must show the submitted snapshot and its associated message thread.

**FR-30:** The farmer must be able to read messages after the veterinarian closes the request.

**FR-31:** Farmers cannot close or reopen a submitted request.

## 4.5 Veterinarian dashboard

**FR-32:** Create a veterinarian dashboard accessible to real users whose role is Veterinarian.

**FR-33:** The dashboard must display only review requests assigned to the authenticated veterinarian.

**FR-34:** Use a Firestore query filtered by the veterinarian's UID.

**FR-35:** Display at least the cow identifier, prediction, risk level, farmer display name, submission date, and request status.

**FR-36:** Provide status filtering for Pending, In Review, Responded, and Closed.

**FR-37:** Tapping a request opens the detail screen.

**FR-38:** The veterinarian detail screen must show the immutable submitted snapshot, not just the farmer's latest live data.

**FR-39:** The veterinarian must be able to send messages and close an open request.

**FR-40:** The veterinarian must not be able to view requests assigned to other veterinarians.

**FR-41:** The dashboard must update while the application is open when relevant Firestore data changes.

## 4.6 Status lifecycle

Use these exact status values:

- `pending`
- `inReview`
- `responded`
- `closed`

Display user-friendly labels: Pending, In Review, Responded, Closed.

Transitions:

| Current status | Action | Next status |
|---|---|---|
| Pending | Veterinarian opens/accepts request | In Review |
| Pending | Veterinarian sends first assessment | Responded |
| In Review | Veterinarian sends a response | Responded |
| Responded | Farmer replies | In Review |
| Responded | Veterinarian closes request | Closed |
| In Review | Veterinarian closes request | Closed |
| Pending | Veterinarian closes request | Closed |

A farmer reply to an open request must set its status to In Review, as specified. The veterinarian can then respond or close it.

A Closed request is terminal in the MVP. No participant can reopen it or add new messages after closure.

The application must enforce valid transitions in both its UI and trusted data-access rules or backend logic where necessary. Client-side button visibility alone is not an access-control mechanism.

## 4.7 Messaging

**MSG-01:** Each review request has its own message thread.

**MSG-02:** Only the farmer who owns the request and the veterinarian assigned to it can read the thread.

**MSG-03:** Both participants can send text messages while the request is open.

**MSG-04:** Messages are append-only. Editing and deletion are not supported in the MVP.

**MSG-05:** Each message records:

- Message ID.
- Sender UID.
- Sender role.
- Message text.
- Server timestamp.

**MSG-06:** Reject empty or whitespace-only messages.

**MSG-07:** Set a reasonable configurable message-length limit, for example 2,000 characters.

**MSG-08:** Display messages in chronological order and identify the sender.

**MSG-09:** Use Firestore real-time listeners to update the open conversation while connected.

**MSG-10:** A message must be persisted successfully before the UI represents it as a confirmed server message. If optimistic display is used, clearly handle failed writes.

**MSG-11:** No messages can be added after a request becomes Closed.

**MSG-12:** The farmer's message changes the request status to In Review if the request was Responded.

**MSG-13:** The veterinarian's reply changes an open request to Responded.

**MSG-14:** A message and its related status update must be handled consistently. Use a transaction, batched write, or trusted backend operation appropriate to the selected schema and Firestore rules.

## 4.8 Notifications

**NOT-01:** Do not implement push notifications in the MVP.

**NOT-02:** Use live Firestore updates and in-app status/unread indicators.

**NOT-03:** A new request must appear in the assigned veterinarian's dashboard while it is open and connected.

**NOT-04:** New veterinarian replies must be visible to the farmer through the request list and conversation.

**NOT-05:** Do not add Firebase Cloud Messaging solely for this feature.

---

# 5. Proposed Firestore Data Model

Use the following as the baseline. Adapt names to existing repository conventions without changing the required semantics.

## 5.1 `users/{uid}`

```json
{
  "uid": "firebase-auth-uid",
  "name": "Example User",
  "email": "user@example.com",
  "role": "farmer",
  "createdAt": "Firestore Timestamp"
}
```

Roles: `farmer`, `veterinarian`.

The `uid` in the document must match its document ID.

## 5.2 `reviewRequests/{requestId}`

```json
{
  "farmerUid": "farmer-auth-uid",
  "farmerNameSnapshot": "Example Farmer",
  "veterinarianUid": "vet-auth-uid",
  "veterinarianNameSnapshot": "Example Veterinarian",
  "cowId": "COW-104",
  "cowTagNumber": "COW-104",
  "predictionLabel": "Example prediction",
  "riskLevel": "high",
  "status": "pending",
  "snapshotVersion": 1,
  "snapshot": {
    "cow": {},
    "prediction": {},
    "milkMeasurement": {},
    "collarHistory": {},
    "historicalHealthRecords": []
  },
  "createdAt": "Firestore Timestamp",
  "updatedAt": "Firestore Timestamp",
  "lastMessageAt": null
}
```

The example prediction is illustrative, not a prescribed model output.

Requirements:

- The document ID is generated uniquely.
- `farmerUid` and `veterinarianUid` are immutable after submission.
- The submitted snapshot is immutable after submission.
- `status`, `updatedAt`, and message summary metadata may change through permitted operations.
- Snapshot names and summary labels are captured at submission time.
- Store server timestamps for authoritative ordering.
- Do not put secrets or unnecessary personal information in the snapshot.

## 5.3 `reviewRequests/{requestId}/messages/{messageId}`

```json
{
  "senderUid": "firebase-auth-uid",
  "senderRole": "farmer",
  "text": "Please review the elevated risk result.",
  "createdAt": "Firestore Timestamp"
}
```

Requirements:

- Create a new document for each message.
- Never update or delete message documents.
- Use a server timestamp for `createdAt`.
- Validate sender identity and participant membership.
- Do not trust a client-supplied sender role without validating it against the user's profile or trusted authorization data.

## 5.4 Draft storage

Drafts are not shared with veterinarians.

Prefer a dedicated local draft repository using the existing persistence layer where feasible. Each draft should contain:

- A unique local draft ID.
- Farmer UID.
- Intended cow ID.
- Immutable report snapshot.
- Creation and last-updated timestamps.
- Submission state.

A draft must be scoped to the authenticated farmer. Do not reuse another account's draft after logout or account switching.

Do not add a server-side draft collection unless the existing architecture or a verified platform limitation makes local persistence unsuitable.

---

# 6. Firebase Setup and Configuration

## 6.1 Required Firebase services

Use:

1. Firebase Authentication — email/password.
2. Cloud Firestore — user profiles, review requests, and messages.

Do not add Firebase Storage, Cloud Messaging, or Cloud Functions unless a concrete requirement cannot be safely fulfilled with the selected minimal design.

## 6.2 Flutter dependencies

Inspect the existing `pubspec.yaml` before adding packages.

Add compatible versions of the official FlutterFire packages required for:

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`

Do not blindly copy old version pins from tutorials. Choose mutually compatible stable versions for the installed Flutter and Dart SDK, then update the lockfile appropriately.

## 6.3 Firebase project configuration

The repository audit did not identify tracked Firebase configuration files. Codex must verify the current working tree and project setup before proceeding.

The developer must configure the Firebase project and platform applications using the official FlutterFire workflow where appropriate.

Expected configuration may include:

- Firebase project configuration generated for Flutter.
- Android Firebase configuration.
- Web Firebase initialization configuration.
- Firebase Authentication email/password enabled in the Firebase console.
- Cloud Firestore database created in the intended project.
- Firestore security rules deployed to that project.

Do not invent Firebase project IDs, API keys, credentials, or service-account files.

Never commit service-account private keys or other privileged credentials.

If the project configuration is missing, implement the application integration and provide exact setup instructions. Clearly identify any steps that require the developer's Firebase project access.

## 6.4 Initialization

Initialize Firebase before constructing Firebase-backed repositories or listening to authentication state.

Preserve the existing Provider setup. Introduce Firebase initialization without unnecessarily restructuring `main.dart`.

The app must handle initialization errors clearly. Do not silently fall back from a real account to demo authentication.

Firebase initialization must work on both Android and web.

## 6.5 Environment separation

Keep demo mode isolated from Firebase-backed production data.

Do not allow a demo session to create or access real Firestore review requests.

Use explicit authentication/session state to distinguish demo and real accounts. Do not rely only on email-domain conventions or a display-name string.

---

# 7. Firestore Security Requirements

Security rules are part of the feature, not an optional deployment step.

## 7.1 General rules

- Deny access by default.
- Require Firebase authentication for private data.
- A user may read their own profile.
- A farmer must not modify their role.
- A veterinarian must not modify their role.
- Users must not create or modify arbitrary profiles for other UIDs.
- A farmer can read only review requests they own.
- A veterinarian can read only requests assigned to their UID.
- Only the assigned veterinarian can close a request.
- Neither participant can change the request's farmer or assigned veterinarian after submission.
- Neither participant can alter the immutable snapshot.
- Only request participants can read its messages.
- Only request participants can create messages while the request is open.
- Message documents cannot be edited or deleted.
- Demo records must not be treated as real Firebase records.

## 7.2 Important design constraint: registration and role integrity

The user has selected open veterinarian self-registration without manual approval. The MVP should honor this.

However, the role must still be protected from post-registration modification. A client must not be able to promote a farmer account to veterinarian by updating a Firestore document.

The implementation should establish the role during account creation and prevent subsequent self-service role changes.

The role selected by a user is not proof of professional credentials. A separate verification workflow is outside this MVP.

## 7.3 Important design constraint: status transitions

Firestore rules must validate status changes and restrict them to permitted participants and transitions.

If the chosen client-side transaction model cannot securely validate a status transition or coordinate it with message creation, use a minimal trusted backend operation rather than weakening the rules.

Do not ship permissive rules such as unrestricted reads/writes for all authenticated users.

## 7.4 Rules validation

Create or update Firestore rules and, where practical, add Firebase Emulator Suite tests for:

- Farmer reads own request.
- Farmer cannot read another farmer's request.
- Veterinarian reads assigned request.
- Veterinarian cannot read an unassigned request.
- Farmer cannot close a request.
- Farmer cannot change the assigned veterinarian.
- Participants cannot modify the snapshot.
- Nonparticipants cannot read or write messages.
- Messages cannot be edited or deleted.
- Closed requests reject new messages.
- Users cannot change their own role.

Directory access must expose only the minimum public veterinarian profile fields necessary for selection. Do not grant all users unrestricted access to every private user profile merely to populate the directory.

---

# 8. User Interface Requirements

## 8.1 General UI

- Reuse the existing Gau-Prahari design system, colors, typography, spacing, and navigation patterns.
- Maintain responsive layouts for Android and web.
- Avoid unnecessary redesign of existing screens.
- Provide clear loading, empty, error, and success states.
- Disable duplicate submissions while requests are being created.
- Use readable status labels and consistent status colors already available in the app, if any.
- Ensure keyboard entry and scrolling work on narrow screens and desktop browsers.
- Do not introduce decorative dashboards or charts unrelated to veterinarian review.

## 8.2 Farmer screens

### A. Prediction result screen

Add a Request Veterinarian Review button/action.

The existing prediction, clinical report sharing, and Done/Select Next Animal functionality must remain intact.

### B. Select veterinarian screen

Display:

- Available veterinarian names.
- Relevant designation if available.
- Selection control.
- Continue/submit action.

Include loading, empty, and retry states.

### C. Confirm and submit screen

Display:

- Selected veterinarian.
- Cow identifier.
- Prediction and risk summary.
- A concise summary of included data.
- Confirmation action.

Do not require the farmer to re-enter data already available in the app.

### D. My Review Requests screen

Show submitted requests and locally saved drafts, with status and assigned veterinarian.

Provide simple filtering only if it does not complicate the existing app.

### E. Farmer review detail screen

Display:

- Request status.
- Veterinarian identity.
- Submitted cow and prediction details.
- Milk-test values.
- Collar summary and available historical readings.
- Available historical health records from the snapshot.
- Chronological conversation.
- Message composer while the request remains open.

For Closed requests, display the thread in read-only mode.

## 8.3 Veterinarian screens

### A. Veterinarian login

Reuse the existing visual language but provide a distinct entry screen.

Authenticate with Firebase email/password and enforce the Veterinarian role.

### B. Veterinarian dashboard

Display requests assigned to the signed-in veterinarian.

Show request status and basic case information. Use live updates while connected.

Include a useful empty state such as: “No review requests assigned to you yet.”

### C. Veterinarian review detail screen

Display the immutable report snapshot in clearly labeled sections.

Provide:

- Status.
- Farmer identity.
- Cow identifier.
- Prediction and supporting measurements.
- Available collar history.
- Available historical health records.
- Message thread.
- Message composer while open.
- Close Request action.

Closing a request must require a deliberate user action, not occur simply because the veterinarian viewed the report.

## 8.4 Responsive web behavior

The same feature must work on Flutter Web and Android.

Verify:

- Web navigation and route handling.
- Responsive dashboard and detail layouts.
- Scrollable snapshot sections.
- Message composer behavior.
- Firebase initialization and authentication.
- No use of Android-only APIs in the review feature.
- No dependency on Bluetooth or other unavailable browser functionality.

Do not modify unrelated Bluetooth or AI assistant features to implement the review workflow.

---

# 9. Error Handling and Data Integrity

**ERR-01:** Handle invalid credentials, email already in use, weak passwords, and network failures.

**ERR-02:** Handle missing veterinarian directory results without crashing or creating an unassigned submitted request.

**ERR-03:** Preserve a local draft if submission fails after the farmer has created it.

**ERR-04:** Do not remove a draft until the corresponding submitted request is confirmed persisted.

**ERR-05:** If a submitted request fails to load, show a retry action.

**ERR-06:** Handle deleted, disabled, or otherwise unavailable accounts without exposing private data.

**ERR-07:** Prevent message sending after closure, including if the request becomes closed while a detail screen is open.

**ERR-08:** Prevent duplicate message creation from repeated taps.

**ERR-09:** Handle malformed or incomplete legacy records gracefully.

**ERR-10:** Treat missing measurements as unavailable rather than fabricating zero values.

**ERR-11:** Ensure timestamps are handled consistently across Android and web.

**ERR-12:** Do not claim that a veterinarian has reviewed a case until a veterinarian has actually sent a response or the UI otherwise has reliable evidence of that action.

---

# 10. Testing Requirements

## 10.1 Unit tests

Add tests for:

- Review request model serialization and deserialization.
- Snapshot construction from the existing entities.
- Preservation of timestamps and measurement values.
- Missing optional values.
- Snapshot independence from subsequent source-data changes.
- Status transition validation.
- Message validation.
- Draft creation, retrieval, and submission behavior.
- Role-based routing decisions.

## 10.2 Repository tests

Test the review repository for:

- Creating a request.
- Retrieving farmer-owned requests.
- Retrieving veterinarian-assigned requests.
- Reading messages in chronological order.
- Appending messages.
- Closing a request.
- Handling network and permission errors.
- Preventing writes to closed requests.

Use Firebase Emulator Suite where practical. Avoid tests that require access to a real production Firebase project.

## 10.3 Widget tests

Test:

- The review action appears on the analysis-result screen.
- Existing report-sharing actions remain available.
- The veterinarian selector handles loading, results, and empty states.
- Submission progress and errors are visible.
- Farmer request cards show the correct status.
- Veterinarian dashboard filtering works.
- Conversation messages display in order.
- Closed requests show a read-only conversation.
- Role-specific screens cannot be accessed through ordinary UI navigation by the wrong role.

## 10.4 Integration tests

At minimum, verify the following end-to-end scenarios:

1. A farmer registers, signs in, selects a veterinarian, submits a review, and sees the request.
2. The assigned veterinarian sees that request on their dashboard.
3. The veterinarian opens the report and sends a response.
4. The farmer sees the response without manually refreshing the page.
5. The farmer replies, and the request returns to In Review.
6. The veterinarian responds again and closes the request.
7. Both participants can still read the closed request and its message history.
8. A farmer cannot view another farmer's request.
9. A veterinarian cannot view another veterinarian's request.
10. When no veterinarian is registered, the farmer can save a draft and later submit it.
11. A demo session cannot access real review requests.
12. The feature works on Android and Flutter Web.

## 10.5 Regression tests

Run the existing project checks and relevant tests.

Verify that these existing capabilities continue to work:

- Login and demo entry.
- Cow selection.
- Milk measurement flow.
- Collar history import or retrieval.
- Analysis-result rendering.
- AI prediction integration.
- Clinical report sharing.
- Done/Select Next Animal navigation.
- Existing provider initialization.
- Android build.
- Web build.

Do not declare the feature complete merely because the new screens compile.

---

# 11. Acceptance Criteria

The MVP is accepted when all of the following conditions are satisfied.

### Authentication

- [ ] Real accounts register and sign in with Firebase email/password.
- [ ] Registration offers Farmer and Veterinarian roles.
- [ ] Separate veterinarian login is available.
- [ ] The authenticated user's stored role controls access.
- [ ] Existing demo mode remains available and isolated.

### Farmer submission

- [ ] The analysis-result screen includes Request Veterinarian Review.
- [ ] The farmer can select a registered veterinarian.
- [ ] The farmer can confirm the report before submission.
- [ ] The report contains a submission-time snapshot of available data.
- [ ] Multiple predictions can produce separate requests.
- [ ] Submission errors do not falsely report success.
- [ ] The no-veterinarian scenario supports a local draft.

### Veterinarian review

- [ ] Veterinarians see only requests assigned to them.
- [ ] Each request displays the original submitted snapshot.
- [ ] Veterinarians can send messages.
- [ ] Veterinarians can close open requests.
- [ ] Closed requests remain readable to both participants.

### Messaging and statuses

- [ ] Messages are append-only.
- [ ] Message creation is limited to the two participants.
- [ ] Farmer replies change Responded to In Review.
- [ ] Veterinarian responses change an open request to Responded.
- [ ] Closed requests cannot receive new messages.
- [ ] Relevant updates appear live while connected.

### Security and compatibility

- [ ] Firestore rules prevent unauthorized request and message access.
- [ ] Users cannot self-promote to veterinarian after registration.
- [ ] Snapshot data cannot be modified after submission.
- [ ] Android and web builds succeed.
- [ ] Existing application workflows pass regression checks.

---

# 12. Implementation Plan for Codex

Implement the feature in the following order.

## Phase 1 — Repository inspection

1. Inspect the current Git branch, working tree, and uncommitted changes.
2. Read the current `pubspec.yaml`, `main.dart`, authentication flow, entities, repositories, and analysis-result screen.
3. Verify the actual location and structure of historical health records.
4. Identify the existing routing and Provider patterns.
5. Identify whether Firebase has already been configured outside tracked files.
6. Report any blockers before destructive or broad changes.

Do not overwrite user changes or reset the working tree.

## Phase 2 — Firebase foundation

1. Add compatible FlutterFire dependencies.
2. Add Firebase initialization.
3. Implement Firebase email/password authentication and role-aware profiles.
4. Preserve demo authentication as a separate path.
5. Add the minimum required Firestore rules and configuration guidance.
6. Verify that the app can start on Android and web.

## Phase 3 — Review domain and repository

1. Implement the review request, message, and veterinarian profile entities.
2. Implement snapshot construction using the actual existing entities.
3. Implement the review repository interface and Firestore implementation.
4. Add status transition validation.
5. Implement local draft persistence.
6. Add unit and repository tests.

## Phase 4 — Farmer experience

1. Add Request Veterinarian Review to the existing analysis-result screen.
2. Implement veterinarian selection and confirmation.
3. Implement submission and local drafts.
4. Implement My Review Requests.
5. Implement the farmer review-detail screen and conversation.

## Phase 5 — Veterinarian experience

1. Implement the separate veterinarian login entry point.
2. Implement the assigned-requests dashboard.
3. Implement snapshot review.
4. Implement messaging and status updates.
5. Implement request closure and read-only closed conversations.

## Phase 6 — Security, testing, and regression

1. Validate Firestore rules and role boundaries.
2. Test status transitions and message restrictions.
3. Test empty, loading, offline, and permission-denied states.
4. Run existing tests and format/analyze the code.
5. Verify Android and web builds.
6. Provide a concise implementation report, including any Firebase console actions the developer still needs to perform.

---

# 13. Implementation Constraints

Codex must follow these constraints throughout the implementation:

1. **Minimal additive changes:** Reuse the existing architecture and avoid unrelated refactoring.
2. **No prediction changes:** Do not modify the AI model, prediction calculations, or existing analysis semantics.
3. **No regression:** Preserve existing Android and web behavior.
4. **No fabricated data:** Include only information actually available from the app or its stored history.
5. **Snapshot immutability:** Submitted report data must remain unchanged.
6. **Real access control:** Use Firebase Authentication and Firestore security rules, not UI-only checks.
7. **Demo isolation:** Never mix demo identities, requests, or messages with real Firebase data.
8. **Online-only submission and messaging:** Local drafts are the only explicitly supported offline workflow.
9. **No unnecessary services:** Do not introduce push notifications, a new backend, or additional infrastructure without a demonstrated need.
10. **No secrets in source control:** Never invent or commit privileged Firebase credentials.
11. **Explain setup requirements:** If a Firebase project or platform configuration is missing, document the exact developer action required.
12. **Verify before completion:** Report actual test and build outcomes. Do not claim checks passed if they were not run.

---

# 14. Expected Deliverables

Codex must deliver:

- Working Firebase initialization for Android and web, subject to the developer's Firebase project configuration.
- Real email/password authentication with Farmer/Veterinarian roles.
- Isolated Try Demo mode.
- Veterinarian directory and selection.
- Immutable report snapshot creation.
- Farmer review-request list and local draft workflow.
- Veterinarian assigned-request dashboard.
- Request-detail screens and two-way append-only messaging.
- Status transitions and veterinarian-controlled closure.
- Firestore security rules.
- Unit, repository, and relevant widget tests.
- Firebase setup instructions.
- A summary of files added or modified.
- A list of checks actually run and their results.
- Any remaining manual setup steps or limitations.

## Final instruction to Codex

Implement this specification against the current repository, not against an assumed clean project. Inspect existing code before editing, reuse the current Provider-based architecture, preserve all unrelated functionality, and complete the feature in small verifiable stages. If an implementation detail is unclear, prefer the simplest secure solution consistent with this specification and document the decision rather than expanding the MVP.
