type IconProps = {
  className?: string;
};

export function BrandMark({ className }: IconProps) {
  return (
    <svg viewBox="0 0 32 36" fill="none" className={className} aria-hidden="true">
      <path d="M16 2L30 9.5V24.5L16 32L2 24.5V9.5L16 2Z" stroke="currentColor" strokeWidth="2" fill="none" />
      <path d="M16 8L24 12.5V21.5L16 26L8 21.5V12.5L16 8Z" stroke="currentColor" strokeOpacity="0.42" strokeWidth="1.2" />
      <text x="16" y="21" textAnchor="middle" fill="currentColor" fontSize="9.5" fontWeight="800" fontFamily="system-ui,sans-serif">PM</text>
    </svg>
  );
}

export function DashboardIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><rect x="3" y="3" width="7" height="7" rx="1.5" stroke="currentColor" strokeWidth="1.7" /><rect x="14" y="3" width="7" height="7" rx="1.5" stroke="currentColor" strokeWidth="1.7" /><rect x="3" y="14" width="7" height="7" rx="1.5" stroke="currentColor" strokeWidth="1.7" /><rect x="14" y="14" width="7" height="7" rx="1.5" stroke="currentColor" strokeWidth="1.7" /></svg>;
}

export function UsersIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" /><circle cx="9" cy="7" r="4" stroke="currentColor" strokeWidth="1.7" /><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" /></svg>;
}

export function PeopleIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /><circle cx="9" cy="7" r="4" stroke="currentColor" strokeWidth="1.8" /><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>;
}

export function CartIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" /><line x1="3" y1="6" x2="21" y2="6" stroke="currentColor" strokeWidth="1.8" /><path d="M16 10a4 4 0 0 1-8 0" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>;
}

export function DollarIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><line x1="12" y1="1" x2="12" y2="23" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>;
}

export function TrendUpIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><polyline points="23,6 13.5,15.5 8.5,10.5 1,18" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /><polyline points="17,6 23,6 23,12" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /></svg>;
}

export function ArrowUpSmallIcon({ className }: IconProps) {
  return <svg viewBox="0 0 12 12" fill="none" className={className} aria-hidden="true"><polyline points="2,9 6,3 10,9" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /></svg>;
}

export function RefreshIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><polyline points="23,4 23,11 16,11" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /><polyline points="1,20 1,13 8,13" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 11M1 13l4.64 5.36A9 9 0 0 0 20.49 15" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" /></svg>;
}

export function UserRegisterIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" /><circle cx="12" cy="7" r="4" stroke="currentColor" strokeWidth="1.6" /></svg>;
}

export function CancelCircleIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="1.6" /><line x1="15" y1="9" x2="9" y2="15" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" /><line x1="9" y1="9" x2="15" y2="15" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" /></svg>;
}

export function TemplatesIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><path d="M3 8.5A2.5 2.5 0 0 1 5.5 6H9l1.9 2H18.5A2.5 2.5 0 0 1 21 10.5v7A2.5 2.5 0 0 1 18.5 20h-13A2.5 2.5 0 0 1 3 17.5v-9Z" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" /><path d="M7.5 12h9M7.5 15.5h6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" /></svg>;
}

export function ImageIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><rect x="3" y="3" width="18" height="18" rx="2.5" stroke="currentColor" strokeWidth="1.7" /><circle cx="8.5" cy="8.5" r="1.5" stroke="currentColor" strokeWidth="1.5" /><path d="M21 15l-5-5L5 21" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" /></svg>;
}

export function VideoIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><polygon points="23,7 16,12 23,17" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" /><rect x="1" y="5" width="15" height="14" rx="2.5" stroke="currentColor" strokeWidth="1.7" /></svg>;
}

export function LogoutIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" /><polyline points="16,17 21,12 16,7" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" /><line x1="21" y1="12" x2="9" y2="12" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" /></svg>;
}

export function MenuIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><line x1="3" y1="6" x2="21" y2="6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" /><line x1="3" y1="12" x2="21" y2="12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" /><line x1="3" y1="18" x2="21" y2="18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" /></svg>;
}

export function GlobeIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="1.6" /><path d="M12 2C8 6 8 12 8 12C8 18 12 22 12 22" stroke="currentColor" strokeWidth="1.6" /><path d="M12 2C16 6 16 12 16 12C16 18 12 22 12 22" stroke="currentColor" strokeWidth="1.6" /><path d="M2 12H22M4 7H20M4 17H20" stroke="currentColor" strokeWidth="1.4" /></svg>;
}

export function CaretDownIcon({ className }: IconProps) {
  return <svg viewBox="0 0 12 8" fill="none" className={className} aria-hidden="true"><path d="M1 1L6 7L11 1" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>;
}

export function PlusIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><line x1="12" y1="5" x2="12" y2="19" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /><line x1="5" y1="12" x2="19" y2="12" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>;
}

export function PencilIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><path d="M17.5 3.5a2.12 2.12 0 1 1 3 3L8 19l-4 1 1-4 12.5-12.5Z" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" /><path d="m14 7 3 3" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" /></svg>;
}

export function ChartIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><path d="M4 20V10" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /><path d="M10 20V4" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /><path d="M16 20v-7" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /><path d="M22 20v-3" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /><path d="M2 20h20" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" /></svg>;
}

export function PlayCircleIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.7" /><path d="M10 8.8c0-.58.64-.94 1.14-.62l4.85 3.2a.74.74 0 0 1 0 1.24l-4.85 3.2A.74.74 0 0 1 10 15.2V8.8Z" fill="currentColor" /></svg>;
}

export function CalendarIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><rect x="3" y="5" width="18" height="16" rx="2.5" stroke="currentColor" strokeWidth="1.7" /><path d="M8 3v4M16 3v4M3 10h18" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" /></svg>;
}

export function ClockIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.7" /><path d="M12 7v5l3 2" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" /></svg>;
}

export function DownloadIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><path d="M12 3v11" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /><path d="m8 10 4 4 4-4" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /><path d="M4 20h16" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>;
}

export function TableIcon({ className }: IconProps) {
  return <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true"><rect x="3" y="4" width="18" height="16" rx="2" stroke="currentColor" strokeWidth="1.7" /><path d="M3 10h18M9 4v16M15 4v16" stroke="currentColor" strokeWidth="1.5" /></svg>;
}
