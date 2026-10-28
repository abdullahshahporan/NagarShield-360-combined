import Link from 'next/link'
import { Activity, Bell, ChartNoAxesCombined, ClipboardList, FileScan, LayoutDashboard, LogOut, MapPinned, ShieldCheck, ScanSearch, UsersRound, Workflow } from 'lucide-react'
import { signOut } from '@/app/actions/auth'
import { roleLabels } from '@/src/lib/demo'
import type { OfficialProfile } from '@/src/lib/types'

const nav = [
  { href: '/dashboard', label: 'সারসংক্ষেপ', Icon: LayoutDashboard },
  { href: '/incidents', label: 'ঘটনা ও যাচাই', Icon: Activity },
  { href: '/map', label: 'কমান্ড মানচিত্র', Icon: MapPinned },
  { href: '/operations', label: 'সমন্বিত অপারেশন', Icon: Workflow },
  { href: '/analysis', label: 'রিয়েলটাইম অ্যানালাইসিস', Icon: FileScan },
  { href: '/surveys', label: 'ড্রোন ও সংকীর্ণ স্থান', Icon: ScanSearch },
  { href: '/tasks', label: 'কাজের তালিকা', Icon: ClipboardList },
  { href: '/reports', label: 'প্রতিবেদন', Icon: ChartNoAxesCombined },
  { href: '/governance', label: 'বিভাগ ও অনুমতি', Icon: UsersRound },
]

export function OfficialShell({ profile, notifications, children }: { profile: OfficialProfile; notifications: { id: number; text_bn: string }[]; children: React.ReactNode }) {
  const links = profile.role === 'survey_operator' ? nav.filter(item => item.href === '/surveys')
    : profile.role === 'field_employee' ? nav.filter(item => ['/dashboard','/tasks','/incidents','/operations'].includes(item.href))
    : profile.role === 'supervisor' ? nav.filter(item => !['/governance','/analysis','/surveys'].includes(item.href)) : nav
  return <div className="official-app">
    <aside className="official-sidebar">
      <Link className="official-brand" href={profile.role === 'survey_operator' ? '/surveys' : '/dashboard'}><span className="official-mark"><ShieldCheck size={23} /></span><span>Nagar Shield <b>360</b><small>অফিসিয়াল ডেমো</small></span></Link>
      <div className="sidebar-label">কর্মক্ষেত্র</div>
      <nav className="official-nav" aria-label="অফিসিয়াল নেভিগেশন">{links.map(({ href, label, Icon }) => <Link key={href} href={href}><Icon size={18} strokeWidth={1.8} />{label}</Link>)}</nav>
      <div className="sidebar-bottom"><div className="sidebar-profile"><div className="avatar">{profile.display_name.slice(0,1)}</div><div><strong>{profile.display_name}</strong><span>{roleLabels[profile.role]}</span></div></div><form action={signOut}><button type="submit" className="sidebar-signout"><LogOut size={17} /> সাইন আউট</button></form></div>
    </aside>
    <div className="official-main">
      <header className="official-topbar"><div className="mobile-brand">Nagar Shield <b>360</b></div><div className="topbar-right"><span className="demo-indicator">● ডেমো তথ্য</span><details className="notification-menu"><summary className="notification-badge" aria-label={`ডেমো বিজ্ঞপ্তি ${notifications.length}টি`}><Bell size={18} /><span>{notifications.length}</span></summary><div className="notification-popover"><strong>ডেমো বিজ্ঞপ্তি</strong>{notifications.length ? notifications.map(item => <p key={item.id}>{item.text_bn}</p>) : <p>নতুন বিজ্ঞপ্তি নেই।</p>}<small>বিজ্ঞপ্তিগুলো শুধু এই অ্যাপে দেখা যায়; ইমেইল বা ফোনে পাঠানো হয় না।</small></div></details><div className="topbar-user">{profile.display_name}</div></div></header>
      <main className="official-content">{children}</main>
      <nav className="mobile-official-nav" aria-label="মোবাইল নেভিগেশন">{links.map(({ href,label,Icon }) => <Link href={href} key={href}><Icon size={19}/><span>{label}</span></Link>)}</nav>
    </div>
  </div>
}
