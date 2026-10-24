# App Actions and Screen Context

## 1. Purpose

The assistant should help a farmer navigate Gau-Prahari and understand the screen they are on. The AI decides which documented action best matches the request, but Flutter retains control of actual navigation and feature execution.

The AI is not a general-purpose remote-control layer. Its output is a suggestion in a strict contract, not executable code.

## 2. Action registry

Create a small Dart registry or equivalent fixed mapping. The list below is the only set of actions to support in the initial stages.

| Action name | Initial priority | Preconditions | Expected behavior |
|---|---|---|---|
| `scan_cow` | P0 | User is authenticated | Open the existing `QrScannerScreen` using current app navigation |
| `explain_current_screen` | P0 | Current screen name is known | Give a concise explanation based on the supplied screen context; no navigation |
| `explain_selected_cow` | P1 | A selected cow exists in current context | Summarize only fields available in the existing Cow object |
| `open_milk_tester` | P1 | Required cow/workflow arguments and an existing route are available | Navigate through the existing milk-tester flow; do not construct fake arguments |
| `explain_analysis_result` | P1 | A real current `AnalysisResult` is available | Explain the result and recommendations actually returned by the app |
| `start_collar_sync` | P2 | Existing collar sync action and needed controller/service are available in current workflow | Invoke the existing supported sync flow; otherwise explain that it is not available from this screen |

If an action cannot be executed safely with the available context, do not execute it. Ask the farmer to open the relevant screen, select the cow, or clarify the request.

The exact names above are internal action identifiers. User-facing language should be natural and localized.

## 3. Execution contract

For each action:

1. Parse the AI response into a typed Dart result.
2. Verify that the action name is on the allowlist.
3. Validate its arguments against the action-specific schema.
4. Check authentication and any required current-screen/workflow preconditions.
5. Invoke a known Flutter callback that reuses existing screen/controller behavior.
6. Capture the real success/failure result.
7. Persist the action name and outcome with the assistant message.
8. Speak a confirmation only after Flutter has invoked the action successfully.

Unknown actions, invalid arguments, and navigation failures must fail closed: no action is executed, and the farmer receives a clear response.

Do not dynamically instantiate a Dart class, call a method by an AI-supplied name, navigate to an arbitrary route, or open an arbitrary URL.

## 4. Current screen context

Build a small serializable context object from existing app state, for example:

```json
{
  "screen": "cow_selection",
  "selectedCow": null,
  "collarHistoryAvailable": false,
  "milkMeasurementAvailable": false,
  "analysisResultAvailable": false
}
```

These fields are illustrative. The implementation must derive each value from real current state and should omit unknown values or mark them unavailable. Do not make up state to fill the context object.

When a cow is available, include only relevant fields such as cow ID, breed, and current workflow status. Include a risk result only if an actual result object is present. Do not send unrelated profile data, login credentials, raw local database rows, or the entire collar telemetry history unless a future defined use case requires a specific summary.

## 5. Maintaining context with existing navigation

Current screens use direct `Navigator.push(MaterialPageRoute(...))` calls, and many route names may be unset. Inspect the relevant screens before implementation.

Use the smallest reliable context-reporting mechanism, such as:

- Explicit screen-context updates in the voice-enabled screens; or
- A narrowly scoped `NavigatorObserver` plus route settings for the screens whose names are needed.

Do not require a full navigation rewrite. In P0, prioritize the global scan action and a context explanation only when the context is known. Extend context coverage screen-by-screen as each existing flow is inspected.

The assistant entry point should not appear on the login screen. It should be available to authenticated users and should navigate through the root app navigator or another existing supported mechanism.

## 6. Safety and factuality

- Do not invent sensor readings, milk values, collar measurements, risk scores, model factors, or analysis outcomes.
- Do not claim that the cow has mastitis solely because an app result indicates elevated risk.
- When explaining a result, state what the application reports and follow its existing recommendations.
- Do not initiate hardware operations unless the existing flow exposes a tested action and its preconditions are satisfied.
- For actions that change data or produce consequential outcomes, ask for confirmation. Opening the QR scanner is a navigation action and does not require an extra confirmation in the MVP.
- If the screen context is missing or stale, ask a clarifying question rather than guessing.

## 7. First milestone

The first vertical slice is deliberately narrow:

- Show the assistant entry point for authenticated users.
- Understand a request equivalent to “Scan a cow.”
- Return a `scan_cow` action in the internal schema.
- Validate it in Flutter.
- Open the existing QR scanner.
- Speak a confirmation/instruction in the currently selected language.
- Persist the user transcript, assistant reply, and action outcome.
