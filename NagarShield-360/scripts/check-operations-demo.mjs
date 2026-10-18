import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { chromium } from 'playwright-core'

const baseUrl = process.env.DEMO_BASE_URL || 'http://localhost:3000'
const accounts = JSON.parse(await readFile(process.env.DEMO_ACCOUNTS_FILE || 'demo-accounts.local.json', 'utf8'))
const executive = accounts.find(item => item.role === 'executive')
if (!executive) throw new Error('Executive demo account is required')

const browser = await chromium.launch({
  executablePath: process.env.CHROME_PATH || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  headless: true,
})
try {
  const page = await browser.newPage({ viewport: { width: 1366, height: 768 } })
  await page.goto(`${baseUrl}/`, { waitUntil: 'domcontentloaded' })
  await page.locator('input[name="email"]').fill(executive.email)
  await page.locator('input[name="password"]').fill(executive.password)
  await page.getByRole('button', { name: /সাইন ইন করুন/ }).click()
  try { await page.waitForURL('**/dashboard', { timeout: 20000 }) }
  catch {
    const message = await page.locator('.signin-error').textContent().catch(() => null)
    throw new Error(`Demo sign-in failed (${message || page.url()}); check the local account and Supabase project`)
  }
  await page.goto(`${baseUrl}/operations`, { waitUntil: 'networkidle' })
  await page.locator('.ops-case-picker button').last().click()
  await page.locator('.ops-asset-marker').nth(1).click()
  if (!await page.locator('.ops-path').first().textContent().then(value => value?.includes('S-13'))) throw new Error('Connected sewer path was not traced')
  if (!await page.getByText('মাটির নিচের sewer ও pump-এর অবস্থা').isVisible()) throw new Error('Camera blind area was not explained')
  const survey = page.getByRole('button', { name: /নমুনা জরিপ সম্পন্ন দেখান/ })
  if (await survey.isEnabled()) throw new Error('Sample survey was available before permission review')
  await page.locator('.ops-action-line input').check()
  if (!await survey.isEnabled()) throw new Error('Sample survey stayed blocked after permission review')
  await survey.click()
  await page.locator('.ops-action-line input').uncheck()
  if (!await page.getByRole('button', { name: /নমুনা জরিপ সম্পন্ন দেখান/ }).isDisabled()) throw new Error('Sample survey did not reset when permission was withdrawn')
  await page.locator('.ops-steps button').nth(1).click()
  await page.locator('.ops-media-picker button').last().click()
  await page.locator('.ops-use-evidence input').check()
  await page.locator('.ops-steps button').nth(2).click()
  const explainedScore = await page.locator('.ops-options button').first().locator('em').textContent()
  if (!explainedScore) throw new Error('Explained priority was not rendered')
  await page.locator('.ops-steps button').first().click()
  await page.locator('.ops-asset-marker').last().click()
  await page.getByRole('button', { name: /এই asset থেকে কাজের খসড়া/ }).click()
  await page.getByRole('button', { name: /নমুনা mission অনুমোদন/ }).click()
  await page.locator('.ops-capacity-warning input').uncheck()
  if (!await page.locator('.ops-task-list button').first().isDisabled()) throw new Error('Resource constraint did not block unsafe assignment')
  await page.locator('.ops-capacity-warning input').check()
  await page.locator('.ops-coordination-list select').first().selectOption('blocked')
  if (!await page.locator('.ops-coordination').getByText(/এস্কালেশন/).isVisible()) throw new Error('Cross-team blocker was not escalated')
  await page.getByRole('button', { name: /নাগরিক update-এর খসড়া দেখুন/ }).click()
  if (!await page.getByText(/ক্লিনিকের পথ নিরাপদ রাখা হচ্ছে/).isVisible()) throw new Error('Citizen update draft was not shown')
  await page.getByRole('button', { name: /বাজারের পথে অগ্নিকাণ্ড/ }).click()
  if (!await page.getByText(/ফায়ার সার্ভিসের ঘটনাস্থল কমান্ডার/).isVisible()) throw new Error('Fire Service lead was not shown')
  const leadClearance = page.getByRole('button', { name: /Lead unit scene ছাড়ার অনুমতি দিয়েছে/ })
  if (await leadClearance.isEnabled()) throw new Error('Scene clearance was allowed before responder acknowledgement')
  const tasks = page.locator('.ops-task-list button')
  for (let index = 0; index < await tasks.count(); index++) {
    await tasks.nth(index).click()
    await tasks.nth(index).click()
  }
  await page.locator('.ops-steps button').nth(4).click()
  await page.getByRole('button', { name: /ভারী বৃষ্টির পূর্বাভাস/ }).click()
  await page.getByRole('button', { name: /জরুরি অবস্থার অনুশীলন/ }).click()
  const checks = page.locator('.ops-task-list button')
  for (let index = 0; index < await checks.count(); index++) await checks.nth(index).click()
  await page.getByRole('button', { name: /নমুনা follow-up নির্ধারণ/ }).click()
  if (!await page.getByRole('button', { name: /পুনরাবৃত্তির সংকেত অনুশীলন/ }).isVisible()) throw new Error('Repeat-issue watch was not scheduled')
  for (const [name, width, height] of [['desktop', 1366, 768], ['mobile', 390, 844]]) {
    await page.setViewportSize({ width, height })
    const metrics = await page.evaluate(() => ({
      viewport: innerWidth,
      document: document.documentElement.scrollWidth,
      caseCount: document.querySelectorAll('.ops-case-picker button').length,
      verified: document.querySelectorAll('.ops-task-list button.done').length,
    }))
    const path = join(tmpdir(), `nagarshield-operations-${name}.png`)
    await page.screenshot({ path, fullPage: true })
    process.stdout.write(`${name}: ${JSON.stringify(metrics)}\n${path}\n`)
    if (metrics.document > metrics.viewport || metrics.caseCount !== 4 || metrics.verified !== 4) process.exitCode = 1
  }
} finally {
  await browser.close()
}
