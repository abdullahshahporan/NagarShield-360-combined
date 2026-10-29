import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
await db.exec(`
create role anon; create role authenticated; create role service_role;
create schema auth; create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function auth.role() returns text language sql stable as $$ select nullif(current_setting('request.jwt.claim.role',true),'') $$;
create schema storage;
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
create function storage.foldername(p_name text) returns text[] language sql immutable as $$
  select (string_to_array(p_name,'/'))[1:array_length(string_to_array(p_name,'/'),1)-1] $$;
create function storage.extension(p_name text) returns text language sql immutable as $$
  select split_part(p_name,'.',array_length(string_to_array(p_name,'.'),1)) $$;
alter table storage.objects enable row level security;
grant usage on schema public,auth,storage to anon,authenticated,service_role;
grant select,insert on storage.objects to authenticated;
`)
const migration = await readFile(new URL('../supabase/migrations/202610130001_prototype.sql', import.meta.url), 'utf8')
// PGlite has built-in gen_random_uuid() but does not package Supabase's pgcrypto extension.
try { await db.exec(migration.replace('create extension if not exists pgcrypto;', '')) }
catch (error) { process.stderr.write(`Migration failed: ${error.message}\n${error.detail || ''}\n`); process.exit(1) }
const resetHotfix = await readFile(new URL('../supabase/migrations/202610130002_reset_hotfix.sql', import.meta.url), 'utf8')
// PGlite does not include Supabase safe updates, so guard against the original failure explicitly.
assert.match(resetHotfix, /truncate table public\.notifications/)
assert.doesNotMatch(resetHotfix, /delete\s+from\s+public\./i)
await db.exec(resetHotfix)
const mobileExtension = await readFile(new URL('../../NagarShield App/supabase/mobile_extension.sql', import.meta.url), 'utf8')
const mobileRetry = await readFile(new URL('../../NagarShield App/supabase/mobile_extension_2.sql', import.meta.url), 'utf8')
await db.exec(mobileExtension)
await db.exec(mobileRetry)
const surveyMigration = await readFile(new URL('../supabase/migrations/202610140001_survey_demo.sql', import.meta.url), 'utf8')
await db.exec(surveyMigration)
const copyMigration = await readFile(new URL('../supabase/migrations/202610140002_bangla_copy.sql', import.meta.url), 'utf8')
await db.exec(copyMigration)
const markedFootageMigration = await readFile(new URL('../supabase/migrations/202610290001_marked_footage_assignment.sql', import.meta.url), 'utf8')
await db.exec(markedFootageMigration)
const demoCopy = await db.query("select summary_bn from public.scenarios where id='drain'")
assert.equal(demoCopy.rows[0].summary_bn, 'বাজার সড়কের ড্রেনের মুখে বর্জ্য জমে আছে।')
const count = await db.query('select count(*)::int as count from public.incidents')
assert.equal(count.rows[0].count, 18)
const initialSurveys = await db.query('select count(*)::int as count from public.survey_missions')
assert.equal(initialSurveys.rows[0].count, 2)
const scores = await db.query(`select id,score,round(least(100,
  (factors->>'drain')::numeric*.30+(factors->>'vector')::numeric*.25+
  (factors->>'waste')::numeric*.15+(factors->>'access')::numeric*.15+
  (factors->>'recurrence')::numeric*.10+(factors->>'evidence')::numeric*.05+
  (factors->>'bonus')::numeric))::int as expected from public.scenarios`)
for (const row of scores.rows) assert.equal(row.score,row.expected,`Score mismatch: ${row.id}`)

const users = [
  ['00000000-0000-4000-8000-000000001001','নির্বাহী','executive',null,null],
  ['00000000-0000-4000-8000-000000001002','প্রধান','department_head','drainage',null],
  ['00000000-0000-4000-8000-000000001003','তত্ত্বাবধায়ক','supervisor','drainage','drainage-a'],
  ['00000000-0000-4000-8000-000000001004','ড্রেনেজ কর্মী','field_employee','drainage','drainage-a'],
  ['00000000-0000-4000-8000-000000001005','বর্জ্য কর্মী','field_employee','waste','waste-a'],
  ['00000000-0000-4000-8000-000000001007','জরিপ অপারেটর','survey_operator','drainage',null],
]
for (const [id,name,role,department,team] of users) {
  await db.query('insert into auth.users(id) values($1)',[id])
  await db.query('insert into public.profiles(id,display_name,role,department_id,team_id) values($1,$2,$3,$4,$5)',[id,name,role,department,team])
}
await db.exec("select set_config('request.jwt.claim.role','service_role',false); select public.reset_demo();")
await db.exec("insert into storage.objects(bucket_id,name) values ('demo-media','scenarios/drain.svg'),('demo-media','unlisted/private.svg')")

