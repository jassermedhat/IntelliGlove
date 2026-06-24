import type { AdminConfig } from '../types';
import { useApi } from '../hooks/useApi';
import type { AuditLog } from '../types';
import { PageSpinner } from '../components/Spinner';
import { ErrorBanner } from '../components/ErrorBanner';
import { StatusPill } from '../components/StatusPill';

const SERVICE_LABELS: Record<string, string> = {
  translation: 'Translation',
  healthMonitor: 'Health Monitor',
  smartHouse: 'Smart House',
  analytics: 'Analytics',
  practiceMode: 'Practice Mode',
  feedback: 'Feedback',
  devices: 'Devices',
  firmware: 'Firmware',
};

function fmtTime(iso: string) {
  return new Date(iso).toLocaleString(undefined, {
    month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit',
  });
}

function StatCard({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <article className="stat-card">
      <small className="muted">{label}</small>
      <strong className="stat-value">{value}</strong>
      {sub && <small className="muted">{sub}</small>}
    </article>
  );
}

export function Overview({ config }: { config: AdminConfig }) {
  const { state: auditState } = useApi<AuditLog[]>('/admin/audit');
  const recentLogs = auditState.status === 'success' ? auditState.data.slice(0, 6) : [];

  const enabled = Object.values(config.serviceToggles).filter(Boolean).length;
  const total = Object.keys(config.serviceToggles).length;
  const disabledServices = Object.entries(config.serviceToggles)
    .filter(([, on]) => !on)
    .map(([key]) => SERVICE_LABELS[key] ?? key);

  return (
    <section className="page">
      <header className="page-header">
        <p className="eyebrow">SYSTEM SNAPSHOT</p>
        <h2>Dashboard Overview</h2>
        <p className="muted">
          Last config update: {config.updatedAt ? fmtTime(config.updatedAt) : '—'}
        </p>
      </header>

      <div className="stat-grid">
        <StatCard
          label="Master System"
          value={config.systemStatus.toUpperCase()}
          sub={config.systemStatus === 'on' ? 'Accepting translations' : 'Inference paused'}
        />
        <StatCard
          label="Services"
          value={`${enabled} / ${total}`}
          sub={disabledServices.length > 0 ? `Disabled: ${disabledServices.join(', ')}` : 'All enabled'}
        />
        <StatCard
          label="Active Model"
          value={config.activeModelId ? 'Configured' : 'None'}
          sub={config.activeModelId ? config.activeModelId.slice(0, 20) + '…' : 'No model activated'}
        />
      </div>

      {config.systemStatus === 'off' && (
        <div className="notice warning">
          <strong>⚠ System is OFF.</strong> Users cannot start translation sessions. Turn the system
          on from the <em>System &amp; Models</em> page when ready.
        </div>
      )}

      {disabledServices.length > 0 && (
        <div className="notice">
          <strong>Some services are disabled:</strong> {disabledServices.join(', ')}. Users will
          receive SERVICE_DISABLED (503) for those features.
        </div>
      )}

      <div className="card" style={{ marginTop: 32 }}>
        <div className="card-header">
          <h3>Recent Audit Activity</h3>
        </div>
        {auditState.status === 'loading' && (
          <div className="card-body">
            <PageSpinner />
          </div>
        )}
        {auditState.status === 'error' && (
          <div className="card-body">
            <ErrorBanner message={auditState.message} />
          </div>
        )}
        {auditState.status === 'success' && recentLogs.length === 0 && (
          <div className="card-body muted" style={{ padding: '20px' }}>
            No audit events recorded yet.
          </div>
        )}
        {auditState.status === 'success' && recentLogs.length > 0 && (
          <table className="data-table">
            <thead>
              <tr>
                <th>Action</th>
                <th>Target</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              {recentLogs.map((log) => (
                <tr key={log.id}>
                  <td>
                    <code className="action-code">{log.action}</code>
                  </td>
                  <td className="muted">
                    {log.targetType && <span>{log.targetType}</span>}
                    {log.targetId && (
                      <span style={{ marginLeft: 6, opacity: 0.6 }}>
                        {log.targetId.slice(0, 24)}
                      </span>
                    )}
                  </td>
                  <td className="muted">{fmtTime(log.createdAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <div className="notice" style={{ marginTop: 20 }}>
        <strong>PostgreSQL is the source of truth.</strong> Firebase supplies identity only. All
        system state and user data are read from the local backend API.
      </div>
    </section>
  );
}
