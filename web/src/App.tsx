import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { useAuth } from './hooks/useAuth';
import { Layout } from './components/Layout';
import { ProtectedRoute } from './components/ProtectedRoute';
import { LoginPage } from './pages/LoginPage';
import { DashboardPage } from './pages/DashboardPage';
import { AnimalsPage } from './pages/AnimalsPage';
import { AnimalDetailPage } from './pages/AnimalDetailPage';
import { FinancesPage } from './pages/FinancesPage';
import { HistoryPage } from './pages/HistoryPage';
import { CulturesPage } from './pages/CulturesPage';

function AuthRedirect() {
  const { user, loading } = useAuth();
  if (loading) return null;
  return user ? <Navigate to="/" replace /> : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route
          element={
            <ProtectedRoute>
              <Layout />
            </ProtectedRoute>
          }
        >
          <Route path="/" element={<DashboardPage />} />
          <Route path="/animals" element={<AnimalsPage />} />
          <Route path="/animals/:id" element={<AnimalDetailPage />} />
          <Route path="/finances" element={<FinancesPage />} />
          <Route path="/history" element={<HistoryPage />} />
          <Route path="/cultures" element={<CulturesPage />} />
        </Route>
        <Route path="*" element={<AuthRedirect />} />
      </Routes>
    </BrowserRouter>
  );
}
