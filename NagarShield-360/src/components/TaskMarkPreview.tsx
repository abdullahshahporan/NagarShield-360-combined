import { PrivateMedia } from './PrivateMedia'

export function TaskMarkPreview({ note, mediaKey }: { note: string | null; mediaKey: string | null }) {
  if (!note || !mediaKey) return null
  const match = note.match(/চিহ্নিত অংশ: বাম (\d+)%, উপর (\d+)%, প্রস্থ (\d+)%, উচ্চতা (\d+)%/)
  if (!match) return null
  const [x, y, w, h] = match.slice(1).map(value => Math.max(0, Math.min(100, Number(value))))
  return <figure className="task-mark-figure"><div className="task-mark-image"><PrivateMedia mediaKey={mediaKey} alt="কর্মকর্তার চিহ্ন দেওয়া নমুনা দৃশ্য" controls/><span className="task-mark-box" style={{ left: `${x}%`, top: `${y}%`, width: `${Math.min(w, 100 - x)}%`, height: `${Math.min(h, 100 - y)}%` }}><small>চিহ্নিত কাজ</small></span></div><figcaption>কর্মকর্তা এই অংশে কাজ চিহ্নিত করেছেন। ভিডিও হলে সময়টি কাজের বিবরণে আছে।</figcaption></figure>
}
