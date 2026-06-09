import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../auth/AuthContext';
import {
    Plus, Edit3, CheckCircle, Clock, FileText, ChevronDown, ChevronUp, Search,
} from 'lucide-react';

export default function DiseaseSheetsPage() {
    const { profile, isSenior } = useAuth();
    const [sheets, setSheets] = useState([]);
    const [loading, setLoading] = useState(true);
    const [editing, setEditing] = useState(null);
    const [creating, setCreating] = useState(false);
    const [expandedId, setExpandedId] = useState(null);
    const [filter, setFilter] = useState('');

    useEffect(() => { loadSheets(); }, []);

    async function loadSheets() {
        const { data, error } = await supabase
            .from('disease_sheets')
            .select('*, creator:profiles!disease_sheets_created_by_fkey(full_name)')
            .order('culture')
            .order('local_name');
        if (!error) setSheets(data || []);
        setLoading(false);
    }

    const filtered = sheets.filter(s =>
        s.local_name.toLowerCase().includes(filter.toLowerCase()) ||
        s.culture.toLowerCase().includes(filter.toLowerCase()) ||
        (s.scientific_name || '').toLowerCase().includes(filter.toLowerCase())
    );

    if (loading) return <div className="loading-page"><div className="spinner" /></div>;

    return (
        <div>
            <div className="page-header">
                <div>
                    <h1>Fiches Maladies</h1>
                    <p>{sheets.length} fiche{sheets.length > 1 ? 's' : ''}</p>
                </div>
                <button className="btn btn-primary" onClick={() => setCreating(true)}>
                    <Plus size={16} /> Nouvelle fiche
                </button>
            </div>

            {/* Search */}
            <div className="filters-bar">
                <Search size={16} style={{ color: 'var(--text-muted)' }} />
                <input
                    className="form-input"
                    placeholder="Rechercher par nom, culture..."
                    value={filter}
                    onChange={(e) => setFilter(e.target.value)}
                    style={{ flex: 1 }}
                />
            </div>

            {/* Create/Edit modal */}
            {(creating || editing) && (
                <SheetForm
                    sheet={editing}
                    onSave={async (data) => {
                        if (editing) {
                            const newVersion = { ...data, version: (editing.version || 1) + 1, parent_version_id: editing.id, status: 'draft', created_by: profile.id };
                            await supabase.from('disease_sheets').insert(newVersion);
                        } else {
                            await supabase.from('disease_sheets').insert({ ...data, created_by: profile.id, status: 'draft' });
                        }
                        setCreating(false);
                        setEditing(null);
                        loadSheets();
                    }}
                    onCancel={() => { setCreating(false); setEditing(null); }}
                />
            )}

            {/* Sheets list */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--sp-md)' }}>
                {filtered.map((sheet) => (
                    <div className="card" key={sheet.id} style={{ padding: 0 }}>
                        {/* Header */}
                        <div
                            style={{
                                padding: 'var(--sp-md) var(--sp-lg)',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'space-between',
                                cursor: 'pointer',
                            }}
                            onClick={() => setExpandedId(expandedId === sheet.id ? null : sheet.id)}
                        >
                            <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--sp-md)' }}>
                                <FileText size={16} style={{ color: 'var(--sage)' }} />
                                <div>
                                    <div style={{ fontWeight: 600, fontSize: '0.95rem' }}>{sheet.local_name}</div>
                                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                                        {sheet.scientific_name && <em>{sheet.scientific_name} · </em>}
                                        {sheet.culture}
                                        {sheet.version > 1 && ` · v${sheet.version}`}
                                    </div>
                                </div>
                            </div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--sp-sm)' }}>
                                <span className={`badge badge--${sheet.status === 'published' ? 'validated' : sheet.status === 'review' ? 'annotating' : 'pending'}`}>
                                    {sheet.status === 'published' ? '✓ Publié' : sheet.status === 'review' ? '⏳ En revue' : '📝 Brouillon'}
                                </span>
                                {expandedId === sheet.id ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                            </div>
                        </div>

                        {/* Expanded content */}
                        {expandedId === sheet.id && (
                            <div style={{ padding: '0 var(--sp-lg) var(--sp-lg)', borderTop: '1px solid var(--border)' }}>
                                {sheet.description && (
                                    <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', margin: 'var(--sp-md) 0' }}>
                                        {sheet.description}
                                    </p>
                                )}

                                {sheet.symptoms && sheet.symptoms.length > 0 && (
                                    <div style={{ marginBottom: 'var(--sp-md)' }}>
                                        <h4 style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginBottom: 4 }}>Symptômes</h4>
                                        <ul style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', paddingLeft: 16 }}>
                                            {sheet.symptoms.map((s, i) => <li key={i}>{s}</li>)}
                                        </ul>
                                    </div>
                                )}

                                {sheet.preventive_reco && sheet.preventive_reco.length > 0 && (
                                    <div style={{ marginBottom: 'var(--sp-md)' }}>
                                        <h4 style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginBottom: 4 }}>Prévention</h4>
                                        <ul style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', paddingLeft: 16 }}>
                                            {sheet.preventive_reco.map((s, i) => <li key={i}>{s}</li>)}
                                        </ul>
                                    </div>
                                )}

                                <div style={{ display: 'flex', gap: 'var(--sp-sm)', marginTop: 'var(--sp-md)' }}>
                                    <button className="btn btn-ghost btn-sm" onClick={() => setEditing(sheet)}>
                                        <Edit3 size={12} /> Modifier
                                    </button>
                                    {isSenior && sheet.status === 'draft' && (
                                        <button
                                            className="btn btn-primary btn-sm"
                                            onClick={async () => {
                                                await supabase.from('disease_sheets').update({ status: 'review' }).eq('id', sheet.id);
                                                loadSheets();
                                            }}
                                        >
                                            Soumettre en revue
                                        </button>
                                    )}
                                    {isSenior && sheet.status === 'review' && (
                                        <button
                                            className="btn btn-primary btn-sm"
                                            onClick={async () => {
                                                await supabase.from('disease_sheets').update({
                                                    status: 'published',
                                                    approved_by: profile.id,
                                                }).eq('id', sheet.id);
                                                loadSheets();
                                            }}
                                        >
                                            <CheckCircle size={12} /> Approuver & Publier
                                        </button>
                                    )}
                                    <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', marginLeft: 'auto', alignSelf: 'center' }}>
                                        Par {sheet.creator?.full_name || '?'} · {new Date(sheet.created_at).toLocaleDateString('fr-FR')}
                                    </span>
                                </div>
                            </div>
                        )}
                    </div>
                ))}
            </div>
        </div>
    );
}

