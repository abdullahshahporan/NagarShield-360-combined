'use client'

import { useEffect, useRef, useState } from 'react'
import { Camera, CircleStop, FileVideo, Maximize2, MonitorPlay, ScanSearch, UsersRound } from 'lucide-react'
import { assignMarkedFootage } from '@/app/actions/marked-footage'
import type { Role, Scenario } from '@/src/lib/types'
import { ScenarioAnalysis } from './ScenarioAnalysis'

type Case = { id: string; code: string; title_bn: string; area_bn: string; before_key: string | null; department_id: string; status: string }
type Employee = { id: string; display_name: string; department_id: string; team_id: string | null }
type Mark = { source: string; x: number; y: number; w: number; h: number; seconds: number | null }
const feedIds = ['mixed', 'water', 'footpath', 'waste']
const feedSource: Record<string, string> = { mixed: 'CCTV নমুনা · বাজার সড়ক', water: 'প্রদত্ত ড্রোন ভিডিও · খাল', footpath: 'CCTV নমুনা · পূর্ব ফুটপাত', waste: 'ড্রোন নমুনা · বাজার গলি' }
const mediaUrl = (key: string) => `/api/media/${key.split('/').map(encodeURIComponent).join('/')}`
const pct = (value: number) => Math.round(value * 100)

