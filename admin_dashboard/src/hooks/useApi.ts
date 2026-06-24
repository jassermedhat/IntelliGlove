import { useState, useEffect, useCallback } from 'react';
import { api } from '../api';

type State<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; message: string };

export function useApi<T>(path: string, deps: unknown[] = []) {
  const [state, setState] = useState<State<T>>({ status: 'loading' });

  const load = useCallback(async () => {
    setState({ status: 'loading' });
    try {
      const data = await api<T>(path);
      setState({ status: 'success', data });
    } catch (err) {
      setState({ status: 'error', message: err instanceof Error ? err.message : 'Request failed.' });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [path, ...deps]);

  useEffect(() => { void load(); }, [load]);

  return { state, reload: load };
}
