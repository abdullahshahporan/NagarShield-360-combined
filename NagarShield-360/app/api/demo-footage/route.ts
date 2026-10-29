import { open, stat } from 'node:fs/promises'
import { join } from 'node:path'
import { NextResponse, type NextRequest } from 'next/server'
import { requireOfficial } from '@/src/lib/supabase/server'

export const runtime = 'nodejs'
const filePath = join(process.cwd(), 'Video', 'Facebook.mp4')

export async function GET(request: NextRequest) {
  const { profile } = await requireOfficial()
  if (!['executive', 'department_head'].includes(profile.role)) return new NextResponse('Forbidden', { status: 403 })
  let size: number
  try { size = (await stat(filePath)).size }
  catch { return new NextResponse('Demo video unavailable', { status: 404 }) }

  const range = request.headers.get('range')
  const match = range?.match(/^bytes=(\d+)-(\d*)$/)
  if (range && !match) return new NextResponse(null, { status: 416, headers: { 'Content-Range': `bytes */${size}` } })
  const start = match ? Number(match[1]) : 0
  const end = match && match[2] ? Number(match[2]) : size - 1
  if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start > end || end >= size) {
    return new NextResponse(null, { status: 416, headers: { 'Content-Range': `bytes */${size}` } })
  }
  const file = await open(filePath, 'r')
  let position = start
  const body = new ReadableStream<Uint8Array>({
    async pull(controller) {
      const buffer = Buffer.allocUnsafe(Math.min(256 * 1024, end - position + 1))
      const { bytesRead } = await file.read(buffer, 0, buffer.length, position)
      if (!bytesRead) { await file.close(); controller.close(); return }
      position += bytesRead
      controller.enqueue(buffer.subarray(0, bytesRead))
      if (position > end) { await file.close(); controller.close() }
    },
    async cancel() { await file.close().catch(() => undefined) },
  })
  return new NextResponse(body, { status: match ? 206 : 200, headers: {
    'Content-Type': 'video/mp4', 'Content-Length': String(end - start + 1),
    'Accept-Ranges': 'bytes', 'Cache-Control': 'private, no-store',
    'X-Content-Type-Options': 'nosniff',
    ...(match ? { 'Content-Range': `bytes ${start}-${end}/${size}` } : {}),
  } })
}
