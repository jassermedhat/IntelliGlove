import { useState, useCallback, useEffect } from 'react';
import type { Report } from '../types';
import { api } from '../api';
import { PageSpinner } from '../components/Spinner';
import { ErrorBanner } from '../components/ErrorBanner';
import { EmptyState } from '../components/EmptyState';
import { StatusPill } from '../components/StatusPill';

type ReportType = 'bugs' | 'feedback';
type StatusFilter = '' | 'open' | 'reviewed' | 'resolved' | 'dismissed';

function fmtTime(iso: string) {
  return new Date(iso).toLocaleString(undefined, {
    month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit',
  });
}

function ReportCard({
  report,
  onUpdated,
}: {
  report: Report;
  onUpdated: () => void;
}) {
  const [notes, setNotes] = useState(report.adminNotes ?? '');
  const [status, setStatus] = useState<Report['status']>(report.status);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [saved, setSaved] = useState(false);

  // Keep in sync if parent refreshes
  useEffect(() => {
    setNotes(report.adminNotes ?? '');
    setStatus(report.status);
    setSaved(false);
  }, [report.adminNotes, report.status, report.reportId]);

  async function save(newStatus?: Report['status']) {
    const targetStatus = newStatus ?? status;
    setBusy(true);
    setError('');
    setSaved(false);
    try {
      await api(`/admin/reports/${report.reportId}`, {
        method: 'PATCH',
        body: JSON.stringify({
          status: targetStatus,
          adminNotes: notes.trim() || null,
        }),
      });
      setStatus(targetStatus);
      setSaved(true);
      onUpdated();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Save failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <article className="report-card">
      <div className="report-card-header">
        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
          <StatusPill value={status} />
          {report.appVersion && (
            <span className="pill" style={{ background: '#152a3a', color: '#8bbfd4' }}>
              v{report.appVersion}
            </span>
          )}
          <span className="muted" style={{ fontSize: 12 }}>
            {fmtTime(report.createdAt)}
          </span>
          <span className="muted" style={{ fontSize: 11, opacity: 0.55, fontFamily: 'monospace' }}>
            {report.reportId}
          </span>
        </div>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexShrink: 0 }}>
          {(['reviewed', 'resolved', 'dismissed'] as Report['status'][]).map((s) => (
            <button
              key={s}
              className={`btn-chip ${status === s ? 'btn-chip-active' : ''}`}
              disabled={busy}
              onClick={() => void save(s)}
            >
              {s}
            </button>
          ))}
        </div>
      </div>

      <p className="report-message">{report.message}</p>

      <div className="report-notes-row">
        <label className="report-notes-label">
          Admin notes
          <textarea
            className="report-notes-input"
            rows={2}
            placeholder="Internal notes (not visible to users)…"
            value={notes}
            disabled={busy}
            onChange={(e) => { setNotes(e.target.value); setSaved(false); }}
          />
        </label>
        <button
          className="btn-secondary"
          style={{ alignSelf: 'flex-end', whiteSpace: 'nowrap', minWidth: 100 }}
          disabled={busy}
          onClick={() => void save()}
        >
          {busy ? 'Saving…' : saved ? '✓ Saved' : 'Save notes'}
        </button>
      </div>

      {error && <ErrorBanner message={error} />}
    </article>
  );
}

function ReportList({ type }: { type: ReportType }) {
  const [rows, setRows] = useState<Report[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [filter, setFilter] = useState<StatusFilter>('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const path = `/admin/reports/${type}${filter ? `?status=${filter}` : ''}`;
      setRows(await api<Report[]>(path));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load reports.');
    } finally {
      setLoading(false);
    }
  }, [type, filter]);

  useEffect(() => { void load(); }, [load]);

  return (
    <>
      <div className="filter-row">
        <span className="muted" style={{ fontSize: 13 }}>Filter:</span>
        {(['', 'open', 'reviewed', 'resolved', 'dismissed'] as StatusFilter[]).map((s) => (
          <button
            key={s || 'all'}
            className={`btn-chip ${filter === s ? 'btn-chip-active' : ''}`}
            onClick={() => setFilter(s)}
          >
            {s || 'All'}
          </button>
        ))}
        <button className="btn-ghost" style={{ marginLeft: 'auto' }} onClick={() => void load()}>
          ↻ Refresh
        </button>
      </div>

      {error && <ErrorBanner message={error} onRetry={() => void load()} />}
      {loading && <PageSpinner />}
      {!loading && !error && rows.length === 0 && (
        <EmptyState
          icon={type === 'bugs' ? '🐛' : '💬'}
          title={`No ${type === 'bugs' ? 'bug reports' : 'feedback'} found`}
          message={filter ? `No ${type} with status "${filter}".` : `No ${type} submitted yet.`}
        />
      )}
      {!loading && rows.length > 0 && (
        <div className="report-list">
          {rows.map((report) => (
            <ReportCard key={report.reportId} report={report} onUpdated={() => void load()} />
          ))}
        </div>
      )}
    </>
  );
}

export function Reports({ type }: { type: ReportType }) {
  return (
    <section className="page">
      <header className="page-header">
        <p className="eyebrow">USER INTAKE</p>
        <h2>{type === 'bugs' ? 'Bug Reports' : 'User Feedback'}</h2>
        <p className="muted">
          {type === 'bugs'
            ? 'Submitted crash and defect reports from mobile users.'
            : 'Feature requests and general feedback from mobile users.'}
        </p>
      </header>
      <ReportList key={type} type={type} />
    </section>
  );
}
