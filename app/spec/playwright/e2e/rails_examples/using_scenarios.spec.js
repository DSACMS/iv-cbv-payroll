import { test, expect } from "@playwright/test";
import { app, appFactories, appScenario } from '../../support/on-rails';


test('has title', async ({ page }) => {
  await page.goto('/');

  // Expect a title "to contain" a substring.
  await expect(page).toHaveTitle(/Welcome to the SNAP Income Pilot/);
});

test.describe("Rails using scenarios examples", () => {
  test.beforeEach(async ({ page }) => {
    await app('clean');
  });

  test("setup basic scenario", async ({ page }) => {

    const records = await appFactories([['create', 'cbv_flow_invitation', {auth_token: 'oqaKCUzxkaZX8FKaTtKZzTLfBe2BK2ThFS7Z'}]]);
    console.log(records)
    await page.goto(`/cbv/entry/?token=oqaKCUzxkaZX8FKaTtKZzTLfBe2BK2ThFS7Z`);
    await expect(page).toHaveTitle(/Let\'s verify your income through your payment information/);

  });
});
