begin;
alter table quotes add column pricing_rules jsonb not null default '{}';
commit;