function SheetForm({ sheet, onSave, onCancel }) {
    const [form, setForm] = useState({
        local_name: sheet?.local_name || '',
        scientific_name: sheet?.scientific_name || '',
        model_label: sheet?.model_label || '',
        culture: sheet?.culture || '',
        description: sheet?.description || '',
        severity: sheet?.severity || '',
        symptoms: (sheet?.symptoms || []).join('\n'),
        preventive_reco: (sheet?.preventive_reco || []).join('\n'),
        curative_reco: (sheet?.curative_reco || []).join('\n'),
        biological_reco: (sheet?.biological_reco || []).join('\n'),
        cultural_practices: (sheet?.cultural_practices || []).join('\n'),
    });

    function handleSubmit(e) {
        e.preventDefault();
        onSave({
            ...form,
            symptoms: form.symptoms.split('\n').filter(Boolean),
            preventive_reco: form.preventive_reco.split('\n').filter(Boolean),
            curative_reco: form.curative_reco.split('\n').filter(Boolean),
            biological_reco: form.biological_reco.split('\n').filter(Boolean),
            cultural_practices: form.cultural_practices.split('\n').filter(Boolean),
        });
    }

    return (
        <div className="card" style={{ marginBottom: 'var(--sp-lg)' }}>
            <h3 style={{ fontSize: '1rem', marginBottom: 'var(--sp-base)' }}>
                {sheet ? 'Modifier la fiche' : 'Nouvelle fiche maladie'}
            </h3>
            <form onSubmit={handleSubmit}>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--sp-md)' }}>
                    <div className="form-group">
                        <label className="form-label">Nom local *</label>
                        <input className="form-input" value={form.local_name} onChange={(e) => setForm({ ...form, local_name: e.target.value })} required />
                    </div>
                    <div className="form-group">
                        <label className="form-label">Nom scientifique</label>
                        <input className="form-input" value={form.scientific_name} onChange={(e) => setForm({ ...form, scientific_name: e.target.value })} />
                    </div>
                    <div className="form-group">
                        <label className="form-label">Culture *</label>
                        <input className="form-input" value={form.culture} onChange={(e) => setForm({ ...form, culture: e.target.value })} required />
                    </div>
                    <div className="form-group">
                        <label className="form-label">Label modèle</label>
                        <input className="form-input" value={form.model_label} onChange={(e) => setForm({ ...form, model_label: e.target.value })} placeholder="Ex: Tomato___Early_Blight" />
                    </div>
                </div>
                <div className="form-group">
                    <label className="form-label">Description</label>
                    <textarea className="form-input" rows={3} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
                </div>
                <div className="form-group">
                    <label className="form-label">Symptômes (un par ligne)</label>
                    <textarea className="form-input" rows={4} value={form.symptoms} onChange={(e) => setForm({ ...form, symptoms: e.target.value })} />
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--sp-md)' }}>
                    <div className="form-group">
                        <label className="form-label">Recommandations préventives</label>
                        <textarea className="form-input" rows={3} value={form.preventive_reco} onChange={(e) => setForm({ ...form, preventive_reco: e.target.value })} />
                    </div>
                    <div className="form-group">
                        <label className="form-label">Recommandations curatives</label>
                        <textarea className="form-input" rows={3} value={form.curative_reco} onChange={(e) => setForm({ ...form, curative_reco: e.target.value })} />
                    </div>
                </div>
                <div style={{ display: 'flex', gap: 'var(--sp-sm)' }}>
                    <button type="submit" className="btn btn-primary">Enregistrer</button>
                    <button type="button" className="btn btn-ghost" onClick={onCancel}>Annuler</button>
                </div>
            </form>
        </div>
    );
}
