# App Actions and Screen Context

## 1. General rule

The AI may recommend one of a small set of named actions. Flutter validates and executes actions. Model output is not executable code. Never accept arbitrary route names, URLs, method names, shell commands, SQL, or Dart code from the model.

## 2. Phased action scope

| Phase | Action scope |
|---|---|
| 1 | No AI actions; local responder only |
| 2 | No actions execute, even if the model suggests one |
| 3 | Only scan_cow |
| 4 | Read-only contextual help/explanation actions when supported by current state; any additional navigation/hardware actions require explicit implementation and acceptance |

### Phase 3 action: scan_cow

- Name: scan_cow
- Arguments: empty object
- Preconditions: authenticated user; app is not already on the QR scanner; existing scanner route is available
- Effect: open the existing QrScannerScreen
- Confirmation: only after Flutter dispatches the action successfully
- History: persist the action name and outcome with the conversation turn

Do not duplicate the scanner or implement an alternate scanning flow.

## 3. Navigation and back-stack behavior

Current screens use direct Navigator and MaterialPageRoute calls. The assistant screen should return an action request to the invoking authenticated screen, which dispatches it through a reusable handler. Inspect the current route stack before choosing the exact callback/return-value implementation.

After scan_cow, the scanner must be visible without the assistant overlay covering it. After scanning and continuing, existing navigation should behave naturally; pressing back must not unexpectedly reopen the assistant or leave a broken stack.

Expose the assistant entry point on cow selection, collar import, milk tester, and analysis-result screens. Hide it on login/register and while the QR scanner is active.

## 4. Screen context in Phase 4

Create a small typed context description derived from real in-memory state, for example:
- Current screen/workflow.
- Current selected cow: ID and only the relevant existing fields.
- Collar history availability and approved summary, where present.
- Milk measurement availability and approved fields, where present.
- Analysis result availability and actual returned fields, where present.

The current Cow model has ID, tag number, breed, age, lactation stage, and status. Existing screens pass Cow/CollarHistory/MilkMeasurement/AnalysisResult through the workflow. The app-wide assistant cannot assume those values are automatically available; owning screens must publish/update context explicitly.

Update context on entry and when state changes. Clear or replace it when leaving the workflow, changing cow, or making old result data irrelevant. If context is absent or stale, ask for clarification rather than guessing.

Only send context needed for the user’s request. Do not send login credentials, unrelated user information, all telemetry, entire local DB rows, or unnecessary records.

## 5. Phase 4 contextual guidance

Support basic questions such as:
- “What can I do on this screen?”
- “Which cow am I testing?”
- “What should I do next?”
- “Explain this result.”

Use only the available current app data. The assistant may explain what the application reports but must not invent sensor measurements, risk values, model factors, or diagnoses. Analysis explanations must make clear that the app shows a risk result, not definitive veterinary diagnosis.

Do not add collar-sync or milk-tester-starting actions merely because they are mentioned in older plans. An action is not enabled until its callback, arguments, preconditions, expected outcome, and manual acceptance test are specified and implemented.
