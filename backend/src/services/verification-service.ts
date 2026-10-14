import { randomUUID } from 'node:crypto';
import { supabaseAdmin } from '../config/supabase.js';
import { databaseError } from '../repositories/account-repository.js';
import { deliveryRpc } from '../repositories/delivery-repository.js';
import { ApiError } from '../utils/api-error.js';
import type { AuthUser } from '../middleware/auth.js';

export async function ownedApplication(userId: string, id: string) {
  const { data, error } = await supabaseAdmin.from('verification_applications').select('*,documents:verification_documents(id,document_type,mime_type,size_bytes,upload_verified_at)').eq('id', id).eq('user_id', userId).maybeSingle();
  databaseError(error);
  if (!data) throw new ApiError(404, 'APPLICATION_NOT_FOUND', 'Application was not found.');
  return data;
}
export async function documentUpload(userId: string, applicationId: string, documentType: string, mimeType: string) {
  const extension = mimeType === 'application/pdf' ? 'pdf' : mimeType === 'image/png' ? 'png' : 'jpg';
  const path = `${userId}/${applicationId}/${randomUUID()}.${extension}`;
  const document = await deliveryRpc('reserve_verification_document', { p_user_id: userId, p_application_id: applicationId,
    p_type: documentType, p_path: path, p_mime: mimeType });
  const { data, error } = await supabaseAdmin.storage.from('verification-documents').createSignedUploadUrl(path, { upsert: false });
  if (error || !data) throw new ApiError(503, 'UPLOAD_UNAVAILABLE', 'Document upload is unavailable.');
  return { documentId: document.id, signedUrl: data.signedUrl };
}
export async function verificationDocument(user: AuthUser, documentId: string) {
  const { data, error } = await supabaseAdmin.from('verification_documents').select('*').eq('id', documentId).maybeSingle();
  databaseError(error);
  if (!data || (data.user_id !== user.id && !user.roles.some((role) => ['verification_agent', 'admin', 'super_admin'].includes(role)))) {
    throw new ApiError(404, 'DOCUMENT_NOT_FOUND', 'Document was not found.');
  }
  return data;
}
export async function confirmDocument(user: AuthUser, documentId: string) {
  const document = await verificationDocument(user, documentId);
  if (document.user_id !== user.id) throw new ApiError(403, 'DOCUMENT_OWNER_REQUIRED', 'Only the applicant can confirm an upload.');
  const { data, error } = await supabaseAdmin.storage.from('verification-documents').info(document.storage_path);
  if (error || !data) throw new ApiError(409, 'UPLOAD_NOT_FOUND', 'Upload the document before confirming it.');
  if (data.contentType !== document.mime_type || typeof data.size !== 'number' || data.size < 1 || data.size > 10485760) {
    throw new ApiError(400, 'INVALID_DOCUMENT', 'Document type or size is not supported.');
  }
  return deliveryRpc('confirm_verification_document', { p_user_id: user.id, p_document_id: document.id, p_path: document.storage_path, p_size: data.size });
}
export async function signedDocument(user: AuthUser, documentId: string) {
  const document = await verificationDocument(user, documentId);
  if (!document.upload_verified_at) throw new ApiError(409, 'DOCUMENT_NOT_UPLOADED', 'The document is not uploaded.');
  const { data, error } = await supabaseAdmin.storage.from('verification-documents').createSignedUrl(document.storage_path, 60);
  if (error || !data) throw new ApiError(503, 'DOCUMENT_UNAVAILABLE', 'Document download is unavailable.');
  return { signedUrl: data.signedUrl, expiresIn: 60 };
}
