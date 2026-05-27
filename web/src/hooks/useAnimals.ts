import { orderBy } from 'firebase/firestore';
import type { Animal } from '../types';
import { useCollection } from './useCollection';

export function useAnimals(uid: string | undefined) {
  return useCollection<Animal>(uid, 'animals', [orderBy('createdAt', 'desc')]);
}
