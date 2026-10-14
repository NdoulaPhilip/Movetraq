import { expect, test } from '@playwright/test';

test('archive-adapted order inspection uses current backend contracts', async ({ page }, info) => {
  test.setTimeout(60000);
  const errors: string[] = []; page.on('pageerror', error => errors.push(error.message));
  const order = { id: 'order-1', public_ref: 'MT-123', service_type: 'p2p', status: 'completed',
    total_amount_minor: 350000, currency: 'NGN', payment_status: 'succeeded', escrow_status: 'released',
    created_at: '2026-10-01T10:00:00Z', pickup_address: 'Pickup address', destination_address: 'Destination address' };
  await page.route('**/api/v1/**', async route => {
    const url = new URL(route.request().url()); let data: unknown = {};
    if (url.pathname.endsWith('/auth/signin')) data = { user: { uid: 'staff-1', name: 'Operations', email: 'operations@example.test', roles: ['operations'] }, session: { accessToken: 'test-token', refreshToken: 'test-refresh', expiresAt: 9999999999 } };
    else if (url.pathname.endsWith('/admin/support/cases')) data = { cases: [] };
    else if (url.pathname.endsWith('/admin/orders/order-1')) data = { order, timeline: [{ id: 'event-1', event_type: 'completed', previous_status: 'awaiting_confirmation', new_status: 'completed', created_at: order.created_at }] };
    else if (url.pathname.endsWith('/admin/orders')) data = { orders: [order], total: 26 };
    await route.fulfill({ json: { success: true, data } });
  });
  await page.goto('/');
  await page.getByLabel('Email', { exact: true }).fill('operations@example.test');
  await page.getByLabel('Password', { exact: true }).fill('test-password');
  await page.getByRole('button', { name: 'Sign in', exact: true }).click();
  await page.getByRole('button', { name: 'Orders', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Order Management' })).toBeVisible();
  await page.getByRole('button', { name: 'MT-123', exact: true }).click();
  await expect(page.getByText('Pickup address', { exact: true })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Timeline (latest 100)' })).toBeVisible();
  await expect(page.getByRole('button', { name: /refund|release funds|reassign/i })).toHaveCount(0);
  await page.getByLabel('Order reference', { exact: true }).fill('MT-123');
  const filtered = page.waitForRequest(request => new URL(request.url()).searchParams.get('reference') === 'MT-123');
  await page.getByRole('button', { name: 'Search', exact: true }).click(); await filtered;
  await page.getByRole('combobox', { name: 'Status', exact: true }).selectOption('completed');
  const next = page.waitForRequest(request => new URL(request.url()).searchParams.get('page') === '1');
  await page.getByRole('button', { name: 'Next orders' }).click(); await next;
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({ path: info.outputPath('orders.png'), fullPage: true });
  expect(errors).toEqual([]);
});
