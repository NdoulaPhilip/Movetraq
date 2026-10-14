import { randomUUID } from 'node:crypto';
import { fileTypeFromBuffer } from 'file-type';
import { supabaseAdmin } from '../config/supabase.js';
import type { AuthUser } from '../middleware/auth.js';
import { databaseError } from '../repositories/account-repository.js';
import { deliveryRpc, participantOrder } from '../repositories/delivery-repository.js';
import { ApiError } from '../utils/api-error.js';

const bucket = () => supabaseAdmin.storage.from('delivery-evidence');
export async function reservePhoto(actorId: string, orderId: string, mimeType: string) {
  const extension = mimeType === 'image/jpeg' ? 'jpg' : mimeType === 'image/png' ? 'png' : 'webp';
  const path = `${orderId}/${randomUUID()}.${extension}`;
  const upload = await deliveryRpc('reserve_evidence_upload', { p_actor_id: actorId, p_order_id: orderId, p_path: path, p_mime: mimeType });
  const { data, error } = await bucket().createSignedUploadUrl(path, { upsert: false });
  if (error || !data) throw new ApiError(503, 'UPLOAD_UNAVAILABLE', 'Evidence upload is unavailable.');
  return { uploadId: upload.id, signedUrl: data.signedUrl, maximumBytes: 1572864 };
}
export async function confirmPhoto(actorId: string, uploadId: string) {
  const { data: upload, error: queryError } = await supabaseAdmin.from('evidence_uploads').select('*').eq('id', uploadId).eq('submitted_by', actorId).maybeSingle();
  databaseError(queryError);
  if (!upload) throw new ApiError(404, 'EVIDENCE_NOT_FOUND', 'Evidence upload was not found.');
  const { data: metadata, error: metadataError } = await bucket().info(upload.storage_path);
  if (metadataError || !metadata || typeof metadata.size !== 'number' || metadata.size < 1 || metadata.size > 1572864 || metadata.contentType !== upload.mime_type) {
    throw new ApiError(400, 'INVALID_EVIDENCE', 'Evidence must be JPG, PNG or WebP, at most 1.5 MB.');
  }
  const { data: file, error } = await bucket().download(upload.storage_path);
  if (error || !file) throw new ApiError(503, 'EVIDENCE_UNAVAILABLE', 'Could not verify evidence.');
  const bytes = new Uint8Array(await file.arrayBuffer());
  let detectedMime: string | undefined;
  try { detectedMime = (await fileTypeFromBuffer(bytes))?.mime; } catch { detectedMime = undefined; }
  if (bytes.length !== metadata.size || detectedMime !== upload.mime_type) {
    throw new ApiError(400, 'INVALID_EVIDENCE', 'Uploaded evidence content does not match the image type.');
  }
  return deliveryRpc('confirm_evidence_upload', { p_actor_id: actorId, p_upload_id: uploadId, p_path: upload.storage_path, p_size: bytes.length });
}
export async function evidenceList(user: AuthUser, orderId: string) {
  if (!user.roles.some((role) => ['support','operations','admin','super_admin'].includes(role))) await participantOrder(user.id, orderId);
  const { data, error } = await supabaseAdmin.from('delivery_evidence').select('id,recipient_name,captured_at,submitted_by').eq('order_id', orderId).order('created_at');
  databaseError(error); return data ?? [];
}
export async function evidenceDownload(user: AuthUser, evidenceId: string) {
  const { data, error } = await supabaseAdmin.from('delivery_evidence').select('order_id,photo_path').eq('id', evidenceId).maybeSingle();
  databaseError(error);
  if (!data?.photo_path) throw new ApiError(404, 'PHOTO_NOT_FOUND', 'Evidence photo was not found.');
  if (!user.roles.some((role) => ['support','operations','admin','super_admin'].includes(role))) await participantOrder(user.id, data.order_id);
  const result = await bucket().createSignedUrl(data.photo_path, 60);
  if (result.error || !result.data) throw new ApiError(503, 'PHOTO_UNAVAILABLE', 'Evidence photo is unavailable.');
  return { signedUrl: result.data.signedUrl, expiresIn: 60 };
}
