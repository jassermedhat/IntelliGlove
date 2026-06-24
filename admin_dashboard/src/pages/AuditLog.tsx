import { useState } from 'react';
import type { AuditLog } from '../types';
import { useApi } from '../hooks/useApi';
import { PageSpinner } from '../components/Spinner';
import { ErrorBanner } from '../components/ErrorBanner';
import { EmptyState } from '../components/EmptyState';

const ACTION_ICONS: Record<string, string> = {
  'system.status.update': '⚡',
  'services.update':      '⚙',
  'models.scan':          '🔍',
  'model.activate':       '✅',
  'data.seed':            '🌱',
  'report.update':        '📝',
  'admin.login_sync':     '🔑',
  'admin.seed':           '🛠',
};

function fmtTime(iso: string) {
  return new Date(iso).toLocaleString(undefined, {
    month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit', second: '2-digit',
  });
}

function truncate(s: string, n = 36) {
  return s.length > n ? s.slice(0, n) + '…' : s;
}

export function AuditLog() {
  const [limit, setLimit] = useState(100);
  const { state, reload } = useApi<AuditLog[]>(`/admin/audit?limit=${limit}`, [limit]);

  return (
    <section className="page">
      <header className="page-header">
        <p className="eyebrow">SECURITY &amp; COMPLIANCE</p>
        <h2>Audit Log</h2>
        <p className="muted">
          Every administrative action is recorded here. Entries are append-only and cannot be
          deleted.
        </p>
      </header>

      <div className="filter-row">
        <span className="muted" style={{ fontSize: 13 }}>Show last:</span>
        {[25, 50, 100, 200].map((n) => (
          <button
            key={n}
            className={`btn-chip ${limit === n ? 'btn-chip-active' : ''}`}
            onClick={() => setLimit(n)}
          >
            {n}
          </button>
        ))}
        <button className="btn-ghost" style={{ marginLeft: 'auto' }} onClick={() => void reload()}>
          ↻ Refresh
        </button>
      </div>

      {state.status === 'loading' && <PageSpinner />}
      {state.status === 'error' && (
        <ErrorBanner message={state.message} onRetry={() => void reload()} />
      )}
      {state.status === 'success' && state.data.length === 0 && (
        <EmptyState
          icon="📋"
          title="No audit entries yet"
          message="Admin actions will appear here as they happen."
        />
      )}
      {state.status === 'success' && state.data.length > 0 && (
        <div className="card">
          <table className="data-table">
            <thead>
              <tr>
                <th style={{ width: 32 }} />
                <th>Action</th>
                <th>Target</th>
                <th>Details</th>
                <th>Actor</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              {state.data.map((log) => (
                <tr key={log.id}>
                  <td style={{ textAlign: 'center', fontSize: 16 }}>
                    {ACTION_ICONS[log.action] ?? '•'}
                  </td>
                  <td>
                    <code className="action-code">{log.action}</code>
                  </td>
                  <td className="muted" style={{ fontSize: 12 }}>
                    {log.targetType && (
                      <span style={{ textTransform: 'uppercase', letterSpacing: '.05em', opacity: .7 }}>
                        {log.targetType}
                      </span>
                    )}
                    {log.targetId && (
                      <div style={{ fontFamily: 'monospace', opacity: .55, marginTop: 2 }}>
                        {truncate(log.targetId, 28)}
                      </div>
                    )}
                  </td>
                  <td className="muted" style={{ fontSize: 12, maxWidth: 220 }}>
                    {Object.keys(log.details).length > 0 ? (
                      <pre className="details-pre">
                        {JSON.stringify(log.details, null, 1)}
                      </pre>
                    ) : '—'}
                  </td>
                  <td className="muted" style={{ fontSize: 12, fontFamily: 'monospace' }}>
                    {log.actorUserId ? truncate(log.actorUserId, 18) : '—'}
                  </td>
                  <td className="muted" style={{ whiteSpace: 'nowrap', fontSize: 12 }}>
                    {fmtTime(log.createdAt)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
