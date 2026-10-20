-- A separate committed migration is required before PostgreSQL can use the new enum value.
alter type public.verification_status add value if not exists 'pending_approval';
