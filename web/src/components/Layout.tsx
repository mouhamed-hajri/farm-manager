import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';

const navItems = [
  { to: '/', label: 'Tableau de bord', icon: '🏠', end: true },
  { to: '/animals', label: 'Animaux', icon: '🐄' },
  { to: '/finances', label: 'Finances', icon: '💰' },
  { to: '/cultures', label: 'Cultures', icon: '🌾' },
  { to: '/history', label: 'Historique', icon: '📋' },
];

export function Layout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  return (
    <div className="flex h-screen bg-gray-50">
      {/* Sidebar */}
      <aside className="w-56 bg-white border-r border-gray-200 flex flex-col">
        <div className="p-4 border-b border-gray-100">
          <h1 className="text-lg font-bold text-green-700">🌿 مزرعتي</h1>
          <p className="text-xs text-gray-400 mt-0.5">Ma Ferme</p>
        </div>
        <nav className="flex-1 p-3 space-y-1">
          {navItems.map(({ to, label, icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                  isActive
                    ? 'bg-green-100 text-green-700'
                    : 'text-gray-600 hover:bg-gray-100'
                }`
              }
            >
              <span>{icon}</span>
              {label}
            </NavLink>
          ))}
        </nav>
        <div className="p-3 border-t border-gray-100">
          <p className="text-xs text-gray-400 mb-2 truncate">{user?.email}</p>
          <button
            onClick={handleLogout}
            className="w-full text-xs text-red-600 hover:text-red-700 hover:bg-red-50 px-3 py-2 rounded-lg text-left transition-colors"
          >
            🚪 Déconnexion
          </button>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-auto">
        <Outlet />
      </main>
    </div>
  );
}
