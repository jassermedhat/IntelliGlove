import { Component, StrictMode } from 'react';
import type { ReactNode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import './styles.css';

class ErrorBoundary extends Component<{ children: ReactNode }, { error: Error | null }> {
  state = { error: null };

  static getDerivedStateFromError(error: Error) {
    return { error };
  }

  render() {
    if (this.state.error) {
      const err = this.state.error as Error;
      return (
        <main className="login-shell">
          <div className="login-card" style={{ gap: 12 }}>
            <div className="login-brand">
              <div className="brand-mark">IG</div>
              <div>
                <p className="eyebrow" style={{ margin: 0 }}>INTELLIGLOVE</p>
                <p className="muted" style={{ margin: 0, fontSize: 12 }}>Administration Portal</p>
              </div>
            </div>
            <p className="error" role="alert">Application failed to initialize.</p>
            <code style={{ fontSize: 11, display: 'block', background: 'var(--surface)', padding: 12, borderRadius: 6, color: 'var(--error, #e06c75)', overflowX: 'auto', whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
              {err.message}
            </code>
            <button className="btn-primary" onClick={() => window.location.reload()}>
              Reload page
            </button>
          </div>
        </main>
      );
    }
    return this.props.children;
  }
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  </StrictMode>,
);
