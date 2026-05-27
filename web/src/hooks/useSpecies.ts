import { orderBy } from 'firebase/firestore';
import type { Species } from '../types';
import { useCollection } from './useCollection';

export function useSpecies(uid: string | undefined) {
  return useCollection<Species>(uid, 'species', [orderBy('createdAt', 'asc')]);
}
