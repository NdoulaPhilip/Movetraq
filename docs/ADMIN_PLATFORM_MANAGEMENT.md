# User Management and Platform Activity

## Activation

Apply `supabase/migrations/0012_platform_management.sql` after migration 0011.
Restart/redeploy the Node API and deploy the updated admin build. The local
console remains at http://localhost:5173 when the development server is running.
These new endpoints require migration 0012; they do not fabricate empty results
when database configuration is missing.

The new sections require `super_admin`, not `admin`. Existing administrators
retain their verification, support and pricing access. No account is promoted
automatically. Bootstrap the first Super Admin only using the project owner's
trusted SQL Editor, after independently verifying the user's Auth UUID and email:

```sql
begin;
insert into public.user_roles(user_id, role)
select id, 'super_admin' from auth.users
where id = 'REPLACE_WITH_VERIFIED_AUTH_UUID'::uuid
  and email = 'REPLACE_WITH_VERIFIED_EMAIL'
on conflict do nothing;
insert into public.audit_logs(action, entity, entity_id, metadata)
select 'super_admin_bootstrap', 'profiles', id,
  '{"source":"project_owner_sql_editor"}'::jsonb
from auth.users
where id = 'REPLACE_WITH_VERIFIED_AUTH_UUID'::uuid
  and email = 'REPLACE_WITH_VERIFIED_EMAIL';
commit;
```

Sign out and sign in after a role change to refresh the console navigation.
Backend authorization reads current database roles on every request.

## Sections and Contracts

- Users: searchable directory with role, status and UTC registration date filters,
  25-row pagination, recent activity, invitation, edit and deactivation.
- Administrators: the same directory restricted to accounts with staff roles.
  Remove elevated checkboxes to remove administrative permissions.
- Profile details: latest 25 orders/deliveries, ledger entries, verification
  applications, reports and activity events; private documents and payment
  credentials are not included in these responses.
- Platform Activity: server-generated registration, login, order-state, payment,
  wallet, verification and dispute events. Refreshes every 15 seconds while
  the tab is visible. Analytics refresh every 30 seconds.
- Audit Logs: actor, entity, timestamp, reason and previous/new state.

`GET/POST /api/v1/admin/users`, `GET/PATCH/DELETE /admin/users/:id`, and
`GET /admin/platform/{activity,audit,analytics}` are Super Admin-only. Query
and body validation reject unrecognized fields. Actor IDs come from verified
authentication, never request bodies. Permissions follow the existing fixed
role definitions, not user-editable arbitrary permission strings.

Creation sends a real Supabase Auth invitation. It requires Auth email delivery
and `ADMIN_INVITE_REDIRECT_URL=http://localhost:5173/accept-invitation` locally
(use the HTTPS admin origin in production). Add the same URL to Supabase Auth's
redirect allowlist. The standard invitation email must preserve the Supabase
confirmation link; after confirmation it redirects with the invitation session
in the URL fragment. The acceptance screen removes the fragment from browser
history, validates the session through Node, and lets the recipient set a
12-character-or-longer password. It does not automatically enter the staff
console; normal login and role checks still apply. Never use this redirect for
the mobile OAuth callback. The console never creates or displays user
passwords. A provisioning failure is reported explicitly and attempts to ban
the newly invited identity; inspect that identity before retrying.

Email is read-only for existing accounts. Changing login identifiers requires
a separate verified Auth workflow; profile editing changes name and phone only.

## Access and Retention

Self-management is forbidden. Privilege changes serialize in the database and
protect the last enabled Super Admin. Every successful management mutation and
its audit entry commit together. Suspended/deactivated accounts are rejected+
by API middleware, account loading, delivery eligibility and restrictive RLS
policies. Removing a role affects subsequent backend requests immediately.

Deactivation is not physical deletion. It removes roles and clears the public
name, phone and avatar; hides email in the directory; and records deleted and
anonymized timestamps. It cannot be reactivated through this console. UUIDs,
Auth identity, financial ledger, order/evidence history, support records and
audit trails are retained. This is limited profile anonymization, not a claim
that all personal data has been erased. Set jurisdiction-specific retention
periods and an independently reviewed erasure process before production launch.
Outstanding jobs/funds remain visible for operations and finance resolution.

No historical activities are invented or backfilled: activity collection begins
when migration 0012 is applied; existing audit logs remain available. Active
users means enabled accounts with a recorded event in the last seven days;
online deliverers must be enabled, have the deliverer role, and be verified.

## Verification

For migration 0013, expanded module coverage, authenticated realtime monitoring,
privacy-safe record previews and activation steps, see [Activity Monitoring](ACTIVITY_MONITORING.md).

Backend HTTP authorization/validation tests, embedded PostgreSQL migration and
retention/RLS tests, and desktop/mobile Playwright UI contract tests are provided.
Browser fixtures are test-only. Hosted invitations, actual Super Admin login,
and production email delivery require staging acceptance checks; local tests
do not establish that these external systems have been configured.

Local verification: both builds passed, 83 backend tests passed, and 16
desktop/mobile Playwright tests passed. Migration 0012 and email invitations
have not been executed against the hosted project by this implementation run.
