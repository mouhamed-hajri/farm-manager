import { orderBy } from 'firebase/firestore';
import type { Expense } from '../types';
import { useCollection } from './useCollection';

export function useExpenses(uid: string | undefined) {
  return useCollection<Expense>(uid, 'expenses', [orderBy('date', 'desc')]);
}
