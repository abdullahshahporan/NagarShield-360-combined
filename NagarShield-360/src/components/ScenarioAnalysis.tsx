'use client'

import { useEffect, useState } from 'react'
import { Check, FileVideo, ImagePlus, ScanSearch } from 'lucide-react'
import { performWorkflowAction } from '@/app/actions/workflow'
import { bn, priorities, scoreFactors } from '@/src/lib/demo'
import type { Scenario } from '@/src/lib/types'
import { ManualMediaPreview } from './ManualMediaPreview'

export function ScenarioAnalysis({ items, importedFile }: { items: Scenario[]; importedFile?: File | null }) {
  const [selected, setSelected] = useState(items[0]?.id || '')
  const [preview, setPreview] = useState<string | null>(null)
  const [fileKind, setFileKind] = useState<'image' | 'video'>('image')
  const [fileName, setFileName] = useState('')
  const [fileError, setFileError] = useState('')
  const scenario = items.find(s => s.id === selected) || items[0]
  const score = scenario ? scoreFactors(scenario.factors) : null
  useEffect(() => () => { if (preview) URL.revokeObjectURL(preview) }, [preview])
  useEffect(() => { if (importedFile) chooseFile(importedFile) }, [importedFile])
  function chooseFile(file?: File) {
    if (preview) URL.revokeObjectURL(preview)
    setPreview(null); setFileName(''); setFileError('')
    if (!file) return
    if (!['image/png','image/jpeg','image/webp','video/mp4','video/webm'].includes(file.type) || file.size > 50 * 1024 * 1024) { setFileError('PNG, JPEG, WebP, MP4 বা WebM ফাইল বেছে নিন (সর্বোচ্চ ৫০ MB)।'); return }
    setPreview(URL.createObjectURL(file)); setFileName(file.name); setFileKind(file.type.startsWith('video/') ? 'video' : 'image')
  }
  if (!scenario || !score) return <div className="empty-state">নমুনা ছবি বা ভিডিও পাওয়া যাচ্ছে না।</div>
  return <div className="analysis-layout"><section className="panel"><div className="panel-head"><div><span className="mini-kicker">১ · নমুনা নির্বাচন</span><h2>নমুনা দেখুন</h2></div><ScanSearch size={20}/></div><div className="scenario-options">{items.map(item => <button className={selected === item.id ? 'scenario-option active' : 'scenario-option'} type="button" key={item.id} onClick={() => setSelected(item.id)}><span>{item.kind === 'video' ? <FileVideo size={17}/> : <ImagePlus size={17}/>}</span><strong>{item.title_bn}</strong>{selected === item.id && <Check size={16}/>}</button>)}</div><div className="analysis-preview"><ManualMediaPreview scenario={scenario} preview={preview} fileKind={fileKind} fileName={fileName}/></div><label className="upload-label">নিজের ফাইল বেছে দেখুন<input type="file" accept="image/png,image/jpeg,image/webp,video/mp4,video/webm" onChange={event => chooseFile(event.target.files?.[0])}/></label>{fileError && <p role="alert" className="field-error">{fileError}</p>}<p className="help-text">আপনার ফাইল শুধু এই ব্রাউজারে দেখা যায়; সার্ভারে যায় না। পাশের ফলাফলটি বেছে নেওয়া নমুনার জন্য আগে থেকে তৈরি।</p></section>
    <section className="analysis-side"><div className="panel"><div className="panel-head"><div><span className="mini-kicker">২ · নমুনার ফল</span><h2>কী দেখা যাচ্ছে</h2></div><span className="prototype-tag">নমুনা ফল</span></div><p>{scenario.summary_bn}</p><div className="analysis-facts"><span>নমুনা অবস্থান</span><strong>{scenario.area_bn}</strong><span>চিহ্নিত সমস্যা</span><strong>{scenario.detections.length ? scenario.detections.map(d => d.label_bn).join(' · ') : 'কোনো সমস্যা দেখা যাচ্ছে না'}</strong></div><div className="score-summary"><div><span>অগ্রাধিকার স্কোর</span><strong>{bn(score.score)}<small>/১০০</small></strong></div><span className={`priority-pill priority-${score.priority}`}>{priorities[score.priority]}</span></div><p className="help-text">স্কোরটি ডেমোর জন্য তৈরি। এটি রোগ বা বন্যার পূর্বাভাস কিংবা আইনগত সিদ্ধান্ত নয়।</p></div>
    <div className="panel"><div className="panel-head"><div><span className="mini-kicker">৩ · কারণ দেখুন</span><h2>স্কোর কীভাবে এসেছে</h2></div></div><div className="factor-list">{score.parts.map(([label,value,weight]) => <div key={label}><div><span>{label}</span><strong>{bn(Math.round(value*weight))}</strong></div><div className="factor-track"><span style={{width:`${value}%`}}/></div></div>)}<div className="factor-bonus">অতিরিক্ত নম্বর <strong>+{bn(score.bonus)}</strong></div></div><p className="help-text">হিসাব: ৩০% ড্রেন, ২৫% পানি জমা, ১৫% বর্জ্য, ১৫% চলাচল, ১০% পুনরাবৃত্তি ও ৫% তথ্যের স্পষ্টতা; সঙ্গে অতিরিক্ত নম্বর।</p></div>
    <form action={performWorkflowAction} className="panel analysis-submit"><span className="mini-kicker">৪ · কর্মকর্তার যাচাই</span><h2>যাচাইয়ের জন্য পাঠান</h2><p>ঘটনা খোলার আগে একজন দায়িত্বপ্রাপ্ত কর্মকর্তা তথ্যটি যাচাই করবেন।</p><input type="hidden" name="action" value="create_observation"/><input type="hidden" name="scenario_id" value={scenario.id}/><input type="hidden" name="return_to" value="/incidents"/><button className="button-dark" type="submit">যাচাই করতে পাঠান</button></form></section></div>
}
