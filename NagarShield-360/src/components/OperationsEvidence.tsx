'use client'

import { useState } from 'react'
import { Camera, Eye, FileVideo, Plane, UserRoundCheck } from 'lucide-react'
import seed from '@/src/lib/operations-seed.json'

type Media = (typeof seed.cases)[number]['media']
const sourceLabel: Record<string, string> = { camera: 'স্থানীয় CCTV', drone: 'অনুমোদিত ড্রোন জরিপ', citizen: 'নাগরিকের ছবি', field: 'মাঠের ছবি' }
const sourceIcon: Record<string, typeof Camera> = { camera: Camera, drone: Plane, citizen: Eye, field: UserRoundCheck }

export function OperationsEvidence({ media, usedIds, onToggle }: { media: Media; usedIds: string[]; onToggle: (id: string) => void }) {
  const [selectedId, setSelectedId] = useState(media[0].id)
  const selected = media.find(item => item.id === selectedId) || media[0]
  return <div className="ops-two-col ops-evidence-layout">
    <section className="ops-card"><span className="mini-kicker">নমুনা frame/clip · AI inference নয়</span><h3>Footage দেখে কী বোঝা যায়?</h3><div className="ops-media-picker">{media.map(item => { const Icon = sourceIcon[item.source] || FileVideo; return <button type="button" key={item.id} className={selected.id === item.id ? 'active' : ''} onClick={() => setSelectedId(item.id)}><Icon size={17}/><span>{sourceLabel[item.source] || item.source}<small>{item.age} আগে · {item.timeRange}</small></span></button> })}</div><div className="ops-media-frame">{selected.kind === 'video' ? <video key={selected.id} controls playsInline preload="metadata" poster={`/api/media/scenarios/${selected.preset}.svg`} src={`/api/media/scenarios/${selected.preset}.webm`}/> : <img src={`/api/media/scenarios/${selected.preset}.svg`} alt="নমুনা evidence frame"/>}<span className="ops-media-box" style={{left:`${selected.box[0]}%`,top:`${selected.box[1]}%`,width:`${selected.box[2]}%`,height:`${selected.box[3]}%`}}>নমুনা চিহ্ন</span></div><p className="ops-muted">সময়সীমা, box ও confidence আগে থেকে seed করা। বাস্তব footage analysis হলে অনুমতি, model validation ও মানুষ দিয়ে review লাগবে।</p></section>
    <section className="ops-card"><span className="mini-kicker">উৎস → পর্যবেক্ষণ → সিদ্ধান্ত</span><h3>{sourceLabel[selected.source] || selected.source}</h3><div className="ops-evidence-facts"><div><span>নমুনা confidence</span><strong>{Math.round(selected.confidence * 100)}%</strong></div><div><span>সময়সীমা / বয়স</span><strong>{selected.timeRange} · {selected.age}</strong></div><div><span>যা দেখা যাচ্ছে</span><strong>{selected.finding.bn}</strong></div><div><span>যা নিশ্চিত নয়</span><strong>{selected.limit.bn}</strong></div></div><label className="ops-use-evidence"><input type="checkbox" checked={usedIds.includes(selected.id)} onChange={() => onToggle(selected.id)}/> এই evidence পরামর্শে ধরুন</label><p className="ops-muted">গ্রহণ বা বাদ দিলে পরের ধাপে ব্যাখ্যাসহ priority বদলাবে। পুরোনো বা আড়ালযুক্ত footage বাদ দেওয়ার কারণও বোঝা যাবে।</p><a className="inline-link" href="/analysis">পূর্ণ মিডিয়া বিশ্লেষণ খুলুন →</a></section>
  </div>
}
