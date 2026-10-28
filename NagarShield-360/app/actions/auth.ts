'use server'

import { redirect } from 'next/navigation'
import { isConfigured, supabaseServer } from '@/src/lib/supabase/server'

export async function signIn(formData: FormData) {
  if (!isConfigured) redirect('/?auth=unavailable#signin')
  const email = String(formData.get('email') || '').trim()
  const password = String(formData.get('password') || '')
  if (!email || !password) redirect('/?auth=missing#signin')
  const supabase = await supabaseServer()
  let signInResult
  try {
    signInResult = await supabase.auth.signInWithPassword({ email, password })
  } catch {
    redirect('/?auth=unavailable#signin')
  }
  if (signInResult.error) redirect(signInResult.error.status === 0 ? '/?auth=unavailable#signin' : '/?auth=invalid#signin')
  const { data: { user }, error: userError } = await supabase.auth.getUser()
  if (userError) redirect('/?auth=unavailable#signin')
  if (!user) redirect('/?auth=invalid#signin')
  const profile = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (profile.error) redirect('/?auth=unavailable#signin')
  if (!profile.data || !['executive','department_head','supervisor','field_employee','survey_operator'].includes(profile.data.role)) {
    await supabase.auth.signOut()
    redirect('/?auth=denied#signin')
  }
  redirect('/dashboard')
}

export async function signOut() {
  if (isConfigured) {
    const supabase = await supabaseServer()
    await supabase.auth.signOut()
  }
  redirect('/')
}
