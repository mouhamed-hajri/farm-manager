import { useState, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';
import { useAnimals } from '../hooks/useAnimals';
import { useSpecies } from '../hooks/useSpecies';
import type { Animal } from '../types';
import { AnimalFormModal } from '../components/AnimalFormModal';

function AnimalCard({ animal, speciesEmoji }: { animal: Animal; speciesEmoji: string }) {
  const age = animal.birthDate
    ? Math.floor((Date.now() - new Date(animal.birthDate).getTime()) / (1000 * 60 * 60 * 24 * 30))
    : null;

  return (
    <Link
      to={`/animals/${animal.id}`}
      className="bg-white border border-gray-200 rounded-xl p-4 hover:shadow-md hover:border-green-300 transition-all block"
    >
      {animal.photoCloudUrl ? (
        <img
          src={animal.photoCloudUrl}
          alt={animal.nickname ?? animal.farmId}
          className="w-full h-32 object-cover rounded-lg mb-3"
        />
      ) : (
        <div className="w-full h-32 bg-gray-100 rounded-lg mb-3 flex items-center justify-center text-4xl">
          {speciesEmoji}
        </div>
      )}
      <p className="font-semibold text-gray-800 truncate">{animal.nickname ?? animal.farmId}</p>
      <p className="text-xs text-gray-500">{animal.farmId}</p>
      <div className="flex items-center gap-2 mt-2">
        <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${animal.gender === 'female' ? 'bg-pink-100 text-pink-700' : 'bg-blue-100 text-blue-700'}`}>
          {animal.gender === 'female' ? '♀' : '♂'}
        </span>
        {age !== null && <span className="text-xs text-gray-400">{age} mois</span>}
        {animal.isBreeder && <span className="text-xs">⭐</span>}
      </div>
    </Link>
  );
}

export function AnimalsPage() {
  const { user } = useAuth();
  const { data: animals, loading } = useAnimals(user?.uid);
  const { data: speciesList } = useSpecies(user?.uid);
  const [selectedSpeciesId, setSelectedSpeciesId] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [editAnimal, setEditAnimal] = useState<Animal | null>(null);

  const speciesMap = useMemo(() =>
    Object.fromEntries(speciesList.map((s) => [s.id, s])),
    [speciesList]
  );

  const filtered = useMemo(() => {
    let list = animals;
    if (selectedSpeciesId) list = list.filter((a) => a.speciesId === selectedSpeciesId);
    if (search.trim()) {
      const q = search.toLowerCase();
      list = list.filter((a) =>
        a.farmId.toLowerCase().includes(q) ||
        (a.nickname ?? '').toLowerCase().includes(q)
      );
    }
    return list;
  }, [animals, selectedSpeciesId, search]);

  const active = filtered.filter((a) => a.status === 'active');
  const sold = filtered.filter((a) => a.status === 'sold');
  const dead = filtered.filter((a) => a.status === 'dead');

  if (loading) {
    return (
      <div className="p-8 flex items-center justify-center h-full">
        <div className="animate-spin w-8 h-8 border-4 border-green-600 border-t-transparent rounded-full" />
      </div>
    );
  }

  return (
    <div className="p-6 space-y-5">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-gray-800">Animaux</h2>
        <button
          onClick={() => { setEditAnimal(null); setShowForm(true); }}
          className="bg-green-600 hover:bg-green-700 text-white text-sm font-semibold px-4 py-2 rounded-lg transition-colors"
        >
          + Ajouter
        </button>
      </div>

      {/* Species filter */}
      <div className="flex gap-2 flex-wrap">
        <button
          onClick={() => setSelectedSpeciesId(null)}
          className={`px-3 py-1.5 rounded-full text-sm font-medium transition-colors ${
            selectedSpeciesId === null ? 'bg-green-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
          }`}
        >
          Tous
        </button>
        {speciesList.map((s) => (
          <button
            key={s.id}
            onClick={() => setSelectedSpeciesId(s.id)}
            className={`px-3 py-1.5 rounded-full text-sm font-medium transition-colors ${
              selectedSpeciesId === s.id ? 'bg-green-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            {s.iconEmoji} {s.nameFr}
          </button>
        ))}
      </div>

      {/* Search */}
      <input
        type="text"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Rechercher par ID ou nom..."
        className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
      />

      {/* Active animals */}
      {active.length > 0 && (
        <div>
          <h3 className="font-semibold text-gray-600 text-sm mb-3">Actifs ({active.length})</h3>
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3">
            {active.map((a) => (
              <AnimalCard key={a.id} animal={a} speciesEmoji={speciesMap[a.speciesId]?.iconEmoji ?? '🐄'} />
            ))}
          </div>
        </div>
      )}

      {/* Sold */}
      {sold.length > 0 && (
        <details className="bg-gray-50 rounded-xl border border-gray-200">
          <summary className="p-4 cursor-pointer font-semibold text-gray-600 text-sm">
            Vendus ({sold.length})
          </summary>
          <div className="p-4 pt-0 grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3">
            {sold.map((a) => (
              <AnimalCard key={a.id} animal={a} speciesEmoji={speciesMap[a.speciesId]?.iconEmoji ?? '🐄'} />
            ))}
          </div>
        </details>
      )}

      {/* Dead */}
      {dead.length > 0 && (
        <details className="bg-gray-50 rounded-xl border border-gray-200">
          <summary className="p-4 cursor-pointer font-semibold text-gray-600 text-sm">
            Décédés ({dead.length})
          </summary>
          <div className="p-4 pt-0 grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3">
            {dead.map((a) => (
              <AnimalCard key={a.id} animal={a} speciesEmoji={speciesMap[a.speciesId]?.iconEmoji ?? '🐄'} />
            ))}
          </div>
        </details>
      )}

      {active.length === 0 && sold.length === 0 && dead.length === 0 && (
        <div className="text-center py-16 text-gray-400">
          <p className="text-4xl mb-3">🐄</p>
          <p>Aucun animal trouvé.</p>
        </div>
      )}

      {showForm && (
        <AnimalFormModal
          uid={user!.uid}
          animal={editAnimal}
          speciesList={speciesList}
          onClose={() => setShowForm(false)}
        />
      )}
    </div>
  );
}
