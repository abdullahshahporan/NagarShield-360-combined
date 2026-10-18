'use client'

import { useState } from 'react'
import { ArrowRight, Camera, MapPinned, Plane, Route, ShieldCheck } from 'lucide-react'
import seed from '@/src/lib/operations-seed.json'

type Copy = { en: string; bn: string }
type CityMap = (typeof seed.cases)[number]['map']
const say = (copy: Copy) => copy.bn
const points = (values: number[][]) => values.map(pair => pair.join(',')).join(' ')

export function OperationsMap({ map, tasks, selectedId, onSelect, showFlight, onFlightToggle, permission, onPermission, surveyComplete, onSurveyComplete, onDraftTask }: {
  map: CityMap
  tasks: (typeof seed.cases)[number]['tasks']
  selectedId: string
  onSelect: (id: string) => void
  showFlight: boolean
  onFlightToggle: () => void
  permission: boolean
  onPermission: (value: boolean) => void
  surveyComplete: boolean
  onSurveyComplete: () => void
  onDraftTask: (index: number) => void
}) {
  const [showBlindSpot, setShowBlindSpot] = useState(true)
  const [showTrace, setShowTrace] = useState(true)
  const selected = map.assets.find(asset => asset.id === selectedId) || map.assets[0]
  const cameraCount = map.cameras.length
  const trace = [selected]
  const visited = new Set([selected.id])
  let cursor = selected
  while (true) {
    const nextId = 'downstreamId' in cursor ? cursor.downstreamId : cursor.downstream
    const next = map.assets.find(asset => asset.id === nextId)
    if (!next || visited.has(next.id)) break
    trace.push(next)
    visited.add(next.id)
    cursor = next
  }
  const terminal = cursor.downstream !== '—' ? cursor.downstream : null
  return <div className="ops-two-col ops-map-layout">
    <section className="ops-card"><span className="mini-kicker">এলাকার নমুনা GIS · বাস্তব স্থানাঙ্ক নয়</span><h3>{say(map.label)}</h3><div className="ops-ward-map" role="group" aria-label="নমুনা এলাকা, ড্রেন, ক্যামেরা এবং জরিপ পথ">
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
        <defs><marker id="ops-flow-arrow" markerWidth="5" markerHeight="5" refX="4" refY="2.5" orient="auto"><path d="M0,0 L5,2.5 L0,5 Z" fill="#438daf"/></marker></defs>
        <rect width="100" height="100" fill="#e9f1e9"/>
        {map.buildings.map((rect, index) => <rect key={index} x={rect[0]} y={rect[1]} width={rect[2]} height={rect[3]} rx="1" fill="#cbdacb"/>)}
        {map.roads.map((road, index) => <polyline key={index} points={points(road)} stroke="#fff" strokeWidth="7" fill="none"/>)}
        {map.drains.map(drain => <polyline key={drain.id} points={points(drain.points)} stroke="#438daf" strokeWidth="1.4" fill="none" markerEnd="url(#ops-flow-arrow)"/>)}
        {showBlindSpot && <polygon points={points(map.blindSpot.polygon)} fill="#d9774533" stroke="#b75636" strokeWidth=".7" strokeDasharray="1.5 1"/>}
        {showTrace && trace.length > 1 && <polyline points={points(trace.map(asset => [asset.x, asset.y]))} fill="none" stroke="#bd6237" strokeWidth="1.5" strokeDasharray="2 1"/>}
        {showFlight && <><polygon points={points(map.survey.polygon)} fill="#7bb68044" stroke="#4e9a68" strokeWidth=".7" strokeDasharray="1.5 1"/><polyline points={points(map.survey.route)} fill="none" stroke="#e4aa42" strokeWidth="1" strokeDasharray="2 1"/><circle cx={map.survey.launch[0]} cy={map.survey.launch[1]} r="1.7" fill="#df9030"/></>}
      </svg>
      {map.cameras.map((point, index) => <span className="ops-camera-marker" key={index} style={{left:`${point[0]}%`,top:`${point[1]}%`}} title="অনুমোদিত স্থানীয় ক্যামেরার নমুনা স্থান"><Camera size={13}/></span>)}
      {map.assets.map(asset => <button type="button" key={asset.id} className={`ops-asset-marker ${asset.id === selected.id ? 'active' : ''} ${showTrace && trace.some(item => item.id === asset.id) ? 'traced' : ''}`} style={{left:`${asset.x}%`,top:`${asset.y}%`}} title={`${asset.id}: ${say(asset.label)}`} aria-label={`${asset.id}: ${say(asset.label)}`} onClick={() => onSelect(asset.id)}><span>{asset.id}</span></button>)}
    </div><div className="ops-map-legend"><span><i className="drain"/> পানি/sewer সংযোগের নমুনা</span><span><i className="survey"/> ড্রোন survey area</span><span><Camera size={15}/> অনুমোদিত CCTV</span><span><MapPinned size={15}/> কাজের asset</span></div><p className="ops-muted">রেখা ও সংযোগগুলো নমুনা; ড্রেন, sewer বা হাঁটার পথের প্রকৃত অবস্থা সংশ্লিষ্ট মাঠদল নিশ্চিত করবে।</p></section>
    <div className="ops-side-stack"><section className="ops-card"><span className="mini-kicker">মানচিত্রে বাছা স্থাপনা</span><h3>{selected.id} · {say(selected.label)}</h3><p><strong>পরের সংযোগ:</strong> {selected.downstream}</p><div className="ops-path">{trace.map((asset, index) => <div key={asset.id}><b>{index + 1}</b><span>{asset.id}</span>{index < trace.length - 1 && <ArrowRight size={14}/>}</div>)}{terminal && <div><ArrowRight size={14}/>{terminal}</div>}</div><p className="ops-muted">এটি সম্ভাব্য সংযোগপথ, নিশ্চিত কারণ নয়। <button className="ops-text-action" type="button" onClick={() => setShowTrace(!showTrace)}>{showTrace ? 'মানচিত্রের trace লুকান' : 'মানচিত্রের trace দেখান'}</button></p><p><strong>প্রস্তাবিত দল:</strong> {say(tasks[selected.taskIndex].team)}</p><button className="button-dark" type="button" onClick={() => onDraftTask(selected.taskIndex)}><ArrowRight size={16}/> এই asset থেকে কাজের খসড়া</button><p className="ops-muted">এতে নমুনা mission-এর সংশ্লিষ্ট কাজ খুলবে; বাস্তব দায়িত্ব পাঠানো হবে না।</p></section>
      <section className="ops-card"><span className="mini-kicker">ক্যামেরায় যা দেখা যায় না</span><h3>{say(map.blindSpot.label)}</h3><p>{say(map.blindSpot.reason)}</p><div className="ops-action-line"><button className="button-outline" type="button" onClick={() => setShowBlindSpot(!showBlindSpot)}>{showBlindSpot ? 'আড়ালের এলাকা লুকান' : 'আড়ালের এলাকা দেখান'}</button><button className="button-dark" type="button" onClick={() => onDraftTask(map.blindSpot.taskIndex)}>মাঠ যাচাইয়ের খসড়া</button></div><p className="ops-muted">কমলা এলাকা আনুমানিক coverage gap; camera field-of-view survey করা হয়নি।</p></section>
      <section className="ops-card"><span className="mini-kicker">অনুমোদনসাপেক্ষ survey পরিকল্পনা</span><h3><Plane size={20}/> ড্রোন কোন অংশ দেখবে?</h3><p>{say(map.survey.scope)}</p><div className="ops-check"><Camera size={17}/><span>{cameraCount}টি নমুনা camera point পুরো জায়গা দেখে না। তাই আড়ালের জায়গার জন্য জরিপ বা মাঠ পরিদর্শন দরকার।</span></div><p className="ops-muted">{say(map.survey.permission)}</p><div className="ops-action-line"><button className="button-outline" type="button" onClick={onFlightToggle}><Route size={16}/>{showFlight ? 'পথ লুকান' : 'পথ দেখান'}</button><label><input type="checkbox" checked={permission} onChange={event => onPermission(event.target.checked)}/> অনুমতি যাচাই হয়েছে (নমুনা)</label></div><button className="button-dark" type="button" disabled={!permission || surveyComplete} onClick={onSurveyComplete}><ShieldCheck size={16}/>{surveyComplete ? 'নমুনা জরিপ নথিভুক্ত' : 'নমুনা জরিপ সম্পন্ন দেখান'}</button><p className="ops-muted">এটি flight control নয়। বাস্তবে pilot, airspace, property ও privacy approval এবং site safety check লাগবে।</p></section></div>
  </div>
}
