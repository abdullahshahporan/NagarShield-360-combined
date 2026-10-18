import { redirect } from 'next/navigation'
import Link from 'next/link'
import { ArrowUpRight, CircleCheck, Clock3, FileScan, MapPinned, ShieldAlert } from 'lucide-react'
import { ResetDemoButton } from '@/src/components/ResetDemoButton'
import { DemoNote, IncidentList, Notice, PageHeading } from '@/src/components/Ui'
import { bn, eventLabels, roleLabels } from '@/src/lib/demo'
import { requireOfficial } from '@/src/lib/supabase/server'
import type { DemoTask, Incident } from '@/src/lib/types'

export default async function Dashboard({ searchParams }: { searchParams: Promise<{ notice?: string }> }) {
  const { supabase, profile } = await requireOfficial()
  if (profile.role === 'survey_operator') redirect('/surveys')
  const [{ data: incidents }, { data: tasks }, { data: observations }, { data: events }] = await Promise.all([
    supabase.from('incidents').select('*').order('updated_at', { ascending: false }),
    supabase.from('tasks').select('*'),
    supabase.from('observations').select('id,status'),
    supabase.from('events').select('id,kind,note,created_at,incident_id').order('created_at', { ascending: false }).limit(4),
  ])
  const list = (incidents || []) as Incident[]
  const work = (tasks || []) as DemoTask[]
  const isField = profile.role === 'field_employee'
  const isSupervisor = profile.role === 'supervisor'
  const cards = isField ? [
    { label: 'আমার দায়িত্ব', value: work.length, Icon: MapPinned },
    { label: 'চলমান কাজ', value: work.filter(t => ['acknowledged','in_progress'].includes(t.status)).length, Icon: Clock3 },
    { label: 'যাচাইয়ের অপেক্ষা', value: work.filter(t => t.status === 'action_submitted').length, Icon: ShieldAlert },
    { label: 'সম্পন্ন', value: work.filter(t => t.status === 'resolved').length, Icon: CircleCheck },
  ] : isSupervisor ? [
    { label: 'দলের দায়িত্ব', value: work.length, Icon: MapPinned },
    { label: 'ফল যাচাই প্রয়োজন', value: work.filter(t => t.status === 'action_submitted').length, Icon: ShieldAlert },
    { label: 'চলমান কাজ', value: work.filter(t => ['assigned','acknowledged','in_progress'].includes(t.status)).length, Icon: Clock3 },
    { label: 'কাজ শেষ', value: work.filter(t => t.status === 'resolved').length, Icon: CircleCheck },
  ] : [
    { label: 'মোট ঘটনা', value: list.length, Icon: MapPinned },
    { label: 'যাচাই প্রয়োজন', value: (observations || []).filter(o => o.status === 'needs_review').length, Icon: FileScan },
    { label: 'চলমান কাজ', value: list.filter(i => !['resolved','verified'].includes(i.status)).length, Icon: Clock3 },
    { label: 'কাজ শেষ', value: list.filter(i => i.status === 'resolved').length, Icon: CircleCheck },
  ]
  const { notice } = await searchParams
  return <>
    <PageHeading kicker={`${roleLabels[profile.role]} · অফিসিয়াল কর্মক্ষেত্র`} title={`স্বাগতম, ${profile.display_name}`} description={isField ? 'আপনার কাজ ও তার অগ্রগতি এখানে দেখুন।' : 'এলাকার ঘটনা, দেওয়া দায়িত্ব ও কাজের অগ্রগতি এখানে দেখুন।'} action={profile.role === 'executive' ? <ResetDemoButton/> : undefined} />
    <Notice value={notice}/><DemoNote />
    <div className="stat-grid">{cards.map(({label,value,Icon}) => <div className="stat-card" key={label}><div className="stat-icon"><Icon size={20}/></div><span>{label}</span><strong>{bn(value)}</strong><small>এই মুহূর্তের হিসাব</small></div>)}</div>
    <div className="dashboard-grid"><section className="panel"><div className="panel-head"><div><span className="mini-kicker">সাম্প্রতিক</span><h2>{isField ? 'আমার ঘটনাগুলো' : 'ঘটনার অগ্রগতি'}</h2></div><Link href="/incidents" className="inline-link">সব দেখুন <ArrowUpRight size={15}/></Link></div><IncidentList incidents={list.slice(0,5)}/></section>
      <section className="panel activity-panel"><div className="panel-head"><div><span className="mini-kicker">পদক্ষেপ</span><h2>দ্রুত শুরু করুন</h2></div></div><div className="quick-links">{(isField ? [{href:'/tasks',title:'আমার দায়িত্ব',detail:'দায়িত্ব নিন, কাজের বিবরণ জমা দিন'},{href:'/operations',title:'সমন্বিত অপারেশন',detail:'নমুনা mission-এর পুরো পথ দেখুন'}] : isSupervisor ? [{href:'/tasks',title:'দলের দায়িত্ব',detail:'জমা দেওয়া কাজ যাচাই করুন'},{href:'/operations',title:'সমন্বিত অপারেশন',detail:'দল ও ফল যাচাইয়ের অনুশীলন'},{href:'/map',title:'কমান্ড মানচিত্র',detail:'দলের ঘটনা দেখুন'},{href:'/reports',title:'প্রতিবেদন',detail:'দলের অগ্রগতি দেখুন'}] : [{href:'/operations',title:'সমন্বিত অপারেশন',detail:'কারণ থেকে কাজ ও ফল পর্যন্ত দেখুন'},{href:'/analysis',title:'ডেমো মিডিয়া বিশ্লেষণ',detail:'আগে থেকে তৈরি ফল দেখুন'},{href:'/map',title:'কমান্ড মানচিত্র',detail:'নমুনা এলাকা দেখুন'},{href:'/reports',title:'প্রতিবেদন',detail:'অগ্রগতি ও CSV দেখুন'}]).map(item => <Link key={item.href} href={item.href}><div><strong>{item.title}</strong><span>{item.detail}</span></div><ArrowUpRight size={18}/></Link>)}</div><div className="activity-divider"/><span className="mini-kicker">সাম্প্রতিক কাজ</span><div className="activity-list">{(events || []).length ? events?.map(event => <Link href={`/incidents/${event.incident_id}`} key={event.id}><span className="activity-dot"/><span>{event.note || eventLabels[event.kind] || 'কাজের তথ্য সংরক্ষিত'}</span></Link>) : <span className="muted">এখনও কোনো নতুন পদক্ষেপ নেই।</span>}</div></section></div>
  </>
}

