import { useMemo } from 'react';
import { useAuth } from '../hooks/useAuth';
import { useAnimals } from '../hooks/useAnimals';
import { useExpenses } from '../hooks/useExpenses';
import { useSales } from '../hooks/useSales';
import { useHistory } from '../hooks/useHistory';
import { useFields } from '../hooks/useFields';
import { StatCard } from '../components/StatCard';

function isSameMonth(dateStr: string, now: Date) {
  const d = new Date(dateStr);
  return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
}

const ACTION_ICONS: Record<string, string> = {
  animal_added: '🐄',
  animal_died: '💀',
  animal_sold: '💸',
  sale_added: '🛒',
  expense_added: '📤',
  crop_sold: '🌾',
  product_sold: '📦',
};

export function DashboardPage() {
  const { user } = useAuth();
  const { data: animals, loading: aLoading } = useAnimals(user?.uid);
  const { data: expenses, loading: eLoading } = useExpenses(user?.uid);
  const { data: sales, loading: sLoading } = useSales(user?.uid);
  const { data: history, loading: hLoading } = useHistory(user?.uid);
  const { data: fields } = useFields(user?.uid);

  const now = new Date();

  const stats = useMemo(() => {
    const active = animals.filter((a) => a.status === 'active').length;
    const soldThisMonth = animals.filter(
      (a) => a.status === 'sold' && a.updatedAt && isSameMonth(a.updatedAt, now)
    ).length;
    const monthExpenses = expenses
      .filter((e) => isSameMonth(e.date, now))
      .reduce((sum, e) => sum + e.amount, 0);
    const monthRevenue = sales
      .filter((s) => isSameMonth(s.saleDate, now))
      .reduce((sum, s) => sum + s.totalPrice, 0);
    return { active, soldThisMonth, monthExpenses, monthRevenue, profit: monthRevenue - monthExpenses };
  }, [animals, expenses, sales]);

  const recentHistory = history.slice(0, 15);
  const loading = aLoading || eLoading || sLoading || hLoading;

  if (loading) {
    return (
      <div className="p-8 flex items-center justify-center h-full">
        <div className="animate-spin w-8 h-8 border-4 border-green-600 border-t-transparent rounded-full" />
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-gray-800">Tableau de bord</h2>
        <p className="text-gray-500 text-sm">{now.toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' })}</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
        <StatCard title="Animaux actifs" value={stats.active} icon="🐄" color="green" />
        <StatCard title="Vendus ce mois" value={stats.soldThisMonth} icon="💸" color="blue" />
        <StatCard title="Dépenses" value={`${stats.monthExpenses.toFixed(0)} TND`} icon="📤" color="red" />
        <StatCard title="Revenus" value={`${stats.monthRevenue.toFixed(0)} TND`} icon="📥" color="green" />
        <StatCard
          title="Bénéfice"
          value={`${stats.profit.toFixed(0)} TND`}
          icon={stats.profit >= 0 ? '📈' : '📉'}
          color={stats.profit >= 0 ? 'green' : 'red'}
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <StatCard title="Champs" value={fields.length} icon="🌾" color="orange" />
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-5">
        <h3 className="font-semibold text-gray-800 mb-4">Activité récente</h3>
        {recentHistory.length === 0 ? (
          <p className="text-gray-400 text-sm">Aucune activité enregistrée.</p>
        ) : (
          <ul className="space-y-3">
            {recentHistory.map((entry) => (
              <li key={entry.id} className="flex items-start gap-3">
                <span className="text-lg mt-0.5">{ACTION_ICONS[entry.actionType] ?? '📝'}</span>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-800 truncate">{entry.title}</p>
                  {entry.description && (
                    <p className="text-xs text-gray-500 truncate">{entry.description}</p>
                  )}
                </div>
                <span className="text-xs text-gray-400 whitespace-nowrap">
                  {new Date(entry.date).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })}
                </span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
