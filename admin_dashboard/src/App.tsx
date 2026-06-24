import { FormEvent, useCallback, useEffect, useState } from 'react';
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import { api, ApiError } from './api';
import { developmentAutoLogin } from './env';
import { auth } from './firebase';
import type { AdminConfig } from './types';
import { Spinner } from './components/Spinner';
import { ErrorBanner } from './components/ErrorBanner';
import { Overview } from './pages/Overview';
import { SystemControl } from './pages/SystemControl';
import { Services } from './pages/Services';
import { Reports } from './pages/Reports';
import { AuditLog } from './pages/AuditLog';
import { SeedTool } from './pages/SeedTool';
import { LiveTranslation } from './pages/LiveTranslation';
import { DeviceAssignment } from './pages/DeviceAssignment';
import {
  endTestingSession,
  isTestingSession,
  matchesTestingCredentials,
  startTestingSession,
  TESTING_USER,
} from './testingSession';

type DashboardUser = {
  email: string | null;
  displayName: string | null;
};

// ── Page routing ─────────────────────────────────────────────────────────────
type Page = 'overview' | 'system' | 'services' | 'bugs' | 'feedback' | 'audit' | 'seed' | 'live' | 'devices';

const NAV: { id: Page; label: string; icon: string; group?: string }[] = [
  { id: 'overview',  label: 'Overview',        icon: '▤',  group: 'Dashboard' },
  { id: 'system',    label: 'System & Models',  icon: '⚙',  group: 'Dashboard' },
  { id: 'services',  label: 'Services',         icon: '⌁',  group: 'Dashboard' },
  { id: 'bugs',      label: 'Bug Reports',      icon: '⚠',  group: 'User Reports' },
  { id: 'feedback',  label: 'Feedback',         icon: '✦',  group: 'User Reports' },
  { id: 'devices',   label: 'Assign Device',    icon: '🖐', group: 'User Reports' },
  { id: 'audit',     label: 'Audit Log',        icon: '📋', group: 'System' },
  { id: 'seed',      label: 'Demo Data',        icon: '＋', group: 'System' },
  { id: 'live',      label: 'Live Translation', icon: '✋', group: 'System' },
];

// ── Login screen ─────────────────────────────────────────────────────────────
function Login({ onTestingLogin }: { onTestingLogin: () => void }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      if (matchesTestingCredentials(email, password)) {
        startTestingSession();
        onTestingLogin();
        return;
      }
      await signInWithEmailAndPassword(auth, email.trim(), password);
    } catch (caught) {
      const msg =
        caught instanceof Error
          ? caught.message.replace('Firebase: ', '').replace(/\(auth\/.*?\)\.?/, '').trim()
          : 'Sign-in failed.';
      setError(msg);
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="login-shell">
      <form className="login-card" onSubmit={(e) => void submit(e)}>
        <div className="login-brand">
          <div className="brand-mark">IG</div>
          <div>
            <p className="eyebrow" style={{ margin: 0 }}>INTELLIGLOVE</p>
            <p className="muted" style={{ margin: 0, fontSize: 12 }}>Administration Portal</p>
          </div>
        </div>

        <h1 style={{ margin: 0, fontSize: 24 }}>Sign in</h1>
        <p className="muted" style={{ margin: 0 }}>
          Firebase credentials are verified by the backend. Only admin accounts can access this panel.
        </p>

        <label>
          Email address
          <input
            type="text"
            inputMode="email"
            autoComplete="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </label>
        <label>
          Password
          <input
            type="password"
            autoComplete="current-password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </label>

        {error && <p className="error" role="alert">{error}</p>}

        <button type="submit" className="btn-primary" disabled={busy} style={{ width: '100%', padding: 13 }}>
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </main>
  );
}

