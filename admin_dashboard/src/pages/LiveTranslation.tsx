import { FormEvent, useEffect, useState } from 'react';
import type { ActiveTranslationSession } from '../types';
import { useApi } from '../hooks/useApi';
import { api } from '../api';
import { PageSpinner } from '../components/Spinner';
import { ErrorBanner } from '../components/ErrorBanner';
import { EmptyState } from '../components/EmptyState';

function fmtTime(iso: string) {
  return new Date(iso).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

type SentEntry = { text: string; sentAt: string };

export function LiveTranslation() {
  const { state, reload } = useApi<ActiveTranslationSession[]>('/admin/translation/active-sessions');
  const [sessionId, setSessionId] = useState('');
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [sentLog, setSentLog] = useState<SentEntry[]>([]);

  // Pre-hardware/pre-ML phase: this list of active sessions can change at any
  // time as users open/close the Translation screen, so refresh it often.
  useEffect(() => {
    const id = setInterval(() => void reload(), 4000);
    return () => clearInterval(id);
  }, [reload]);

  const sessions = state.status === 'success' ? state.data : [];

  // Keep the selection valid as the active-session list changes.
  useEffect(() => {
    if (sessions.length > 0 && !sessions.some((s) => s.sessionId === sessionId)) {
      setSessionId(sessions[0].sessionId);
    }
    if (sessions.length === 0 && sessionId) {
      setSessionId('');
    }
  }, [sessions, sessionId]);

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!sessionId || !text.trim()) return;
    setBusy(true);
    setError('');
    try {
      await api('/admin/translation/send', {
        method: 'POST',
        body: JSON.stringify({ sessionId, text: text.trim() }),
      });
      setSentLog((prev) => [{ text: text.trim(), sentAt: new Date().toISOString() }, ...prev].slice(0, 20));
      setText('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to send translation.');
    } finally {
      setBusy(false);
    }
  }

  const selected = sessions.find((s) => s.sessionId === sessionId) ?? null;

  return (
    <section className="page">
      <header className="page-header">
        <p className="eyebrow">PRE-HARDWARE TOOLING</p>
        <h2>Live Translation</h2>
        <p className="muted">
          Until the glove and ML model are wired in, this is how translated letters reach a
          live session. Pick a session that&rsquo;s currently open on the Translation screen,
          type a letter or word, and send it &mdash; it appears immediately over the same
          WebSocket the real pipeline will use later.
        </p>
      </header>

      {state.status === 'loading' && <PageSpinner />}
      {state.status === 'error' && (
        <ErrorBanner message={state.message} onRetry={() => void reload()} />
      )}

      {state.status === 'success' && sessions.length === 0 && (
        <EmptyState
          icon="✋"
          title="No active sessions"
          message="Open the Translation screen in the app and tap Start to begin a session — it will appear here automatically."
        />
      )}

      {state.status === 'success' && sessions.length > 0 && (
        <div className="card seed-card">
          <form onSubmit={(e) => void submit(e)}>
            <div className="card-section">
              <h4 style={{ margin: '0 0 14px' }}>Target session</h4>
              <div className="seed-targets">
                {sessions.map((s) => (
                  <label
                    key={s.sessionId}
                    className={`seed-target ${sessionId === s.sessionId ? 'selected' : ''}`}
                  >
                    <input
                      type="radio"
                      name="session"
                      checked={sessionId === s.sessionId}
                      onChange={() => setSessionId(s.sessionId)}
                    />
                    <div>
                      <strong>{s.userName || s.userEmail}</strong>
                      <div className="muted" style={{ fontSize: 12, marginTop: 2 }}>
                        {s.userEmail} &middot; started {fmtTime(s.startedAt)} &middot; {s.totalReadings} entr
                        {s.totalReadings === 1 ? 'y' : 'ies'} so far
                      </div>
                    </div>
                  </label>
                ))}
              </div>
            </div>

            <div className="card-section" style={{ display: 'flex', gap: 16, alignItems: 'flex-end' }}>
              <label style={{ flex: 1 }}>
                Letter or word to translate
                <input
                  type="text"
                  placeholder="e.g. H or HELLO"
                  value={text}
                  maxLength={500}
                  onChange={(e) => setText(e.target.value)}
                  autoFocus
                />
              </label>
              <button
                type="submit"
                className="btn-primary"
                disabled={!selected || !text.trim() || busy}
                style={{ padding: '11px 22px' }}
              >
                {busy ? 'Sending…' : 'Send to live session'}
              </button>
            </div>

            {error && <ErrorBanner message={error} />}
          </form>

          {sentLog.length > 0 && (
            <div className="card-section" style={{ borderTop: '1px solid var(--border, #1e3d52)' }}>
              <h4 style={{ margin: '0 0 10px', fontSize: 13 }} className="muted">Recently sent</h4>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                {sentLog.map((entry, i) => (
                  <span key={i} className="pill good" title={fmtTime(entry.sentAt)}>
                    {entry.text}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      <div className="notice" style={{ marginTop: 16 }}>
        <strong>Note:</strong> entries sent from here are tagged <code>source=&quot;manual_test&quot;</code>{' '}
        and behave identically to real translation entries — they show up live on the
        Translation screen and are saved permanently to that session&rsquo;s history.
      </div>
    </section>
  );
}