begin;
create table security_settings(user_id uuid primary key references profiles(id),pin_hash text,pin_salt text,updated_at timestamptz not null default now());
alter table security_settings enable row level security;
revoke all on security_settings from anon,authenticated;
-- Pin hashes are never returned to clients. PIN supplements authenticated sessions.
commit;
