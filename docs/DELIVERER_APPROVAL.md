# Deliverer Approval

New registrations remain senders. A workspace preference or the old `verified`
flag is not a deliverer permission. Both APIs now require authoritative approval
for deliverer work; role switching cannot grant that permission.

## Authoritative Records

Supabase `verification_applications` and `verification_documents` store all
applications and private documents. Migration `0015_mobile_deliverer_approval.sql`
adds an explicit `legacy_user_id` link for the existing mobile identity, without
inventing Supabase Auth accounts or changing wallet ownership. Exactly one
identity type is allowed per application. Existing Supabase applicants remain
compatible with the original workflow.

The mobile API verifies its own session and forwards the authenticated account
through the existing private server-to-server credential. It cannot accept a
client-provided applicant identity, status or approval. Neither that credential
nor Supabase privileged credentials are sent to Flutter.

## Workflow

1. Open Profile > Deliverer mode > Delivery verification.
2. Enter identity, age, transport and safety information.
3. Upload all server-required documents to private Supabase Storage using
   signed upload URLs. The backend confirms storage ownership, size and MIME.
4. Submit. Submitted and under-review applicants retain sender access only.
5. Authorized admin/verification staff review the application in the existing
   Delivery Verification screen, inspect signed document previews, mark it
   under review, then approve or reject it. All decisions are audited.
6. Approval enables delivery work on the same account. Status checks update the
   app every twenty seconds; every backend delivery operation checks approval
   again, independently of the client state.
7. Rejected applicants can correct and resubmit their application. Suspension
   cannot be cleared by the applicant; authorized staff must reopen the review.

Missing status, service outages and incomplete applications deny delivery work,
not sender login. Existing deliverer flags are not grandfathered as approvals.
Do not enable anyone by editing their local profile or by granting a role alone.

## Activation

Apply `supabase/migrations/0015_mobile_deliverer_approval.sql` once, after 0014,
to the existing Supabase project. Keep the original migration chain active.
The project HTTPS URL and API service-role key do not provide SQL migration
access: use the Supabase integration, SQL Editor, or a private database URL
stored as `SUPABASE_DB_URL` in ignored `backend/.env`.

The shared `MONITORING_SERVICE_TOKEN` must match on both APIs. Set
`DELIVERER_AUTHORITY_URL=https://movetraq-production-api.onrender.com` on the
legacy API. Deploy the Supabase API first, then the legacy API and admin, and
install a newly built APK. Until the migration and deployment are complete,
do not describe the new approval workflow as live.

No existing users are approved automatically, and no test applicant or fake
documents should be inserted into production to demonstrate the workflow.

The legacy PostgreSQL pool defaults to four connections (`PG_POOL_MAX`), with
idle cleanup and graceful shutdown. A ten-connection pool per instance exceeded
the hosted session pool's fifteen-client budget during rolling deployment.
Keep the combined old/new instance connection budget within the database limit.

## Application workflow repair - October 2026

The application form saves a resumable draft (`not_started`). A draft does not
notify reviewers or unlock delivery work. The status screen lists the required
identity/vehicle documents for the selected transport, marks server-confirmed
uploads, and enables **Submit for review** only after every required document is
confirmed. Returning from an upload refreshes the checklist immediately.

Final submission stores `pending_approval` and `submitted_at` in Supabase.
Flutter displays **Pending Approval** for this state and for an application
under review. Existing `submitted` records are migrated to `pending_approval`.
The database inserts an inbox notification for each active authorized reviewer
in the same transaction. Admin alerts and the pending queue refresh every five
seconds; this change does not configure email, SMS, or browser push delivery.

