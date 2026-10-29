'use server'

import { randomUUID } from 'node:crypto'
import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { requireOfficial } from '@/src/lib/supabase/server'

export async function assignMarkedFootage(formData: FormData): Promise<{ error: string }> {
  const { supabase, profile, user } = await requireOfficial()
  if (!['executive', 'department_head'].includes(profile.role)) return { error: 'কাজ দেওয়ার অনুমতি নেই।' }
  const incidentId = String(formData.get('incident_id') || '')
  const assigneeId = String(formData.get('assignee_id') || '')
  const note = String(formData.get('note') || '').trim()
  const instruction = String(formData.get('instruction') || '').trim()
  const screenshot = formData.get('screenshot')
  if (!/^[0-9a-f-]{36}$/i.test(incidentId) || !/^[0-9a-f-]{36}$/i.test(assigneeId)) return { error: 'ঘটনা ও কর্মী নির্বাচন করুন।' }
  if (note.length < 8 || note.length > 1000) return { error: 'কাজের বিবরণ ঠিক করুন।' }
  if (instruction.length < 8 || instruction.length > 500) return { error: 'কী করতে হবে তা অন্তত ৮ অক্ষরে লিখুন।' }
  if (!(screenshot instanceof File) || screenshot.type !== 'image/jpeg' || screenshot.size < 100 || screenshot.size > 1024 * 1024) {
    return { error: 'চিহ্নিত স্ক্রিনশট পাওয়া যায়নি বা ফাইলটি বড়।' }
  }
  const bytes = new Uint8Array(await screenshot.arrayBuffer())
  if (bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff) return { error: 'স্ক্রিনশট JPEG নয়।' }
  const [{ data: incident }, { data: employee }] = await Promise.all([
    supabase.from('incidents').select('id,department_id,status').eq('id', incidentId).maybeSingle(),
    supabase.from('profiles').select('id,role,department_id,team_id').eq('id', assigneeId).maybeSingle(),
  ])
  if (!incident || incident.status === 'resolved' || !employee || employee.role !== 'field_employee') return { error: 'ঘটনা বা মাঠকর্মী পাওয়া যায়নি।' }
  if (profile.role === 'department_head' && profile.department_id !== incident.department_id) return { error: 'এই বিভাগের অনুমতি নেই।' }
  if (employee.department_id !== incident.department_id) return { error: 'কর্মীর বিভাগ ঘটনার সঙ্গে মিলছে না।' }
  const { data: ready, error: readinessError } = await supabase.rpc('marked_footage_ready')
  if (readinessError || ready !== true) return { error: 'Supabase-এ চিহ্নিত ফুটেজের নতুন SQL migration চালাতে হবে।' }
  const key = `task/${user.id}/${randomUUID()}.jpg`
  const { error: uploadError } = await supabase.storage.from('evidence').upload(key, bytes, { contentType: 'image/jpeg', cacheControl: '0', upsert: false })
  if (uploadError) return { error: `স্ক্রিনশট সংরক্ষণ করা যায়নি: ${uploadError.message.slice(0, 120)}` }
  const { error } = await supabase.rpc('assign_marked_demo_task', {
    p_incident: incident.id,
    p_department: incident.department_id,
    p_team: employee.team_id || '',
    p_assignee: employee.id,
    p_note: note,
    p_media_key: key,
  })
  if (error) {
    await supabase.storage.from('evidence').remove([key])
    return { error: `কাজ দেওয়া যায়নি: ${error.message.slice(0, 120)}` }
  }
  revalidatePath('/', 'layout')
  redirect(`/incidents/${incident.id}?notice=done`)
}
