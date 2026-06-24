import { describe, expect, it } from 'vitest';
import { matchesTestingCredentials } from './testingSession';

describe('testing credentials', () => {
  it('accepts the requested credentials in development', () => {
    expect(matchesTestingCredentials('testing', '1234', true)).toBe(true);
    expect(matchesTestingCredentials(' testing ', '1234', true)).toBe(true);
  });

  it('rejects incorrect credentials and all production attempts', () => {
    expect(matchesTestingCredentials('testing', 'wrong', true)).toBe(false);
    expect(matchesTestingCredentials('testing@example.com', '1234', true)).toBe(false);
    expect(matchesTestingCredentials('testing', '1234', false)).toBe(false);
  });
});