The admin queue filters pending applications before pagination, shows verified
private document previews, and requires a review stage and decision notes.
Choose **Review application** beside an applicant to open the review panel
(on narrow screens the panel scrolls into view). Enter review notes and select
**Start review**. After checking the private documents, enter decision notes
and choose **Approve application** or **Reject application**. A pending
application can also be rejected directly. Draft applications explain that the
applicant must finish uploading and submit before a decision is available.
Only active `verification_agent`, `admin`, or `super_admin` accounts may review.
Self review, applicant-supplied approval/ownership fields, direct client database
writes, and approval without required verified documents are rejected. Decisions
remain audited. Native Supabase applicants receive roles only after approval;
legacy mobile identities use the same approved application as their authority.

Self review includes a mobile applicant whose account email matches the signed-in
reviewer's email, even when the two accounts have different IDs. Super Admin
does not bypass this restriction. The dashboard disables these actions and the
API returns `SELF_REVIEW_FORBIDDEN` with instructions to use a different reviewer.
A Super Admin can authorize a separate existing account with the
`verification_agent` role through **Administrators**. Reviewers can then process
other applicants through the same private document and audited decision flow.

Approval, rejection and suspension create durable applicant notifications.
The legacy API imports these using stable IDs and acknowledges reads against
the owner's Supabase inbox. Flutter refreshes approval and notification state
at the existing twenty-second interval. Rejected applicants can correct their
information and re-verify documents; suspended accounts cannot restart the
application to bypass an administrator. Every delivery mutation still checks
current approval independently of the Flutter UI.

### Rollout order

1. Apply `0017_pending_approval_status.sql` and commit it **before** applying
   `0018_deliverer_application_workflow.sql`. PostgreSQL must commit the new enum
   value before the next transaction can use it. Apply only these new migrations
   to an existing project that already has migrations 0001 through 0016.
2. Use a connected Supabase integration/SQL Editor, or set `SUPABASE_DB_URL` in
   ignored `backend/.env` and run `node tools/apply-deliverer-workflow.mjs --apply`.
   The helper verifies the project identity, keeps TLS certificate validation,
   serializes schema changes, and does not print credentials. It does not use or
   modify the separate mobile Render database.
3. Check `node tools/apply-deliverer-workflow.mjs --check-hosted`. It calls only
   a read-only notification RPC for a deployment probe identity; it creates no
   test account, application, document, notification, or approval in production.
4. After the schema check passes, build/test and deploy the backend, mobile API,
   and admin, then install a newly built Android APK. The Render release helper
   refuses to deploy the workflow if the hosted RPC is missing. A normal GitHub
   push may auto-deploy services, so keep schema-dependent commits local or use
   `[skip render]` until the migration is applied.

The repository contains isolated PostgreSQL, HTTP, Flutter widget, upload
contract, and admin browser tests. These validate permissions and transitions
without inserting production fixtures. A real applicant must supply their own
legitimate documents for the final device acceptance check.

## Work preferences and approval refresh

Apply `0019_deliverer_work_preferences.sql` after 0018 before releasing the
preferences connection. The rollout helper checks the new schema before deployment.
The existing mobile preferences URL is used with `?scope=work` for GET/PATCH.
The authenticated mobile API binds the legacy user ID and calls the existing
private authority bridge; its service-only `mobile_deliverer_preferences` RPC
checks current approval and stores configuration on the reviewed application.
No Supabase Auth identity is fabricated for a mobile account. Existing RLS and
client column restrictions remain in place, and pending/rejected/suspended
accounts cannot access work preferences. Transport stays tied to the verified
application; preferences cannot grant approval or change identity information.

Flutter loads preferences before enabling save, confirms the server response,
and offers a retry after a failed load or save. Work preferences include service
choices, delivery area and notification settings; saving them does not enable
new push/SMS providers. Sender preferences are a separate existing feature.

Approval refresh runs at sign-in, every 20 seconds, and when the app resumes.
Same-account profile events update the profile without restarting the polling
timer. Failed approval checks restrict delivery access while preserving sender
access and expose a retry on the delivery access screen. Only read-only status
calls receive one bounded retry for transient bridge failures; application
submissions and other mutations are never blindly replayed. Sanitized bridge
failure logs record the command, reason and retry state without tokens or user
identities.
