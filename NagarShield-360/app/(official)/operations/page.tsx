import { redirect } from 'next/navigation'
import Link from 'next/link'
import { DemoNote, PageHeading } from '@/src/components/Ui'
import { OperationsLab } from '@/src/components/OperationsLab'
import { requireOfficial } from '@/src/lib/supabase/server'

export default async function OperationsPage() {
  const { profile } = await requireOfficial()
  if (profile.role === 'survey_operator') redirect('/surveys')
  return <>
    <PageHeading kicker="পরিকল্পনার অনুশীলন" title="সমন্বিত অপারেশন" description="বিচ্ছিন্ন খবর থেকে কারণ, অগ্রাধিকার, সমন্বিত কাজ ও ফল যাচাই—পুরো সিদ্ধান্তের পথ দেখুন।" action={<Link href="/incidents" className="button-outline">মোবাইল প্রতিবেদন দেখুন</Link>}/>
    <DemoNote>এখানে সব দৃশ্য ও সিদ্ধান্ত স্থানীয় dummy rehearsal। বাস্তব ঘটনা ও দায়িত্বের জন্য ঘটনা কেন্দ্র এবং কাজের তালিকা ব্যবহার করুন।</DemoNote>
    <OperationsLab/>
  </>
}
