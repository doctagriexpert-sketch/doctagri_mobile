import { BrowserRouter, Routes, Route, Navigate, NavLink } from 'react-router-dom';
import { AuthProvider } from './auth/AuthContext';
import { useAuth } from './auth/useAuth';
import { Toaster } from 'react-hot-toast';
import LoginPage from './pages/LoginPage';
import OverviewPage from './pages/OverviewPage';
import AnnotationQueuePage from './pages/AnnotationQueuePage';
import AnnotationPage from './pages/AnnotationPage';
import ConflictsPage from './pages/ConflictsPage';
import DiseaseSheetsPage from './pages/DiseaseSheetsPage';
import ProductsPage from './pages/ProductsPage';
import DatasetPage from './pages/DatasetPage';
import {
  Leaf, LayoutDashboard, Image, Crosshair, AlertTriangle,
  FileText, Package, Database, LogOut,
} from 'lucide-react';

function AppShell() {
  const { user, profile, loading, signOut, isSenior } = useAuth();

  if (loading) {
    return (
      <div className="loading-page">
        <div className="spinner" />
        <p style={{ color: 'var(--text-muted)' }}>Chargement…</p>
      </div>
    );
  }

  if (!user) return <LoginPage />;

  return (
    <div className="app-layout">
      {/* Header */}
      <header className="app-header">
        <div className="app-header__brand">
          <Leaf size={28} />
          <span>DoctAgri Expert</span>
        </div>
        <div className="app-header__user">
          <span className="app-header__role">{profile?.role || 'expert'}</span>
          <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
            {profile?.full_name || user.email}
          </span>
          <button className="btn-icon" onClick={signOut} title="Déconnexion">
            <LogOut size={16} />
          </button>
        </div>
      </header>

      {/* Sidebar */}
      <nav className="app-sidebar">
        <ul className="sidebar-nav">
          <SidebarLink to="/" icon={LayoutDashboard} label="Tableau de bord" />
          <SidebarLink to="/queue" icon={Image} label="File d'annotation" />
          <div className="sidebar-separator" />
          {isSenior && <SidebarLink to="/conflicts" icon={AlertTriangle} label="Conflits" />}
          <SidebarLink to="/diseases" icon={FileText} label="Fiches maladies" />
          <SidebarLink to="/products" icon={Package} label="Produits" />
          <div className="sidebar-separator" />
          <SidebarLink to="/dataset" icon={Database} label="Dataset" />
        </ul>
      </nav>

      {/* Main content */}
      <main className="app-main">
        <Routes>
          <Route path="/" element={<OverviewPage />} />
          <Route path="/queue" element={<AnnotationQueuePage />} />
          <Route path="/annotation/:id" element={<AnnotationPage />} />
          {isSenior && <Route path="/conflicts" element={<ConflictsPage />} />}
          <Route path="/diseases" element={<DiseaseSheetsPage />} />
          <Route path="/products" element={<ProductsPage />} />
          <Route path="/dataset" element={<DatasetPage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
    </div>
  );
}

function SidebarLink({ to, icon, label }) {
  const Icon = icon;
  return (
    <li>
      <NavLink
        to={to}
        end={to === '/'}
        className={({ isActive }) =>
          `sidebar-nav__item ${isActive ? 'sidebar-nav__item--active' : ''}`
        }
      >
        <Icon size={18} />
        {label}
      </NavLink>
    </li>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Toaster position="top-right" toastOptions={{
          style: {
            background: '#1e211e',
            color: '#e8e8e8',
            border: '1px solid rgba(255,255,255,0.06)',
          },
        }} />
        <AppShell />
      </AuthProvider>
    </BrowserRouter>
  );
}
