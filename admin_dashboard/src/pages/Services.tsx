import { useState } from 'react';
import type { AdminConfig } from '../types';
import { api } from '../api';
import { ErrorBanner } from '../components/ErrorBanner';

const SERVICE_META: Record<string, { label: string; description: string }> = {
  translation:  { label: 'Translation',     description: 'Live gesture translation pipeline and session management' },
  healthMonitor:{ label: 'Health Monitor',  description: 'Biometric sensor readings and health data display' },
  smartHouse:   { label: 'Smart House',     description: 'Gesture-controlled smart home device integration' },
  analytics:    { label: 'Analytics',       description: 'Usage metrics, session charts, and gesture statistics' },
  practiceMode: { label: 'Practice Mode',   description: 'Guided sign-language practice drills and scoring' },
  feedback:     { label: 'Feedback',        description: 'In-app bug reports and user feedback submission' },
  devices:      { label: 'Devices',         description: 'Glove device pairing, provisioning, and management' },
  firmware:     { label: 'Firmware',        description: 'OTA firmware version checking for connected gloves' },
};

export function Services({
  config,
  reload,
}: {
  config: AdminConfig;
  reload: () => Promise<void>;
}) {
  const [busyKey, setBusyKey] = useState('');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  async function toggle(key: string, value: boolean) {
    setBusyKey(key);
    setError('');
    setNotice('');
    try {
      await api('/admin/config/service-toggles', {
        method: 'PATCH',
        body: JSON.stringify({ serviceToggles: { [key]: value } }),
      });
      await reload();
      setNotice(`${SERVICE_META[key]?.label ?? key} ${value ? 'enabled' : 'disabled'}.`);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update service.');
    } finally {
      setBusyKey('');
    }
  }

  const entries = Object.entries(config.serviceToggles).sort(([a], [b]) => a.localeCompare(b));

  return (
    <section className="page">
      <header className="page-header">
        <p className="eyebrow">FEATURE AVAILABILITY</p>
        <h2>Service Management</h2>
        <p className="muted">
          Disabled services return <code>503 SERVICE_DISABLED</code> to mobile clients. Toggles
          take effect immediately with no restart required.
        </p>
      </header>

      {error && <ErrorBanner message={error} />}
      {notice && <div className="notice success">{notice}</div>}

      <div className="card">
        <table className="data-table">
          <thead>
            <tr>
              <th>Service</th>
              <th>Description</th>
              <th style={{ textAlign: 'center', width: 100 }}>Status</th>
              <th style={{ width: 110 }} />
            </tr>
          </thead>
          <tbody>
            {entries.map(([key, enabled]) => {
              const meta = SERVICE_META[key];
              return (
                <tr key={key} className={!enabled ? 'row-muted' : ''}>
                  <td>
                    <strong>{meta?.label ?? key}</strong>
                    <div style={{ fontFamily: 'monospace', fontSize: 11, opacity: 0.5, marginTop: 2 }}>
                      {key}
                    </div>
                  </td>
                  <td className="muted" style={{ fontSize: 13 }}>
                    {meta?.description ?? '—'}
                  </td>
                  <td style={{ textAlign: 'center' }}>
                    <span className={`pill ${enabled ? 'good' : 'bad'}`}>
                      {enabled ? 'Enabled' : 'Disabled'}
                    </span>
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <button
                      className={enabled ? 'btn-danger' : 'btn-primary'}
                      style={{ fontSize: 12, padding: '5px 14px' }}
                      disabled={busyKey === key}
                      onClick={() => void toggle(key, !enabled)}
                    >
                      {busyKey === key ? '…' : enabled ? 'Disable' : 'Enable'}
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </section>
  );
}
