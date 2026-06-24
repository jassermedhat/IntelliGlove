import { auth } from './firebase';
import { DEVELOPMENT_ADMIN_TOKEN, isTestingSession } from './testingSession';

const baseUrl = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000/api/v1';

export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
  ) {
    super(message);
  }
}

async function fetchWithToken(path: string, init: RequestInit, token: string): Promise<Response> {
  return fetch(`${baseUrl}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...init.headers,
    },
  });
}

export async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const testing = isTestingSession();
  const user = auth.currentUser;
  if (!testing && !user) throw new ApiError(401, 'UNAUTHORIZED', 'Sign in is required.');

  const token = testing ? DEVELOPMENT_ADMIN_TOKEN : await user!.getIdToken();
  let response: Response;
  try {
    response = await fetchWithToken(path, init, token);
  } catch (_err) {
    throw new ApiError(0, 'NETWORK_ERROR', 'Cannot reach the backend. Is it running on http://localhost:8000?');
  }

  // Issue 10: on 401, refresh the Firebase token once and retry.
  // DEVELOPMENT_ADMIN_TOKEN bypass sessions do not use Firebase tokens so no
  // refresh is possible there.
  if (response.status === 401 && !testing && user) {
    const refreshed = await user.getIdToken(/* forceRefresh */ true).catch(() => null);
    if (refreshed) {
      response = await fetchWithToken(path, init, refreshed);
    }
  }

  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new ApiError(response.status, body.code ?? 'REQUEST_FAILED', body.message ?? 'Request failed.');
  }
  return body.data as T;
}
