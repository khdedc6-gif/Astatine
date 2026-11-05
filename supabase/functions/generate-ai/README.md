# `generate-ai` Edge Function

The Flutter app calls this function with the caller's Supabase session. The
function validates the session and prompt/context sizes, and keeps the Gemini
key on the server. It does not impose an app-level request quota; Gemini
provider rate limits and quota still apply.

Before deployment:

1. Revoke/rotate any Gemini key previously included in a client build.
2. Set the rotated key in the Supabase project secret store (never commit it):

   ```powershell
   supabase secrets set GEMINI_API_KEY=YOUR_ROTATED_KEY
   ```

3. Apply the database migration, then deploy:

   ```powershell
   supabase functions deploy generate-ai
   ```

The Supabase Edge Function runtime provides `SUPABASE_URL` and
`SUPABASE_ANON_KEY` for session validation.

`GEMINI_MODEL` is optional. When it is set, the function verifies it against
Google's `ListModels` response. If it is unavailable, the function logs a
warning and selects an available model that supports `generateContent`.
This avoids turning a retired or unsupported model name into a provider `404`.

## Assignment draft mode

The function also supports `mode: "create_assignment_draft"`. This mode uses
the `get_assignment_template` tool adapter before asking Gemini to generate a
draft. The adapter currently exposes the four-option multiple-choice template
used by the Flutter assignment wizard.

The response is structured as:

```json
{
  "type": "assignment_draft",
  "template": "multiple_choice_four_options",
  "draft": {
    "title": "...",
    "subject": "Chemistry",
    "questions": [
      {
        "text": "...",
        "options": ["...", "...", "...", "..."],
        "correct_option": 0,
        "points": 10,
        "explanation": "..."
      }
    ]
  }
}
```

The function validates this shape before returning it. The Flutter wizard
loads the result into the form as a draft; it does not save or publish the
assignment automatically.
The requested question count is enforced (five by default, up to 20 per
request), and the output-token budget scales with the count. Responses stopped
by Gemini's output-token limit are returned as errors rather than incomplete
text.
