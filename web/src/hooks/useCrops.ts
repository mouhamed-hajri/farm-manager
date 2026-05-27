import { orderBy } from 'firebase/firestore';
import type { Crop } from '../types';
import { useCollection } from './useCollection';

export function useCrops(uid: string | undefined) {
  return useCollection<Crop>(uid, 'crops', [orderBy('createdAt', 'desc')]);
}
