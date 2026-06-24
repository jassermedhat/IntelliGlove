import { describe, expect, it } from 'vitest';
import { developmentAutoLogin } from './env';

describe('developmentAutoLogin', () => {
  it('never returns credentials for production builds', () => {
    expect(developmentAutoLogin({ DEV: false, VITE_ADMIN_AUTO_LOGIN: 'true', VITE_ADMIN_EMAIL: 'admin@example.com', VITE_ADMIN_PASSWORD: 'secret' })).toBeNull();
  });

  it('requires an explicit development opt-in and both credentials', () => {
    expect(developmentAutoLogin({ DEV: true, VITE_ADMIN_AUTO_LOGIN: 'true', VITE_ADMIN_EMAIL: 'admin@example.com', VITE_ADMIN_PASSWORD: 'secret' })).toEqual({ email: 'admin@example.com', password: 'secret' });
    expect(developmentAutoLogin({ DEV: true, VITE_ADMIN_AUTO_LOGIN: 'false' })).toBeNull();
  });
});
