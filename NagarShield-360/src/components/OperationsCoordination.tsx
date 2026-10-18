'use client'

import { useState } from 'react'
import { AlertTriangle, MessageSquareText, UsersRound } from 'lucide-react'

type Copy = { en: string; bn: string }
type Partner = { who: Copy; action: Copy }
type Task = { team: Copy; action: Copy }
type Coordination = { external: Partner[]; escalation: Copy; publicUpdate: Copy }
type Status = 'waiting' | 'acknowledged' | 'blocked'

export function OperationsCoordination({ owner, tasks, coordination }: { owner: Copy; tasks: Task[]; coordination: Coordination }) {
  const [statuses, setStatuses] = useState<Record<string, Status>>({})
  const [showUpdate, setShowUpdate] = useState(false)
  const partners = [
    ...tasks.map((task, index) => ({ id: `team-${index}`, who: task.team, action: task.action })),
    ...coordination.external.map((partner, index) => ({ id: `external-${index}`, ...partner })),
  ]
  const acknowledged = partners.filter(item => statuses[item.id] === 'acknowledged').length
  const blocked = partners.filter(item => statuses[item.id] === 'blocked').length

  return <section className="ops-card ops-coordination">
    <span className="mini-kicker">একটি case · সবার একই কাজের ছবি</span><h3><UsersRound size={20}/> বিভাগ ও অংশীদার সমন্বয়</h3>
    <p><strong>সমন্বয়ের দায়িত্ব:</strong> {owner.bn}. প্রতিটি দলের সাড়া ও বাধা এখানে দেখা যায়; কাজের মালিকানা নিজ নিজ সংস্থার থাকে।</p>
    <div className="ops-coordination-summary"><span>{acknowledged}/{partners.length} সাড়া দিয়েছে</span><span>{blocked}টি বাধা</span><span>{partners.length - acknowledged - blocked}টি অপেক্ষায়</span></div>
    <div className="ops-coordination-list">{partners.map(partner => <div key={partner.id}><span><strong>{partner.who.bn}</strong><small>{partner.action.bn}</small></span><label>অবস্থা <select value={statuses[partner.id] || 'waiting'} onChange={event => setStatuses(values => ({ ...values, [partner.id]: event.target.value as Status }))}><option value="waiting">সাড়া বাকি</option><option value="acknowledged">সাড়া দিয়েছে</option><option value="blocked">বাধা আছে</option></select></label></div>)}</div>
    {(blocked > 0 || acknowledged < partners.length) && <div className="ops-capacity-warning"><AlertTriangle size={18}/><span><strong>সমন্বয়/এস্কালেশন:</strong> {coordination.escalation.bn}</span></div>}
    <button type="button" className="button-outline" onClick={() => setShowUpdate(!showUpdate)}><MessageSquareText size={17}/>{showUpdate ? 'নাগরিক update-এর খসড়া লুকান' : 'নাগরিক update-এর খসড়া দেখুন'}</button>
    {showUpdate && <div className="ops-watch-card"><strong>নাগরিকের জন্য নমুনা বার্তা</strong><p>{coordination.publicUpdate.bn}</p><small>এটি শুধু preview। বাস্তব বার্তা পাঠাতে অনুমোদিত Incident/Task workflow ও যাচাইকৃত অবস্থা ব্যবহার করতে হবে।</small></div>}
  </section>
}
