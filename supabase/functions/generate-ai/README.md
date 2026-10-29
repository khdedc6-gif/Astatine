# `generate-ai` Edge Function

The Flutter app calls this function with the caller's Supabase session. The
function validates the session, enforces a 30-request daily quota, validates
prompt/context sizes, and keeps the Gemini key on the server.

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

The Supabase Edge Function runtime provides `SUPABASE_URL`,
`SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`. The service-role key is
used only by the function to consume the quota after the caller session has
been validated.