async function asUser(id, fn) {
  await db.exec('set role authenticated')
  await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id])
  await db.exec("select set_config('request.jwt.claim.role','authenticated',false)")
  try { return await fn() } finally { await db.exec('reset role') }
}
const executiveId=users[0][0], supervisorId=users[2][0], drainageId=users[3][0], wasteId=users[4][0]
await asUser(executiveId, async () => {
  const visible=await db.query('select count(*)::int as count from public.incidents')
  assert.equal(visible.rows[0].count,18)
  const score=await db.query("select score from public.scenarios where id='mixed'")
  assert.equal(score.rows[0].score,90)
  const queue = await db.query("select count(*)::int as count from public.observations where status='needs_review'")
  assert.equal(queue.rows[0].count,2)
})
await asUser(users[5][0], async () => {
  const missions=await db.query('select count(*)::int as count from public.survey_missions')
  assert.equal(missions.rows[0].count,1)
  const observations=await db.query('select count(*)::int as count from public.observations')
  assert.equal(observations.rows[0].count,1)
  await assert.rejects(db.query("select public.perform_demo_action('verify_observation','00000000-0000-4000-a000-000000000001','{}')"))
})
await asUser(users[1][0], async () => {
  await assert.rejects(db.query("select public.perform_demo_action('verify_observation','00000000-0000-4000-a000-000000000002','{}')"))
  const reviewed=await db.query("select public.perform_demo_action('verify_observation','00000000-0000-4000-a000-000000000001','{}') as id")
  const linked=await db.query('select observation_id from public.incidents where id=$1',[reviewed.rows[0].id])
  assert.equal(linked.rows[0].observation_id,'00000000-0000-4000-a000-000000000001')
})
await asUser(drainageId, async () => {
  const visible=await db.query('select count(*)::int as count from public.incidents')
  assert(visible.rows[0].count>0 && visible.rows[0].count<18)
  const mapFeatures=await db.query('select count(*)::int as count from public.infrastructure')
  assert.equal(mapFeatures.rows[0].count,0)
  const media=await db.query('select name from storage.objects order by name')
  assert.deepEqual(media.rows.map(row=>row.name),['scenarios/drain.svg'])
})
await asUser(wasteId, async () => {
  const hidden=await db.query("select count(*)::int as count from public.incidents where department_id='drainage'")
  assert.equal(hidden.rows[0].count,0)
})
const assigned=await db.query("select id,incident_id from public.tasks where status='assigned' and assignee_id=$1 limit 1",[drainageId])
assert(assigned.rows.length)
const taskId=assigned.rows[0].id
await asUser(drainageId, async () => {
  await assert.rejects(db.query("select public.perform_demo_action('start_task',$1,'{}')",[taskId]))
  await db.query("select public.perform_demo_action('acknowledge_task',$1,'{}')",[taskId])
  await db.query("select public.perform_demo_action('start_task',$1,'{}')",[taskId])
  await db.query("select public.perform_demo_action('submit_task',$1,$2)",[taskId,JSON.stringify({media_key:'scenarios/clean.svg',note:'ডেমো কাজ শেষ হয়েছে'})])
})
await asUser(supervisorId, async () => {
  await db.query("select public.perform_demo_action('approve_task',$1,'{}')",[taskId])
})
const resolved=await db.query('select status from public.incidents where id=$1',[assigned.rows[0].incident_id])
assert.equal(resolved.rows[0].status,'resolved')
await asUser(wasteId, async () => {
  await assert.rejects(db.query("select public.perform_demo_action('reopen_task',$1,'{}')",[taskId]))
})
await asUser(supervisorId, async () => {
  const scenarios=await db.query('select count(*)::int as count from public.scenarios')
  assert.equal(scenarios.rows[0].count,0)
  await assert.rejects(db.query("select public.perform_demo_action('create_observation',null,$1)",[JSON.stringify({scenario_id:'drain'})]))
})
let newIncident
await asUser(executiveId, async () => {
  const observation=await db.query("select public.perform_demo_action('create_observation',null,$1) as id",[JSON.stringify({scenario_id:'mixed'})])
  const verified=await db.query("select public.perform_demo_action('verify_observation',$1,'{}') as id",[observation.rows[0].id])
  newIncident=verified.rows[0].id
  await db.query("select public.perform_demo_action('assign_task',$1,$2)",[newIncident,JSON.stringify({department_id:'drainage',assignee_id:drainageId,team_id:'drainage-a'})])
  await db.query("select public.perform_demo_action('assign_task',$1,$2)",[newIncident,JSON.stringify({department_id:'waste',assignee_id:wasteId,team_id:'waste-a'})])
})
const multiTasks=await db.query('select id,department_id from public.tasks where incident_id=$1',[newIncident])
const markedKey=`task/${executiveId}/20000000-0000-4000-8000-000000000001.jpg`
await db.query("insert into storage.objects(bucket_id,name) values('evidence',$1)",[markedKey])
let markedTask
await asUser(executiveId, async () => {
  const assigned=await db.query('select public.assign_marked_demo_task($1,$2,$3,$4,$5,$6) as id',[
    newIncident,'drainage','drainage-a',drainageId,'Inspect the marked canal edge',markedKey,
  ])
  markedTask=assigned.rows[0].id
})
await asUser(drainageId, async () => {
  const assets=await db.query('select storage_key from public.media_assets where task_id=$1',[markedTask])
  assert.equal(assets.rows[0].storage_key,markedKey)
  const stored=await db.query('select name from storage.objects where name=$1',[markedKey])
  assert.equal(stored.rows[0].name,markedKey)
  const notifications=await db.query('select count(*)::int as count from public.notifications where recipient_id=$1',[drainageId])
  assert(notifications.rows[0].count>0)
})
const drainageTask=multiTasks.rows.find(row=>row.department_id==='drainage').id
await asUser(drainageId, async () => {
  await db.query("select public.perform_demo_action('acknowledge_task',$1,'{}')",[drainageTask])
  await db.query("select public.perform_demo_action('start_task',$1,'{}')",[drainageTask])
})
const multiStatus=await db.query('select status from public.incidents where id=$1',[newIncident])
assert.equal(multiStatus.rows[0].status,'in_progress')
await asUser(supervisorId, async () => {
  const visible=await db.query('select count(*)::int as count from public.incidents where id=$1',[newIncident])
  assert.equal(visible.rows[0].count,1)
})
await asUser(wasteId, async () => {
  const visible=await db.query('select count(*)::int as count from public.incidents where id=$1',[newIncident])
  assert.equal(visible.rows[0].count,1)
  await assert.rejects(db.query("select public.perform_demo_action('toggle_escalation',$1,'{}')",[newIncident]))
  await assert.rejects(db.query('select public.reset_demo()'))
})
const unprofiledId='00000000-0000-4000-8000-000000001006'
await db.query('insert into auth.users(id) values($1)',[unprofiledId])
await asUser(unprofiledId, async () => {
  await assert.rejects(db.query('select public.reset_demo()'))
  const incidents=await db.query('select count(*)::int as count from public.incidents')
  assert.equal(incidents.rows[0].count,0)
})
await asUser(executiveId, async () => {
  await db.query('select public.reset_demo()')
})
const restored=await db.query('select count(*)::int as count from public.incidents')
assert.equal(restored.rows[0].count,18)
const restoredSurveys=await db.query('select count(*)::int as count from public.survey_missions')
assert.equal(restoredSurveys.rows[0].count,2)
const restoredTaskCopy=await db.query('select distinct note from public.tasks')
assert.deepEqual(restoredTaskCopy.rows.map(row=>row.note),['জায়গাটি দেখে প্রয়োজনীয় কাজ করুন।'])
const citizenId='00000000-0000-4000-8000-000000001008'
const otherCitizenId='00000000-0000-4000-8000-000000001009'
await db.query('insert into auth.users(id) values($1),($2)',[citizenId,otherCitizenId])
let citizenObservation
let citizenTask
await asUser(citizenId, async () => {
  const created=await db.query('select public.submit_public_report($1,$2,$3,$4,$5,$6,$7,$8) as id',[
    '10000000-0000-4000-8000-000000000043','Blocked drain','Water has remained for three days',
    ['DRAIN_OBSTRUCTION'],'Market Road',23.8073,90.3683,'approximate',
  ])
  citizenObservation=created.rows[0].id
  assert.equal((await db.query('select * from public.public_report_status()')).rows[0].status,'needs_review')
})
await asUser(otherCitizenId, async () => {
  assert.equal((await db.query('select * from public.public_report_status()')).rows.length,0)
  assert.equal((await db.query('select count(*)::int as count from public.observations')).rows[0].count,0)
})
await asUser(executiveId, async () => {
  const reviewed=await db.query('select public.review_intake_observation($1,true,$2) as id',[citizenObservation,'Verified on web'])
  const assigned=await db.query("select public.perform_demo_action('assign_task',$1,$2) as id",[
    reviewed.rows[0].id,JSON.stringify({department_id:'drainage',assignee_id:drainageId,team_id:'drainage-a',note:'Clear the drain'}),
  ])
  citizenTask=assigned.rows[0].id
})
await asUser(drainageId, async () => {
  await db.query("select public.perform_demo_action('acknowledge_task',$1,'{}')",[citizenTask])
  await db.query("select public.perform_demo_action('start_task',$1,'{}')",[citizenTask])
  await assert.rejects(db.query("select public.perform_demo_action('submit_task',$1,$2)",[
    citizenTask,JSON.stringify({media_key:'scenarios/clean.svg',note:'Pretend work is complete'}),
  ]))
})
await asUser(executiveId, async () => {
  await db.query('select public.reset_demo()')
})
assert.equal((await db.query('select count(*)::int as count from public.incidents where observation_id=$1',[citizenObservation])).rows[0].count,1)
await asUser(citizenId, async () => {
  assert.equal((await db.query('select * from public.public_report_status()')).rows[0].status,'in_progress')
})
await db.exec('set role anon')
await assert.rejects(db.query('select * from public.incidents'))
await assert.rejects(db.query('select * from public.survey_missions'))
await db.exec('reset role')
process.stdout.write('Shared migrations, citizen ownership, reset preservation, role visibility and task transitions passed.\n')
await db.close()
