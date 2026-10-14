# Archive Reference Migrations

These 16 SQL files belong to the separate implementation supplied in
`Movetraq.rar`. They were moved here with user approval to preserve them without
mixing incompatible schemas in the active migration chain.

Do not execute this directory against the current MoveTraq database. Active
migrations remain in `supabase/migrations/`, numbered `0001` through `0013`.
Adapt future archive features through reviewed forward migrations based on the
existing schema. This relocation changes local files only; no hosted database
or migration history was modified.
