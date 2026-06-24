import type { Report } from './types';

export function reportUpdatePayload(
  status: Report['status'],
  adminNotes: string,
) {
  return {
    status,
    adminNotes: adminNotes.trim() || null,
  };
}
