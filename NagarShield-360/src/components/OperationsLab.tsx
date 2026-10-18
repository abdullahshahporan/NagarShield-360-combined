'use client'

import { useRef, useState } from 'react'
import { AlertTriangle, ArrowRight, CheckCircle2, ClipboardCheck, CloudRain, Eye, MapPinned, RotateCcw, ShieldCheck, UsersRound, Route } from 'lucide-react'
import seed from '@/src/lib/operations-seed.json'
import { OperationsMap } from './OperationsMap'
import { OperationsEvidence } from './OperationsEvidence'
import { OperationsResponse } from './OperationsResponse'
import { OperationsCoordination } from './OperationsCoordination'

type Copy = { en: string; bn: string }
type Case = (typeof seed.cases)[number]
const say = (value: Copy) => value.bn
const sourceName: Record<string, string> = { citizen: 'নাগরিক', camera: 'অনুমোদিত CCTV', drone: 'অনুমোদিত ড্রোন জরিপ', field: 'মাঠকর্মী' }
const qualityName: Record<string, string> = { high: 'ভালো', medium: 'মাঝারি', low: 'আবার যাচাই দরকার' }
const steps = [
  { id: 'map', label: 'এলাকা ও জরিপ', Icon: Route },
  { id: 'observe', label: 'দেখুন', Icon: Eye },
  { id: 'decide', label: 'সিদ্ধান্তের কারণ', Icon: MapPinned },
  { id: 'mission', label: 'কাজ চালান', Icon: UsersRound },
  { id: 'follow', label: 'ফল যাচাই', Icon: ClipboardCheck },
] as const
type Step = (typeof steps)[number]['id']

function rank(option: Case['options'][number]) {
  return Math.round((option.reach * 4 + option.safety * 3 + option.recurrence * 2 + option.access) * 2)
}