function DemoFeed({ scenario, selected, mark, marking, onSelect, onPointerDown, onPointerUp }: {
  scenario: Scenario; selected: boolean; mark: Mark | null; marking: boolean
  onSelect: () => void; onPointerDown: (event: React.PointerEvent<HTMLDivElement>) => void; onPointerUp: (event: React.PointerEvent<HTMLDivElement>, seconds: number | null, media: HTMLVideoElement | HTMLImageElement | null) => void
}) {
  const [failed, setFailed] = useState(false)
  const video = useRef<HTMLVideoElement>(null)
  const image = useRef<HTMLImageElement>(null)
  const provided = scenario.id === 'water'
  const isVideo = scenario.kind === 'video' && !failed
  useEffect(() => { if (marking && selected) video.current?.pause() }, [marking, selected])
  return <article className={`feed-card${selected ? ' selected' : ''}`}>
    <div className="feed-image" onClick={onSelect}>
      {isVideo ? <video ref={video} src={provided ? '/api/demo-footage' : mediaUrl(scenario.media_key)} poster={provided ? undefined : mediaUrl(scenario.media_key.replace(/\.webm$/, '.svg'))} autoPlay muted loop controls playsInline preload="metadata" onError={() => setFailed(true)} aria-label={`${feedSource[scenario.id]} রেকর্ড করা ভিডিও`}/>
        : failed && provided ? <div className="feed-unavailable">প্রদত্ত ভিডিওটি লোড করা যায়নি।</div>
          : <img ref={image} src={mediaUrl(scenario.media_key.replace(/\.webm$/, '.svg'))} alt={`${scenario.title_bn} নমুনা দৃশ্য`}/>}
      <span className="feed-badge">{provided ? 'প্রদত্ত ফুটেজ · রেকর্ড করা' : isVideo ? 'নমুনা ভিডিও · পুনরাবৃত্তি' : 'নমুনা স্থিরচিত্র'}</span>
      {mark?.source === scenario.id && <span className="feed-mark" style={{ left: `${pct(mark.x)}%`, top: `${pct(mark.y)}%`, width: `${pct(mark.w)}%`, height: `${pct(mark.h)}%` }}><small>কর্মকর্তার চিহ্ন</small></span>}
      {marking && selected && <div className="feed-hitbox" role="presentation" onPointerDown={onPointerDown} onPointerUp={event => onPointerUp(event, video.current?.currentTime ?? null, video.current || image.current)}/>}
    </div>
    <button type="button" className="feed-caption" onClick={onSelect} aria-pressed={selected}><strong>{feedSource[scenario.id]}</strong><span>{provided ? 'ভিডিওর নির্দিষ্ট অবস্থান কর্মকর্তা যাচাই করবেন' : `${scenario.area_bn} · ${scenario.title_bn}`}</span></button>
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
  const [screenshot, setScreenshot] = useState<File | null>(null)
  const [screenshotUrl, setScreenshotUrl] = useState<string | null>(null)
  const [captureError, setCaptureError] = useState('')
  const [submitError, setSubmitError] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [reviewId, setReviewId] = useState(items[0]?.id || '')
  const [importedFile, setImportedFile] = useState<File | null>(null)
  const [liveMode, setLiveMode] = useState<'camera' | 'screen' | null>(null)
  const [liveError, setLiveError] = useState('')
  const liveVideo = useRef<HTMLVideoElement>(null)
  const liveStream = useRef<MediaStream | null>(null)
  const dragStart = useRef<{ x: number; y: number } | null>(null)
  const selectedFeed = feeds.find(feed => feed.id === selected)
  const caseOptions = incidents.filter(item => selectedFeed && (selected === 'water' || item.before_key === selectedFeed.media_key) && (role === 'executive' || item.department_id === departmentId))
  const activeCase = caseOptions.find(item => item.id === caseId)
  const availableEmployees = employees.filter(item => item.department_id === activeCase?.department_id)
  const assignee = availableEmployees.find(item => item.id === assigneeId)

  useEffect(() => { setCaseId(selected === 'water' ? '' : caseOptions[0]?.id || ''); setAssigneeId(''); setMark(null); setScreenshot(null); setCaptureError(''); setSubmitError('') }, [selected])
  useEffect(() => () => { liveStream.current?.getTracks().forEach(track => track.stop()) }, [])
  useEffect(() => { if (liveMode && liveVideo.current && liveStream.current) { liveVideo.current.srcObject = liveStream.current; void liveVideo.current.play() } }, [liveMode])
  useEffect(() => {
    if (!screenshot) { setScreenshotUrl(null); return }
    const url = URL.createObjectURL(screenshot)
    setScreenshotUrl(url)
    return () => URL.revokeObjectURL(url)
  }, [screenshot])

  function selectFeed(id: string) { setSelected(id); setMarking(false) }
  function position(event: React.PointerEvent<HTMLDivElement>) {
    const rect = event.currentTarget.getBoundingClientRect()
    return { x: Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width)), y: Math.max(0, Math.min(1, (event.clientY - rect.top) / rect.height)) }
  }
  function startMark(event: React.PointerEvent<HTMLDivElement>) {
    event.currentTarget.setPointerCapture(event.pointerId)
    dragStart.current = position(event)
  }
  async function endMark(event: React.PointerEvent<HTMLDivElement>, seconds: number | null, media: HTMLVideoElement | HTMLImageElement | null) {
    if (!dragStart.current) return
    const end = position(event)
    const start = dragStart.current
    const width = Math.abs(end.x - start.x)
    const height = Math.abs(end.y - start.y)
    const x = width < .025 ? Math.max(0, start.x - .04) : Math.min(start.x, end.x)
    const y = height < .025 ? Math.max(0, start.y - .04) : Math.min(start.y, end.y)
    const nextMark = { source: selected, x, y, w: Math.min(width < .025 ? .08 : width, 1 - x), h: Math.min(height < .025 ? .08 : height, 1 - y), seconds }
    setMark(nextMark)
    setScreenshot(null)
    setCaptureError('')
    dragStart.current = null
    setMarking(false)
    if (selected !== 'live' && media) {
      try { setScreenshot(await captureMarkedFrame(media, nextMark)) }
      catch { setCaptureError('ফ্রেমের ছবি নেওয়া যায়নি। ভিডিওটি চালু করে আবার চিহ্ন দিন।') }
    }
  }

  async function captureMarkedFrame(media: HTMLVideoElement | HTMLImageElement, area: Mark) {
    const sourceWidth = media instanceof HTMLVideoElement ? media.videoWidth : media.naturalWidth
    const sourceHeight = media instanceof HTMLVideoElement ? media.videoHeight : media.naturalHeight
    if (!sourceWidth || !sourceHeight) throw new Error('Media not ready')
    const rect = media.getBoundingClientRect()
    const canvas = document.createElement('canvas')
    canvas.width = 960
    canvas.height = Math.max(360, Math.round(960 * rect.height / rect.width))
    const context = canvas.getContext('2d')
    if (!context) throw new Error('Canvas unavailable')
    const scale = Math.max(canvas.width / sourceWidth, canvas.height / sourceHeight)
    const drawWidth = sourceWidth * scale
    const drawHeight = sourceHeight * scale
    context.drawImage(media, (canvas.width - drawWidth) / 2, (canvas.height - drawHeight) / 2, drawWidth, drawHeight)
    const x = area.x * canvas.width
    const y = area.y * canvas.height
    const w = area.w * canvas.width
    const h = area.h * canvas.height
    context.fillStyle = '#dfff5030'
    context.fillRect(x, y, w, h)
    context.strokeStyle = '#e9ff7d'
    context.lineWidth = 5
    context.strokeRect(x, y, w, h)
    context.fillStyle = '#173c34'
    context.fillRect(x, Math.max(0, y - 30), 150, 30)
    context.fillStyle = '#ffffff'
    context.font = 'bold 16px Arial'
    context.fillText('Marked area', x + 8, Math.max(20, y - 9))
    const blob = await new Promise<Blob | null>(resolve => canvas.toBlob(resolve, 'image/jpeg', .8))
    if (!blob || blob.size > 1024 * 1024) throw new Error('Screenshot too large')
    return new File([blob], `marked-frame-${Date.now()}.jpg`, { type: 'image/jpeg' })
  }

  async function submitMarked(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (submitting) return
    if (!mark || !screenshot) { setSubmitError('আগে ভিডিও বা ছবিতে জায়গাটি চিহ্নিত করে স্ক্রিনশট তৈরি করুন।'); return }
    if (!activeCase) { setSubmitError('কোন ঘটনার কাজ দেবেন, সেটি নির্বাচন করুন।'); document.getElementById('monitor-incident')?.focus(); return }
    if (!assignee) { setSubmitError('দায়িত্ব দেওয়ার জন্য একজন মাঠকর্মী নির্বাচন করুন।'); document.getElementById('monitor-assignee')?.focus(); return }
    if (instruction.trim().length < 8) { setSubmitError('কী করতে হবে তা অন্তত ৮ অক্ষরে লিখুন। যেমন: ড্রেন পরিষ্কার করে ছবি দিন।'); document.getElementById('monitor-instruction')?.focus(); return }
    setSubmitting(true)
    setSubmitError('')
    try {
      const data = new FormData(event.currentTarget)
      data.set('screenshot', screenshot)
      const result = await assignMarkedFootage(data)
      if (result?.error) setSubmitError(result.error)
    } catch { setSubmitError('কাজ পাঠানো যায়নি। সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।') }
    finally { setSubmitting(false) }
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
      <div className="panel-head"><div><span className="mini-kicker">প্রদত্ত ভিডিও ও নমুনা দৃশ্য</span><h2>ফুটেজ মনিটর</h2></div><span className="monitor-count">{feeds.length}টি রেকর্ড করা দৃশ্য · {liveMode ? '১টি ব্রাউজার লাইভ দৃশ্য' : 'নেটওয়ার্ক লাইভ সংযোগ নেই'}</span></div>
      <div className="monitor-intro"><p>আপনার দেওয়া ড্রোন ভিডিওতে খাল ও আশপাশের জায়গা দেখুন। যেখানে ব্যবস্থা দরকার, ভিডিও থামিয়ে সেই অংশে বক্স আঁকুন। চিহ্নসহ ফ্রেমটি নির্দিষ্ট মাঠকর্মীর কাজের সঙ্গে যাবে।</p><span>প্রদত্ত ও নমুনা ভিডিও রেকর্ড করা; কোনো সরাসরি CCTV/ড্রোন ফিড নয়।</span></div>
      <div className="feed-grid">{feeds.map(feed => <DemoFeed key={feed.id} scenario={feed} selected={selected === feed.id} mark={mark} marking={marking} onSelect={() => selectFeed(feed.id)} onPointerDown={startMark} onPointerUp={endMark}/>)}</div>
      <div className="monitor-live"><div><strong><MonitorPlay size={18}/> নিজের লাইভ ইনপুট</strong><p>প্রেজেন্টেশনে ক্যামেরা বা অনুমোদিত ড্রোন/CCTV উইন্ডো শেয়ার করে সরাসরি দৃশ্য দেখান। এটি শুধু এই ব্রাউজারে চলে।</p></div><div className="monitor-live-actions"><button type="button" className="button-outline" onClick={() => void startLive('camera')}><Camera size={15}/> ক্যামেরা চালু</button><button type="button" className="button-outline" onClick={() => void startLive('screen')}><Maximize2 size={15}/> স্ক্রিন শেয়ার</button>{liveMode && <button type="button" className="button-text" onClick={stopLive}><CircleStop size={15}/> বন্ধ</button>}</div></div>
      {liveError && <p className="field-error" role="alert">{liveError}</p>}
      {liveMode && <div className={`monitor-live-view${selected === 'live' ? ' selected' : ''}`}><div className="feed-image" onClick={() => selectFeed('live')}><video ref={liveVideo} autoPlay muted playsInline aria-label="আপনার অনুমোদিত লাইভ দৃশ্য"/><span className="feed-badge live">শুধু ব্রাউজারে লাইভ · {liveMode === 'camera' ? 'ক্যামেরা' : 'স্ক্রিন শেয়ার'}</span>{mark?.source === 'live' && <span className="feed-mark" style={{ left: `${pct(mark.x)}%`, top: `${pct(mark.y)}%`, width: `${pct(mark.w)}%`, height: `${pct(mark.h)}%` }}><small>কর্মকর্তার চিহ্ন</small></span>}{marking && selected === 'live' && <div className="feed-hitbox" role="presentation" onPointerDown={startMark} onPointerUp={event => void endMark(event, null, liveVideo.current)}/>}</div><button type="button" className="feed-caption" onClick={() => selectFeed('live')}>এই লাইভ দৃশ্য বেছে নিন</button></div>}
    </section>
    <section className="panel monitor-decision section-gap" aria-label="চিহ্ন ও দায়িত্ব">
      <div className="panel-head"><div><span className="mini-kicker">দৃশ্য → চিহ্ন → দায়িত্ব</span><h2>যেখানে সমস্যা, সেখানেই কাজ দিন</h2></div><ScanSearch size={19}/></div>
      <div className="monitor-step-grid"><div><span>১</span><strong>দৃশ্য বাছুন</strong><p>{sourceName || 'বাঁ পাশের কোনো দৃশ্য বাছুন'}</p></div><div><span>২</span><strong>জায়গাটি চিহ্নিত করুন</strong><p>{mark ? `বাম ${pct(mark.x)}%, উপর ${pct(mark.y)}%` : 'চিহ্ন দিন বোতাম চাপুন, তারপর দৃশ্যে টেনে বক্স আঁকুন'}</p></div><div><span>৩</span><strong>মাঠকর্মীকে পাঠান</strong><p>কাজটি তাঁর তালিকায় যাবে, অ্যাপের বিজ্ঞপ্তিতেও দেখা যাবে।</p></div></div>
      <div className="monitor-actions"><button type="button" className="button-dark" disabled={!selected} onClick={() => { setMark(null); setScreenshot(null); setMarking(true) }}>{marking ? 'দৃশ্যে টেনে চিহ্ন দিন…' : mark ? 'চিহ্ন বদলান' : 'দৃশ্যে চিহ্ন দিন'}</button>{mark && <button type="button" className="button-text" onClick={() => { setMark(null); setScreenshot(null) }}>চিহ্ন মুছুন</button>}{selectedFeed && selected !== 'water' && <button type="button" className="button-outline" onClick={reviewFeed}><FileVideo size={15}/> নমুনা বিশ্লেষণ দেখুন</button>}{selected === 'live' && liveMode && <button type="button" className="button-outline" onClick={() => void captureFrame()}>ফ্রেম নিয়ে নিজে চিহ্ন দিন</button>}</div>
      {captureError && <p className="field-error" role="alert">{captureError}</p>}
      {screenshotUrl && <figure className="monitor-screenshot"><img src={screenshotUrl} alt="চিহ্নিত অংশসহ পাঠানোর স্ক্রিনশট"/><figcaption>এই চিহ্নিত স্ক্রিনশটটি নির্বাচিত কর্মীর কাজের সঙ্গে সংরক্ষিত হবে।</figcaption></figure>}
      <form noValidate onSubmit={event => void submitMarked(event)} className="monitor-assignment"><div className="panel-head"><div><span className="mini-kicker">চিহ্নিত স্ক্রিনশটসহ দায়িত্ব</span><h2>নির্দিষ্ট কর্মীকে কাজ দিন</h2></div><UsersRound size={18}/></div>
        <div className="form-grid">
          <label htmlFor="monitor-incident">খোলা ঘটনা<select id="monitor-incident" required value={caseId} onChange={event => { setCaseId(event.target.value); setAssigneeId('') }}><option value="" disabled>ঘটনা নির্বাচন করুন</option>{caseOptions.map(item => <option key={item.id} value={item.id}>{item.code} · {item.title_bn} · {item.area_bn}</option>)}</select></label>
          <label htmlFor="monitor-assignee">মাঠকর্মী<select id="monitor-assignee" required value={assigneeId} onChange={event => setAssigneeId(event.target.value)}><option value="" disabled>কর্মী নির্বাচন করুন</option>{availableEmployees.map(item => <option key={item.id} value={item.id}>{item.display_name}</option>)}</select></label>
        </div>
        <label htmlFor="monitor-instruction">কী করতে হবে<input id="monitor-instruction" name="instruction" required minLength={8} maxLength={500} aria-describedby="monitor-instruction-help" value={instruction} onChange={event => { setInstruction(event.target.value); setSubmitError('') }} placeholder="যেমন: চিহ্নিত জায়গায় ড্রেনের মুখ পরিষ্কার করে ছবি দিন"/></label>
        <p id="monitor-instruction-help" className="help-text">কাজের নির্দেশনা অন্তত ৮ অক্ষরে লিখুন।</p>
        <input type="hidden" name="incident_id" value={caseId}/><input type="hidden" name="assignee_id" value={assigneeId}/><input type="hidden" name="note" value={`${instruction.trim()} | ${markNote}`.slice(0, 1000)}/>
        {!caseOptions.length && <p className="field-error">{selected === 'live' ? 'ব্রাউজারের লাইভ দৃশ্য সংরক্ষিত ঘটনা নয়। আগে ফ্রেম নিয়ে নিজে পর্যালোচনা করুন; নমুনা ফুটেজের চিহ্ন থেকে সরাসরি কাজ দিতে পারবেন।' : 'এই দৃশ্যের খোলা ঘটনা নেই। আগে নিচে নমুনাটি যাচাই করে ঘটনা খুলুন, অথবা অন্য দৃশ্য বাছুন।'}</p>}
        {selected === 'water' && <p className="help-text">প্রদত্ত ভিডিওর জায়গা স্বয়ংক্রিয়ভাবে জানা যায় না। মিল আছে এমন খোলা ঘটনা কর্মকর্তা বেছে নেবেন।</p>}
        {submitError && <p className="field-error" role="alert">{submitError}</p>}
        <button className="button-dark" type="submit" disabled={submitting}>{submitting ? 'স্ক্রিনশট ও কাজ পাঠানো হচ্ছে…' : 'স্ক্রিনশটসহ কাজ পাঠান'}</button>
        <p className="help-text">পাঠালে ব্যক্তিগত storage-এ চিহ্নিত JPEG, ঘটনার অধীনে কাজ এবং নির্বাচিত কর্মীর অ্যাপের বিজ্ঞপ্তি তৈরি হয়। কর্মী ঘটনা খুলে ছবিটি দেখতে পারবেন। ফোনের push/SMS যায় না।</p>
      </form>
    </section>
    <div id="manual-review" className="section-gap">{importedFile && <p className="monitor-capture-note">এই ফ্রেমটি শুধু আপনার ব্রাউজারে এসেছে। নিচের নমুনা স্কোর ও শনাক্তকরণ এই ফ্রেমের ফল নয়; নিজের চিহ্ন আঁকতে পারবেন, কিন্তু এই ফ্রেম থেকে স্বয়ংক্রিয়ভাবে কাজ পাঠানো হয় না।</p>}<ScenarioAnalysis key={reviewId} items={reviewItems} importedFile={importedFile}/></div>
  </>
}
