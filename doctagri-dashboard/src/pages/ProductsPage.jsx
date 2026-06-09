import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../auth/AuthContext';
import { Plus, Edit3, Package, Search } from 'lucide-react';

export default function ProductsPage() {
    const { profile } = useAuth();
    const [products, setProducts] = useState([]);
    const [loading, setLoading] = useState(true);
    const [editing, setEditing] = useState(null);
    const [creating, setCreating] = useState(false);
    const [filter, setFilter] = useState('');

    useEffect(() => { loadProducts(); }, []);

    async function loadProducts() {
        const { data } = await supabase.from('products').select('*').order('commercial_name');
        if (data) setProducts(data);
        setLoading(false);
    }

    const filtered = products.filter(p =>
        p.commercial_name.toLowerCase().includes(filter.toLowerCase()) ||
        (p.active_substance || '').toLowerCase().includes(filter.toLowerCase())
    );

    if (loading) return <div className="loading-page"><div className="spinner" /></div>;

    return (
        <div>
            <div className="page-header">
                <div>
                    <h1>Produits phytosanitaires</h1>
                    <p>{products.length} produit{products.length > 1 ? 's' : ''}</p>
                </div>
                <button className="btn btn-primary" onClick={() => setCreating(true)}>
                    <Plus size={16} /> Ajouter
                </button>
            </div>

            <div className="filters-bar">
                <Search size={16} style={{ color: 'var(--text-muted)' }} />
                <input className="form-input" placeholder="Rechercher..." value={filter}
                    onChange={(e) => setFilter(e.target.value)} style={{ flex: 1 }} />
            </div>

            {(creating || editing) && (
                <ProductForm product={editing}
                    onSave={async (data) => {
                        if (editing) await supabase.from('products').update(data).eq('id', editing.id);
                        else await supabase.from('products').insert({ ...data, created_by: profile.id });
                        setCreating(false); setEditing(null); loadProducts();
                    }}
                    onCancel={() => { setCreating(false); setEditing(null); }}
                />
            )}

            <div className="table-container">
                <table className="table">
                    <thead><tr>
                        <th>Nom</th><th>Substance</th><th>Dosage</th><th>Délai récolte</th><th>Toxicité</th><th>Conforme</th><th>Actions</th>
                    </tr></thead>
                    <tbody>
                        {filtered.map((p) => (
                            <tr key={p.id}>
                                <td style={{ fontWeight: 600 }}><Package size={14} style={{ color: 'var(--sage)', marginRight: 6, verticalAlign: -2 }} />{p.commercial_name}</td>
                                <td>{p.active_substance || '–'}</td>
                                <td>{p.dosage || '–'}</td>
                                <td>{p.days_before_harvest ? `${p.days_before_harvest}j` : '–'}</td>
                                <td>{p.toxicity_level && <span className={`badge ${p.toxicity_level === 'faible' ? 'badge--validated' : p.toxicity_level === 'modéré' ? 'badge--annotating' : 'badge--rejected'}`}>{p.toxicity_level}</span>}</td>
                                <td>{p.local_compliance ? '✅' : '❌'}</td>
                                <td><button className="btn-icon" onClick={() => setEditing(p)}><Edit3 size={14} /></button></td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        </div>
    );
}

function ProductForm({ product, onSave, onCancel }) {
    const [f, setF] = useState({
        commercial_name: product?.commercial_name || '',
        active_substance: product?.active_substance || '',
        dosage: product?.dosage || '',
        frequency: product?.frequency || '',
        days_before_harvest: product?.days_before_harvest || '',
        toxicity_level: product?.toxicity_level || '',
        precautions: product?.precautions || '',
        local_compliance: product?.local_compliance ?? true,
    });

    return (
        <div className="card" style={{ marginBottom: 'var(--sp-lg)' }}>
            <h3 style={{ fontSize: '1rem', marginBottom: 'var(--sp-base)' }}>{product ? 'Modifier' : 'Nouveau produit'}</h3>
            <form onSubmit={(e) => { e.preventDefault(); onSave({ ...f, days_before_harvest: f.days_before_harvest ? parseInt(f.days_before_harvest) : null }); }}>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--sp-md)' }}>
                    <div className="form-group"><label className="form-label">Nom commercial *</label><input className="form-input" value={f.commercial_name} onChange={(e) => setF({ ...f, commercial_name: e.target.value })} required /></div>
                    <div className="form-group"><label className="form-label">Substance active</label><input className="form-input" value={f.active_substance} onChange={(e) => setF({ ...f, active_substance: e.target.value })} /></div>
                    <div className="form-group"><label className="form-label">Dosage</label><input className="form-input" value={f.dosage} onChange={(e) => setF({ ...f, dosage: e.target.value })} /></div>
                    <div className="form-group"><label className="form-label">Toxicité</label>
                        <select className="form-input form-select" value={f.toxicity_level} onChange={(e) => setF({ ...f, toxicity_level: e.target.value })}>
                            <option value="">—</option><option value="faible">Faible</option><option value="modéré">Modéré</option><option value="élevé">Élevé</option>
                        </select>
                    </div>
                </div>
                <div className="form-group"><label className="form-label">Précautions</label><textarea className="form-input" rows={2} value={f.precautions} onChange={(e) => setF({ ...f, precautions: e.target.value })} /></div>
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: '0.85rem', marginBottom: 'var(--sp-base)' }}>
                    <input type="checkbox" checked={f.local_compliance} onChange={(e) => setF({ ...f, local_compliance: e.target.checked })} /> Conforme réglementations locales
                </label>
                <div style={{ display: 'flex', gap: 'var(--sp-sm)' }}>
                    <button type="submit" className="btn btn-primary">Enregistrer</button>
                    <button type="button" className="btn btn-ghost" onClick={onCancel}>Annuler</button>
                </div>
            </form>
        </div>
    );
}
