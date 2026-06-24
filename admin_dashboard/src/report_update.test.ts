import { describe, expect, it } from 'vitest';
import { reportUpdatePayload } from './report_update';

describe('reportUpdatePayload', () => {
  it('sends status and trimmed admin notes', () => {
    expect(reportUpdatePayload('reviewed', '  Reproduced on Android.  ')).toEqual({
      status: 'reviewed',
      adminNotes: 'Reproduced on Android.',
    });
  });

  it('clears blank admin notes with null', () => {
    expect(reportUpdatePayload('resolved', '   ')).toEqual({
      status: 'resolved',
      adminNotes: null,
    });
  });
});
