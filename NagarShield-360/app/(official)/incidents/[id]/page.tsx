import Link from 'next/link'
import { notFound } from 'next/navigation'
import { AlertTriangle, ArrowLeft, CheckCircle2, Clock3, MapPin } from 'lucide-react'
import { performWorkflowAction } from '@/app/actions/workflow'
import { DemoNote, Notice, PageHeading, PriorityPill, StatusPill } from '@/src/components/Ui'
import { bn, dateBn, dateTimeBn, eventLabels, hazards, roleLabels } from '@/src/lib/demo'
import { requireOfficial } from '@/src/lib/supabase/server'
import type { DemoTask, Incident } from '@/src/lib/types'
import { PrivateMedia } from '@/src/components/PrivateMedia'
import { TaskMarkPreview } from '@/src/components/TaskMarkPreview'
import { AssignmentForm } from '@/src/components/AssignmentForm'

export default async function IncidentDetail({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ notice?: string }> }) {
  const { id } = await params
  const { supabase, profile } = await requireOfficial()
  const { data } = await supabase.from('incidents').select('*').eq('id',id).maybeSingle()
  if (!data) notFound()
  const incident = data as Incident
  const { data: observation } = incident.observation_id
    ? await supabase.from('observations').select('source,scenario_id').eq('id', incident.observation_id).maybeSingle()
    : { data: null }
  const mobileIntake = Boolean(observation && observation.source !== 'scenario' && !observation.scenario_id)
  const [{ data: tasksRaw }, { data: events }, { data: departments }, { data: employees }, { data: markedEvidence }] = await Promise.all([
    supabase.from('tasks').select('*,departments(name_bn),profiles!tasks_assignee_id_fkey(display_name)').eq('incident_id',id).order('created_at'),
    supabase.from('events').select('id,kind,note,created_at,profiles!events_actor_id_fkey(display_name)').eq('incident_id',id).order('created_at',{ascending:false}),
    supabase.from('departments').select('id,name_bn').order('name_bn'),
    supabase.from('profiles').select('id,display_name,department_id,team_id').eq('role','field_employee').order('display_name'),
    supabase.from('media_assets').select('task_id,storage_key').eq('incident_id',id).eq('stage','before'),
  ])
  const tasks = (tasksRaw || []) as DemoTask[]
  const { notice } = await searchParams
  const manager = ['executive','department_head','supervisor'].includes(profile.role)
  return <><Link href="/incidents" className="back-link"><ArrowLeft size={16}/> সব ঘটনা</Link><PageHeading kicker={`${incident.code} · ${hazards[incident.hazard]}`} title={incident.title_bn} description={`${incident.area_bn} · ${dateBn(incident.created_at)} · নথিভুক্ত অবস্থান`}/><Notice value={notice}/><DemoNote/>
    <div className="detail-top-grid"><section className="panel detail-summary"><div className="panel-head"><div><span className="mini-kicker">ঘটনার অবস্থা</span><h2>পর্যালোচনা</h2></div><PriorityPill value={incident.priority}/></div><p>{incident.description_bn}</p><div className="detail-facts"><div><span>অবস্থা</span><StatusPill value={incident.status}/></div><div><span>অগ্রাধিকার স্কোর</span><strong>{bn(incident.score)}/১০০</strong></div><div><span>অবস্থান</span><strong><MapPin size={15}/>{incident.area_bn}</strong></div><div><span>সমন্বয়</span><strong>{incident.escalated ? 'বিশেষ নজরদারিতে' : 'বিশেষ নজরদারি নেই'}</strong></div></div>{manager && <form action={performWorkflowAction}><input type="hidden" name="action" value="toggle_escalation"/><input type="hidden" name="target" value={incident.id}/><input type="hidden" name="return_to" value={`/incidents/${id}`}/><button className="button-outline" type="submit"><AlertTriangle size={16}/>{incident.escalated ? 'বিশেষ নজরদারি সরান' : 'বিশেষ নজরদারিতে রাখুন'}</button></form>}</section>
      <section className="panel"><div className="panel-head"><div><span className="mini-kicker">জমা দেওয়া দৃশ্য</span><h2>কাজের আগে ও পরে</h2></div></div><div className="evidence-grid"><figure><div className="evidence-image">{incident.before_key ? <PrivateMedia mediaKey={incident.before_key} alt="ঘটনার আগের নমুনা দৃশ্য" controls/> : <span>দৃশ্য নেই</span>}</div><figcaption>কাজের আগে · সংরক্ষিত দৃশ্য</figcaption></figure><figure><div className="evidence-image">{incident.after_key ? <PrivateMedia mediaKey={incident.after_key} alt="কাজের পরের নমুনা দৃশ্য" controls/> : <span>এখনো দৃশ্য দেওয়া হয়নি</span>}</div><figcaption>কাজের পরে · সংরক্ষিত দৃশ্য</figcaption></figure></div><p className="help-text">নমুনা দৃশ্য কৃত্রিম। মোবাইল থেকে জমা দেওয়া ছবি পরীক্ষামূলক তথ্য; কাজ শেষ হয়েছে কি না তদারককারী যাচাই করবেন।</p></section></div>
    <div className="detail-lower-grid"><section className="panel"><div className="panel-head"><div><span className="mini-kicker">দায়িত্বপ্রাপ্ত বিভাগ</span><h2>কাজের অগ্রগতি</h2></div></div>{tasks.length ? <div className="detail-task-list">{tasks.map(task => <article className="detail-task" key={task.id}><div className="detail-task-head"><div><strong>{task.departments?.name_bn || task.department_id}</strong><span>{task.profiles?.display_name || 'মাঠকর্মী'} · {dateBn(task.created_at)}</span></div><StatusPill value={task.status}/></div>{task.note && <p>{task.note}</p>}{task.completion_note && <div className="task-card-note">কাজের বিবরণ: {task.completion_note}</div>}
          {profile.role === 'field_employee' && task.assignee_id === profile.id && <div className="action-stack">{task.status === 'assigned' || task.status === 'acknowledged' ? <form action={performWorkflowAction}><input type="hidden" name="action" value={task.status === 'assigned' ? 'acknowledge_task' : 'start_task'}/><input type="hidden" name="target" value={task.id}/><input type="hidden" name="return_to" value={`/incidents/${id}`}/><button className="button-dark" type="submit">{task.status === 'assigned' ? 'দায়িত্ব গ্রহণ' : 'কাজ শুরু'}</button></form> : null}{!mobileIntake && task.status === 'in_progress' && <form action={performWorkflowAction} className="stacked-form"><input type="hidden" name="action" value="submit_task"/><input type="hidden" name="target" value={task.id}/><input type="hidden" name="return_to" value={`/incidents/${id}`}/><label>কাজের বিবরণ<textarea name="note" required minLength={8} maxLength={1000} placeholder="কী কাজ করেছেন, সংক্ষেপে লিখুন"/></label><label>কাজের পরের নমুনা দৃশ্য<select name="media_key" required defaultValue="scenarios/clean.svg"><option value="scenarios/clean.svg">পরিচ্ছন্ন জায়গার ছবি</option><option value="scenarios/drain.svg">ড্রেনের ছবি</option><option value="scenarios/water.svg">জমে থাকা পানির ছবি</option></select></label><button className="button-dark" type="submit">যাচাইয়ের জন্য জমা দিন</button></form>}{mobileIntake && task.status === 'in_progress' && <p className="help-text">এই মোবাইল প্রতিবেদন বা জরিপের কাজশেষের ছবি Flutter অ্যাপ থেকে জমা দিন। এখানে নমুনা দৃশ্য পাঠানো যাবে না।</p>}</div>}
          {manager && task.status === 'action_submitted' && <div className="action-stack"><form action={performWorkflowAction}><input type="hidden" name="action" value="approve_task"/><input type="hidden" name="target" value={task.id}/><input type="hidden" name="return_to" value={`/incidents/${id}`}/><button className="button-dark" type="submit"><CheckCircle2 size={16}/> কাজটি ঠিক আছে</button></form><form action={performWorkflowAction}><input type="hidden" name="action" value="rework_task"/><input type="hidden" name="target" value={task.id}/><input type="hidden" name="return_to" value={`/incidents/${id}`}/><button className="button-outline" type="submit">সংশোধনের জন্য ফেরত দিন</button></form></div>}
          {manager && task.status === 'resolved' && incident.status === 'resolved' && <form action={performWorkflowAction}><input type="hidden" name="action" value="reopen_task"/><input type="hidden" name="target" value={task.id}/><input type="hidden" name="return_to" value={`/incidents/${id}`}/><button className="button-outline" type="submit">ঘটনা আবার খুলুন</button></form>}
          <TaskMarkPreview note={task.note} mediaKey={incident.before_key} screenshotKey={markedEvidence?.find(item => item.task_id === task.id)?.storage_key || null}/>
        </article>)}</div> : <div className="empty-state">এখনো কাউকে কাজ দেওয়া হয়নি।</div>}
      {manager && incident.status !== 'resolved' && <AssignmentForm incidentId={incident.id} role={profile.role} departmentId={profile.department_id} teamId={profile.team_id} departments={departments || []} employees={employees || []}/>}
      </section>
      <aside className="panel timeline-panel"><div className="panel-head"><div><span className="mini-kicker">কাজের ইতিহাস</span><h2>কখন কী হয়েছে</h2></div><Clock3 size={18}/></div><div className="timeline">{(events || []).map(event => <div className="timeline-item" key={event.id}><span className="timeline-dot"/><strong>{eventLabels[event.kind] || 'কাজের তথ্য সংরক্ষিত'}</strong><span>{event.note || roleLabels[profile.role]}</span><small>{dateTimeBn(event.created_at)}</small></div>)}</div></aside></div>
  </>
}

