create index notifications_unread_user_idx on public.notifications (user_id)
where read_at is null;
