import { FormEvent, useEffect, useRef, useState } from 'react';
import { api } from '../api';
import { ErrorBanner } from '../components/ErrorBanner';
import type { AdminUserSummary, DemoGloveState } from '../types';

const SEED_TARGETS: { id: string; label: string; description: string }[] = [
  { id: 'healthMonitor',     label: 'Health Monitor',   description: 'Biometric readings with random vitals' },
  { id: 'smartHouse',        label: 'Smart House',      description: '4 sample smart devices with gesture mappings' },
  { id: 'analytics',         label: 'Analytics',        description: 'Weekly gesture and accuracy metrics' },
  { id: 'practiceMode',      label: 'Practice Mode',    description: 'Practice session results for "Hello" sign' },
  { id: 'translationHistory',label: 'Translation History', description: 'Closed session with letter-by-letter entries' },
];

// ── UserPicker combobox (Issue 1) ─────────────────────────────────────────────
function UserPicker({ value, onChange }: { value: string; onChange: (id: string) => void }) {
  const [users, setUsers] = useState<AdminUserSummary[]>([]);
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    api<AdminUserSummary[]>('/admin/users?limit=200').then((res) => {
      setUsers(Array.isArray(res) ? res : []);
    }).catch(() => {});
  }, []);

  // Close dropdown when clicking outside.
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

  function clear() {
    onChange('');
    setQuery('');
  }

  const displayValue = selected
    ? `${selected.name || selected.email} (${selected.email})`
    : query;

  return (
    <div ref={containerRef} style={{ position: 'relative' }}>
      <div style={{ display: 'flex', gap: 8 }}>
        <input
          type="text"
          placeholder="Search users… (defaults to admin account)"
          value={displayValue}
          onChange={(e) => { setQuery(e.target.value); onChange(''); setOpen(true); }}
          onFocus={() => setOpen(true)}
          style={{ flex: 1 }}
        />
        {value && (
          <button type="button" className="btn-ghost" onClick={clear} style={{ flexShrink: 0 }}>
            Clear
          </button>
        )}
      </div>
      {open && (filtered.length > 0 || query.trim()) && (
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
          {filtered.length === 0 ? (
            <div style={{ padding: '10px 12px', fontSize: 13, color: 'var(--muted, #6b8fa8)' }}>
              No users found
            </div>
          ) : (
            filtered.slice(0, 50).map((u) => (
              <div
                key={u.id}
                onMouseDown={() => select(u)}
                style={{
                  padding: '8px 12px',
                  cursor: 'pointer',
                  borderBottom: '1px solid var(--border, #1e3d52)',
                  overflow: 'hidden',
                }}
              >
                <div style={{ fontWeight: 600, fontSize: 13, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {u.name || u.email}
                </div>
                <div className="muted" style={{ fontSize: 11, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {u.email} · {u.role}
                </div>
              </div>
            ))
          )}
        </div>
      )}
    </div>
  );
}

export function SeedTool() {
  const [selected, setSelected] = useState<string[]>([]);
  const [count, setCount] = useState(10);
  const [userId, setUserId] = useState('');
  const [useTestingUser, setUseTestingUser] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [result, setResult] = useState<{ userId: string; inserted: Record<string, number> } | null>(null);
  const [demoGlove, setDemoGlove] = useState<DemoGloveState | null>(null);
  const [demoGloveBusy, setDemoGloveBusy] = useState(false);
  const [demoGloveError, setDemoGloveError] = useState('');

  // Wipe section state
  const [wipeUserId, setWipeUserId] = useState('');
  const [wipeUseTestingUser, setWipeUseTestingUser] = useState(true);
  const [wipeBusy, setWipeBusy] = useState(false);
  const [wipeError, setWipeError] = useState('');
  const [wipeResult, setWipeResult] = useState<{ userId: string; deleted: Record<string, number> } | null>(null);
  const [wipeConfirm, setWipeConfirm] = useState(false);

  async function loadDemoGlove() {
    try {
      setDemoGlove(await api<DemoGloveState>('/admin/testing/demo-glove'));
      setDemoGloveError('');
    } catch (err) {
      setDemoGloveError(err instanceof Error ? err.message : 'Failed to load demo glove state.');
    }
  }

  useEffect(() => {
    void loadDemoGlove();
  }, []);

  async function toggleDemoGlove() {
    setDemoGloveBusy(true);
    setDemoGloveError('');
    try {
      setDemoGlove(await api<DemoGloveState>('/admin/testing/demo-glove', {
        method: 'PATCH',
        body: JSON.stringify({ connected: !demoGlove?.connected }),
      }));
    } catch (err) {
      setDemoGloveError(err instanceof Error ? err.message : 'Failed to update demo glove.');
    } finally {
      setDemoGloveBusy(false);
    }
  }

  function toggle(id: string, checked: boolean) {
    setSelected((prev) => checked ? [...prev, id] : prev.filter((v) => v !== id));
  }

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (selected.length === 0) return;
    setBusy(true);
    setError('');
    setResult(null);
    try {
      const res = await api<{ userId: string; inserted: Record<string, number> }>('/admin/seed', {
        method: 'POST',
        body: JSON.stringify({
          targets: selected,
          count,
          useTestingUser: useTestingUser || undefined,
          userId: useTestingUser ? undefined : (userId.trim() || undefined),
        }),
      });
      setResult(res);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Seed failed.');
    } finally {
      setBusy(false);
    }
  }

  async function wipe() {
    setWipeBusy(true);
    setWipeError('');
    setWipeResult(null);
    setWipeConfirm(false);
    try {
      const res = await api<{ userId: string; deleted: Record<string, number> }>('/admin/seed/wipe', {
        method: 'POST',
        body: JSON.stringify({
          useTestingUser: wipeUseTestingUser || undefined,
          userId: wipeUseTestingUser ? undefined : (wipeUserId.trim() || undefined),
        }),
      });
      setWipeResult(res);
    } catch (err) {
      setWipeError(err instanceof Error ? err.message : 'Wipe failed.');
    } finally {
      setWipeBusy(false);
    }
  }

  const total = result
    ? Object.values(result.inserted).reduce((sum, n) => sum + n, 0)
    : 0;
  const wipeTotal = wipeResult
    ? Object.values(wipeResult.deleted).reduce((sum, n) => sum + n, 0)
    : 0;

  return (
    <section className="page">
      <header className="page-header">
        <p className="eyebrow">DEMO TOOLING</p>
        <h2>Seed Demo Data</h2>
        <p className="muted">
          Populate the PostgreSQL database with realistic demo records. Use this to quickly
          demonstrate features without a live glove. Data is tagged <code>source="mock_seed"</code>.
        </p>
      </header>

      <div className="card seed-card" style={{ marginBottom: 24 }}>
        <div
          className="card-section seed-glove-section"
          style={{
            display: 'flex',
            flexWrap: 'nowrap',
            alignItems: 'flex-start',
            justifyContent: 'space-between',
            gap: 16,
          }}
        >
          <div style={{ flex: '1 1 auto', minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 6 }}>
              <h3 style={{ margin: 0 }}>Mobile Demo Glove</h3>
              <span className={`pill ${demoGlove?.connected ? 'good' : 'bad'}`}>
                {demoGlove?.connected ? 'Connected' : 'Disconnected'}
              </span>
            </div>
            <p className="muted" style={{ margin: 0, maxWidth: 560 }}>
              Makes the mobile testing account see <strong>INTELLIGLOVE DEMO</strong> as a real
              backend-connected glove. The mobile app synchronizes the state automatically.
            </p>
            {demoGlove?.device && (
              <p className="muted" style={{ margin: '8px 0 0', fontSize: 12 }}>
                Battery {demoGlove.device.batteryLevel ?? 0}% · Signal {demoGlove.device.signalStrength ?? 0}/5 · Firmware {demoGlove.device.firmwareVersion ?? '—'}
              </p>
            )}
          </div>
          <button
            className={demoGlove?.connected ? 'btn-danger' : 'btn-primary'}
            disabled={!demoGlove || demoGloveBusy}
            onClick={() => void toggleDemoGlove()}
            style={{ flexShrink: 0, minWidth: 190, textAlign: 'center' }}
          >
            {demoGloveBusy
              ? 'Updating…'
              : demoGlove?.connected
                ? 'Disconnect demo glove'
                : 'Connect demo glove'}
          </button>
        </div>
        {demoGloveError && (
          <div className="card-section">
            <ErrorBanner message={demoGloveError} onRetry={() => void loadDemoGlove()} />
          </div>
        )}
      </div>

      <div className="card seed-card">
        <form onSubmit={(e) => void submit(e)}>
          <div className="card-section">
            <h4 style={{ margin: '0 0 14px' }}>Select targets</h4>
            <div className="seed-targets">
              {SEED_TARGETS.map(({ id, label, description }) => (
                <label key={id} className={`seed-target ${selected.includes(id) ? 'selected' : ''}`}>
                  <input
                    type="checkbox"
                    checked={selected.includes(id)}
                    onChange={(e) => toggle(id, e.target.checked)}
                  />
                  <div>
                    <strong>{label}</strong>
                    <div className="muted" style={{ fontSize: 12, marginTop: 2 }}>{description}</div>
                  </div>
                </label>
              ))}
            </div>
          </div>

          <div className="card-section">
            <label style={{ maxWidth: 200 }}>
              Records per target
              <input
                type="number"
                min={1}
                max={100}
                value={count}
                onChange={(e) => setCount(Math.max(1, Math.min(100, Number(e.target.value))))}
              />
            </label>
          </div>

          <div className="card-section">
            <h4 style={{ margin: '0 0 12px' }}>Target account</h4>
            <div className="seed-account-grid">
              <label className={`seed-target seed-account-card${useTestingUser ? ' selected' : ''}`}>
                <div className="seed-account-row">
                  <input
                    type="radio"
                    name="targetAccount"
                    checked={useTestingUser}
                    onChange={() => { setUseTestingUser(true); setUserId(''); }}
                  />
                  <div>
                    <strong>Mobile Demo Account</strong>
                    <div className="muted" style={{ fontSize: 12, marginTop: 4 }}>
                      testing@intelliglove.local
                    </div>
                    <div className="muted" style={{ fontSize: 12, marginTop: 2 }}>
                      Login: <code>testing</code> / <code>1234</code>
                    </div>
                  </div>
                </div>
              </label>

              <label className={`seed-target seed-account-card${!useTestingUser ? ' selected' : ''}`}>
                <div className="seed-account-row">
                  <input
                    type="radio"
                    name="targetAccount"
                    checked={!useTestingUser}
                    onChange={() => setUseTestingUser(false)}
                  />
                  <div>
                    <strong>Other user</strong>
                    <div className="muted" style={{ fontSize: 12, marginTop: 2 }}>
                      Select any registered account
                    </div>
                  </div>
                </div>
                {!useTestingUser && (
                  <UserPicker value={userId} onChange={setUserId} />
                )}
              </label>
            </div>
          </div>

          <div className="card-section" style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            <button
              type="submit"
              className="btn-primary"
              disabled={selected.length === 0 || busy}
            >
              {busy ? 'Seeding…' : `Push demo data (${selected.length} target${selected.length !== 1 ? 's' : ''})`}
            </button>
            {selected.length > 0 && (
              <button
                type="button"
                className="btn-ghost"
                onClick={() => setSelected([])}
              >
                Clear selection
              </button>
            )}
          </div>

          {error && <ErrorBanner message={error} />}

          {result && (
            <div className="notice success">
              <strong>✓ Inserted {total} records</strong> for user <code>{result.userId.slice(0, 18)}…</code>
              <div style={{ marginTop: 8, display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                {Object.entries(result.inserted).map(([target, n]) => (
                  <span key={target} className="pill good">
                    {target}: {n}
                  </span>
                ))}
              </div>
            </div>
          )}
        </form>
      </div>

      <div className="card seed-card" style={{ marginTop: 24 }}>
        <div className="card-section">
          <h3 style={{ margin: '0 0 6px', color: 'var(--danger, #e05260)' }}>Wipe Demo Data</h3>
          <p className="muted" style={{ margin: 0 }}>
            Delete <strong>only</strong> demo records tagged <code>source="mock_seed"</code> for the selected
            user. Real user-created data is never touched.
          </p>
        </div>

        <div className="card-section">
          <h4 style={{ margin: '0 0 12px' }}>Target account</h4>
          <div className="seed-account-grid">
            <label className={`seed-target seed-account-card${wipeUseTestingUser ? ' selected' : ''}`}>
              <div className="seed-account-row">
                <input
                  type="radio"
                  name="wipeAccount"
                  checked={wipeUseTestingUser}
                  onChange={() => { setWipeUseTestingUser(true); setWipeUserId(''); }}
                />
                <div>
                  <strong>Mobile Demo Account</strong>
                  <div className="muted" style={{ fontSize: 12, marginTop: 4 }}>testing@intelliglove.local</div>
                </div>
              </div>
            </label>

            <label className={`seed-target seed-account-card${!wipeUseTestingUser ? ' selected' : ''}`}>
              <div className="seed-account-row">
                <input
                  type="radio"
                  name="wipeAccount"
                  checked={!wipeUseTestingUser}
                  onChange={() => setWipeUseTestingUser(false)}
                />
                <div>
                  <strong>Other user</strong>
                  <div className="muted" style={{ fontSize: 12, marginTop: 2 }}>Select any registered account</div>
                </div>
              </div>
              {!wipeUseTestingUser && (
                <UserPicker value={wipeUserId} onChange={setWipeUserId} />
              )}
            </label>
          </div>
        </div>

        <div className="card-section" style={{ display: 'flex', alignItems: 'center', gap: 16, flexWrap: 'wrap' }}>
          {!wipeConfirm ? (
            <button
              className="btn-danger"
              disabled={wipeBusy || (!wipeUseTestingUser && !wipeUserId)}
              onClick={() => setWipeConfirm(true)}
            >
              Wipe Demo Data
            </button>
          ) : (
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
              <span style={{ fontSize: 13, color: 'var(--danger, #e05260)', fontWeight: 600 }}>
                This will permanently delete all demo data for the selected user. Confirm?
              </span>
              <button
                className="btn-danger"
                disabled={wipeBusy}
                onClick={() => void wipe()}
              >
                {wipeBusy ? 'Wiping…' : 'Yes, wipe it'}
              </button>
              <button
                className="btn-ghost"
                onClick={() => setWipeConfirm(false)}
              >
                Cancel
              </button>
            </div>
          )}
        </div>

        {wipeError && (
          <div className="card-section">
            <ErrorBanner message={wipeError} />
          </div>
        )}

        {wipeResult && (
          <div className="card-section">
            <div className="notice success">
              <strong>✓ Wiped {wipeTotal} demo records</strong> for user{' '}
              <code>{wipeResult.userId.slice(0, 18)}…</code>
              <div style={{ marginTop: 8, display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                {Object.entries(wipeResult.deleted).map(([target, n]) => (
                  <span key={target} className={`pill ${n > 0 ? 'good' : ''}`}>
                    {target}: {n}
                  </span>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>

      <div className="notice" style={{ marginTop: 16 }}>
        <strong>Note:</strong> SOS alerts are intentionally unavailable as a seed target. Session
        history data also writes a companion JSON file to the translation output directory.
      </div>
    </section>
  );
}