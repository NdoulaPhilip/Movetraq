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