export function OperationsLab() {
  const stepsRef = useRef<HTMLElement>(null)
  const [caseId, setCaseId] = useState(seed.cases[0].id)
  const [step, setStep] = useState<Step>('map')
  const [choice, setChoice] = useState<string | null>(null)
  const [approved, setApproved] = useState(false)
  const [assigned, setAssigned] = useState<number[]>([])
  const [done, setDone] = useState<number[]>([])
  const [checked, setChecked] = useState<number[]>([])
  const [rain, setRain] = useState(false)
  const [crisis, setCrisis] = useState(false)
  const [resourceReady, setResourceReady] = useState(true)
  const [watchScheduled, setWatchScheduled] = useState(false)
  const [watchAlert, setWatchAlert] = useState(false)
  const [assetId, setAssetId] = useState(seed.cases[0].map.assets[0].id)
  const [showFlight, setShowFlight] = useState(true)
  const [flightPermission, setFlightPermission] = useState(false)
  const [surveyComplete, setSurveyComplete] = useState(false)
  const [focusTask, setFocusTask] = useState<number | null>(null)
  const [usedEvidence, setUsedEvidence] = useState<string[]>(seed.cases[0].media.filter(item => item.initiallyUsed).map(item => item.id))
  const current = seed.cases.find(item => item.id === caseId) || seed.cases[0]
  const evidenceBoost = (optionId: string) => current.media.filter(item => usedEvidence.includes(item.id) && item.optionId === optionId).reduce((sum, item) => sum + item.boost, 0)
  const recommendationScore = (option: Case['options'][number]) => Math.min(100, rank(option) + evidenceBoost(option.id))
  const ranked = [...current.options].sort((a, b) => recommendationScore(b) - recommendationScore(a))
  const selected = current.options.find(item => item.id === choice) || ranked[0]
  const allDone = done.length === current.tasks.length
  const allChecked = checked.length === current.verify.length

  function reset(nextId = caseId) {
    const next = seed.cases.find(item => item.id === nextId) || seed.cases[0]
    setCaseId(nextId)
    setStep('map')
    setChoice(null)
    setApproved(false)
    setAssigned([])
    setDone([])
    setChecked([])
    setRain(false)
    setCrisis(false)
    setResourceReady(true)
    setWatchScheduled(false)
    setWatchAlert(false)
    setAssetId(next.map.assets[0].id)
    setShowFlight(true)
    setFlightPermission(false)
    setSurveyComplete(false)
    setFocusTask(null)
    setUsedEvidence(next.media.filter(item => item.initiallyUsed).map(item => item.id))
  }
  function toggle(index: number, values: number[], setter: (value: number[]) => void) {
    if (values.includes(index)) setWatchScheduled(false)
    setter(values.includes(index) ? values.filter(value => value !== index) : [...values, index])
  }
  function toggleEvidence(id: string) {
    setUsedEvidence(values => values.includes(id) ? values.filter(value => value !== id) : [...values, id])
    setChoice(null); setApproved(false); setAssigned([]); setDone([]); setChecked([])
  }
  function advanceTask(index: number) {
    if (!resourceReady && index === current.capacity.taskIndex) return
    if (!assigned.includes(index)) setAssigned([...assigned, index])
    else if (!done.includes(index)) setDone([...done, index])
    else { setDone(done.filter(value => value !== index)); setChecked([]) }
  }
  function changeResource(ready: boolean) {
    setResourceReady(ready)
    if (!ready) {
      const blocked = current.capacity.taskIndex
      setAssigned(values => values.filter(index => index !== blocked))
      setDone(values => values.filter(index => index !== blocked))
      setChecked([])
    }
  }
  function flagRepeat() {
    setWatchAlert(true)
    setWatchScheduled(false)
    setFocusTask(current.watch.taskIndex)
    setApproved(false)
    setAssigned([])
    setDone([])
    setChecked([])
    goToStep('mission')
  }
  function goToStep(next: Step) {
    setStep(next)
    requestAnimationFrame(() => stepsRef.current?.scrollIntoView({ block: 'start', behavior: 'smooth' }))
  }

  return <div className="ops-lab">
    <div className="ops-intro"><div><span className="mini-kicker">একই জায়গার সমস্যাগুলো একসঙ্গে বুঝুন</span><h2>একজন কর্মকর্তা, একটি পরিষ্কার কাজের ছবি</h2><p>নাগরিকের খবর, অনুমোদিত জরিপ ও মাঠের তথ্য মিলিয়ে কাজের পরের ধাপ ঠিক করার অনুশীলন।</p></div><button type="button" className="button-outline" onClick={() => reset()}><RotateCcw size={15}/> আবার শুরু</button></div>
    <div className="ops-disclaimer" role="note"><AlertTriangle size={18}/><span>{say(seed.notice)}</span></div>
    <div className="ops-case-picker" aria-label="নমুনা ঘটনা বাছুন">{seed.cases.map(item => <button type="button" key={item.id} className={item.id === current.id ? 'active' : ''} onClick={() => reset(item.id)}><small>{item.code}</small><strong>{say(item.title)}</strong><span>{say(item.area)}</span></button>)}</div>
    <div className="ops-story"><div><span className="mini-kicker">{current.code} · {say(current.area)}</span><h3>{say(current.title)}</h3><p>{say(current.story)}</p></div><div className="ops-story-art"><img src={`/api/media/scenarios/${current.image}.svg`} alt="ডেমোর নমুনা দৃশ্য"/><span>নমুনা illustration</span></div></div>
    <nav ref={stepsRef} className="ops-steps" aria-label="অপারেশন ধাপ">{steps.map(({id,label,Icon}, index) => <button type="button" key={id} className={step === id ? 'active' : ''} onClick={() => goToStep(id)}><Icon size={18}/><span>{index + 1}. {label}</span></button>)}</nav>

    {step === 'map' && <OperationsMap map={current.map} tasks={current.tasks} selectedId={assetId} onSelect={setAssetId} showFlight={showFlight} onFlightToggle={() => setShowFlight(!showFlight)} permission={flightPermission} onPermission={value => { setFlightPermission(value); if (!value) setSurveyComplete(false) }} surveyComplete={surveyComplete} onSurveyComplete={() => setSurveyComplete(true)} onDraftTask={index => { setFocusTask(index); goToStep('mission') }}/>}

    {step === 'observe' && <><OperationsEvidence key={current.id} media={current.media} usedIds={usedEvidence} onToggle={toggleEvidence}/><div className="ops-two-col">
      <section className="ops-card"><span className="mini-kicker">উৎস ও সময় দেখা জরুরি</span><h3>এক জায়গার খবর কয়েক উৎস থেকে আসে</h3><div className="ops-signals">{current.signals.map((signal, index) => <article key={`${signal.source}-${index}`}><div className="ops-signal-head"><strong>{sourceName[signal.source] || signal.source}</strong><span>{signal.age} আগে · {qualityName[signal.quality]}</span></div><p>{say(signal.text)}</p><small>{say(signal.limit)}</small></article>)}</div></section>
      <div className="ops-side-stack"><section className="ops-card"><span className="mini-kicker">একটি ঘটনা, উৎসগুলো অক্ষত</span><h3>একই খবর দুবার এলে?</h3><p>{say(current.duplicate)}</p></section><section className="ops-card"><span className="mini-kicker">প্রাথমিক শহর মানচিত্র</span><h3>জায়গাগুলোর সংযোগ</h3><div className="ops-path">{current.assetPath.map((asset, index) => <div key={asset}><b>{String(index + 1).padStart(2, '0')}</b><span>{asset}</span>{index < current.assetPath.length - 1 && <ArrowRight size={16}/>}</div>)}</div><p className="ops-muted">এটি নমুনা asset path। মাঠের পরিদর্শনে ভুল সংযোগ সংশোধন করতে হবে।</p></section></div>
    </div></>}

    {step === 'decide' && <div className="ops-two-col">
      <section className="ops-card"><span className="mini-kicker">সম্ভাব্য কারণ · নিশ্চিত সিদ্ধান্ত নয়</span><h3>{say(current.hypothesis)}</h3><p>{say(current.reason)}</p><div className="ops-check"><ShieldCheck size={19}/><span>{say(current.fieldCheck)}</span></div><div className="ops-check ops-uncertainty"><AlertTriangle size={19}/><span>{usedEvidence.length === 0 ? 'কোনো footage গ্রহণ করা হয়নি। অগ্রাধিকার দেওয়ার আগে মাঠ যাচাই করুন।' : current.media.some(item => usedEvidence.includes(item.id) && item.confidence < .7) ? 'গ্রহণ করা evidence-এর কিছু অংশ অনিশ্চিত বা পুরোনো। কর্মকর্তা সীমাগুলো দেখে সিদ্ধান্ত নেবেন।' : 'গৃহীত evidence-ও সম্ভাব্য কারণ নিশ্চিত করে না। মাঠ যাচাই প্রয়োজন।'}</span></div></section>
      <section className="ops-card"><span className="mini-kicker">ব্যাখ্যাসহ পরামর্শ · কর্মকর্তা বদলাতে পারেন</span><h3>কোন জায়গা আগে দেখবেন?</h3><p className="ops-muted">নমুনা তুলনা: প্রভাবের এলাকা ৪০%, জননিরাপত্তা ৩০%, পুনরাবৃত্তি ২০%, প্রবেশের সুবিধা ১০%; review করা media থেকে ছোট adjustment যোগ হয়। এটি যাচাইকৃত AI risk model নয়।</p><div className="ops-options">{ranked.map((option, index) => <button type="button" key={option.id} className={selected.id === option.id ? 'active' : ''} onClick={() => { setChoice(option.id); setApproved(false); setAssigned([]); setDone([]); setChecked([]) }}><b>{index + 1}</b><span><strong>{say(option.title)}</strong><small>{say(option.why)} · মূল {rank(option)} + evidence {evidenceBoost(option.id)}</small></span><em>{recommendationScore(option)}/100</em></button>)}</div><div className="ops-explain"><strong>এই পরামর্শে কোন footage ধরা হয়েছে?</strong>{current.media.filter(item => usedEvidence.includes(item.id) && item.optionId === selected.id).length ? current.media.filter(item => usedEvidence.includes(item.id) && item.optionId === selected.id).map(item => <p key={item.id}>+{item.boost} · {say(item.finding)} <small>({sourceName[item.source] || item.source}; সীমা: {say(item.limit)})</small></p>) : <p>এই বিকল্পে কোনো review করা media যোগ হয়নি। মাঠ যাচাই প্রয়োজন।</p>}</div><p className="ops-muted">মানুষ উৎস বাদ দিতে, priority override করতে এবং site inspection চাইতে পারবেন।</p></section>
    </div>}

    {step === 'mission' && <div className="ops-two-col">
      <section className="ops-card"><span className="mini-kicker">একজন case owner, কয়েকটি দল</span><h3>একটি সমন্বিত mission</h3>{watchAlert && <div className="ops-capacity-warning"><strong>পুনরাবৃত্তির নতুন সংকেত</strong><p>{say(current.watch.reason)}</p><small>এটি নতুন কাজের খসড়া; আগের সমাপ্তি বর্তমান অবস্থার প্রমাণ নয়।</small></div>}{focusTask !== null && <div className="ops-check"><MapPinned size={18}/><span>মানচিত্র/পুনরায় দেখার বাছা কাজ: {say(current.tasks[focusTask].team)} · {say(current.tasks[focusTask].action)}</span></div>}<p><strong>মূল দায়িত্ব:</strong> {say(current.owner)}</p><p><strong>আগে পরীক্ষা:</strong> {say(selected.title)}</p><p><strong>দল ও সরঞ্জাম:</strong> {say(current.resources)}</p><p><strong>এক সফরের পথ:</strong> {say(current.route)}</p><div className="ops-capacity-warning"><strong>দল ও সরঞ্জাম সত্যিই পাওয়া যাচ্ছে?</strong><label className="ops-use-evidence"><input type="checkbox" checked={resourceReady} onChange={event => changeResource(event.target.checked)}/>{say(current.capacity.resource)} প্রস্তুত (নমুনা)</label>{!resourceReady && <><p>{say(current.capacity.whenMissing)}</p><p><strong>বিকল্প:</strong> {say(current.capacity.fallback)}</p></>}</div><button type="button" className="button-dark" onClick={() => { if (approved) { setAssigned([]); setDone([]); setChecked([]) } setApproved(!approved) }}>{approved ? 'অনুশীলনের অনুমোদন প্রত্যাহার' : 'নমুনা mission অনুমোদন করুন'}</button><p className="ops-muted">এই বোতাম শুধু এই screen-এর অনুশীলন বদলায়; Supabase-এ দায়িত্ব পাঠায় না।</p></section>
      <section className="ops-card"><span className="mini-kicker">{assigned.length}টি দায়িত্ব দেওয়া · {done.length}টি কাজ জমা</span><h3>মানচিত্রের তথ্য থেকে দলের কাজ</h3><div className="ops-task-list">{current.tasks.map((task, index) => <button type="button" key={index} disabled={!approved || (!resourceReady && index === current.capacity.taskIndex)} className={`${done.includes(index) ? 'done' : ''} ${focusTask === index ? 'focused' : ''} ${!resourceReady && index === current.capacity.taskIndex ? 'resource-blocked' : ''}`} onClick={() => advanceTask(index)}><CheckCircle2 size={20}/><span><strong>{say(task.team)}</strong><small>{say(task.action)}</small></span><em>{!resourceReady && index === current.capacity.taskIndex ? 'সরঞ্জাম/অনুমতি নেই' : done.includes(index) ? 'জমা · আবার খুলুন' : assigned.includes(index) ? 'দেওয়া · update দিন' : 'দায়িত্ব দিন'}</em></button>)}</div><p className="ops-muted">প্রথম click-এ নমুনা দায়িত্ব, দ্বিতীয় click-এ মাঠের update। বাস্তব assignment ও evidence বিদ্যমান Incident/Task workflow-তে হবে।</p></section>
      {'responseModes' in current && current.responseModes && <OperationsResponse key={current.id} modes={current.responseModes}/>}
      <OperationsCoordination key={`coordination-${current.id}`} owner={current.owner} tasks={current.tasks} coordination={current.coordination}/>
    </div>}

    {step === 'follow' && <div className="ops-follow">
      <section className="ops-card"><span className="mini-kicker">আগে ব্যবস্থা, পরে শেখা</span><h3>পরিস্থিতি বদলালে পরিকল্পনাও বদলাবে</h3><div className="ops-trigger"><button type="button" className={rain ? 'active' : ''} onClick={() => setRain(!rain)}><CloudRain size={19}/> ভারী বৃষ্টির পূর্বাভাস</button><button type="button" className={crisis ? 'active' : ''} onClick={() => setCrisis(!crisis)}><AlertTriangle size={19}/> জরুরি অবস্থার অনুশীলন</button></div>{rain && <div className="ops-response"><strong>আগাম পদক্ষেপ</strong><p>{say(current.prevention)}</p></div>}{crisis && <div className="ops-response warning"><strong>অগ্রাধিকার পুনর্বিবেচনা</strong><p>{say(current.crisis)}</p><small>পরিবর্তনের কারণ ও পুরোনো কাজের প্রভাব দেখে কর্মকর্তা অনুমোদন করবেন।</small></div>}{!rain && !crisis && <p className="ops-muted">যেকোনো পরিস্থিতি চালু করে পরের সিদ্ধান্ত দেখুন।</p>}</section>
      <section className="ops-card"><span className="mini-kicker">কাজ জমা হলেই শেষ নয়</span><h3>ফল যাচাই ও পুনরাবৃত্তি দেখা</h3><div className="ops-task-list">{current.verify.map((item, index) => <button type="button" key={index} disabled={!allDone} className={checked.includes(index) ? 'done' : ''} onClick={() => toggle(index, checked, setChecked)}><CheckCircle2 size={20}/><span><strong>{say(item)}</strong></span><em>{checked.includes(index) ? 'যাচাই' : 'বাকি'}</em></button>)}</div><p className="ops-muted">{allChecked ? 'নমুনা case যাচাই হয়েছে। পরের বৃষ্টি/ব্যস্ত সময়ে আবার দেখার কাজও নথিভুক্ত করুন।' : allDone ? 'মাঠের জমা দেওয়া কাজ যাচাই করুন।' : 'আগের ধাপে mission অনুমোদন করে সব নমুনা কাজ জমা দিন।'}</p></section>
      <section className="ops-card ops-watch"><span className="mini-kicker">আগের কাজ শেষ হলেও নজরদারি চলবে</span><h3>পুনরাবৃত্তি ও পাশের জায়গা দেখুন</h3><p><strong>কখন:</strong> {say(current.watch.trigger)} · <strong>কোথায়:</strong> {say(current.watch.location)}</p><p>{say(current.watch.reason)}</p><button type="button" className="button-dark" disabled={!allChecked || watchScheduled} onClick={() => setWatchScheduled(true)}>{watchScheduled ? 'নমুনা follow-up নির্ধারিত' : 'নমুনা follow-up নির্ধারণ'}</button>{watchScheduled && <div className="ops-watch-card"><strong>পুনরায় সমস্যা দেখা গেলে?</strong><p>আগের case বন্ধ দেখিয়ে থামবেন না; সংশ্লিষ্ট জায়গার নতুন মাঠ যাচাই ও দায়িত্বের খসড়া খুলুন।</p><button type="button" className="button-outline" onClick={flagRepeat}>পুনরাবৃত্তির সংকেত অনুশীলন</button></div>}<p className="ops-muted">এখানে কোনো বাস্তব reminder বা task তৈরি হয় না।</p></section>
      <section className="ops-card ops-partners"><span className="mini-kicker">পাইলট চালাতে যা লাগবে</span><h3>চ্যালেঞ্জ, দায়িত্ব ও ব্যবস্থা</h3><div>{seed.stakeholders.map(item => <article key={item.who.en}><strong>{say(item.who)}</strong><span>{say(item.challenge)}</span><b>{say(item.response)}</b></article>)}</div></section>
    </div>}
  </div>
}
