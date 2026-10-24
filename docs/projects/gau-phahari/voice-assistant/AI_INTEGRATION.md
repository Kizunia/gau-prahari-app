# Gemini AI Integration and API Configuration

## 1. Provider and model

Use Google Gemini API with initial model ID gemini-3.8-flash. Google's current model catalog lists this model as stable; availability and access must still be verified for the project/key before implementation.

Official documentation:
- Model catalog: https://ai.google.dev/gemini-api/docs/models
- API key use: https://ai.google.dev/gemini-api/docs/api-key
- Function calling: https://ai.google.dev/gemini-api/docs/function-calling
- Structured output: https://ai.google.dev/gemini-api/docs/structured-output

Use the existing Flutter http dependency. Confirm the current supported REST endpoint, authentication header, request body, and response format from Google's current documentation before implementing. Do not guess an endpoint or copy a legacy response parser without checking it against the selected model/API.

The assistant calls Gemini directly from Flutter for this hackathon MVP. Do not add a FastAPI assistant endpoint or alter the existing prediction API.

## 2. Local API configuration

Planned files:

- gau_prahari/lib/core/config/ai_config.dart — local config; ignored by Git.
- gau_prahari/lib/core/config/ai_config.example.dart — tracked template with placeholders only.

Update gau_prahari/.gitignore to ignore the real config path. Verify the rule with git check-ignore from the Flutter package directory and confirm the file is not already tracked.

Because a missing Dart import can break compilation even when tests don't need a live key, the setup instructions must tell a fresh checkout user to copy the example file to ai_config.dart and leave the key blank/placeheld when running tests. No valid API key should be required by unit/widget tests.

Do not commit a real key. The team accepts that a key embedded in a compiled Flutter APK can be extracted for this controlled hackathon demo. This is not a production credential-handling pattern. Use a dedicated demo key, apply provider-supported API/quota restrictions, avoid personal/production keys, and revoke/rotate the demo key after the event.

New Google AI Studio keys are currently created as authorization keys by default according to Google's API-key guide. Do not assume all keys have the same restrictions; follow the current official authentication instructions for the key that is actually created.

## 3. Request content

The request should include:
- The selected app language code: en, hi, or mr.
- Up to 20 recent messages from the active conversation.
- The new user transcript exactly once.
- A compact screen-context object only in Phase 4.
- System instructions describing a short, friendly farmer-facing assistant.
- Only action declarations supported by the current implementation phase.

Do not send the entire local DB, raw audio, API key in the prompt/body, unrelated profile data, or full cow records. Authenticate using the current documented mechanism for the selected API.

## 4. Internal response contract

Normalize the provider response into a typed internal result equivalent to:

    reply: non-empty string
    action: null OR { name: allowlisted string, arguments: object }

In Phase 2, action execution is disabled. The model must not trigger navigation during this phase.

In Phase 3, the only executable action is scan_cow with empty arguments. The Phase 4 allowlist can expand only when the implementation adds and tests those actions.

A structured model output/function call is an aid to parsing, not an authorization decision. Flutter must validate action names, arguments, current state, and result. Unknown/malformed responses must not execute.

## 5. Assistant instructions

Require the model to:
- Respond in the selected app language when supported.
- Use concise, simple instructions suitable for farmers.
- Prefer one or two next steps at a time.
- Use only the provided conversation and context when describing current app state.
- Ask a short clarifying question if required context is missing.
- Never claim an action happened before Flutter confirms it.
- Never invent measurements, telemetry, risk scores, result factors, diagnoses, or test outcomes.
- Explain actual analysis output as app-generated risk information, not as a definitive veterinary diagnosis.
- Return only the response/action structure required by the current phase.

## 6. Error handling

Handle missing configuration, offline state, timeout, HTTP errors, quota/rate-limit response, invalid JSON, empty reply, and unsupported/invalid action. Use a finite timeout and typed error outcomes. Do not log keys, authorization headers, or complete sensitive request payloads. Do not retry indefinitely.

Tests should use a fake/injectable AI service and must not require a live network or valid key.
