import { useState, useMemo } from 'react';
import type { FormEvent } from 'react';
import { doc, deleteDoc, addDoc, setDoc } from 'firebase/firestore';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { useAuth } from '../hooks/useAuth';
import { useExpenses } from '../hooks/useExpenses';
import { useSales } from '../hooks/useSales';
import type { Expense, Sale } from '../types';
import { userColl, db } from '../lib/firebase';

type DateRange = 'today' | 'week' | 'month' | 'year';

function isInRange(dateStr: string, range: DateRange): boolean {
  const d = new Date(dateStr);
  const now = new Date();
  if (range === 'today') return d.toDateString() === now.toDateString();
  if (range === 'week') {
    const start = new Date(now); start.setDate(now.getDate() - 7);
    return d >= start;
  }
  if (range === 'month') return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
  if (range === 'year') return d.getFullYear() === now.getFullYear();
  return true;
}

function last6Months() {
  const months = [];
  for (let i = 5; i >= 0; i--) {
    const d = new Date();
    d.setMonth(d.getMonth() - i);
    months.push({ key: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`, label: d.toLocaleDateString('fr-FR', { month: 'short' }) });
  }
  return months;
}

function ExpenseModal({ uid, expense, onClose }: { uid: string; expense: Expense | null; onClose: () => void }) {
  const isEdit = expense !== null;
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    amount: expense?.amount?.toString() ?? '',
    category: expense?.category ?? 'Alimentation',
    date: expense?.date ?? new Date().toISOString().slice(0, 10),
    description: expense?.description ?? '',
    scope: expense?.scope ?? 'general',
  });
  const set = (f: string, v: string) => setForm((p) => ({ ...p, [f]: v }));

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    const amount = parseFloat(form.amount.replace(',', '.'));
    if (!amount || amount <= 0) return;
    setSaving(true);
    try {
      const now = new Date().toISOString();
      const payload: Partial<Expense> = {
        userId: uid, amount, category: form.category, date: form.date,
        description: form.description.trim() || undefined, scope: form.scope,
        updatedAt: now, syncStatus: 'pending',
      };
      if (isEdit) {
        await setDoc(doc(db, 'users', uid, 'expenses', expense.id), { ...expense, ...payload }, { merge: true });
      } else {
        payload.createdAt = now;
        await addDoc(userColl(uid, 'expenses'), payload);
      }
      onClose();
    } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl w-full max-w-md">
        <div className="p-5 border-b border-gray-100 flex items-center justify-between">
          <h3 className="font-bold text-gray-800">{isEdit ? 'Modifier la dépense' : 'Ajouter une dépense'}</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-xl">×</button>
        </div>
        <form onSubmit={handleSubmit} className="p-5 space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Montant (TND) *</label>
              <input required value={form.amount} onChange={(e) => set('amount', e.target.value)} placeholder="0"
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Date</label>
              <input type="date" value={form.date} onChange={(e) => set('date', e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Catégorie</label>
            <select value={form.category} onChange={(e) => set('category', e.target.value)}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
              {['Alimentation', 'Médicaments', 'Équipement', 'Transport', 'Main d\'œuvre', 'Vétérinaire', 'Semences', 'Engrais', 'Autre'].map((c) => <option key={c}>{c}</option>)}
            </select>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Description</label>
            <input value={form.description} onChange={(e) => set('description', e.target.value)}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
          </div>
          <div className="flex gap-3 pt-2">
            <button type="button" onClick={onClose} className="flex-1 border border-gray-200 rounded-lg py-2.5 text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors">Annuler</button>
            <button type="submit" disabled={saving} className="flex-1 bg-red-500 hover:bg-red-600 disabled:opacity-60 text-white rounded-lg py-2.5 text-sm font-semibold transition-colors">
              {saving ? 'Enregistrement...' : isEdit ? 'Mettre à jour' : 'Ajouter'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function SaleModal({ uid, sale, onClose }: { uid: string; sale: Sale | null; onClose: () => void }) {
  const isEdit = sale !== null;
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    totalPrice: sale?.totalPrice?.toString() ?? '',
    productName: sale?.productName ?? '',
    saleDate: sale?.saleDate ?? new Date().toISOString().slice(0, 10),
    buyerName: sale?.buyerName ?? '',
    notes: sale?.notes ?? '',
    scope: sale?.scope ?? 'general',
  });
  const set = (f: string, v: string) => setForm((p) => ({ ...p, [f]: v }));

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    const totalPrice = parseFloat(form.totalPrice.replace(',', '.'));
    if (!totalPrice || totalPrice <= 0) return;
    setSaving(true);
    try {
      const now = new Date().toISOString();
      const payload: Partial<Sale> = {
        userId: uid, totalPrice, unitPrice: totalPrice, quantity: 1, unit: 'unité',
        productName: form.productName.trim() || undefined,
        saleDate: form.saleDate,
        buyerName: form.buyerName.trim() || undefined,
        notes: form.notes.trim() || undefined, scope: form.scope,
        updatedAt: now, syncStatus: 'pending',
      };
      if (isEdit) {
        await setDoc(doc(db, 'users', uid, 'sales', sale.id), { ...sale, ...payload }, { merge: true });
      } else {
        payload.createdAt = now;
        await addDoc(userColl(uid, 'sales'), payload);
      }
      onClose();
    } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl w-full max-w-md">
        <div className="p-5 border-b border-gray-100 flex items-center justify-between">
          <h3 className="font-bold text-gray-800">{isEdit ? 'Modifier la vente' : 'Ajouter une vente'}</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-xl">×</button>
        </div>
        <form onSubmit={handleSubmit} className="p-5 space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Montant (TND) *</label>
              <input required value={form.totalPrice} onChange={(e) => set('totalPrice', e.target.value)} placeholder="0"
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Date</label>
              <input type="date" value={form.saleDate} onChange={(e) => set('saleDate', e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Produit</label>
            <input value={form.productName} onChange={(e) => set('productName', e.target.value)}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Acheteur</label>
            <input value={form.buyerName} onChange={(e) => set('buyerName', e.target.value)}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Notes</label>
            <input value={form.notes} onChange={(e) => set('notes', e.target.value)}
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

export function FinancesPage() {
  const { user } = useAuth();
  const { data: expenses, loading: eLoading } = useExpenses(user?.uid);
  const { data: sales, loading: sLoading } = useSales(user?.uid);
  const [tab, setTab] = useState<'expenses' | 'sales' | 'reports'>('reports');
  const [range, setRange] = useState<DateRange>('month');
  const [showExpenseForm, setShowExpenseForm] = useState(false);
  const [editExpense, setEditExpense] = useState<Expense | null>(null);
  const [showSaleForm, setShowSaleForm] = useState(false);
  const [editSale, setEditSale] = useState<Sale | null>(null);

  const months = last6Months();

  const chartData = useMemo(() => months.map(({ key, label }) => ({
    name: label,
    Dépenses: expenses.filter((e) => e.date.startsWith(key)).reduce((s, e) => s + e.amount, 0),
    Revenus: sales.filter((s) => s.saleDate.startsWith(key)).reduce((s, e) => s + e.totalPrice, 0),
  })), [expenses, sales]);

  const rangeExpenses = expenses.filter((e) => isInRange(e.date, range));
  const rangeSales = sales.filter((s) => isInRange(s.saleDate, range));
  const totalExp = rangeExpenses.reduce((s, e) => s + e.amount, 0);
  const totalRev = rangeSales.reduce((s, e) => s + e.totalPrice, 0);

  const categoryTotals = useMemo(() => {
    const map: Record<string, number> = {};
    rangeExpenses.forEach((e) => { map[e.category] = (map[e.category] ?? 0) + e.amount; });
    return Object.entries(map).sort((a, b) => b[1] - a[1]);
  }, [rangeExpenses]);

  const loading = eLoading || sLoading;

  if (loading) return <div className="p-8 flex items-center justify-center h-full"><div className="animate-spin w-8 h-8 border-4 border-green-600 border-t-transparent rounded-full" /></div>;

  return (
    <div className="p-6 space-y-5">
      <h2 className="text-2xl font-bold text-gray-800">Finances</h2>

      {/* Tab bar */}
      <div className="flex border-b border-gray-200">
        {[
          { key: 'reports', label: 'Rapports' },
          { key: 'expenses', label: 'Dépenses' },
          { key: 'sales', label: 'Ventes' },
        ].map(({ key, label }) => (
          <button
            key={key}
            onClick={() => setTab(key as typeof tab)}
            className={`px-5 py-2.5 text-sm font-medium border-b-2 transition-colors ${tab === key ? 'border-green-600 text-green-700' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
          >
            {label}
          </button>
        ))}
      </div>

      {tab === 'reports' && (
        <div className="space-y-5">
          {/* Range pills */}
          <div className="flex gap-2">
            {([['today', "Aujourd'hui"], ['week', 'Semaine'], ['month', 'Mois'], ['year', 'Année']] as const).map(([r, l]) => (
              <button key={r} onClick={() => setRange(r)}
                className={`px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${range === r ? 'bg-green-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}>
                {l}
              </button>
            ))}
          </div>

          {/* KPI cards */}
          <div className="grid grid-cols-3 gap-4">
            <div className="bg-red-50 border border-red-200 rounded-xl p-4 text-center">
              <p className="text-xs text-red-600 font-medium">Dépenses</p>
              <p className="text-xl font-bold text-red-700">{totalExp.toFixed(0)} TND</p>
            </div>
            <div className="bg-green-50 border border-green-200 rounded-xl p-4 text-center">
              <p className="text-xs text-green-600 font-medium">Revenus</p>
              <p className="text-xl font-bold text-green-700">{totalRev.toFixed(0)} TND</p>
            </div>
            <div className={`border rounded-xl p-4 text-center ${totalRev - totalExp >= 0 ? 'bg-green-50 border-green-200' : 'bg-red-50 border-red-200'}`}>
              <p className="text-xs font-medium text-gray-600">Bénéfice</p>
              <p className={`text-xl font-bold ${totalRev - totalExp >= 0 ? 'text-green-700' : 'text-red-700'}`}>{(totalRev - totalExp).toFixed(0)} TND</p>
            </div>
          </div>

          {/* Bar chart */}
          <div className="bg-white rounded-xl border border-gray-200 p-5">
            <h3 className="font-semibold text-gray-800 mb-4">6 derniers mois</h3>
            <ResponsiveContainer width="100%" height={220}>
              <BarChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="name" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip formatter={(v) => [`${Number(v).toFixed(0)} TND`]} />
                <Legend />
                <Bar dataKey="Dépenses" fill="#ef4444" radius={[3, 3, 0, 0]} />
                <Bar dataKey="Revenus" fill="#16a34a" radius={[3, 3, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>

          {/* Category breakdown */}
          {categoryTotals.length > 0 && (
            <div className="bg-white rounded-xl border border-gray-200 p-5">
              <h3 className="font-semibold text-gray-800 mb-4">Dépenses par catégorie</h3>
              <div className="space-y-3">
                {categoryTotals.map(([cat, amount]) => (
                  <div key={cat}>
                    <div className="flex justify-between text-sm mb-1">
                      <span className="text-gray-700">{cat}</span>
                      <span className="font-medium">{amount.toFixed(0)} TND</span>
                    </div>
                    <div className="w-full bg-gray-100 rounded-full h-1.5">
                      <div className="bg-red-400 h-1.5 rounded-full" style={{ width: `${totalExp > 0 ? (amount / totalExp) * 100 : 0}%` }} />
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {tab === 'expenses' && (
        <div className="space-y-4">
          <button onClick={() => { setEditExpense(null); setShowExpenseForm(true); }}
            className="bg-red-500 hover:bg-red-600 text-white text-sm font-semibold px-4 py-2 rounded-lg transition-colors">
            + Ajouter une dépense
          </button>
          <div className="bg-white rounded-xl border border-gray-200 divide-y divide-gray-100">
            {expenses.length === 0 && <p className="p-6 text-gray-400 text-sm text-center">Aucune dépense.</p>}
            {expenses.map((e) => (
              <div key={e.id} className="flex items-center gap-3 p-4">
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-800">{e.category}</p>
                  <p className="text-xs text-gray-500">{e.description ?? e.date}</p>
                </div>
                <span className="text-sm font-bold text-red-600">{e.amount.toFixed(0)} TND</span>
                <span className="text-xs text-gray-400">{e.date}</span>
                <div className="flex gap-1">
                  <button onClick={() => { setEditExpense(e); setShowExpenseForm(true); }} className="p-1.5 hover:bg-gray-100 rounded text-xs">✏️</button>
                  <button onClick={async () => { if (confirm('Supprimer ?')) await deleteDoc(doc(db, 'users', user!.uid, 'expenses', e.id)); }} className="p-1.5 hover:bg-red-50 rounded text-xs">🗑️</button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {tab === 'sales' && (
        <div className="space-y-4">
          <button onClick={() => { setEditSale(null); setShowSaleForm(true); }}
            className="bg-green-600 hover:bg-green-700 text-white text-sm font-semibold px-4 py-2 rounded-lg transition-colors">
            + Ajouter une vente
          </button>
          <div className="bg-white rounded-xl border border-gray-200 divide-y divide-gray-100">
            {sales.length === 0 && <p className="p-6 text-gray-400 text-sm text-center">Aucune vente.</p>}
            {sales.map((s) => (
              <div key={s.id} className="flex items-center gap-3 p-4">
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-800">{s.productName ?? s.scope}</p>
                  <p className="text-xs text-gray-500">{s.buyerName ?? s.saleDate}</p>
                </div>
                <span className="text-sm font-bold text-green-600">{s.totalPrice.toFixed(0)} TND</span>
                <span className="text-xs text-gray-400">{s.saleDate}</span>
                <div className="flex gap-1">
                  <button onClick={() => { setEditSale(s); setShowSaleForm(true); }} className="p-1.5 hover:bg-gray-100 rounded text-xs">✏️</button>
                  <button onClick={async () => { if (confirm('Supprimer ?')) await deleteDoc(doc(db, 'users', user!.uid, 'sales', s.id)); }} className="p-1.5 hover:bg-red-50 rounded text-xs">🗑️</button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {showExpenseForm && (
        <ExpenseModal uid={user!.uid} expense={editExpense} onClose={() => { setShowExpenseForm(false); setEditExpense(null); }} />
      )}
      {showSaleForm && (
        <SaleModal uid={user!.uid} sale={editSale} onClose={() => { setShowSaleForm(false); setEditSale(null); }} />
      )}
    </div>
  );
}
