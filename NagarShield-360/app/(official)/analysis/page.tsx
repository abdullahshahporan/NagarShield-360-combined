import { redirect } from 'next/navigation'
import { DemoNote, PageHeading } from '@/src/components/Ui'
import { RealtimeAnalysisWorkspace } from '@/src/components/RealtimeAnalysisWorkspace'
import { requireOfficial } from '@/src/lib/supabase/server'
import { scenarios } from '@/src/lib/demo'
import type { Scenario } from '@/src/lib/types'

export default async function AnalysisPage() {
  const { supabase, profile } = await requireOfficial()
  if (!['executive','department_head'].includes(profile.role)) redirect('/dashboard')
  const [{ data }, { data: incidents }, { data: employees }] = await Promise.all([
    supabase.from('scenarios').select('id,title_bn,summary_bn,kind,hazard,area_bn,media_key,detections,factors').order('id'),
    supabase.from('incidents').select('id,code,title_bn,area_bn,before_key,department_id,status').neq('status','resolved').order('created_at',{ ascending: false }),
    supabase.from('profiles').select('id,display_name,department_id,team_id').eq('role','field_employee').order('display_name'),
  ])
  return <><PageHeading kicker="কর্মকর্তার মনিটরিং ডেমো" title="রিয়েলটাইম অ্যানালাইসিস" description="একসঙ্গে কয়েকটি এলাকার দৃশ্য দেখুন, গুরুত্বপূর্ণ জায়গাটি চিহ্নিত করুন এবং নির্দিষ্ট মাঠকর্মীকে কাজ দিন।"/><DemoNote>ভিডিওগুলো বারবার চলা নমুনা ফুটেজ; এগুলো বাস্তব CCTV বা ড্রোনের লাইভ সংযোগ নয়। ক্যামেরা বা স্ক্রিন শেয়ার চালু করলে শুধু আপনার ব্রাউজারের অনুমোদিত দৃশ্যটি সরাসরি দেখা যায়। নিচের বিশ্লেষণ ফলও নমুনা—স্বয়ংক্রিয় AI শনাক্তকরণ নয়।</DemoNote><RealtimeAnalysisWorkspace items={(data?.length ? data : scenarios) as Scenario[]} incidents={incidents || []} employees={employees || []} role={profile.role} departmentId={profile.department_id}/></>
}
