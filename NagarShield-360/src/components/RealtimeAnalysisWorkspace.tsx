'use client'

import { useEffect, useRef, useState } from 'react'
import { Camera, CircleStop, FileVideo, Maximize2, MonitorPlay, ScanSearch, UsersRound } from 'lucide-react'
import { performWorkflowAction } from '@/app/actions/workflow'
import type { Role, Scenario } from '@/src/lib/types'
import { ScenarioAnalysis } from './ScenarioAnalysis'

type Case = { id: string; code: string; before_key: string | null; department_id: string; status: string }
type Employee = { id: string; display_name: string; department_id: string; team_id: string | null }
type Mark = { source: string; x: number; y: number; w: number; h: number; seconds: number | null }
const feedIds = ['mixed', 'water', 'footpath', 'waste']
const feedSource: Record<string, string> = { mixed: 'CCTV · বাজার সড়ক', water: 'ড্রোন · নিচু রাস্তা', footpath: 'CCTV · পূর্ব ফুটপাত', waste: 'ড্রোন · বাজার গলি' }
const mediaUrl = (key: string) => `/api/media/${key.split('/').map(encodeURIComponent).join('/')}`
const pct = (value: number) => Math.round(value * 100)

function DemoFeed({ scenario, selected, mark, marking, onSelect, onPointerDown, onPointerUp }: {
  scenario: Scenario; selected: boolean; mark: Mark | null; marking: boolean
  onSelect: () => void; onPointerDown: (event: React.PointerEvent<HTMLDivElement>) => void; onPointerUp: (event: React.PointerEvent<HTMLDivElement>, seconds: number | null) => void
}) {
  const [failed, setFailed] = useState(false)
  const video = useRef<HTMLVideoElement>(null)
  const isVideo = scenario.kind === 'video' && !failed
  return <article className={`feed-card${selected ? ' selected' : ''}`}>
    <div className="feed-image" onClick={onSelect}>
      {isVideo ? <video ref={video} src={mediaUrl(scenario.media_key)} poster={mediaUrl(scenario.media_key.replace(/\.webm$/, '.svg'))} autoPlay muted loop playsInline preload="metadata" onError={() => setFailed(true)} aria-label={`${feedSource[scenario.id]} নমুনা ভিডিও`}/>
        : <img src={mediaUrl(scenario.media_key.replace(/\.webm$/, '.svg'))} alt={`${scenario.title_bn} নমুনা দৃশ্য`}/>}
      <span className="feed-badge">{isVideo ? 'নমুনা ভিডিও · পুনরাবৃত্তি' : 'নমুনা স্থিরচিত্র'}</span>
      {mark?.source === scenario.id && <span className="feed-mark" style={{ left: `${pct(mark.x)}%`, top: `${pct(mark.y)}%`, width: `${pct(mark.w)}%`, height: `${pct(mark.h)}%` }}><small>কর্মকর্তার চিহ্ন</small></span>}
      {marking && selected && <div className="feed-hitbox" role="presentation" onPointerDown={onPointerDown} onPointerUp={event => onPointerUp(event, video.current?.currentTime ?? null)}/>}
    </div>
    <button type="button" className="feed-caption" onClick={onSelect} aria-pressed={selected}><strong>{feedSource[scenario.id]}</strong><span>{scenario.area_bn} · {scenario.title_bn}</span></button>
  </article>
}

