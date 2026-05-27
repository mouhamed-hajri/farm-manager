import { useState } from 'react';
import type { FormEvent } from 'react';
import { doc, deleteDoc, addDoc, setDoc } from 'firebase/firestore';
import { useAuth } from '../hooks/useAuth';
import { useFields } from '../hooks/useFields';
import { useCrops } from '../hooks/useCrops';
import type { FarmField, Crop } from '../types';
import { userColl, db } from '../lib/firebase';

function FieldModal({ uid, field, onClose }: { uid: string; field: FarmField | null; onClose: () => void }) {
  const isEdit = field !== null;
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    name: field?.name ?? '',
    areaText: field?.areaText ?? '',
    locationText: field?.locationText ?? '',
    ownership: field?.ownership ?? 'owned',
    notes: field?.notes ?? '',
    rentAmount: field?.rentAmount?.toString() ?? '',
    landlordName: field?.landlordName ?? '',
  });
  const set = (f: string, v: string) => setForm((p) => ({ ...p, [f]: v }));

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!form.name.trim()) return;
    setSaving(true);
    try {
      const now = new Date().toISOString();
      const payload: Partial<FarmField> = {
        userId: uid, name: form.name.trim(),
        areaText: form.areaText.trim() || undefined,
        locationText: form.locationText.trim() || undefined,
        ownership: form.ownership,
        notes: form.notes.trim() || undefined,
        rentAmount: form.rentAmount ? parseFloat(form.rentAmount.replace(',', '.')) : undefined,
        landlordName: form.landlordName.trim() || undefined,
        updatedAt: now, syncStatus: 'pending',
      };
      if (isEdit) {
        await setDoc(doc(db, 'users', uid, 'fields', field.id), { ...field, ...payload }, { merge: true });
      } else {
        payload.createdAt = now;
        await addDoc(userColl(uid, 'fields'), payload);
      }
      onClose();
    } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl w-full max-w-md">
        <div className="p-5 border-b border-gray-100 flex items-center justify-between">
          <h3 className="font-bold text-gray-800">{isEdit ? 'Modifier le champ' : 'Ajouter un champ'}</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-xl">×</button>
        </div>
        <form onSubmit={handleSubmit} className="p-5 space-y-4">
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Nom *</label>
            <input required value={form.name} onChange={(e) => set('name', e.target.value)}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Superficie</label>
              <input value={form.areaText} onChange={(e) => set('areaText', e.target.value)} placeholder="ex: 2 ha"
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Localisation</label>
              <input value={form.locationText} onChange={(e) => set('locationText', e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Propriété</label>
            <select value={form.ownership} onChange={(e) => set('ownership', e.target.value)}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
              <option value="owned">Propriétaire</option>
              <option value="rented">Loué</option>
              <option value="shared">Partagé</option>
            </select>
          </div>
          {form.ownership === 'rented' && (
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">Loyer (TND)</label>
                <input value={form.rentAmount} onChange={(e) => set('rentAmount', e.target.value)}
                  className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">Propriétaire</label>
                <input value={form.landlordName} onChange={(e) => set('landlordName', e.target.value)}
                  className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
              </div>
            </div>
          )}
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Notes</label>
            <textarea value={form.notes} onChange={(e) => set('notes', e.target.value)} rows={2}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
          </div>
          <div className="flex gap-3 pt-2">
            <button type="button" onClick={onClose} className="flex-1 border border-gray-200 rounded-lg py-2.5 text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors">Annuler</button>
            <button type="submit" disabled={saving} className="flex-1 bg-orange-500 hover:bg-orange-600 disabled:opacity-60 text-white rounded-lg py-2.5 text-sm font-semibold transition-colors">
              {saving ? 'Enregistrement...' : isEdit ? 'Mettre à jour' : 'Ajouter'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function CropModal({ uid, crop, fields, onClose }: { uid: string; crop: Crop | null; fields: FarmField[]; onClose: () => void }) {
  const isEdit = crop !== null;
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    nameFr: crop?.nameFr ?? '',
    nameAr: crop?.nameAr ?? '',
    iconEmoji: crop?.iconEmoji ?? '🌱',
    kind: crop?.kind ?? 'annual',
    fieldId: crop?.fieldId ?? '',
    areaOrCountText: crop?.areaOrCountText ?? '',
    notes: crop?.notes ?? '',
  });
  const set = (f: string, v: string) => setForm((p) => ({ ...p, [f]: v }));

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!form.nameFr.trim()) return;
    setSaving(true);
    try {
      const now = new Date().toISOString();
      const payload: Partial<Crop> = {
        userId: uid, nameFr: form.nameFr.trim(), nameAr: form.nameAr.trim(),
        iconEmoji: form.iconEmoji, kind: form.kind,
        fieldId: form.fieldId || undefined,
        areaOrCountText: form.areaOrCountText.trim() || undefined,
        notes: form.notes.trim() || undefined,
        seasonMonths: [], isDefault: false,
        updatedAt: now, syncStatus: 'pending',
      };
      if (isEdit) {
        await setDoc(doc(db, 'users', uid, 'crops', crop.id), { ...crop, ...payload }, { merge: true });
      } else {
        payload.createdAt = now;
        await addDoc(userColl(uid, 'crops'), payload);
      }
      onClose();
    } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl w-full max-w-md">
        <div className="p-5 border-b border-gray-100 flex items-center justify-between">
          <h3 className="font-bold text-gray-800">{isEdit ? 'Modifier la culture' : 'Ajouter une culture'}</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-xl">×</button>
        </div>
        <form onSubmit={handleSubmit} className="p-5 space-y-4">
          <div className="grid grid-cols-4 gap-2">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Icône</label>
              <input value={form.iconEmoji} onChange={(e) => set('iconEmoji', e.target.value)} maxLength={2}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-lg text-center focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
            <div className="col-span-3">
              <label className="block text-xs font-medium text-gray-600 mb-1">Nom (fr) *</label>
              <input required value={form.nameFr} onChange={(e) => set('nameFr', e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Nom (ar)</label>
            <input value={form.nameAr} onChange={(e) => set('nameAr', e.target.value)} dir="rtl"
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Type</label>
              <select value={form.kind} onChange={(e) => set('kind', e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
                <option value="annual">Annuelle</option>
                <option value="perennial">Pérenne</option>
                <option value="tree">Arbre</option>
                <option value="livestock_feed">Fourrage</option>
              </select>
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Champ</label>
              <select value={form.fieldId} onChange={(e) => set('fieldId', e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
                <option value="">— Aucun —</option>
                {fields.map((f) => <option key={f.id} value={f.id}>{f.name}</option>)}
              </select>
            </div>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Superficie / Quantité</label>
            <input value={form.areaOrCountText} onChange={(e) => set('areaOrCountText', e.target.value)} placeholder="ex: 1 ha, 200 pieds"
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Notes</label>
            <textarea value={form.notes} onChange={(e) => set('notes', e.target.value)} rows={2}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
          </div>
          <div className="flex gap-3 pt-2">
            <button type="button" onClick={onClose} className="flex-1 border border-gray-200 rounded-lg py-2.5 text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors">Annuler</button>
            <button type="submit" disabled={saving} className="flex-1 bg-green-600 hover:bg-green-700 disabled:opacity-60 text-white rounded-lg py-2.5 text-sm font-semibold transition-colors">
              {saving ? 'Enregistrement...' : isEdit ? 'Mettre à jour' : 'Ajouter'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

const OWNERSHIP_LABELS: Record<string, string> = { owned: 'Propriétaire', rented: 'Loué', shared: 'Partagé' };

export function CulturesPage() {
  const { user } = useAuth();
  const { data: fields, loading: fLoading } = useFields(user?.uid);
  const { data: crops, loading: cLoading } = useCrops(user?.uid);
  const [tab, setTab] = useState<'fields' | 'crops'>('fields');
  const [showFieldForm, setShowFieldForm] = useState(false);
  const [editField, setEditField] = useState<FarmField | null>(null);
  const [showCropForm, setShowCropForm] = useState(false);
  const [editCrop, setEditCrop] = useState<Crop | null>(null);

  const loading = fLoading || cLoading;
  if (loading) return <div className="p-8 flex items-center justify-center h-full"><div className="animate-spin w-8 h-8 border-4 border-green-600 border-t-transparent rounded-full" /></div>;

  return (
    <div className="p-6 space-y-5">
      <h2 className="text-2xl font-bold text-gray-800">Cultures</h2>

      <div className="flex border-b border-gray-200">
        {[['fields', '🌾 Champs'], ['crops', '🌱 Cultures']].map(([key, label]) => (
          <button key={key} onClick={() => setTab(key as typeof tab)}
            className={`px-5 py-2.5 text-sm font-medium border-b-2 transition-colors ${tab === key ? 'border-green-600 text-green-700' : 'border-transparent text-gray-500 hover:text-gray-700'}`}>
            {label}
          </button>
        ))}
      </div>

      {tab === 'fields' && (
        <div className="space-y-4">
          <button onClick={() => { setEditField(null); setShowFieldForm(true); }}
            className="bg-orange-500 hover:bg-orange-600 text-white text-sm font-semibold px-4 py-2 rounded-lg transition-colors">
            + Ajouter un champ
          </button>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {fields.map((f) => (
              <div key={f.id} className="bg-white border border-gray-200 rounded-xl p-5">
                <div className="flex justify-between items-start mb-3">
                  <div>
                    <h3 className="font-semibold text-gray-800">{f.name}</h3>
                    <span className="text-xs text-gray-500">{OWNERSHIP_LABELS[f.ownership] ?? f.ownership}</span>
                  </div>
                  <div className="flex gap-1">
                    <button onClick={() => { setEditField(f); setShowFieldForm(true); }} className="p-1.5 hover:bg-gray-100 rounded text-xs">✏️</button>
                    <button onClick={async () => { if (confirm('Supprimer ce champ ?')) await deleteDoc(doc(db, 'users', user!.uid, 'fields', f.id)); }} className="p-1.5 hover:bg-red-50 rounded text-xs">🗑️</button>
                  </div>
                </div>
                {f.areaText && <p className="text-sm text-gray-600">📐 {f.areaText}</p>}
                {f.locationText && <p className="text-sm text-gray-600">📍 {f.locationText}</p>}
                {f.rentAmount && <p className="text-sm text-gray-600">💰 {f.rentAmount} TND</p>}
                {f.landlordName && <p className="text-sm text-gray-600">👤 {f.landlordName}</p>}
                {f.notes && <p className="text-xs text-gray-400 mt-2">{f.notes}</p>}
              </div>
            ))}
            {fields.length === 0 && <p className="text-gray-400 text-sm col-span-3 text-center py-8">Aucun champ enregistré.</p>}
          </div>
        </div>
      )}

      {tab === 'crops' && (
        <div className="space-y-4">
          <button onClick={() => { setEditCrop(null); setShowCropForm(true); }}
            className="bg-green-600 hover:bg-green-700 text-white text-sm font-semibold px-4 py-2 rounded-lg transition-colors">
            + Ajouter une culture
          </button>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {crops.map((c) => (
              <div key={c.id} className="bg-white border border-gray-200 rounded-xl p-5">
                <div className="flex justify-between items-start mb-2">
                  <div className="flex items-center gap-2">
                    <span className="text-2xl">{c.iconEmoji}</span>
                    <div>
                      <h3 className="font-semibold text-gray-800">{c.nameFr}</h3>
                      {c.nameAr && <p className="text-xs text-gray-400" dir="rtl">{c.nameAr}</p>}
                    </div>
                  </div>
                  <div className="flex gap-1">
                    <button onClick={() => { setEditCrop(c); setShowCropForm(true); }} className="p-1.5 hover:bg-gray-100 rounded text-xs">✏️</button>
                    <button onClick={async () => { if (confirm('Supprimer cette culture ?')) await deleteDoc(doc(db, 'users', user!.uid, 'crops', c.id)); }} className="p-1.5 hover:bg-red-50 rounded text-xs">🗑️</button>
                  </div>
                </div>
                {c.areaOrCountText && <p className="text-sm text-gray-600">📐 {c.areaOrCountText}</p>}
                {c.fieldId && <p className="text-sm text-gray-600">🌾 {fields.find((f) => f.id === c.fieldId)?.name ?? c.fieldId}</p>}
                {c.notes && <p className="text-xs text-gray-400 mt-2">{c.notes}</p>}
              </div>
            ))}
            {crops.length === 0 && <p className="text-gray-400 text-sm col-span-3 text-center py-8">Aucune culture enregistrée.</p>}
          </div>
        </div>
      )}

      {showFieldForm && (
        <FieldModal uid={user!.uid} field={editField} onClose={() => { setShowFieldForm(false); setEditField(null); }} />
      )}
      {showCropForm && (
        <CropModal uid={user!.uid} crop={editCrop} fields={fields} onClose={() => { setShowCropForm(false); setEditCrop(null); }} />
      )}
    </div>
  );
}
