type StatusVariant =
  | 'on' | 'off'
  | 'available' | 'invalid' | 'archived'
  | 'open' | 'reviewed' | 'resolved' | 'dismissed'
  | 'active' | 'disabled'
  | 'connected' | 'disconnected'
  | string;

const GOOD = new Set(['on', 'available', 'resolved', 'active', 'connected']);
const WARN = new Set(['reviewed', 'archived', 'scanning', 'connecting']);
const BAD  = new Set(['off', 'invalid', 'open', 'disabled', 'disconnected', 'error']);

export function StatusPill({ value }: { value: StatusVariant }) {
  const cls = GOOD.has(value) ? 'good' : WARN.has(value) ? 'warn' : BAD.has(value) ? 'bad' : '';
  return <span className={`pill ${cls}`}>{value}</span>;
}
