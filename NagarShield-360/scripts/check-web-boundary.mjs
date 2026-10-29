import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { chromium } from 'playwright-core'

const base = process.env.DEMO_BASE_URL || 'http://localhost:3000'
const citizens = JSON.parse(await readFile('../NagarShield App/config/public-demo-accounts.local.json','utf8'))
const citizen = citizens[0]
assert(citizen?.email && citizen?.password, 'Missing citizen demo identity')
const browser = await chromium.launch({
  executablePath: process.env.CHROME_PATH || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  headless: true,
})
try {
  const context = await browser.newContext()
  const page = await context.newPage()
  for (const path of ['/dashboard','/operations','/incidents','/analysis','/reports','/surveys']) {
    await page.goto(`${base}${path}`, { waitUntil: 'domcontentloaded' })
    assert.equal(new URL(page.url()).pathname,'/',`${path} exposed to signed-out browser`)
  }
  for (const path of ['/api/reports/export','/api/media/scenarios/drain.svg','/api/demo-footage']) {
    const response = await context.request.get(`${base}${path}`)
    assert.equal(response.status(),401,`${path} exposed to signed-out browser`)
  }
  await page.goto(base, { waitUntil: 'domcontentloaded' })
  await page.locator('input[name="email"]').fill(citizen.email)
  await page.locator('input[name="password"]').fill(citizen.password)
  await page.getByRole('button',{name:/সাইন ইন করুন/}).click()
  await page.waitForURL('**/?auth=denied*')
  assert.match(await page.locator('.signin-error').textContent(),/অনুমতি নেই/)
  await page.goto(`${base}/dashboard`, { waitUntil: 'domcontentloaded' })
  assert.equal(new URL(page.url()).pathname,'/','Citizen reached official dashboard')
  await context.close()
  process.stdout.write('Signed-out routes and citizen web login are blocked.\n')
} finally { await browser.close() }
