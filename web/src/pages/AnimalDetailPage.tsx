import { useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { doc, deleteDoc } from 'firebase/firestore';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { useAuth } from '../hooks/useAuth';
import { useAnimals } from '../hooks/useAnimals';
import { useSpecies } from '../hooks/useSpecies';
import { useExpenses } from '../hooks/useExpenses';
import { useSales } from '../hooks/useSales';
import { useCollection } from '../hooks/useCollection';
import type { WeightMeasurement, HealthEvent, ReproductionEvent } from '../types';
import { db } from '../lib/firebase';
import { AnimalFormModal } from '../components/AnimalFormModal';
import { orderBy } from 'firebase/firestore';

function InfoRow({ label, value }: { label: string; value?: string | number | null }) {
  if (value === undefined || value === null || value === '') return null;
  return (
    <div className="flex justify-between py-2 border-b border-gray-100 last:border-0">
      <span className="text-sm text-gray-500">{label}</span>
      <span className="text-sm font-medium text-gray-800">{value}</span>
    </div>
  );
}

export function AnimalDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const { data: animals, loading } = useAnimals(user?.uid);
  const { data: speciesList } = useSpecies(user?.uid);
  const { data: expenses } = useExpenses(user?.uid);
  const { data: sales } = useSales(user?.uid);
  const { data: weights } = useCollection<WeightMeasurement>(user?.uid, 'weight_measurements', [orderBy('measurementDate', 'asc')]);
  const { data: healthEvents } = useCollection<HealthEvent>(user?.uid, 'health_events', [orderBy('date', 'desc')]);
  const { data: reproEvents } = useCollection<ReproductionEvent>(user?.uid, 'reproduction_events', [orderBy('eventDate', 'desc')]);
  const [showEdit, setShowEdit] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const animal = animals.find((a) => a.id === id);
  const species = speciesList.find((s) => s.id === animal?.speciesId);
  const mother = animals.find((a) => a.id === animal?.motherId);
  const father = animals.find((a) => a.id === animal?.fatherId);

  const animalExpenses = expenses.filter((e) => e.linkedAnimalId === id);
  const animalSales = sales.filter((s) => s.linkedAnimalId === id);
  const animalWeights = weights.filter((w) => w.animalId === id);
  const animalHealth = healthEvents.filter((h) => h.animalId === id);
  const animalRepro = reproEvents.filter((r) => r.animalId === id);

  const totalExpenses = animalExpenses.reduce((s, e) => s + e.amount, 0);
  const totalRevenue = animalSales.reduce((s, e) => s + e.totalPrice, 0);

  const handleDelete = async () => {
    if (!confirm('Supprimer cet animal ? Cette action est irréversible.')) return;
    setDeleting(true);
    await deleteDoc(doc(db, 'users', user!.uid, 'animals', id!));
    navigate('/animals');
  };

  if (loading) {
    return <div className="p-8 flex items-center justify-center h-full"><div className="animate-spin w-8 h-8 border-4 border-green-600 border-t-transparent rounded-full" /></div>;
  }

  if (!animal) {
    return (
      <div className="p-8 text-center text-gray-500">
        <p className="text-4xl mb-3">🔍</p>
        <p>Animal introuvable.</p>
        <Link to="/animals" className="text-green-600 text-sm mt-2 inline-block">← Retour</Link>
      </div>
    );
  }

  const age = animal.birthDate
    ? Math.floor((Date.now() - new Date(animal.birthDate).getTime()) / (1000 * 60 * 60 * 24 * 30))
    : null;

  return (
    <div className="p-6 max-w-4xl mx-auto space-y-5">
      {/* Header */}
      <div className="flex items-center gap-3">
        <Link to="/animals" className="text-gray-400 hover:text-gray-600 text-sm">← Animaux</Link>
        <div className="flex-1" />
        <button
          onClick={() => setShowEdit(true)}
          className="text-sm px-4 py-2 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
        >
          ✏️ Modifier
        </button>
        <button
          onClick={handleDelete}
          disabled={deleting}
          className="text-sm px-4 py-2 bg-red-50 text-red-600 border border-red-200 rounded-lg hover:bg-red-100 transition-colors"
        >
          🗑️ Supprimer
        </button>
      </div>

      {/* Photo + basic info */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {animal.photoCloudUrl ? (
          <img src={animal.photoCloudUrl} alt={animal.farmId} className="w-full h-56 object-cover" />
        ) : (
          <div className="w-full h-56 bg-gray-100 flex items-center justify-center text-7xl">
            {species?.iconEmoji ?? '🐄'}
          </div>
        )}
        <div className="p-5">
          <div className="flex items-start justify-between">
            <div>
              <h2 className="text-xl font-bold text-gray-800">{animal.nickname ?? animal.farmId}</h2>
              <p className="text-gray-400 text-sm">{animal.farmId}</p>
            </div>
            <div className="flex gap-2">
              <span className={`text-xs px-2 py-1 rounded-full font-medium ${animal.gender === 'female' ? 'bg-pink-100 text-pink-700' : 'bg-blue-100 text-blue-700'}`}>
                {animal.gender === 'female' ? '♀ Femelle' : '♂ Mâle'}
              </span>
              <span className={`text-xs px-2 py-1 rounded-full font-medium ${
                animal.status === 'active' ? 'bg-green-100 text-green-700' :
                animal.status === 'sold' ? 'bg-orange-100 text-orange-700' : 'bg-red-100 text-red-700'
              }`}>
                {animal.status === 'active' ? 'Actif' : animal.status === 'sold' ? 'Vendu' : 'Décédé'}
              </span>
            </div>
          </div>

          <div className="mt-4 space-y-0.5">
            <InfoRow label="Espèce" value={species ? `${species.iconEmoji} ${species.nameFr}` : undefined} />
            <InfoRow label="Race" value={animal.breed} />
            <InfoRow label="Couleur" value={animal.color} />
            <InfoRow label="Date de naissance" value={animal.birthDate} />
            <InfoRow label="Âge" value={age !== null ? `${age} mois` : undefined} />
            <InfoRow label="Poids" value={animal.weight ? `${animal.weight} kg` : undefined} />
            <InfoRow label="Santé" value={animal.healthStatus} />
            <InfoRow label="Mère" value={mother?.nickname ?? mother?.farmId} />
            <InfoRow label="Père" value={father?.nickname ?? father?.farmId} />
            <InfoRow label="Date d'achat" value={animal.purchaseDate} />
            <InfoRow label="Prix d'achat" value={animal.purchasePrice ? `${animal.purchasePrice} TND` : undefined} />
            <InfoRow label="Vendeur" value={animal.sellerName} />
            <InfoRow label="Notes" value={animal.notes} />
          </div>
        </div>
      </div>

      {/* Finance summary */}
      <div className="grid grid-cols-3 gap-4">
        <div className="bg-red-50 border border-red-200 rounded-xl p-4 text-center">
          <p className="text-xs text-red-600 font-medium">Dépenses</p>
          <p className="text-xl font-bold text-red-700">{totalExpenses.toFixed(0)} TND</p>
        </div>
        <div className="bg-green-50 border border-green-200 rounded-xl p-4 text-center">
          <p className="text-xs text-green-600 font-medium">Revenus</p>
          <p className="text-xl font-bold text-green-700">{totalRevenue.toFixed(0)} TND</p>
        </div>
        <div className={`border rounded-xl p-4 text-center ${totalRevenue - totalExpenses >= 0 ? 'bg-green-50 border-green-200' : 'bg-red-50 border-red-200'}`}>
          <p className="text-xs font-medium text-gray-600">Bénéfice</p>
          <p className={`text-xl font-bold ${totalRevenue - totalExpenses >= 0 ? 'text-green-700' : 'text-red-700'}`}>
            {(totalRevenue - totalExpenses).toFixed(0)} TND
          </p>
        </div>
      </div>

      {/* Weight chart */}
      {animalWeights.length > 1 && (
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <h3 className="font-semibold text-gray-800 mb-4">Évolution du poids</h3>
          <ResponsiveContainer width="100%" height={180}>
            <LineChart data={animalWeights.map((w) => ({ date: w.measurementDate.slice(5), weight: w.weight }))}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="date" tick={{ fontSize: 11 }} />
              <YAxis tick={{ fontSize: 11 }} unit=" kg" />
              <Tooltip formatter={(v) => [`${v} kg`, 'Poids']} />
              <Line type="monotone" dataKey="weight" stroke="#16a34a" strokeWidth={2} dot={{ r: 3 }} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* Health events */}
      {animalHealth.length > 0 && (
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <h3 className="font-semibold text-gray-800 mb-3">Événements de santé</h3>
          <ul className="space-y-2">
            {animalHealth.map((h) => (
              <li key={h.id} className="flex justify-between text-sm py-2 border-b border-gray-100 last:border-0">
                <div>
                  <p className="font-medium text-gray-800">{h.eventType}</p>
                  <p className="text-gray-500 text-xs">{h.description}</p>
                </div>
                <span className="text-xs text-gray-400">{h.date}</span>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Reproduction events (females) */}
      {animal.gender === 'female' && animalRepro.length > 0 && (
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <h3 className="font-semibold text-gray-800 mb-3">Événements de reproduction</h3>
          <ul className="space-y-2">
            {animalRepro.map((r) => (
              <li key={r.id} className="flex justify-between text-sm py-2 border-b border-gray-100 last:border-0">
                <div>
                  <p className="font-medium text-gray-800">{r.eventType}</p>
                  {r.offspringCount != null && <p className="text-xs text-gray-500">{r.offspringCount} petit(s)</p>}
                </div>
                <span className="text-xs text-gray-400">{r.eventDate}</span>
              </li>
            ))}
          </ul>
        </div>
      )}

      {showEdit && (
        <AnimalFormModal
          uid={user!.uid}
          animal={animal}
          speciesList={speciesList}
          onClose={() => setShowEdit(false)}
        />
      )}
    </div>
  );
}
