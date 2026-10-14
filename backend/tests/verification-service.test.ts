import { beforeEach, describe, expect, it, vi } from 'vitest';

const fixtures = vi.hoisted(() => ({ document: {} as Record<string, unknown>, info: vi.fn(), signed: vi.fn(), rpc: vi.fn() }));
vi.mock('../src/config/supabase.js', () => ({ supabaseAdmin: {
  from: () => { const query: any = { select: () => query, eq: () => query,
    maybeSingle: async () => ({ data: fixtures.document, error: null }) }; return query; },
  storage: { from: () => ({ info: fixtures.info, createSignedUrl: fixtures.signed }) }, rpc: fixtures.rpc,
} }));
import { confirmDocument, signedDocument } from '../src/services/verification-service.js';
const owner = { id: 'owner', roles: ['sender'] };
beforeEach(() => {
  vi.clearAllMocks();
  fixtures.document = { id: 'document', user_id: 'owner', storage_path: 'owner/application/random.pdf', mime_type: 'application/pdf', upload_verified_at: '2026-01-01' };
  fixtures.info.mockResolvedValue({ data: { contentType: 'application/pdf', size: 2048 }, error: null });
  fixtures.signed.mockResolvedValue({ data: { signedUrl: 'https://storage.example.test/signed' }, error: null });
  fixtures.rpc.mockResolvedValue({ data: { id: 'document' }, error: null });
});
describe('private verification documents', () => {
  it('denies outsiders and finance-only staff without requesting a URL', async () => {
    for (const roles of [['sender'], ['finance']]) await expect(signedDocument({ id: 'other', roles }, 'document')).rejects.toMatchObject({ status: 404 });
    expect(fixtures.signed).not.toHaveBeenCalled();
  });
  it('grants reviewers a short-lived URL for the stored private path', async () => {
    await expect(signedDocument({ id: 'reviewer', roles: ['verification_agent'] }, 'document')).resolves.toMatchObject({ expiresIn: 60 });
    expect(fixtures.signed).toHaveBeenCalledWith('owner/application/random.pdf', 60);
  });
  it('does not let reviewers confirm another account upload', async () => {
    await expect(confirmDocument({ id: 'reviewer', roles: ['admin'] }, 'document')).rejects.toMatchObject({ status: 403 });
    expect(fixtures.info).not.toHaveBeenCalled();
  });
  it('checks actual storage metadata before confirming an upload', async () => {
    await confirmDocument(owner, 'document');
    expect(fixtures.rpc).toHaveBeenCalledWith('confirm_verification_document', {
      p_user_id: 'owner', p_document_id: 'document', p_path: 'owner/application/random.pdf', p_size: 2048,
    });
  });
  it('rejects MIME mismatches and excessive file sizes without confirmation', async () => {
    fixtures.info.mockResolvedValueOnce({ data: { contentType: 'text/html', size: 2048 }, error: null });
    await expect(confirmDocument(owner, 'document')).rejects.toMatchObject({ status: 400 });
    fixtures.info.mockResolvedValueOnce({ data: { contentType: 'application/pdf', size: 10485761 }, error: null });
    await expect(confirmDocument(owner, 'document')).rejects.toMatchObject({ status: 400 });
    expect(fixtures.rpc).not.toHaveBeenCalled();
  });
  it('does not issue a download URL before confirmed upload', async () => {
    fixtures.document.upload_verified_at = null;
    await expect(signedDocument(owner, 'document')).rejects.toMatchObject({ status: 409 });
    expect(fixtures.signed).not.toHaveBeenCalled();
  });
});
