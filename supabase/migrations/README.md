# Supabase migrations

Keep migration SQL files directly in this directory. The Supabase CLI discovers
and applies them in timestamp order; moving an applied migration into a
subdirectory or renaming it can break migration history.

Current feature groups, in application order:

1. **Classroom access** — `20261002000000_channel_access_controls.sql`
2. **Assignment recipients** — `20261003000000_assignment_recipients.sql`
3. **Quiz scoring** — `20261004000000_quiz_scoring_configuration.sql`,
   `20261004010000_rename_question_points.sql`, and
   `20261004020000_ensure_question_points.sql`
4. **Authenticated app access** —
   `20261010000000_authenticated_app_access_policies.sql` scopes classroom,
   assignment, submission, daily-quest, and profile-asset access to signed-in
   users, class membership, assignment recipients, and record owners.
5. **Chat hardening and rate limits** —
   `20261013084000_rate_limit_chat_and_harden_channel_inserts.sql` enforces
   channel write permissions, 2,000-character message limits, and a shared
   five-message-per-ten-second limit across chat tables. The `generate-ai`
   Edge Function separately enforces a 30-request rolling 24-hour quota.
   Deploy the Edge Function and configure its Gemini secret using the
   instructions in `../functions/generate-ai/README.md`.
6. **Channel creation RLS alignment** —
   `20261014130000_align_channel_creation_rls.sql` aligns the channel
   management policy with the app's classroom staff checks while still
   requiring staff to be members of the classroom.
7. **Channel management RLS fix** —
   `20261014140000_fix_channel_management_rls.sql` aligns channel management
   with the app's global teacher/developer permissions and normalizes
   classroom-role comparisons.
8. **Assignment teacher RLS** —
   `20261018140000_assignment_teacher_rls.sql` applies the same normalized
   teacher/developer and classroom-staff permissions to assignment creation,
   updates, and question management.
9. **Assignment INSERT RETURNING RLS** —
   `20261018150000_fix_assignment_returning_rls.sql` lets assignment authors
   read their own rows directly so Postgres can authorize `INSERT ... RETURNING`
   without relying on a nested lookup of the row being inserted.
10. **Admin terminal account commands** —
    `20261018170000_admin_terminal_account_commands.sql` adds timed/permanent
    ban metadata and developer-only RPCs for banning, unbanning, and granting
    wallet currency or subscription days, plus a global app maintenance flag
    that blocks non-developer app sessions. Apply this migration before using
    the corresponding Admin Terminal commands.
11. **Repair missing user and wallet records** —
    `20261018173000_repair_missing_user_wallet_records.sql` creates the
    `public.users` parent rows for existing Auth users that are missing them,
    then creates any missing wallet rows without overwriting existing balances.
12. **Align wallet user foreign key** —
    `20261018174000_realign_user_wallet_foreign_key.sql` points
    `user_wallets.user_id` at `public.users`, matching the application schema
    and allowing wallet rows to follow the app-user lifecycle.
13. **Force logout banned users** —
    `20261018190000_user_ban_realtime.sql` adds `public.users` to Supabase
    Realtime so active clients can immediately sign out when an administrator
    bans their account.
14. **Release notes management** —
    `20261018200000_release_notes.sql` creates the readable release-history
    table, limits content edits to `users.is_dev` accounts, and provides a
    developer-only RPC for creating the next patch version.
15. **Delete release notes** —
    `20261018210000_delete_release_note.sql` adds a developer-only RPC for
    deleting a release entry after confirmation in the Update Log dialog.
16. **Admin wallet currency type compatibility** —
    `20261018220000_fix_admin_give_resource_currency_type.sql` casts the
    currency value to the actual `wallet_transactions.currency` column type
    before recording developer grants, supporting both text and enum schemas.
