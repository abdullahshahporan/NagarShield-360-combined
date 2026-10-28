import { requireOfficial } from '@/src/lib/supabase/server'
import { OfficialShell } from '@/src/components/OfficialShell'
import 'leaflet/dist/leaflet.css'
import '../official.css'
import '../monitor.css'

export const dynamic = 'force-dynamic'

export default async function OfficialLayout({ children }: { children: React.ReactNode }) {
  const { supabase, profile } = await requireOfficial()
  const { data } = await supabase.from('notifications').select('id,text_bn').eq('recipient_id', profile.id).is('read_at', null).order('created_at', { ascending: false }).limit(5)
  return <OfficialShell profile={profile} notifications={data || []}>{children}</OfficialShell>
}
