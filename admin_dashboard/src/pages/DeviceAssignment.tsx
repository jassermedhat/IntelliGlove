import { FormEvent, useEffect, useRef, useState } from 'react';
import { api } from '../api';
import { ErrorBanner } from '../components/ErrorBanner';
import type { AdminUserSummary } from '../types';

type AssignedDevice = {
  id: string;
  userId: string;
  deviceName: string;
  hardwareId: string | null;
  connectionStatus: string;
  createdAt: string;
};

// Inline UserPicker — same pattern as SeedTool, avoids a shared component for now.
function UserPicker({ value, onChange }: { value: string; onChange: (id: string) => void }) {
  const [users, setUsers] = useState<AdminUserSummary[]>([]);
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    api<AdminUserSummary[]>('/admin/users?limit=200')
      .then((res) => setUsers(Array.isArray(res) ? res : []))
      .catch(() => {});
  }, []);

  useEffect(() => {
    function onMouseDown(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener('mousedown', onMouseDown);
    return () => document.removeEventListener('mousedown', onMouseDown);
  }, []);

  const selected = users.find((u) => u.id === value);
  const filtered = query.trim()
    ? users.filter(
        (u) =>
          u.email.toLowerCase().includes(query.toLowerCase()) ||
          u.name.toLowerCase().includes(query.toLowerCase()),
      )
    : users;

  function select(user: AdminUserSummary) {
    onChange(user.id);
    setQuery('');
    setOpen(false);
  }

  const displayValue = selected ? `${selected.name || selected.email} (${selected.email})` : query;

  return (
    <div ref={containerRef} style={{ position: 'relative' }}>
      <div style={{ display: 'flex', gap: 8 }}>
        <input
          type="text"
          placeholder="Search users…"
          value={displayValue}
          required
          onChange={(e) => { setQuery(e.target.value); onChange(''); setOpen(true); }}
          onFocus={() => setOpen(true)}
          style={{ flex: 1 }}
        />
        {value && (
          <button
            type="button"
            className="btn-ghost"
            onClick={() => { onChange(''); setQuery(''); }}
            style={{ flexShrink: 0 }}
          >
            Clear
          </button>
        )}
      </div>
      {open && filtered.length > 0 && (
        <div
          style={{
            position: 'absolute',
            top: '100%',
            left: 0,
            right: 0,
            zIndex: 100,
            background: 'var(--surface, #0d2236)',
            border: '1px solid var(--border, #1e3d52)',
            borderRadius: 8,
            maxHeight: 220,
            overflowY: 'auto',
            marginTop: 4,
          }}
        >
          {filtered.slice(0, 50).map((u) => (
            <div
              key={u.id}
              onMouseDown={() => select(u)}
              style={{ padding: '8px 12px', cursor: 'pointer', borderBottom: '1px solid var(--border, #1e3d52)' }}
            >
              <div style={{ fontWeight: 600, fontSize: 13 }}>{u.name || u.email}</div>
              <div className="muted" style={{ fontSize: 11 }}>
                {u.email} · {u.role}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export function DeviceAssignment() {
  const [userId, setUserId] = useState('');
  const [deviceName, setDeviceName] = useState('');
  const [hardwareId, setHardwareId] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [result, setResult] = useState<AssignedDevice | null>(null);

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!userId) return;
    setBusy(true);
    setError('');
    setResult(null);
    try {
      const device = await api<AssignedDevice>('/admin/devices/assign', {
        method: 'POST',
        body: JSON.stringify({
          userId,
          deviceName: deviceName.trim(),
          hardwareId: hardwareId.trim() || undefined,
        }),
      });
      setResult(device);
      setDeviceName('');
      setHardwareId('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Assignment failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="page">
      <header className="page-header">
        <p className="eyebrow">USER MANAGEMENT</p>
        <h2>Assign Device</h2>
        <p className="muted">
          Create or update a glove device assignment for any user. If a device with the same name
          already exists for that user, the hardware ID is updated in place.
        </p>
      </header>

      <div className="card" style={{ maxWidth: 560 }}>
        <form onSubmit={(e) => void submit(e)}>
          <div className="card-section" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <label>
              Target user
              <UserPicker value={userId} onChange={setUserId} />
            </label>

            <label>
              Device name
              <input
                type="text"
                placeholder="e.g. INTELLIGLOVE DEMO"
                required
                maxLength={100}
                value={deviceName}
                onChange={(e) => setDeviceName(e.target.value)}
              />
            </label>

            <label>
              Hardware ID <span className="muted">(optional)</span>
              <input
                type="text"
                placeholder="MAC address or serial number"
                maxLength={128}
                value={hardwareId}
                onChange={(e) => setHardwareId(e.target.value)}
              />
            </label>
          </div>

          <div className="card-section">
            <button
              type="submit"
              className="btn-primary"
              disabled={!userId || !deviceName.trim() || busy}
            >
              {busy ? 'Assigning…' : 'Assign device'}
            </button>
          </div>

          {error && (
            <div className="card-section">
              <ErrorBanner message={error} />
            </div>
          )}

          {result && (
            <div className="card-section">
              <div className="notice success">
                <strong>Device assigned</strong>
                <div style={{ marginTop: 8, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '4px 16px', fontSize: 12 }}>
                  <span className="muted">Device name</span>
                  <span>{result.deviceName}</span>
                  <span className="muted">Hardware ID</span>
                  <span>{result.hardwareId ?? '—'}</span>
                  <span className="muted">Status</span>
                  <span>{result.connectionStatus}</span>
                  <span className="muted">Device ID</span>
                  <span style={{ fontFamily: 'monospace', fontSize: 11 }}>{result.id.slice(0, 18)}…</span>
                </div>
              </div>
            </div>
          )}
        </form>
      </div>
    </section>
  );
}
