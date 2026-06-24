export type AdminEnvironment = {
  DEV: boolean;
  VITE_ADMIN_AUTO_LOGIN?: string;
  VITE_ADMIN_EMAIL?: string;
  VITE_ADMIN_PASSWORD?: string;
};

export function developmentAutoLogin(env: AdminEnvironment) {
  if (!env.DEV || env.VITE_ADMIN_AUTO_LOGIN !== 'true') return null;
  const email = env.VITE_ADMIN_EMAIL?.trim();
  const password = env.VITE_ADMIN_PASSWORD;
  return email && password ? { email, password } : null;
}
