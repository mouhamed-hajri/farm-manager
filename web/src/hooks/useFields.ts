import { orderBy } from 'firebase/firestore';
import type { FarmField } from '../types';
import { useCollection } from './useCollection';

export function useFields(uid: string | undefined) {
  return useCollection<FarmField>(uid, 'fields', [orderBy('createdAt', 'desc')]);
}
