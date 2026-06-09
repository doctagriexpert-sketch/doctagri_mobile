import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../auth/AuthContext';
import { Database, Lock, Download, Archive, Tag } from 'lucide-react';

export default function DatasetPage() {
    const { isAdmin } = useAuth();
    const [versions, setVersions] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => { loadVersions(); }, []);

    async function loadVersions() {
        const { data } = await supabase.from('dataset_versions').select('*').order('created_at', { ascending: false });
        if (data) setVersions(data);
        setLoading(false);
    }

    async function handleFreeze() {
        const tag = prompt('Tag de version (ex: v1.2.0):');
        if (!tag) return;
        const stats = await supabase.rpc('get_overview_stats');
        const s = stats.data || {};
        await supabase.from('dataset_versions').update({ status: 'frozen' }).eq('status', 'active');
        await supabase.from('dataset_versions').insert({
            version_tag: tag, status: 'active',
            total_images: s.validated || 0,
            class_distribution: s.class_distribution || {},
            agreement_rate: s.agreement_rate || 0,
            rejected_count: s.rejected || 0,
        });
        loadVersions();
    }

    if (loading) return <div className="loading-page"><div className="spinner" /></div>;

    const active = versions.find(v => v.status === 'active');

    return (
        <div>
            <div className="page-header">
                <div>
                    <h1>Dataset & Versioning</h1>
                    <p>Gestion des versions du dataset d'entraînement</p>
                </div>
                {isAdmin && (
                    <button className="btn btn-accent" onClick={handleFreeze}>
                        <Lock size={16} /> Geler & créer version
                    </button>
                )}
            </div>

            {active && (
                <div className="card" style={{ marginBottom: 'var(--sp-lg)', borderColor: 'var(--border-active)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--sp-md)', marginBottom: 'var(--sp-md)' }}>
                        <Database size={20} style={{ color: 'var(--sage)' }} />
                        <span style={{ fontSize: '1.2rem', fontWeight: 700 }}>{active.version_tag}</span>
                        <span className="badge badge--validated">Active</span>
                    </div>
                    <div className="stats-grid" style={{ marginBottom: 0 }}>
                        <div className="stat-card"><span className="stat-card__label">Images validées</span><span className="stat-card__value">{active.total_images}</span></div>
                        <div className="stat-card"><span className="stat-card__label">Taux d'accord</span><span className="stat-card__value stat-card__value--healthy">{active.agreement_rate || 0}%</span></div>
                        <div className="stat-card"><span className="stat-card__label">Rejetées</span><span className="stat-card__value stat-card__value--danger">{active.rejected_count}</span></div>
                    </div>
                </div>
            )}

            <div className="card__header"><span className="card__title">Historique des versions</span></div>
            <div className="table-container">
                <table className="table">
                    <thead><tr><th>Version</th><th>Images</th><th>Accord</th><th>Rejetées</th><th>Statut</th><th>Date</th></tr></thead>
                    <tbody>
                        {versions.map(v => (
                            <tr key={v.id}>
                                <td style={{ fontWeight: 600 }}><Tag size={12} style={{ marginRight: 4, verticalAlign: -1 }} />{v.version_tag}</td>
                                <td>{v.total_images}</td>
                                <td>{v.agreement_rate || 0}%</td>
                                <td>{v.rejected_count}</td>
                                <td><span className={`badge badge--${v.status === 'active' ? 'validated' : v.status === 'frozen' ? 'annotating' : 'pending'}`}>{v.status}</span></td>
                                <td style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>{new Date(v.created_at).toLocaleDateString('fr-FR')}</td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        </div>
    );
}
