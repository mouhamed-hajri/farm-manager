import { useState, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';
import { useHistory } from '../hooks/useHistory';

const ACTION_ICONS: Record<string, string> = {
  animal_added: '🐄',
  animal_died: '💀',
  animal_sold: '💸',
  sale_added: '🛒',
  expense_added: '📤',
  crop_sold: '🌾',
  product_sold: '📦',
};

const TYPES = [
  { label: 'Tout', value: '' },
  { label: 'Nés/Ajoutés', value: 'animal_added' },
  { label: 'Vendus', value: 'animal_sold' },
  { label: 'Décédés', value: 'animal_died' },
  { label: 'Ventes', value: 'sale_added' },
  { label: 'Dépenses', value: 'expense_added' },
];

export function HistoryPage() {
  const { user } = useAuth();
  const { data: history, loading } = useHistory(user?.uid);
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('');
  const [yearFilter, setYearFilter] = useState('');

  const years = useMemo(() => {
    const set = new Set(history.map((h) => h.date.slice(0, 4)));
    return Array.from(set).sort((a, b) => b.localeCompare(a));
  }, [history]);

  const filtered = useMemo(() => {
    let list = history;
    if (typeFilter) list = list.filter((h) => h.actionType === typeFilter);
    if (yearFilter) list = list.filter((h) => h.date.startsWith(yearFilter));
    if (search.trim()) {
      const q = search.toLowerCase();
      list = list.filter(
        (h) =>
          h.title.toLowerCase().includes(q) ||
          (h.description ?? '').toLowerCase().includes(q)
      );
    }
    return list;
  }, [history, typeFilter, yearFilter, search]);

  // Group by month
  const grouped = useMemo(() => {
    const map = new Map<string, typeof filtered>();
    for (const entry of filtered) {
      const key = entry.date.slice(0, 7); // YYYY-MM
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(entry);
    }
    return Array.from(map.entries()).sort((a, b) => b[0].localeCompare(a[0]));
  }, [filtered]);

  const formatMonth = (ym: string) => {
    const [y, m] = ym.split('-');
    return new Date(Number(y), Number(m) - 1, 1).toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' });
  };

  const handleExport = () => {
    const text = filtered
      .map((h) => `[${h.date}] ${h.title}${h.description ? ' — ' + h.description : ''}`)
      .join('\n');
    navigator.clipboard.writeText(text);
  };

  if (loading) {
    return <div className="p-8 flex items-center justify-center h-full"><div className="animate-spin w-8 h-8 border-4 border-green-600 border-t-transparent rounded-full" /></div>;
  }

  return (
    <div className="p-6 space-y-5">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-gray-800">Historique</h2>
        <button
          onClick={handleExport}
          className="text-sm px-4 py-2 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
        >
          📋 Copier
        </button>
      </div>

      {/* Search */}
      <input
        type="text"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Rechercher..."
        className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
      />

      {/* Type filter */}
      <div className="flex gap-2 flex-wrap">
        {TYPES.map(({ label, value }) => (
          <button
            key={value}
            onClick={() => setTypeFilter(value)}
            className={`px-3 py-1 rounded-full text-xs font-medium transition-colors ${
              typeFilter === value ? 'bg-green-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Year filter */}
      {years.length > 1 && (
        <div className="flex gap-2 flex-wrap">
          <button
            onClick={() => setYearFilter('')}
            className={`px-3 py-1 rounded-full text-xs font-medium transition-colors ${!yearFilter ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
          >
            Toutes
          </button>
          {years.map((y) => (
            <button
              key={y}
              onClick={() => setYearFilter(y)}
              className={`px-3 py-1 rounded-full text-xs font-medium transition-colors ${yearFilter === y ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
            >
              {y}
            </button>
          ))}
        </div>
      )}

      {/* Timeline */}
      {grouped.length === 0 ? (
        <div className="text-center py-16 text-gray-400">
          <p className="text-4xl mb-3">📋</p>
          <p>Aucune entrée trouvée.</p>
        </div>
      ) : (
        <div className="space-y-6">
          {grouped.map(([month, entries]) => (
            <div key={month}>
              <h3 className="text-sm font-semibold text-gray-500 mb-3 capitalize">{formatMonth(month)}</h3>
              <div className="bg-white rounded-xl border border-gray-200 divide-y divide-gray-100">
                {entries.map((entry) => (
                  <div key={entry.id} className="flex items-start gap-3 p-4">
                    <span className="text-xl mt-0.5">{ACTION_ICONS[entry.actionType] ?? '📝'}</span>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-800">
                        {entry.relatedType === 'animal' && entry.relatedId ? (
                          <Link to={`/animals/${entry.relatedId}`} className="hover:text-green-600 transition-colors">
                            {entry.title}
                          </Link>
                        ) : (
                          entry.title
                        )}
                      </p>
                      {entry.description && (
                        <p className="text-xs text-gray-500 mt-0.5">{entry.description}</p>
                      )}
                    </div>
                    <span className="text-xs text-gray-400 whitespace-nowrap">
                      {new Date(entry.date).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
