'use client'

import { useState } from 'react'
import { AlertTriangle, CheckCircle2, Radio } from 'lucide-react'

type Copy = { en: string; bn: string }
type Mode = {
  id: string
  label: Copy
  lead: Copy
  sceneRule: Copy
  safeRoute: Copy
  cityRole: Copy
  escalation: Copy
  units: { id: string; name: Copy; action: Copy }[]
}

export function OperationsResponse({ modes }: { modes: Mode[] }) {
  const [modeId, setModeId] = useState(modes[0].id)
  const [acknowledged, setAcknowledged] = useState<string[]>([])
  const [cleared, setCleared] = useState(false)
  const mode = modes.find(item => item.id === modeId) || modes[0]
  const allAcknowledged = mode.units.every(unit => acknowledged.includes(unit.id))
  const chooseMode = (id: string) => { setModeId(id); setAcknowledged([]); setCleared(false) }
  const toggle = (id: string) => { setAcknowledged(values => values.includes(id) ? values.filter(value => value !== id) : [...values, id]); setCleared(false) }

  return <section className="ops-card ops-response-desk">
    <span className="mini-kicker">জরুরি unit সমন্বয় · নমুনা handoff</span><h3>দুর্ঘটনা বা আগুন হলে কে নেতৃত্ব দেবে?</h3>
    <div className="ops-trigger">{modes.map(item => <button type="button" key={item.id} className={item.id === mode.id ? 'active' : ''} onClick={() => chooseMode(item.id)}>{item.label.bn}</button>)}</div>
    <div className="ops-two-col"><div><p><strong>ঘটনাস্থলের নেতৃত্ব:</strong> {mode.lead.bn}</p><p>{mode.sceneRule.bn}</p><p><strong>নিরাপদ পথ:</strong> {mode.safeRoute.bn}</p></div><div><p><strong>DNCC-এর ভূমিকা:</strong> {mode.cityRole.bn}</p><div className="ops-capacity-warning"><AlertTriangle size={17}/><span>{mode.escalation.bn}</span></div></div></div>
    <h4><Radio size={17}/> কোন unit সাড়া দিয়েছে? <small>{acknowledged.length}/{mode.units.length} · নমুনা acknowledgement</small></h4>
    <div className="ops-response-units">{mode.units.map(unit => <label key={unit.id}><input type="checkbox" checked={acknowledged.includes(unit.id)} onChange={() => toggle(unit.id)}/><span><strong>{unit.name.bn}</strong><small>{unit.action.bn}</small></span></label>)}</div>
    <button type="button" className="button-dark" disabled={!allAcknowledged || cleared} onClick={() => setCleared(true)}><CheckCircle2 size={17}/>{cleared ? 'Lead unit-এর clearance নথিভুক্ত (নমুনা)' : 'Lead unit scene ছাড়ার অনুমতি দিয়েছে (নমুনা)'}</button>
    <p className="ops-muted">সাড়া দেওয়া আর ঘটনাস্থল নিরাপদ হওয়া এক নয়। Lead unit clearance না দেওয়া পর্যন্ত DNCC নিজের পরিষ্কার বা মেরামতের দল পাঠাবে না। এই screen কোনো unit-কে বার্তা পাঠায় না।</p>
  </section>
}
