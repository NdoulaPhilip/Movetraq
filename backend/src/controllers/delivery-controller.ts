import { z } from 'zod';
import { asyncHandler } from '../utils/async-handler.js';
import { created, ok } from '../utils/responses.js';
import { quoteDelivery } from '../services/delivery-service.js';
import * as repository from '../repositories/delivery-repository.js';
import * as schemas from '../validators/delivery.js';
import { idSchema, paginationSchema } from '../validators/account.js';

export const quote = asyncHandler(async (req, res) => { created(res, { quote: await quoteDelivery(req.user!.id, schemas.quoteSchema.parse(req.body)) }); });
export const createOrder = asyncHandler(async (req, res) => {
  const { quoteId } = schemas.createOrderSchema.parse(req.body);
  const key = schemas.idempotencyKey.parse(req.header('idempotency-key'));
  created(res, { order: await repository.deliveryRpc('create_quoted_order', { p_user_id: req.user!.id, p_quote_id: quoteId, p_key: key }) });
});
export const orders = asyncHandler(async (req, res) => {
  const { limit, offset } = paginationSchema.parse(req.query);
  ok(res, { orders: await repository.ownedOrders(req.user!.id, limit, offset), limit, offset });
});
export const detail = asyncHandler(async (req, res) => { ok(res, { order: await repository.participantOrder(req.user!.id, idSchema.parse(req.params.id)) }); });
export const command = asyncHandler(async (req, res) => {
  const input = schemas.commandSchema.parse(req.body);
  ok(res, { order: await repository.deliveryRpc('execute_delivery_command', {
    p_actor_id: req.user!.id, p_order_id: idSchema.parse(req.params.id), p_command: input.command, p_input: input,
  }) });
});
export const handoverCode = asyncHandler(async (req, res) => { ok(res, await repository.deliveryRpc('sender_handover_code', { p_actor_id: req.user!.id, p_order_id: idSchema.parse(req.params.id) })); });
export const jobs = asyncHandler(async (req, res) => {
  const { limit, offset } = paginationSchema.parse(req.query);
  ok(res, { jobs: await repository.deliveryRpc('eligible_delivery_jobs', { p_user_id: req.user!.id, p_limit: limit, p_offset: offset }) });
});
export const availability = asyncHandler(async (req, res) => { ok(res, await repository.deliveryRpc('set_deliverer_availability', { p_user_id: req.user!.id, p_input: schemas.availabilitySchema.parse(req.body) })); });
export const location = asyncHandler(async (req, res) => { ok(res, await repository.deliveryRpc('record_delivery_location', {
  p_user_id: req.user!.id, p_order_id: idSchema.parse(req.params.id), p_input: schemas.locationSchema.parse(req.body),
})); });
export const tracking = asyncHandler(async (req, res) => {
  const orderId = idSchema.parse(req.params.id);
  await repository.participantOrder(req.user!.id, orderId);
  ok(res, await repository.deliveryRpc('latest_delivery_location', { p_actor_id: req.user!.id, p_order_id: orderId }));
});
export const chatHistory = asyncHandler(async (req, res) => {
  const { limit, offset } = paginationSchema.parse(req.query);
  ok(res, await repository.deliveryRpc('order_chat_history', { p_actor_id: req.user!.id, p_order_id: idSchema.parse(req.params.id), p_limit: limit, p_offset: offset }));
});
export const sendMessage = asyncHandler(async (req, res) => {
  const input = z.object({ body: z.string().trim().min(1).max(4000), clientMessageId: z.string().uuid() }).strict().parse(req.body);
  created(res, await repository.deliveryRpc('send_order_message', { p_actor_id: req.user!.id, p_order_id: idSchema.parse(req.params.id), p_input: input }));
});
export const readMessages = asyncHandler(async (req, res) => { ok(res, await repository.deliveryRpc('mark_order_messages_read', {
  p_actor_id: req.user!.id, p_order_id: idSchema.parse(req.params.id),
})); });
export const unreadMessages = asyncHandler(async (req, res) => { ok(res, { unreadCount: await repository.deliveryRpc('order_message_unread_count', { p_actor_id: req.user!.id }) }); });
export const selectAddress = asyncHandler(async (req, res) => { ok(res, await repository.deliveryRpc('select_saved_address', {
  p_user_id: req.user!.id, p_address_id: idSchema.parse(req.params.id),
})); });
