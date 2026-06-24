const TESTING_SESSION_KEY = 'intelliglove.admin.testing-session';
export const DEVELOPMENT_ADMIN_TOKEN = 'intelliglove-development-admin';

function testingBypassEnabled() {
  return import.meta.env.DEV || import.meta.env.VITE_DEVELOPMENT_AUTH_BYPASS === 'true';
}

export const TESTING_USER = {
  email: 'testing',
  displayName: 'Testing Administrator',
};

export function matchesTestingCredentials(
  email: string,
  password: string,
  enabled = testingBypassEnabled(),
) {
  return enabled && email.trim() === 'testing' && password === '1234';
}

export function startTestingSession() {
  if (testingBypassEnabled()) sessionStorage.setItem(TESTING_SESSION_KEY, 'true');
}

export function isTestingSession() {
  return testingBypassEnabled() && sessionStorage.getItem(TESTING_SESSION_KEY) === 'true';
}

export function endTestingSession() {
  sessionStorage.removeItem(TESTING_SESSION_KEY);
}
