import { expect, test, type Page } from '@playwright/test';

async function mockApi(page: Page, roles = ['admin']) {
  let status = 'submitted';
  await page.route('**/api/v1/**', async (route) => {
    const path = new URL(route.request().url()).pathname;
    let data: unknown = {};
    if (path.endsWith('/auth/signin')) data = { user: { uid: 'staff-1', name: 'Reviewer', email: 'reviewer@example.test', roles }, session: { accessToken: 'test-only-token', refreshToken: 'test-only-refresh', expiresAt: 9999999999 } };
    else if (path.endsWith('/review')) { status = route.request().postDataJSON().status; data = { status }; }
    else if (path.endsWith('/admin/verification-applications')) data = { applications: [{ id: 'application-1', user_id: 'applicant-1', status, identity_info: { fullName: 'Test Applicant', dateOfBirth: '1995-01-01' }, transport_info: { transportType: 'van' }, safety_declarations: { safeTransport: true }, documents: [{ id: 'document-1', document_type: 'identity', mime_type: 'application/pdf', size_bytes: 2048, upload_verified_at: '2026-01-01' }], created_at: '2026-01-01', review_notes: null }] };
    else if (path.endsWith('/admin/pricing-rules')) data = { rules: [] };
    else if (path.endsWith('/admin/support/cases')) data = { cases: [{ id: 'case-12345', order_id: 'order-1', category: 'return', description: 'Recipient unreachable, parcel awaiting approved return.', status: 'open', priority: 'normal', internal_notes: null, resolution: null, created_at: '2026-01-01' }] };
    else if (path.endsWith('/evidence')) data = { evidence: [] };
    await route.fulfill({ json: { success: true, data }, headers: { 'Access-Control-Allow-Origin': '*' } });
  });
}
async function login(page: Page) {
  await page.goto('/');
  await page.getByLabel('Email', { exact: true }).fill('reviewer@example.test');
  await page.getByLabel('Password', { exact: true }).fill('test-password');
  await page.getByRole('button', { name: 'Sign in', exact: true }).click();
}
async function checkLayout(page: Page) {
  await page.evaluate(() => document.fonts.ready);
  expect(await page.evaluate(() => document.fonts.check('700 22px SpaceGrotesk'))).toBe(true);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  expect(await page.locator('img').first().evaluate((image) => (image as HTMLImageElement).naturalWidth)).toBeGreaterThan(0);
}
test('review, tariff configuration and logout', async ({ page }, info) => {
  const errors: string[] = []; page.on('pageerror', (error) => errors.push(error.message));
  await mockApi(page); await login(page);
  await expect(page.getByRole('heading', { name: 'Delivery Verification' })).toBeVisible();
  await page.getByRole('button', { name: 'Test Applicant' }).click();
  await page.getByRole('combobox', { name: 'Decision' }).selectOption('under_review');
  await page.getByLabel('Review notes').fill('Documents received for review.');
  await page.getByRole('button', { name: 'Save decision' }).click();
  await expect(page.getByRole('status')).toHaveText('Review saved.');
  await checkLayout(page);
  await page.screenshot({ path: info.outputPath('verification.png'), fullPage: true });
  await page.getByRole('button', { name: 'Pricing', exact: true }).click();
  await expect(page.getByText('Not configured')).toBeVisible();
  await expect(page.locator('input[type=number]').first()).toHaveValue('');
  await checkLayout(page);
  await page.screenshot({ path: info.outputPath('pricing.png'), fullPage: true });
  expect(await page.evaluate(() => Object.keys(localStorage))).toEqual([]);
  await page.getByRole('button', { name: 'Sign out' }).click();
  await expect(page.getByRole('heading', { name: 'Staff Sign In' })).toBeVisible();
  expect(errors).toEqual([]);
});
test('finance console does not expose verification controls', async ({ page }) => {
  await mockApi(page, ['finance']); await login(page);
  await expect(page.getByRole('heading', { name: 'Service Pricing' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Verification', exact: true })).toHaveCount(0);
  await checkLayout(page);
});
test('customer credentials cannot enter console', async ({ page }) => {
  await mockApi(page, ['sender']); await login(page);
  await expect(page.getByRole('alert')).toHaveText('This account does not have access to this console.');
  await expect(page.getByRole('heading', { name: 'Staff Sign In' })).toBeVisible();
  await checkLayout(page);
});
test('support reviews and approves returns without financial permission', async ({ page }, info) => {
  await mockApi(page, ['support']); await login(page);
  await expect(page.getByRole('heading', { name: 'Delivery Support' })).toBeVisible();
  await page.getByRole('button', { name: 'case-123' }).click();
  await page.getByLabel('Internal notes').fill('Contact attempted. Return approved.');
  await page.getByRole('button', { name: 'Approve return' }).click();
  await expect(page.getByRole('status')).toHaveText('Case updated.');
  await expect(page.getByRole('button', { name: 'Settle dispute' })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Pricing', exact: true })).toHaveCount(0);
  await checkLayout(page);
  await page.screenshot({ path: info.outputPath('support.png'), fullPage: true });
});
test('finance sends an idempotency key for settlement', async ({ page }) => {
  await mockApi(page, ['finance']); await login(page);
  await page.getByRole('button', { name: 'Support', exact: true }).click();
  await page.getByRole('button', { name: 'case-123' }).click();
  await expect(page.getByRole('button', { name: 'Approve return' })).toHaveCount(0);
  await page.getByLabel('Resolution').fill('Parcel returned and sender refunded.');
  await page.getByRole('combobox', { name: 'Settlement' }).selectOption('refund');
  const mutation = page.waitForRequest('**/dispute-settlement');
  await page.getByRole('button', { name: 'Settle dispute' }).click();
  await expect(page.getByRole('dialog')).toBeVisible();
  await page.getByRole('button', { name: 'Confirm settlement' }).click();
  const submitted = await mutation;
  expect(submitted.headers()['idempotency-key']).toMatch(/^[a-f0-9-]{36}$/);
  expect(submitted.postDataJSON()).toEqual({ decision: 'refund', resolution: 'Parcel returned and sender refunded.' });
  await checkLayout(page);
});
