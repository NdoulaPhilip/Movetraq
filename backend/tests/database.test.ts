import { readFile, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';
import { afterAll, beforeAll, describe, it } from 'vitest';
import { readdirSync } from 'node:fs';

let database: PGlite;
const migrationDirectory = fileURLToPath(new URL('../../supabase/migrations/', import.meta.url));
const testDirectory = fileURLToPath(new URL('../../supabase/tests/', import.meta.url));

beforeAll(async () => {
  database = new PGlite({ extensions: { pgcrypto } });
  // Reproduce Supabase identities and default grants without contacting a project.
  await database.exec(`
    create role anon;
    create role authenticated;
    create role service_role bypassrls;
    create schema auth;
    create schema storage;
    grant usage on schema public, auth to anon, authenticated, service_role;
    create table auth.users (
      id uuid primary key, email text, raw_user_meta_data jsonb not null default '{}'
    );
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
    $$;
    create table storage.buckets (id text primary key, name text not null, public boolean not null,
      file_size_limit bigint, allowed_mime_types text[]);
    alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  `);
  const migrations = (await readdir(migrationDirectory)).filter((name) => name.endsWith('.sql')).sort();
  for (const migration of migrations) {
    const source = await readFile(`${migrationDirectory}/${migration}`, 'utf8');
    // PostGIS is currently unused by the schema; its deployment is tested in staging.
    await database.exec(source.replace('create extension if not exists "postgis";', '-- PostGIS not loaded in embedded tests.'));
  }
}, 60000);

afterAll(async () => { await database?.close(); });
describe('Supabase migrations on embedded PostgreSQL', () => {
  it.each(readdirSync(testDirectory).filter((name) => name.endsWith('.sql')).sort())('enforces %s', async (name) => {
    try {
      await database.exec(await readFile(`${testDirectory}/${name}`, 'utf8'));
    } finally {
      await database.exec('rollback;');
    }
  }, 10000);
});
