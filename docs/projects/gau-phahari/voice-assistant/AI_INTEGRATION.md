# AI Integration and API Configuration

## 1. Decision

Call a hosted AI API directly from Flutter for the hackathon MVP. Use the existing `http` package unless repository inspection provides a concrete reason to replace it. Do not add a new assistant endpoint to the current FastAPI backend.

The provider and model are not yet selected. Choose them before wiring the API call, verify the current provider API documentation and response format, and contain provider-specific code inside `AiAssistantService`. Do not spread provider-specific logic across the controller or widgets.

## 2. Configuration files

Planned paths:

- `gau_prahari/lib/core/config/ai_config.dart` — local configuration, ignored by Git.
- `gau_prahari/lib/core/config/ai_config.example.dart` — tracked placeholder/template with no working key.

The actual config may expose constants for the provider API key, model identifier, and endpoint needed by the selected provider. Never place a real key in this specification, the example file, logs, screenshots, tests, or a tracked source file.

During implementation, update `gau_prahari/.gitignore` with the exact relative path:

```gitignore
/lib/core/config/ai_config.dart
```

Confirm with `git check-ignore -v lib/core/config/ai_config.dart` from the Flutter package directory, and confirm that the file is not already tracked before relying on the ignore rule. Keep the example config committed with a blank or obviously fake placeholder.

### Hackathon-only credential trade-off

A Git-ignored Dart file prevents the local source file from being committed accidentally; it does **not** protect the key in a compiled Flutter application. A person who obtains the APK may extract the embedded key. This is an explicitly accepted demo trade-off, not a secure production pattern.

For the demo, use a dedicated key with spending/quota restrictions where the provider supports them. Do not reuse a personal or production credential, and rotate/revoke the demo key after the event. No actual API key should ever be written into Git history.

## 3. Request content

Each AI request should contain:

- The current selected language code (`en`, `hi`, or `mr`).
- The bounded recent conversation window (see [Conversation storage](./CONVERSATION_STORAGE.md)).
- The latest user transcript.
- A compact, sanitized screen-context object.
- A system instruction defining assistant behavior and allowed action names.

Do not send raw audio, credentials, all locally stored conversations, the complete cow database, or full backend records. Send only the details needed to answer the current request.

## 4. Application-level response contract

Normalize the provider-specific response into this internal shape before returning it to the controller:

```json
{
  "reply": "Opening the cow scanner. Please scan the QR code on the collar.",
  "action": {
    "name": "scan_cow",
    "arguments": {}
  }
}
```

For an ordinary question with no app action:

```json
{
  "reply": "You are on the cow selection screen. You can choose a cow or scan its QR code.",
  "action": null
}
```

Contract:

- `reply` is required and must be non-empty plain text.
- `action` is either null or an object with a known `name` and validated arguments.
- Unknown fields can be ignored; malformed or unknown actions must not execute.
- Do not accept arbitrary route names, Dart method names, URLs, shell commands, SQL, or code from the AI.
- A natural-language reply is not evidence that an action succeeded. The controller must run the action handler and use its actual outcome.
- If the selected provider supports structured output/function calling, use it as an output aid; still validate the result in Flutter.

## 5. Allowed AI behavior

The system instruction should require the assistant to:

1. Respond in the currently selected app language.
2. Use simple, short, practical wording suitable for a farmer who may not be digitally experienced.
3. Give one or two actionable steps at a time.
4. Use only the supplied screen context and conversation for claims about the current app state.
5. Ask a brief follow-up when required information is missing.
6. Return only the documented action schema and allowlisted action names.
7. Never claim to have opened a screen, connected hardware, synced data, or completed a test unless Flutter reports that the operation succeeded.
8. Explain an existing analysis result faithfully, without inventing measurements, risk scores, factors, or diagnoses.
9. Make clear that the app's risk output is an aid and is not a veterinary diagnosis.
10. Refuse or give a safe alternative when asked to execute unsupported app actions.

## 6. Errors and fallback

Handle at least:

- No internet connection.
- Connection timeout.
- HTTP error response.
- Provider quota/limit response.
- Invalid response JSON.
- Empty reply.
- Unknown action or invalid arguments.
- Provider/model configuration missing.

Use timeouts and return typed errors from the service. The controller should present a short localized fallback message and keep the transcript in local history. Never expose raw provider payloads, stack traces, or credentials to the user.

Do not log the API key or authorization headers. Do not retry indefinitely; one small retry for a transient network failure is sufficient if implemented.

## 7. Testability

Keep the AI service behind an interface or injectable dependency so controller tests can supply a fake response without network access. Unit-test JSON parsing and action allowlisting independently of the live provider.

Do not require a working API key to run the normal Flutter test suite.
