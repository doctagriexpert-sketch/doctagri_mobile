import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import {
    Image, CheckCircle, AlertTriangle, XCircle, Clock, BarChart3, Timer, Database,
} from 'lucide-react';

export default function OverviewPage() {
    const [stats, setStats] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        loadStats();
        const interval = setInterval(loadStats, 30000); // Refresh every 30s
        return () => clearInterval(interval);
    }, []);

    async function loadStats() {
        const { data, error } = await supabase.rpc('get_overview_stats');
        if (!error && data) setStats(data);
        setLoading(false);
    }

    if (loading) {
        return (
            <div className="loading-page">
                <div className="spinner" />
                <p style={{ color: 'var(--text-muted)' }}>Chargement des statistiques…</p>
            </div>
        );
    }

    if (!stats) {
        return (
            <div className="empty-state">
                <Database size={48} />
                <h3>Aucune donnée</h3>
                <p>
                    Les statistiques apparaîtront une fois que des images seront uploadées
                    et les tables Supabase configurées.
                </p>
            </div>
        );
    }

    const statCards = [
        { label: 'Total images', value: stats.total_images, icon: Image },
        { label: 'Non annotées', value: stats.pending, icon: Clock, variant: '' },
        { label: 'En cours', value: stats.annotating, icon: Clock, variant: 'info' },
        { label: 'Validées', value: stats.validated, icon: CheckCircle, variant: 'healthy' },
        { label: 'En conflit', value: stats.conflict, icon: AlertTriangle, variant: 'warning' },
        { label: 'Rejetées', value: stats.rejected, icon: XCircle, variant: 'danger' },
        { label: 'Taux d\'accord', value: `${stats.agreement_rate || 0}%`, icon: BarChart3, variant: 'healthy' },
        { label: 'Temps moyen', value: stats.avg_annotation_time_ms ? `${Math.round(stats.avg_annotation_time_ms / 1000)}s` : '–', icon: Timer },
    ];

    return (
        <div>
            <div className="page-header">
                <div>
                    <h1>Tableau de bord</h1>
                    <p>Vue d'ensemble du pipeline d'annotation</p>
                </div>
                <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                    Dataset: <strong style={{ color: 'var(--sage)' }}>{stats.active_dataset || 'v0.1.0'}</strong>
                </div>
            </div>

            <div className="stats-grid">
                {statCards.map(({ label, value, icon: Icon, variant }) => (
                    <div className="stat-card" key={label}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                            <Icon size={16} style={{ color: 'var(--text-muted)' }} />
                            <span className="stat-card__label">{label}</span>
                        </div>
                        <span className={`stat-card__value ${variant ? `stat-card__value--${variant}` : ''}`}>
                            {value}
                        </span>
                    </div>
                ))}
            </div>

            {/* Distribution par classe */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--sp-base)' }}>
                <div className="card">
                    <div className="card__header">
                        <span className="card__title">Distribution par maladie</span>
                    </div>
                    {stats.class_distribution && Object.keys(stats.class_distribution).length > 0 ? (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                            {Object.entries(stats.class_distribution)
                                .sort(([, a], [, b]) => b - a)
                                .map(([label, count]) => {
                                    const max = Math.max(...Object.values(stats.class_distribution));
                                    const pct = max > 0 ? (count / max) * 100 : 0;
                                    return (
                                        <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                                            <span style={{ fontSize: '0.8rem', width: 200, color: 'var(--text-secondary)', flexShrink: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                                                {label.replace(/_/g, ' ')}
                                            </span>
                                            <div style={{ flex: 1, height: 6, background: 'var(--border)', borderRadius: 3, overflow: 'hidden' }}>
                                                <div style={{ width: `${pct}%`, height: '100%', background: 'var(--sage)', borderRadius: 3, transition: 'width 0.3s ease' }} />
                                            </div>
                                            <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', width: 30, textAlign: 'right' }}>{count}</span>
                                        </div>
                                    );
                                })}
                        </div>
                    ) : (
                        <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Aucune annotation</p>
                    )}
                </div>

                <div className="card">
                    <div className="card__header">
                        <span className="card__title">Images par culture</span>
                    </div>
                    {stats.culture_distribution && Object.keys(stats.culture_distribution).length > 0 ? (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                            {Object.entries(stats.culture_distribution)
                                .sort(([, a], [, b]) => b - a)
                                .map(([culture, count]) => (
                                    <div key={culture} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                                        <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>{culture}</span>
                                        <span className="badge badge--validated">{count}</span>
                                    </div>
                                ))}
                        </div>
                    ) : (
                        <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Aucune image</p>
                    )}
                </div>
            </div>
        </div>
    );
}