// ── Sidebar ───────────────────────────────────────────────────────────────────
function Sidebar({
  user,
  page,
  onNavigate,
  onSignOut,
}: {
  user: DashboardUser;
  page: Page;
  onNavigate: (p: Page) => void;
  onSignOut: () => void;
}) {
  const groups = [...new Set(NAV.map((n) => n.group).filter(Boolean))] as string[];

  return (
    <aside>
      <div className="brand">
        <div className="brand-mark">IG</div>
        <div>
          <strong>IntelliGlove</strong>
          <small>Administration</small>
        </div>
      </div>

      <nav>
        {groups.map((group) => (
          <div key={group} className="nav-group">
            <div className="nav-group-label">{group}</div>
            {NAV.filter((n) => n.group === group).map((item) => (
              <button
                key={item.id}
                className={page === item.id ? 'active' : ''}
                onClick={() => onNavigate(item.id)}
              >
                <span className="nav-icon">{item.icon}</span>
                {item.label}
              </button>
            ))}
          </div>
        ))}
      </nav>

      <div className="account">
        <div className="account-avatar">{(user.email ?? '?')[0].toUpperCase()}</div>
        <div style={{ minWidth: 0 }}>
          <span style={{ display: 'block', fontSize: 13, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {user.email}
          </span>
          <span className="muted" style={{ fontSize: 11 }}>Administrator</span>
        </div>
        <button
          className="btn-ghost"
          title="Sign out"
          style={{ marginLeft: 'auto', padding: '5px 8px', flexShrink: 0 }}
          onClick={onSignOut}
        >
          ↪
        </button>
      </div>
    </aside>
  );
}

// ── Dashboard shell ───────────────────────────────────────────────────────────
function Dashboard({ user, onSignOut }: { user: DashboardUser; onSignOut: () => void }) {
  const [page, setPage] = useState<Page>('overview');
  const [config, setConfig] = useState<AdminConfig | null>(null);
  const [configError, setConfigError] = useState('');

  const reloadConfig = useCallback(async () => {
    try {
      setConfig(await api<AdminConfig>('/admin/config'));
      setConfigError('');
    } catch (err) {
      if (err instanceof ApiError && (err.status === 401 || err.status === 403)) {
        setConfigError(
          err.code === 'ADMIN_REQUIRED'
            ? 'Your account does not have administrator privileges. Contact a system administrator.'
            : err.message,
        );
      } else {
        setConfigError(err instanceof Error ? err.message : 'Failed to load configuration.');
      }
    }
  }, []);

  // On mount: sync profile then load config
  useEffect(() => {
    void api('/auth/sync', {
      method: 'POST',
      body: JSON.stringify({ name: user.displayName ?? undefined }),
    })
      .then(reloadConfig)
      .catch((err) => {
        if (err instanceof ApiError && err.code === 'ADMIN_REQUIRED') {
          setConfigError('Your account does not have administrator privileges.');
        } else {
          setConfigError(err instanceof Error ? err.message : 'Initialization failed.');
        }
      });
  }, [reloadConfig, user.displayName]);

  function renderPage() {
    if (configError) return null;
    if (!config) return null;

    switch (page) {
      case 'overview': return <Overview config={config} />;
      case 'system':   return <SystemControl config={config} reload={reloadConfig} />;
      case 'services': return <Services config={config} reload={reloadConfig} />;
      case 'bugs':     return <Reports type="bugs" />;
      case 'feedback': return <Reports type="feedback" />;
      case 'audit':    return <AuditLog />;
      case 'devices':  return <DeviceAssignment />;
      case 'seed':     return <SeedTool />;
      case 'live':     return <LiveTranslation />;
    }
  }

  return (
    <div className="app-shell">
      <Sidebar user={user} page={page} onNavigate={setPage} onSignOut={onSignOut} />
      <main className="workspace">
        {configError && (
          <div style={{ padding: '40px 48px' }}>
            <ErrorBanner
              message={configError}
              onRetry={
                configError.includes('privileges') ? undefined : () => void reloadConfig()
              }
            />
            {configError.includes('privileges') && (
              <div style={{ marginTop: 16 }}>
                <button className="btn-ghost" onClick={onSignOut}>
                  Sign out
                </button>
              </div>
            )}
          </div>
        )}
        {!configError && !config && (
          <div className="page-center">
            <Spinner size={48} />
            <p className="muted" style={{ marginTop: 16 }}>
              Initializing admin session…
            </p>
          </div>
        )}
        {renderPage()}
      </main>
    </div>
  );
}

// ── App root ──────────────────────────────────────────────────────────────────
export default function App() {
  const [user, setUser] = useState<DashboardUser | null | undefined>(undefined);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (firebaseUser) => {
      setUser(firebaseUser ?? (isTestingSession() ? TESTING_USER : null));
    });
    const credentials = developmentAutoLogin(import.meta.env);
    if (credentials && !auth.currentUser) {
      void signInWithEmailAndPassword(auth, credentials.email, credentials.password);
    }
    return unsubscribe;
  }, []);

  function handleSignOut() {
    if (isTestingSession()) {
      endTestingSession();
      setUser(null);
      return;
    }
    void signOut(auth);
  }

  // Resolving auth state
  if (user === undefined) {
    return (
      <main className="login-shell">
        <Spinner size={48} />
      </main>
    );
  }

  return user ? (
    <Dashboard user={user} onSignOut={handleSignOut} />
  ) : (
    <Login onTestingLogin={() => setUser(TESTING_USER)} />
  );
}
