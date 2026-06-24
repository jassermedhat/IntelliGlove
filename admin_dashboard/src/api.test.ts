import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { api, ApiError } from './api';

// Minimal Firebase user mock
const mockUser = (token: string, refreshedToken: string | null) => ({
  getIdToken: vi.fn().mockResolvedValue(token),
  getIdToken_forceRefresh: vi.fn().mockResolvedValue(refreshedToken),
});

// We stub the firebase auth module so api() uses our fake user.
vi.mock('./firebase', () => ({ auth: { currentUser: null } }));

// testingSession must return false so api() uses the Firebase path.
vi.mock('./testingSession', () => ({
  isTestingSession: () => false,
  DEVELOPMENT_ADMIN_TOKEN: 'dev-bypass-token',
}));

describe('api() — Issue 10: 401 retry-with-token-refresh', () => {
  let fetchMock: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  async function setupSignedIn(token = 'initial-token', refreshed: string | null = 'refreshed-token') {
    const { auth } = await import('./firebase');
    const user = {
      getIdToken: vi.fn().mockResolvedValue(token),
    } as unknown as import('firebase/auth').User;
    // getIdToken(true) is used for the refresh call
    (user.getIdToken as ReturnType<typeof vi.fn>).mockImplementation((force?: boolean) =>
      Promise.resolve(force ? refreshed : token)
    );
    (auth as { currentUser: typeof user | null }).currentUser = user;
    return user;
  }

  it('succeeds on the first request when the token is valid', async () => {
    await setupSignedIn();
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify({ data: { ok: true } }), { status: 200 })
    );
    const result = await api<{ ok: boolean }>('/test');
    expect(result).toEqual({ ok: true });
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('retries with a refreshed token on a 401 and succeeds', async () => {
    await setupSignedIn('stale-token', 'fresh-token');
    fetchMock
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ message: 'token expired' }), { status: 401 })
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ data: { value: 42 } }), { status: 200 })
      );

    const result = await api<{ value: number }>('/protected');
    expect(result).toEqual({ value: 42 });
    expect(fetchMock).toHaveBeenCalledTimes(2);
    // Second call should use the refreshed token.
    const secondCall = fetchMock.mock.calls[1][1] as RequestInit;
    expect((secondCall.headers as Record<string, string>)['Authorization']).toBe('Bearer fresh-token');
  });

  it('throws ApiError when 401 persists after refresh', async () => {
    await setupSignedIn('stale-token', 'still-stale-token');
    fetchMock.mockResolvedValue(
      new Response(JSON.stringify({ code: 'UNAUTHORIZED', message: 'still expired' }), { status: 401 })
    );
    await expect(api('/protected')).rejects.toBeInstanceOf(ApiError);
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('does not retry when token refresh itself fails', async () => {
    await setupSignedIn('stale-token', null); // null → getIdToken throws
    const { auth } = await import('./firebase');
    const user = auth.currentUser!;
    (user.getIdToken as ReturnType<typeof vi.fn>).mockImplementation((force?: boolean) =>
      force ? Promise.reject(new Error('network error')) : Promise.resolve('stale-token')
    );
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify({ code: 'UNAUTHORIZED', message: 'expired' }), { status: 401 })
    );
    await expect(api('/protected')).rejects.toBeInstanceOf(ApiError);
    // Only one fetch call — refresh failed so no retry.
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });
});
