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
   Edge Function relies on the Gemini provider's quota and rate limits.
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
17. **Class messaging, Subject Rate, and membership policies** —
    `20261020000000_fix_channel_message_realtime_and_rls.sql` fixes channel
    message realtime and access policies. The migrations
    `20261026000000_classes_members_subject_scores_schema.sql`,
    `20261026010000_strict_security_rls_subjects_scores.sql`,
    `20261026020000_student_weighted_averages_rpc.sql`,
    `20261026040000_subject_rate_system.sql`, and
    `20261026050000_subject_rate_rpc_policy.sql` add the class/subject-score
    schema, access policies, weighted-average RPCs, and Subject Rate system.
18. **Subject Rate normalization and classroom membership RLS** —
    `20261029161000_normalize_subject_rate_index.sql` normalizes classroom
    subject-rate data, while `20261029170000_fix_classroom_members_rls_recursion.sql`
    and `20261029172000_fix_class_members_rls_recursion.sql` prevent recursive
    membership policies.
19. **Default Subject Rate score** —
    `20261104173000_subject_rate_default_score.sql` sets new subject-rate rows
    to a neutral score of 5 without changing existing scores.
20. **Admin-managed app visuals** —
    `20261105160000_app_branding_assets.sql` adds the public login/overview
    image settings and a public Storage bucket whose uploads are restricted to
    developer accounts. Apply this migration before using the Admin Terminal
    visual-upload button.
21. **App visual crop settings** —
    `20261105170000_app_branding_image_crop.sql` stores the zoom and focal
    position selected in the Admin Terminal image preview editor.
