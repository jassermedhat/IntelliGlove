import { useState, useCallback } from 'react';
import type { AdminConfig, MlModel } from '../types';
import { api, ApiError } from '../api';
import { useApi } from '../hooks/useApi';
import { PageSpinner } from '../components/Spinner';
import { ErrorBanner } from '../components/ErrorBanner';
import { EmptyState } from '../components/EmptyState';
import { StatusPill } from '../components/StatusPill';

function fmtDate(iso: string) {
  return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
}

function ConfirmButton({
  label,
  confirmLabel,
  className,
  disabled,
  onConfirm,
}: {
  label: string;
  confirmLabel: string;
  className?: string;
  disabled?: boolean;
  onConfirm: () => Promise<void>;
}) {
  const [confirming, setConfirming] = useState(false);
  const [busy, setBusy] = useState(false);

  async function handleClick() {
    if (!confirming) { setConfirming(true); return; }
    setBusy(true);
    setConfirming(false);
    await onConfirm();
    setBusy(false);
  }

  return (
    <button
      className={className ?? 'btn-secondary'}
      disabled={disabled || busy}
      onClick={() => void handleClick()}
      onBlur={() => setConfirming(false)}
    >
      {busy ? 'Working…' : confirming ? confirmLabel : label}
    </button>
  );
}

export function SystemControl({
  config,
  reload,
}: {
  config: AdminConfig;
  reload: () => Promise<void>;
}) {
  const { state: modelsState, reload: reloadModels } = useApi<MlModel[]>('/admin/models');
  const [scanBusy, setScanBusy] = useState(false);
  const [activateBusy, setActivateBusy] = useState('');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const isOn = config.systemStatus === 'on';

  async function toggleSystem() {
    setError('');
    setNotice('');
    try {
      await api('/admin/config/system-status', {
        method: 'PATCH',
        body: JSON.stringify({ systemStatus: isOn ? 'off' : 'on' }),
      });
      await reload();
      setNotice(`System turned ${isOn ? 'off' : 'on'}.`);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update system status.');
    }
  }

  async function scanModels() {
    setScanBusy(true);
    setError('');
    setNotice('');
    try {
      await api('/admin/models/scan', { method: 'POST' });
      await reloadModels();
      setNotice('Model scan complete.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Scan failed.');
    } finally {
      setScanBusy(false);
    }
  }

  const activateModel = useCallback(
    async (modelId: string) => {
      setActivateBusy(modelId);
      setError('');
      setNotice('');
      try {
        await api(`/admin/models/${modelId}/activate`, { method: 'PATCH' });
        await Promise.all([reload(), reloadModels()]);
        setNotice('Model activated.');
      } catch (err) {
        if (err instanceof ApiError && err.code === 'SYSTEM_MUST_BE_OFF') {
          setError('Turn the system OFF before activating a model.');
        } else {
          setError(err instanceof Error ? err.message : 'Activation failed.');
        }
      } finally {
        setActivateBusy('');
      }
    },
    [reload, reloadModels],
  );

  const models = modelsState.status === 'success' ? modelsState.data : [];

  return (
    <section className="page">
      <header className="page-header">
        <p className="eyebrow">PIPELINE CONTROL</p>
        <h2>System &amp; Models</h2>
      </header>

      {error && <ErrorBanner message={error} />}
      {notice && <div className="notice success">{notice}</div>}

      {/* System on/off */}
      <div className="card">
        <div className="card-header">
          <div>
            <h3>Master System Switch</h3>
            <p className="muted">
              When the system is <strong>ON</strong>, the backend accepts translation sessions and
              drives the ingestion pipeline. Set it to <strong>OFF</strong> before changing models.
            </p>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, flexShrink: 0 }}>
            <StatusPill value={config.systemStatus} />
            <ConfirmButton
              label={isOn ? 'Turn OFF' : 'Turn ON'}
              confirmLabel={isOn ? 'Confirm OFF?' : 'Confirm ON?'}
              className={isOn ? 'btn-danger' : 'btn-primary'}
              onConfirm={toggleSystem}
            />
          </div>
        </div>
      </div>

      {/* Models */}
      <div className="card" style={{ marginTop: 24 }}>
        <div className="card-header">
          <h3>ML Models</h3>
          <button className="btn-secondary" disabled={scanBusy} onClick={() => void scanModels()}>
            {scanBusy ? 'Scanning…' : 'Scan model folder'}
          </button>
        </div>

        {modelsState.status === 'loading' && <PageSpinner />}
        {modelsState.status === 'error' && (
          <div className="card-body">
            <ErrorBanner message={modelsState.message} onRetry={reloadModels} />
          </div>
        )}
        {modelsState.status === 'success' && models.length === 0 && (
          <div className="card-body">
            <EmptyState
              icon="🧠"
              title="No models found"
              message="Place .joblib files in the model directory and click Scan."
            />
          </div>
        )}
        {modelsState.status === 'success' && models.length > 0 && (
          <table className="data-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>ID / version</th>
                <th>Status</th>
                <th>Added</th>
                <th style={{ textAlign: 'right' }}>Action</th>
              </tr>
            </thead>
            <tbody>
              {models.map((model) => (
                <tr key={model.modelId} className={model.isActive ? 'row-highlighted' : ''}>
                  <td>
                    <strong>{model.name}</strong>
                    {model.isActive && (
                      <span className="pill good" style={{ marginLeft: 8, fontSize: 10 }}>
                        ACTIVE
                      </span>
                    )}
                  </td>
                  <td className="muted" style={{ fontFamily: 'monospace', fontSize: 12 }}>
                    {model.modelId}
                    {model.version && <span style={{ marginLeft: 6 }}>v{model.version}</span>}
                  </td>
                  <td>
                    <StatusPill value={model.status} />
                  </td>
                  <td className="muted">{fmtDate(model.createdAt)}</td>
                  <td style={{ textAlign: 'right' }}>
                    {model.isActive ? (
                      <span className="muted" style={{ fontSize: 12 }}>
                        Current model
                      </span>
                    ) : (
                      <button
                        className="btn-secondary"
                        style={{ fontSize: 12, padding: '5px 12px' }}
                        disabled={
                          isOn ||
                          model.status !== 'available' ||
                          activateBusy === model.modelId
                        }
                        title={isOn ? 'Turn system OFF before activating a model' : undefined}
                        onClick={() => void activateModel(model.modelId)}
                      >
                        {activateBusy === model.modelId ? 'Activating…' : 'Activate'}
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        {isOn && models.length > 0 && (
          <div className="card-footer muted">
            ⓘ Turn the system OFF to change the active model.
          </div>
        )}
      </div>
    </section>
  );
}
