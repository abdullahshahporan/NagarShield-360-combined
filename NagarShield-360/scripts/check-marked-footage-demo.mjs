import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { chromium } from 'playwright-core'
import { createClient } from '@supabase/supabase-js'

const baseUrl = process.env.DEMO_BASE_URL || 'http://localhost:3000'
const accounts = JSON.parse(await readFile(process.env.DEMO_ACCOUNTS_FILE || 'demo-accounts.local.json', 'utf8'))
const executive = accounts.find(item => item.role === 'executive')
assert(executive, 'Executive demo account is required')
const browser = await chromium.launch({ executablePath: process.env.CHROME_PATH || 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true })
try {
  const context = await browser.newContext({ viewport: { width: 1366, height: 768 } })
  const page = await context.newPage()
  await page.goto(baseUrl, { waitUntil: 'domcontentloaded' })
  await page.locator('input[name="email"]').fill(executive.email)
  await page.locator('input[name="password"]').fill(executive.password)
  await page.getByRole('button', { name: /সাইন ইন করুন/ }).click()
  await page.waitForURL('**/dashboard', { timeout: 20000 })
  await page.goto(`${baseUrl}/analysis`, { waitUntil: 'networkidle' })
  assert.match(await page.locator('main h1').textContent(), /রিয়েলটাইম অ্যানালাইসিস/)
  const provided = page.locator('.feed-card').filter({ hasText: 'প্রদত্ত ড্রোন ভিডিও' })
  const video = provided.locator('video')
  await video.waitFor()
  await video.evaluate(async element => {
    if (element.readyState < 1) await new Promise((resolve, reject) => {
      element.addEventListener('loadedmetadata', resolve, { once: true })
      element.addEventListener('error', reject, { once: true })
    })
  })
  const duration = await video.evaluate(element => element.duration)
  assert(duration > 30 && duration < 60, `Provided clip did not load: ${duration}`)
  await provided.locator('.feed-caption').click()
  await page.getByRole('button', { name: 'দৃশ্যে চিহ্ন দিন' }).click()
  await provided.locator('.feed-hitbox').scrollIntoViewIfNeeded()
  const box = await provided.locator('.feed-hitbox').boundingBox()
  assert(box, 'Drawing layer missing')
  await page.mouse.move(box.x + box.width * .3, box.y + box.height * .45)
  await page.mouse.down()
  await page.mouse.move(box.x + box.width * .58, box.y + box.height * .73, { steps: 5 })
  await page.mouse.up()
  const preview = page.locator('.monitor-screenshot img')
  try { await preview.waitFor({ timeout: 10000 }) }
  catch (error) {
    process.stderr.write(`Preview diagnostics: ${JSON.stringify({ errors: await page.locator('.field-error').allTextContents(), marked: await provided.locator('.feed-mark').count(), selected: await provided.getAttribute('class'), video: await video.evaluate(element => ({ readyState: element.readyState, width: element.videoWidth, height: element.videoHeight })) })}\n`)
    throw error
  }
  const image = await preview.evaluate(async element => {
    const response = await fetch(element.src)
    return { width: element.naturalWidth, height: element.naturalHeight, bytes: (await response.arrayBuffer()).byteLength }
  })
  assert(image.width > 0 && image.height > 0 && image.bytes > 100 && image.bytes < 1024 * 1024)
  const screenshot = join(tmpdir(), 'nagarshield-marked-footage-preview.png')
  await page.locator('.monitor-decision').screenshot({ path: screenshot })
  process.stdout.write(`Provided clip ${duration.toFixed(1)}s; marked screenshot ${JSON.stringify(image)}\n${screenshot}\n`)
  const assignmentButton = page.getByRole('button', { name: 'স্ক্রিনশটসহ কাজ পাঠান', exact: true })
  assert(await assignmentButton.isEnabled(), 'Incomplete form must explain what is missing when submitted')
  await assignmentButton.click()
  await page.getByRole('alert').filter({ hasText: 'কোন ঘটনার কাজ দেবেন' }).waitFor()
  const caseSelect = page.locator('#monitor-incident')
  const staffSelect = page.locator('#monitor-assignee')
  const firstCase = await caseSelect.locator('option').evaluateAll(elements => elements.find(element => element.value)?.value)
  assert(firstCase, 'An open demo case is required')
  await caseSelect.selectOption(firstCase)
  const firstWorker = staffSelect.locator('option:not([value=""])').first()
  await firstWorker.waitFor({ state: 'attached' })
  await staffSelect.selectOption(await firstWorker.getAttribute('value'))
  await page.locator('#monitor-instruction').fill('asaa')
  await assignmentButton.click()
  await page.getByRole('alert').filter({ hasText: 'অন্তত ৮ অক্ষরে লিখুন' }).waitFor()
  assert(new URL(page.url()).pathname === '/analysis', 'Short instruction must not create an assignment')
  process.stdout.write('Missing-case and short-instruction feedback passed without creating a task.\n')
  if (process.env.DEMO_ASSIGN_MARKED === '1') {
    const field = accounts.find(item => item.role === 'field_employee' && item.department_id === 'drainage')
    assert(field, 'Drainage field account is required')
    const client = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY, { auth: { persistSession: false, autoRefreshToken: false } })
    const login = await client.auth.signInWithPassword({ email: field.email, password: field.password })
    assert.ifError(login.error)
    const workerId = login.data.user.id
    const cases = page.locator('.monitor-assignment select').nth(0)
    const staff = page.locator('.monitor-assignment select').nth(1)
    const options = await cases.locator('option').evaluateAll(elements => elements.map(element => element.value).filter(Boolean))
    let found = false
    for (const id of options) {
      await cases.selectOption(id)
      try { await staff.locator(`option[value="${workerId}"]`).waitFor({ state: 'attached', timeout: 500 }); found = true; break }
      catch { /* This case belongs to another department. */ }
    }
    assert(found, `No open case for the demo drainage worker: ${JSON.stringify({ cases: options.length, workerId, staff: await staff.locator('option').evaluateAll(elements => elements.map(element => ({ value: element.value, text: element.textContent }))) })}`)
    await staff.selectOption(workerId)
    const instruction = `ডেমো যাচাই ${Date.now()}: চিহ্নিত খালপাড় পরিদর্শন করে প্রয়োজনীয় কাজের ছবি দিন।`
    await page.getByLabel('কী করতে হবে', { exact: true }).fill(instruction)
    await page.getByRole('button', { name: 'স্ক্রিনশটসহ কাজ পাঠান', exact: true }).click()
    await page.waitForURL(/\/incidents\/[^?]+\?notice=done/, { timeout: 30000 })
    const incidentId = new URL(page.url()).pathname.split('/').pop()
    const task = await client.from('tasks').select('id,note').eq('incident_id', incidentId).like('note', `${instruction}%`).single()
    assert.ifError(task.error)
    const asset = await client.from('media_assets').select('storage_key').eq('task_id', task.data.id).eq('stage', 'before').single()
    assert.ifError(asset.error)
    const evidence = await client.storage.from('evidence').download(asset.data.storage_key)
    assert.ifError(evidence.error)
    assert(evidence.data.size > 100)
    const notices = await client.from('notifications').select('id').eq('incident_id', incidentId).eq('recipient_id', login.data.user.id)
    assert.ifError(notices.error)
    assert(notices.data.length > 0)
    const workerContext = await browser.newContext({ viewport: { width: 390, height: 844 } })
    const workerPage = await workerContext.newPage()
    await workerPage.goto(baseUrl)
    await workerPage.locator('input[name="email"]').fill(field.email)
    await workerPage.locator('input[name="password"]').fill(field.password)
    await workerPage.getByRole('button', { name: /সাইন ইন করুন/ }).click()
    await workerPage.waitForURL('**/dashboard', { timeout: 20000 })
    await workerPage.goto(`${baseUrl}/incidents/${incidentId}`, { waitUntil: 'networkidle' })
    const assignedImage = workerPage.locator(`img[src="/api/media/${asset.data.storage_key}"]`)
    await assignedImage.waitFor()
    assert(await assignedImage.evaluate(element => element.complete && element.naturalWidth > 0))
    process.stdout.write(`Assigned task ${task.data.id}; worker notification and private screenshot access passed.\n`)
    await workerContext.close()
  }
  await context.close()
} finally { await browser.close() }
