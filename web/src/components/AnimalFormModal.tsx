import { useState } from 'react';
import type { FormEvent } from 'react';
import { doc, setDoc, addDoc } from 'firebase/firestore';
import type { Animal, Species } from '../types';
import { userColl, db } from '../lib/firebase';

interface Props {
  uid: string;
  animal: Animal | null;
  speciesList: Species[];
  onClose: () => void;
}

export function AnimalFormModal({ uid, animal, speciesList, onClose }: Props) {
  const isEdit = animal !== null;
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    farmId: animal?.farmId ?? '',
    nickname: animal?.nickname ?? '',
    speciesId: animal?.speciesId ?? (speciesList[0]?.id ?? ''),
    gender: animal?.gender ?? 'male',
    birthDate: animal?.birthDate ?? '',
    breed: animal?.breed ?? '',
    color: animal?.color ?? '',
    weight: animal?.weight?.toString() ?? '',
    healthStatus: animal?.healthStatus ?? 'Bonne',
    status: animal?.status ?? 'active',
    notes: animal?.notes ?? '',
    purchasePrice: animal?.purchasePrice?.toString() ?? '',
    purchaseDate: animal?.purchaseDate ?? '',
    sellerName: animal?.sellerName ?? '',
    isBreeder: animal?.isBreeder ?? false,
  });

  const set = (field: string, value: string | boolean) =>
    setForm((prev) => ({ ...prev, [field]: value }));

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!form.farmId.trim()) return;
    setSaving(true);
    try {
      const now = new Date().toISOString();
      const payload: Partial<Animal> = {
        userId: uid,
        farmId: form.farmId.trim(),
        nickname: form.nickname.trim() || undefined,
        speciesId: form.speciesId,
        gender: form.gender as 'male' | 'female',
        birthDate: form.birthDate || undefined,
        breed: form.breed.trim() || undefined,
        color: form.color.trim() || undefined,
        weight: form.weight ? parseFloat(form.weight.replace(',', '.')) : undefined,
        healthStatus: form.healthStatus,
        status: form.status as 'active' | 'sold' | 'dead',
        notes: form.notes.trim() || undefined,
        purchasePrice: form.purchasePrice ? parseFloat(form.purchasePrice.replace(',', '.')) : undefined,
        purchaseDate: form.purchaseDate || undefined,
        sellerName: form.sellerName.trim() || undefined,
        isBreeder: form.isBreeder,
        updatedAt: now,
        syncStatus: 'pending',
      };

      if (isEdit) {
        await setDoc(doc(db, 'users', uid, 'animals', animal.id), { ...animal, ...payload }, { merge: true });
      } else {
        payload.createdAt = now;
        await addDoc(userColl(uid, 'animals'), payload);
      }
      onClose();
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div className="p-5 border-b border-gray-100 flex items-center justify-between">
          <h3 className="font-bold text-gray-800">{isEdit ? 'Modifier l\'animal' : 'Ajouter un animal'}</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-xl">×</button>
        </div>

        <form onSubmit={handleSubmit} className="p-5 space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">ID de ferme *</label>
              <input required value={form.farmId} onChange={(e) => set('farmId', e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Surnom</label>
              <input value={form.nickname} onChange={(e) => set('nickname', e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Espèce</label>
              <select value={form.speciesId} onChange={(e) => set('speciesId', e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
                {speciesList.map((s) => (
                  <option key={s.id} value={s.id}>{s.iconEmoji} {s.nameFr}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Sexe</label>
              <select value={form.gender} onChange={(e) => set('gender', e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
                <option value="male">♂ Mâle</option>
                <option value="female">♀ Femelle</option>
              </select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Date de naissance</label>
              <input type="date" value={form.birthDate} onChange={(e) => set('birthDate', e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Poids (kg)</label>
              <input value={form.weight} onChange={(e) => set('weight', e.target.value)} placeholder="0"
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Race</label>
              <input value={form.breed} onChange={(e) => set('breed', e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Couleur</label>
              <input value={form.color} onChange={(e) => set('color', e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Prix d'achat (TND)</label>
              <input value={form.purchasePrice} onChange={(e) => set('purchasePrice', e.target.value)} placeholder="0"
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Date d'achat</label>
              <input type="date" value={form.purchaseDate} onChange={(e) => set('purchaseDate', e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Vendeur</label>
            <input value={form.sellerName} onChange={(e) => set('sellerName', e.target.value)}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">État de santé</label>
            <select value={form.healthStatus} onChange={(e) => set('healthStatus', e.target.value)}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
              <option>Bonne</option>
              <option>Malade</option>
              <option>En traitement</option>
              <option>Critique</option>
            </select>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Statut</label>
            <select value={form.status} onChange={(e) => set('status', e.target.value)}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
              <option value="active">Actif</option>
              <option value="sold">Vendu</option>
              <option value="dead">Décédé</option>
            </select>
          </div>

          <div className="flex items-center gap-2">
            <input type="checkbox" id="isBreeder" checked={form.isBreeder}
              onChange={(e) => set('isBreeder', e.target.checked)}
              className="w-4 h-4 rounded accent-green-600" />
            <label htmlFor="isBreeder" className="text-sm text-gray-700">⭐ Reproducteur</label>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Notes</label>
            <textarea value={form.notes} onChange={(e) => set('notes', e.target.value)} rows={2}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
          </div>

          <div className="flex gap-3 pt-2">
            <button type="button" onClick={onClose}
              className="flex-1 border border-gray-200 rounded-lg py-2.5 text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors">
              Annuler
            </button>
            <button type="submit" disabled={saving}
              className="flex-1 bg-green-600 hover:bg-green-700 disabled:opacity-60 text-white rounded-lg py-2.5 text-sm font-semibold transition-colors">
              {saving ? 'Enregistrement...' : isEdit ? 'Mettre à jour' : 'Ajouter'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