export function RealtimeAnalysisWorkspace({ items, incidents, employees, role, departmentId }: {
  items: Scenario[]; incidents: Case[]; employees: Employee[]; role: Role; departmentId: string | null
}) {
  const feeds = feedIds.map(id => items.find(item => item.id === id)).filter((item): item is Scenario => Boolean(item))
  const [selected, setSelected] = useState(feeds[0]?.id || '')
  const [marking, setMarking] = useState(false)
  const [mark, setMark] = useState<Mark | null>(null)
  const [caseId, setCaseId] = useState('')
  const [assigneeId, setAssigneeId] = useState('')
  const [instruction, setInstruction] = useState('')
  const [reviewId, setReviewId] = useState(items[0]?.id || '')
  const [importedFile, setImportedFile] = useState<File | null>(null)
  const [liveMode, setLiveMode] = useState<'camera' | 'screen' | null>(null)
  const [liveError, setLiveError] = useState('')
  const liveVideo = useRef<HTMLVideoElement>(null)
  const liveStream = useRef<MediaStream | null>(null)
  const dragStart = useRef<{ x: number; y: number } | null>(null)
  const selectedFeed = feeds.find(feed => feed.id === selected)
  const matchingCases = incidents.filter(item => selectedFeed && item.before_key === selectedFeed.media_key && (role === 'executive' || item.department_id === departmentId))
  const caseOptions = matchingCases
  const activeCase = caseOptions.find(item => item.id === caseId)
  const availableEmployees = employees.filter(item => item.department_id === activeCase?.department_id)
  const assignee = availableEmployees.find(item => item.id === assigneeId)

  useEffect(() => { setCaseId(caseOptions[0]?.id || ''); setAssigneeId(''); setMark(null) }, [selected])
  useEffect(() => () => { liveStream.current?.getTracks().forEach(track => track.stop()) }, [])
  useEffect(() => { if (liveMode && liveVideo.current && liveStream.current) { liveVideo.current.srcObject = liveStream.current; void liveVideo.current.play() } }, [liveMode])

  function selectFeed(id: string) { setSelected(id); setMarking(false) }
  function position(event: React.PointerEvent<HTMLDivElement>) {
    const rect = event.currentTarget.getBoundingClientRect()
    return { x: Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width)), y: Math.max(0, Math.min(1, (event.clientY - rect.top) / rect.height)) }
  }
  function startMark(event: React.PointerEvent<HTMLDivElement>) {
    event.currentTarget.setPointerCapture(event.pointerId)
    dragStart.current = position(event)
  }
  function endMark(event: React.PointerEvent<HTMLDivElement>, seconds: number | null) {
    if (!dragStart.current) return
    const end = position(event)
    const start = dragStart.current
    const width = Math.abs(end.x - start.x)
    const height = Math.abs(end.y - start.y)
    const x = width < .025 ? Math.max(0, start.x - .04) : Math.min(start.x, end.x)
    const y = height < .025 ? Math.max(0, start.y - .04) : Math.min(start.y, end.y)
    setMark({ source: selected, x, y, w: Math.min(width < .025 ? .08 : width, 1 - x), h: Math.min(height < .025 ? .08 : height, 1 - y), seconds })
    dragStart.current = null
    setMarking(false)
  }
  function stopLive() {
    liveStream.current?.getTracks().forEach(track => track.stop())
    liveStream.current = null
    if (liveVideo.current) liveVideo.current.srcObject = null
    setLiveMode(null)
    setMark(null)
    setMarking(false)
  }
  async function startLive(mode: 'camera' | 'screen') {
    stopLive()
    setLiveError('')
    if (!navigator.mediaDevices) { setLiveError('এই ব্রাউজারে ক্যামেরা বা স্ক্রিন শেয়ার পাওয়া যাচ্ছে না।'); return }
    try {
      const stream = mode === 'camera'
        ? await navigator.mediaDevices.getUserMedia({ video: true, audio: false })
        : await navigator.mediaDevices.getDisplayMedia({ video: true, audio: false })
      liveStream.current = stream
      setLiveMode(mode)
      setSelected('live')
      stream.getVideoTracks()[0]?.addEventListener('ended', stopLive, { once: true })
    } catch { setLiveError('অনুমতি দেওয়া হয়নি বা দৃশ্যটি চালু করা যায়নি। আবার চেষ্টা করুন।') }
  }
  async function captureFrame() {
    const video = liveVideo.current
    if (!video?.videoWidth || !video.videoHeight) return
    const canvas = document.createElement('canvas')
    canvas.width = video.videoWidth; canvas.height = video.videoHeight
    canvas.getContext('2d')?.drawImage(video, 0, 0)
    const blob = await new Promise<Blob | null>(resolve => canvas.toBlob(resolve, 'image/png'))
    if (!blob) return
    setImportedFile(new File([blob], `local-frame-${Date.now()}.png`, { type: 'image/png' }))
    setReviewId(items.find(item => item.id === 'clean')?.id || items[0]?.id || '')
    document.getElementById('manual-review')?.scrollIntoView({ behavior: 'smooth' })
  }
  function reviewFeed() {
    if (!selectedFeed) return
    setImportedFile(null)
    setReviewId(selectedFeed.id)
    document.getElementById('manual-review')?.scrollIntoView({ behavior: 'smooth' })
  }
  const chosen = items.find(item => item.id === reviewId)
  const reviewItems = chosen ? [chosen, ...items.filter(item => item.id !== chosen.id)] : items
  const sourceName = selected === 'live' ? (liveMode === 'camera' ? 'ব্রাউজার ক্যামেরা' : 'শেয়ার করা স্ক্রিন') : feedSource[selected]
  const markNote = mark ? `${sourceName}; চিহ্নিত অংশ: বাম ${pct(mark.x)}%, উপর ${pct(mark.y)}%, প্রস্থ ${pct(mark.w)}%, উচ্চতা ${pct(mark.h)}%${mark.seconds == null ? '' : `; ভিডিও সময় ${mark.seconds.toFixed(1)} সেকেন্ড`}` : ''

  return <>
    <section className="panel monitor-panel section-gap" aria-label="ডেমো ফুটেজ মনিটর">
      <div className="panel-head"><div><span className="mini-kicker">এক নজরে চারটি এলাকা</span><h2>ফুটেজ মনিটর</h2></div><span className="monitor-count">{feeds.length}টি নমুনা দৃশ্য · {liveMode ? '১টি ব্রাউজার লাইভ দৃশ্য' : 'লাইভ সংযোগ নেই'}</span></div>
      <div className="monitor-intro"><p>বাজারের ড্রেন, জমে থাকা পানি, ফুটপাত ও বর্জ্য—একজন কর্মকর্তা একই পর্দায় দেখতে পারেন। যে জায়গায় ব্যবস্থা দরকার, সেই দৃশ্যে চিহ্ন দিয়ে একজন মাঠকর্মী বেছে নিন।</p><span>নমুনা ফুটেজ কখনো বাস্তব লাইভ CCTV/ড্রোন ফিড হিসেবে দেখানো হয় না।</span></div>
      <div className="feed-grid">{feeds.map(feed => <DemoFeed key={feed.id} scenario={feed} selected={selected === feed.id} mark={mark} marking={marking} onSelect={() => selectFeed(feed.id)} onPointerDown={startMark} onPointerUp={endMark}/>)}</div>
      <div className="monitor-live"><div><strong><MonitorPlay size={18}/> নিজের লাইভ ইনপুট</strong><p>প্রেজেন্টেশনে ক্যামেরা বা অনুমোদিত ড্রোন/CCTV উইন্ডো শেয়ার করে সরাসরি দৃশ্য দেখান। এটি শুধু এই ব্রাউজারে চলে।</p></div><div className="monitor-live-actions"><button type="button" className="button-outline" onClick={() => void startLive('camera')}><Camera size={15}/> ক্যামেরা চালু</button><button type="button" className="button-outline" onClick={() => void startLive('screen')}><Maximize2 size={15}/> স্ক্রিন শেয়ার</button>{liveMode && <button type="button" className="button-text" onClick={stopLive}><CircleStop size={15}/> বন্ধ</button>}</div></div>
      {liveError && <p className="field-error" role="alert">{liveError}</p>}
      {liveMode && <div className={`monitor-live-view${selected === 'live' ? ' selected' : ''}`}><div className="feed-image" onClick={() => selectFeed('live')}><video ref={liveVideo} autoPlay muted playsInline aria-label="আপনার অনুমোদিত লাইভ দৃশ্য"/><span className="feed-badge live">শুধু ব্রাউজারে লাইভ · {liveMode === 'camera' ? 'ক্যামেরা' : 'স্ক্রিন শেয়ার'}</span>{mark?.source === 'live' && <span className="feed-mark" style={{ left: `${pct(mark.x)}%`, top: `${pct(mark.y)}%`, width: `${pct(mark.w)}%`, height: `${pct(mark.h)}%` }}><small>কর্মকর্তার চিহ্ন</small></span>}{marking && selected === 'live' && <div className="feed-hitbox" role="presentation" onPointerDown={startMark} onPointerUp={event => endMark(event, null)}/>}</div><button type="button" className="feed-caption" onClick={() => selectFeed('live')}>এই লাইভ দৃশ্য বেছে নিন</button></div>}
    </section>
    <section className="panel monitor-decision section-gap" aria-label="চিহ্ন ও দায়িত্ব">
      <div className="panel-head"><div><span className="mini-kicker">দৃশ্য → চিহ্ন → দায়িত্ব</span><h2>যেখানে সমস্যা, সেখানেই কাজ দিন</h2></div><ScanSearch size={19}/></div>
      <div className="monitor-step-grid"><div><span>১</span><strong>দৃশ্য বাছুন</strong><p>{sourceName || 'বাঁ পাশের কোনো দৃশ্য বাছুন'}</p></div><div><span>২</span><strong>জায়গাটি চিহ্নিত করুন</strong><p>{mark ? `বাম ${pct(mark.x)}%, উপর ${pct(mark.y)}%` : 'চিহ্ন দিন বোতাম চাপুন, তারপর দৃশ্যে টেনে বক্স আঁকুন'}</p></div><div><span>৩</span><strong>মাঠকর্মীকে পাঠান</strong><p>কাজটি তাঁর তালিকায় যাবে, অ্যাপের বিজ্ঞপ্তিতেও দেখা যাবে।</p></div></div>
      <div className="monitor-actions"><button type="button" className="button-dark" disabled={!selected} onClick={() => { setMark(null); setMarking(true) }}>{marking ? 'দৃশ্যে টেনে চিহ্ন দিন…' : mark ? 'চিহ্ন বদলান' : 'দৃশ্যে চিহ্ন দিন'}</button>{mark && <button type="button" className="button-text" onClick={() => setMark(null)}>চিহ্ন মুছুন</button>}{selectedFeed && <button type="button" className="button-outline" onClick={reviewFeed}><FileVideo size={15}/> নমুনা বিশ্লেষণ দেখুন</button>}{selected === 'live' && liveMode && <button type="button" className="button-outline" onClick={() => void captureFrame()}>ফ্রেম নিয়ে নিজে চিহ্ন দিন</button>}</div>
      <form action={performWorkflowAction} className="monitor-assignment"><div className="panel-head"><div><span className="mini-kicker">বর্তমান ঘটনার সঙ্গে যুক্ত দায়িত্ব</span><h2>নির্দিষ্ট কর্মীকে কাজ দিন</h2></div><UsersRound size={18}/></div>
        <div className="form-grid"><label>ঘটনা<select required value={caseId} onChange={event => { setCaseId(event.target.value); setAssigneeId('') }}><option value="" disabled>ঘটনা নির্বাচন করুন</option>{caseOptions.map(item => <option key={item.id} value={item.id}>{item.code} · {selectedFeed?.title_bn}</option>)}</select></label><label>মাঠকর্মী<select required value={assigneeId} onChange={event => setAssigneeId(event.target.value)}><option value="" disabled>কর্মী নির্বাচন করুন</option>{availableEmployees.map(item => <option key={item.id} value={item.id}>{item.display_name}</option>)}</select></label></div>
        <label>কী করতে হবে<input required minLength={8} maxLength={500} value={instruction} onChange={event => setInstruction(event.target.value)} placeholder="যেমন: চিহ্নিত জায়গায় ড্রেনের মুখ পরিষ্কার করে ছবি দিন"/></label>
        <input type="hidden" name="action" value="assign_task"/><input type="hidden" name="target" value={caseId}/><input type="hidden" name="return_to" value={activeCase ? `/incidents/${activeCase.id}` : '/analysis'}/><input type="hidden" name="department_id" value={activeCase?.department_id || ''}/><input type="hidden" name="team_id" value={assignee?.team_id || ''}/><input type="hidden" name="assignee_id" value={assigneeId}/><input type="hidden" name="note" value={`${instruction.trim()} | ${markNote}`.slice(0, 1000)}/>
        {!caseOptions.length && <p className="field-error">{selected === 'live' ? 'ব্রাউজারের লাইভ দৃশ্য সংরক্ষিত ঘটনা নয়। আগে ফ্রেম নিয়ে নিজে পর্যালোচনা করুন; নমুনা ফুটেজের চিহ্ন থেকে সরাসরি কাজ দিতে পারবেন।' : 'এই দৃশ্যের খোলা ঘটনা নেই। আগে নিচে নমুনাটি যাচাই করে ঘটনা খুলুন, অথবা অন্য দৃশ্য বাছুন।'}</p>}
        <button className="button-dark" type="submit" disabled={!mark || !activeCase || !assignee || instruction.trim().length < 8}>চিহ্নিত কাজ পাঠান</button>
        <p className="help-text">পাঠালে বর্তমান ঘটনার অধীনে একটি ডেমো কাজ ও নির্বাচিত মাঠকর্মীর ওয়েব বিজ্ঞপ্তি তৈরি হয়। কাজটি তাঁর মোবাইল অ্যাপের তালিকায়ও দেখা যাবে। ফোনের push/SMS যায় না।</p>
      </form>
    </section>
    <div id="manual-review" className="section-gap">{importedFile && <p className="monitor-capture-note">এই ফ্রেমটি শুধু আপনার ব্রাউজারে এসেছে। নিচের নমুনা স্কোর ও শনাক্তকরণ এই ফ্রেমের ফল নয়; নিজের চিহ্ন আঁকতে পারবেন, কিন্তু এই ফ্রেম থেকে স্বয়ংক্রিয়ভাবে কাজ পাঠানো হয় না।</p>}<ScenarioAnalysis key={reviewId} items={reviewItems} importedFile={importedFile}/></div>
  </>
}
