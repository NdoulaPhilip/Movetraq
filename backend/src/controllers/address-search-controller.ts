import { z } from 'zod';
import { addressProvider } from '../services/address-search.js';
import { pointSchema } from '../validators/delivery.js';
import { asyncHandler } from '../utils/async-handler.js';
import { ok } from '../utils/responses.js';

export const search = asyncHandler(async (req, res) => {
  const { query } = z.object({ query: z.string().trim().min(3).max(200) }).strict().parse(req.query);
  ok(res, { addresses: await addressProvider.search(query) });
});
export const reverse = asyncHandler(async (req, res) => {
  ok(res, { address: await addressProvider.reverse(pointSchema.parse(req.body)) });
});
