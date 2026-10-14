import { asyncHandler } from '../utils/async-handler.js';
import { ok } from '../utils/responses.js';
import { idSchema } from '../validators/account.js';
import { adminOrderQuery } from '../validators/admin-orders.js';
import { managedOrder, managedOrders } from '../repositories/admin-orders-repository.js';

export const list = asyncHandler(async (req, res) => {
  ok(res, await managedOrders(adminOrderQuery.parse(req.query)));
});
export const detail = asyncHandler(async (req, res) => {
  ok(res, await managedOrder(idSchema.parse(req.params.id)));
});
