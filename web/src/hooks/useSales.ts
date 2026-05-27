import { orderBy } from 'firebase/firestore';
import type { Sale } from '../types';
import { useCollection } from './useCollection';

export function useSales(uid: string | undefined) {
  return useCollection<Sale>(uid, 'sales', [orderBy('saleDate', 'desc')]);
}
