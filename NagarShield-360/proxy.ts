import { NextResponse, type NextRequest } from 'next/server'
import { createServerClient } from '@supabase/ssr'

export async function proxy(request: NextRequest) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  if (!url || !key) {
    if (request.nextUrl.pathname.startsWith('/api/')) return new NextResponse('Unauthorized', { status: 401 })
    return NextResponse.redirect(new URL('/?auth=unavailable', request.url))
  }
  let response = NextResponse.next({ request })
  const supabase = createServerClient(url, key, {
    cookies: {
      getAll() { return request.cookies.getAll() },
      setAll(values) {
        values.forEach(({ name, value }) => request.cookies.set(name, value))
        response = NextResponse.next({ request })
        values.forEach(({ name, value, options }) => response.cookies.set(name, value, options))
      },
    },
  })
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) {
    if (request.nextUrl.pathname.startsWith('/api/')) return new NextResponse('Unauthorized', { status: 401 })
    return NextResponse.redirect(new URL('/?auth=required', request.url))
  }
  response.headers.set('Cache-Control', 'private, no-store')
  return response
}

export const config = { matcher: ['/dashboard/:path*','/map/:path*','/operations/:path*','/incidents/:path*','/analysis/:path*','/surveys/:path*','/tasks/:path*','/reports/:path*','/governance/:path*','/api/media/:path*','/api/reports/:path*'] }
