import { beforeEach, describe, expect, it, vi } from 'vitest';
const fixtures = vi.hoisted(() => ({ upload: {} as Record<string, unknown>, info: vi.fn(), download: vi.fn(), signed: vi.fn(), rpc: vi.fn() }));
vi.mock('../src/config/supabase.js', () => ({ supabaseAdmin: {
  from: () => { const query: any = { select: () => query, eq: () => query,
    maybeSingle: async () => ({ data: fixtures.upload, error: null }) }; return query; },
  storage: { from: () => ({ info: fixtures.info, download: fixtures.download, createSignedUrl: fixtures.signed }) }, rpc: fixtures.rpc,
} }));
import { confirmPhoto } from '../src/services/evidence-service.js';
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aXioAAAAASUVORK5CYII=', 'base64');
beforeEach(() => {
  vi.clearAllMocks();
  fixtures.upload = { id: 'upload', submitted_by: 'courier', order_id: 'order', storage_path: 'private/random.png', mime_type: 'image/png' };
  fixtures.info.mockResolvedValue({ data: { contentType: 'image/png', size: png.length }, error: null });
  fixtures.download.mockResolvedValue({ data: new Blob([png]), error: null });
  fixtures.rpc.mockResolvedValue({ data: { verified: true }, error: null });
});
describe('server evidence content checks', () => {
  it('confirms a real image using stored metadata and content', async () => {
    await expect(confirmPhoto('courier', 'upload')).resolves.toEqual({ verified: true });
    expect(fixtures.rpc).toHaveBeenCalledWith('confirm_evidence_upload', { p_actor_id: 'courier', p_upload_id: 'upload', p_path: 'private/random.png', p_size: png.length });
  });
  it('rejects oversized objects before downloading them', async () => {
    fixtures.info.mockResolvedValue({ data: { contentType: 'image/png', size: 1572865 }, error: null });
    await expect(confirmPhoto('courier', 'upload')).rejects.toMatchObject({ status: 400 });
    expect(fixtures.download).not.toHaveBeenCalled(); expect(fixtures.rpc).not.toHaveBeenCalled();
  });
  it('does not trust an image MIME label for a text payload', async () => {
    const content = new Blob(['Not an image']);
    fixtures.info.mockResolvedValue({ data: { contentType: 'image/png', size: content.size }, error: null });
    fixtures.download.mockResolvedValue({ data: content, error: null });
    await expect(confirmPhoto('courier', 'upload')).rejects.toMatchObject({ status: 400 });
    expect(fixtures.rpc).not.toHaveBeenCalled();
  });
  it('maps truncated file signatures to validation failures', async () => {
    const truncated = new Blob([png.subarray(0, 9)]);
    fixtures.info.mockResolvedValue({ data: { contentType: 'image/png', size: truncated.size }, error: null });
    fixtures.download.mockResolvedValue({ data: truncated, error: null });
    await expect(confirmPhoto('courier', 'upload')).rejects.toMatchObject({ status: 400 });
    expect(fixtures.rpc).not.toHaveBeenCalled();
  });
});
