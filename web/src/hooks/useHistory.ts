import { orderBy } from 'firebase/firestore';
import type { HistoryEntry } from '../types';
import { useCollection } from './useCollection';

export function useHistory(uid: string | undefined) {
  return useCollection<HistoryEntry>(uid, 'history', [orderBy('date', 'desc')]);
}
