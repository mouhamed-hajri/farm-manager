import { useState, useEffect } from 'react';
import { onSnapshot, query } from 'firebase/firestore';
import type { QueryConstraint } from 'firebase/firestore';
import { userColl } from '../lib/firebase';

export function useCollection<T>(
  uid: string | undefined,
  collName: string,
  constraints: QueryConstraint[] = []
) {
  const [data, setData] = useState<T[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!uid) { setLoading(false); return; }
    const q = query(userColl(uid, collName), ...constraints);
    return onSnapshot(q, (snap) => {
      setData(snap.docs.map((d) => ({ id: d.id, ...d.data() }) as T));
      setLoading(false);
    });
  }, [uid, collName]);

  return { data, loading };
}
