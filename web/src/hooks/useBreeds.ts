import { orderBy } from 'firebase/firestore';
import type { Breed } from '../types';
import { useCollection } from './useCollection';

export function useBreeds(uid: string | undefined) {
  return useCollection<Breed>(uid, 'breeds', [orderBy('name', 'asc')]);
}
