import { useEffect, useState, useCallback, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useAuth } from '../auth/AuthContext';
import {
    ZoomIn, ZoomOut, RotateCcw, Check, X, ChevronRight,
    MapPin, Calendar, Smartphone, Cloud, Hash, Leaf, AlertTriangle,
    Send, Clock, Flag,
} from 'lucide-react';
import { toast } from 'react-hot-toast';

export default function AnnotationPage() {
    const { id } = useParams();
    const navigate = useNavigate();
    const { profile } = useAuth();
    const [image, setImage] = useState(null);
    const [taxonomy, setTaxonomy] = useState([]);
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [zoom, setZoom] = useState(1);
    const [startTime] = useState(Date.now());
    const formRef = useRef(null);

    // Annotation state
    const [annotation, setAnnotation] = useState({
        disease_label: '',
        severity: '',
        additional_labels: [],
        is_healthy: false,
        is_unusable: false,
        comment: '',
        certainty: 3,
    });

    // Load image + taxonomy
    useEffect(() => {
        async function load() {
            const [imgRes, taxRes] = await Promise.all([
                supabase.from('images').select('*').eq('id', id).single(),
                supabase.from('taxonomy').select('*').eq('is_active', true).order('culture').order('display_name'),
            ]);

            if (imgRes.data) setImage(imgRes.data);
            if (taxRes.data) setTaxonomy(taxRes.data);

            // Pre-fill from ML prediction if available
            if (imgRes.data?.ml_predicted_label) {
                setAnnotation(prev => ({
                    ...prev,
                    disease_label: imgRes.data.ml_predicted_label,
                }));
            }

            setLoading(false);
        }
        load();
    }, [id]);

    // Keyboard shortcuts
    useEffect(() => {
        function handleKeyDown(e) {
            if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.tagName === 'SELECT') return;
            switch (e.key) {
                case '+': case '=': setZoom(z => Math.min(z + 0.25, 4)); break;
                case '-': setZoom(z => Math.max(z - 0.25, 0.25)); break;
                case '0': setZoom(1); break;
                case 'Enter':
                    if (e.ctrlKey) handleSubmit();
                    break;
                case 'Escape': navigate('/queue'); break;
            }
        }
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, [annotation, navigate]);

    const handleFieldChange = useCallback((field, value) => {
        setAnnotation(prev => ({ ...prev, [field]: value }));
    }, []);

    function handleAcceptPrediction() {
        if (image?.ml_predicted_label) {
            setAnnotation(prev => ({
                ...prev,
                disease_label: image.ml_predicted_label,
                is_healthy: image.ml_predicted_label.toLowerCase().includes('healthy'),
            }));
        }
    }

    function handleCorrectPrediction() {
        setAnnotation(prev => ({ ...prev, disease_label: '' }));
        // Focus on the select
        setTimeout(() => {
            const sel = document.querySelector('#disease-select');
            if (sel) sel.focus();
        }, 100);
    }

    async function handleSubmit() {
        if (!annotation.disease_label && !annotation.is_unusable) {
            toast.error('Veuillez sélectionner un diagnostic ou marquer l\'image comme non exploitable.');
            return;
        }

        setSaving(true);
        const annotationTime = Date.now() - startTime;

        const { error } = await supabase.from('annotations').insert({
            image_id: id,
            expert_id: profile.id,
            disease_label: annotation.is_unusable ? 'UNUSABLE' : annotation.disease_label,
            severity: annotation.is_unusable ? null : annotation.severity || null,
            additional_labels: annotation.additional_labels,
            is_healthy: annotation.is_healthy,
            is_unusable: annotation.is_unusable,
            comment: annotation.comment || null,
            certainty: annotation.certainty,
            annotation_time_ms: annotationTime,
            taxonomy_version: 1,
        });

        if (error) {
            if (error.code === '23505') {
                toast.error('Vous avez déjà annoté cette image.');
            } else {
                toast.error(`Erreur: ${error.message}`);
            }
            setSaving(false);
            return;
        }

        // Log audit
        await supabase.rpc('log_audit', {
            p_action: 'annotate',
            p_entity_type: 'image',
            p_entity_id: id,
            p_new: annotation,
        });

        toast.success("Annotation enregistrée avec succès !");
        setSaving(false);
        handleNext();
    }

    async function handleNext() {
        const { data, error } = await supabase.rpc('get_next_image', {
            p_expert_id: profile.id,
        });
        if (!error && data) {
            navigate(`/annotation/${data}`, { replace: true });
        } else {
            navigate('/queue');
        }
    }

    function handleSkip() {
        handleNext();
    }

    if (loading) {
        return (
            <div className="loading-page">
                <div className="spinner" />
            </div>
        );
    }

    if (!image) {
        return (
            <div className="empty-state">
                <AlertTriangle size={48} />
                <h3>Image introuvable</h3>
                <button className="btn btn-ghost" onClick={() => navigate('/queue')}>
                    Retour à la file
                </button>
            </div>
        );
    }

    const imageUrl = image.file_path
        ? `${import.meta.env.VITE_SUPABASE_URL}/storage/v1/object/public/diagnosis-images/${image.file_path}`
        : null;

    // Group taxonomy by culture (if image has a culture, only show that culture's taxonomy)
    const taxonomyByCulture = taxonomy.reduce((acc, t) => {
        if (image.culture && t.culture !== image.culture) return acc;
        if (!acc[t.culture]) acc[t.culture] = [];
        acc[t.culture].push(t);
        return acc;
    }, {});

    return (
        <div className="annotation-layout">
            {/* ─── Left: Image Panel ─── */}
            <div className="annotation-image-panel">
                {imageUrl ? (
                    <img
                        src={imageUrl}
                        alt="Image à annoter"
                        style={{ transform: `scale(${zoom})` }}
                        draggable={false}
                    />
                ) : (
                    <div className="empty-state">
                        <Leaf size={48} />
                        <p>Pas d'image disponible</p>
                    </div>
                )}

                <div className="annotation-image-controls">
                    <button className="btn-icon" onClick={() => setZoom(z => Math.min(z + 0.25, 4))} title="Zoom in (+)">
                        <ZoomIn size={16} />
                    </button>
                    <button className="btn-icon" onClick={() => setZoom(z => Math.max(z - 0.25, 0.25))} title="Zoom out (-)">
                        <ZoomOut size={16} />
                    </button>
                    <button className="btn-icon" onClick={() => setZoom(1)} title="Reset (0)">
                        <RotateCcw size={16} />
                    </button>
                    <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', padding: '0 8px' }}>
                        {Math.round(zoom * 100)}%
                    </span>
                </div>
            </div>

            {/* ─── Right: Annotation Form ─── */}
            <div className="annotation-form-panel" ref={formRef}>
                {/* Metadata */}
                <div className="card" style={{ padding: 'var(--sp-md)' }}>
                    <span className="card__title" style={{ fontSize: '0.7rem', marginBottom: 8, display: 'block' }}>
                        Métadonnées
                    </span>
                    <dl className="metadata-grid">
                        {image.latitude && (
                            <>
                                <dt><MapPin size={12} /> GPS</dt>
                                <dd>{image.latitude.toFixed(4)}, {image.longitude?.toFixed(4)}</dd>
                            </>
                        )}
                        {image.capture_date && (
                            <>
                                <dt><Calendar size={12} /> Date</dt>
                                <dd>{new Date(image.capture_date).toLocaleDateString('fr-FR')}</dd>
                            </>
                        )}
                        {image.culture && (
                            <>
                                <dt><Leaf size={12} /> Culture</dt>
                                <dd>{image.culture}</dd>
                            </>
                        )}
                        {image.device_model && (
                            <>
                                <dt><Smartphone size={12} /> Appareil</dt>
                                <dd>{image.device_model}</dd>
                            </>
                        )}
                        {image.weather_data && (
                            <>
                                <dt><Cloud size={12} /> Météo</dt>
                                <dd>{JSON.stringify(image.weather_data).slice(0, 30)}…</dd>
                            </>
                        )}
                        <dt><Hash size={12} /> ID</dt>
                        <dd style={{ fontFamily: 'monospace', fontSize: '0.7rem' }}>{image.id.slice(0, 12)}</dd>
                    </dl>
                </div>

                {/* Pre-annotation ML */}
                {image.ml_predicted_label && (
                    <div className="pre-annotation-box">
                        <div className="pre-annotation-box__label">Pré-annotation ML</div>
                        <div className="pre-annotation-box__prediction">
                            {image.ml_predicted_label.replace(/_/g, ' ')}
                        </div>
                        {image.ml_confidence && (
                            <div className="pre-annotation-box__confidence">
                                Confiance: {Math.round(image.ml_confidence * 100)}%
                            </div>
                        )}
                        <div className="pre-annotation-box__actions">
                            <button className="btn btn-primary btn-sm" onClick={handleAcceptPrediction}>
                                <Check size={14} /> Accepter
                            </button>
                            <button className="btn btn-ghost btn-sm" onClick={handleCorrectPrediction}>
                                <X size={14} /> Corriger
                            </button>
                        </div>
                    </div>
                )}

                {/* Classification */}
                <div className="card" style={{ padding: 'var(--sp-md)' }}>
                    <span className="card__title" style={{ fontSize: '0.7rem', marginBottom: 8, display: 'block' }}>
                        Classification
                    </span>

                    {/* Unusable toggle */}
                    <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: '0.85rem', cursor: 'pointer', marginBottom: 'var(--sp-md)' }}>
                        <input
                            type="checkbox"
                            checked={annotation.is_unusable}
                            onChange={(e) => handleFieldChange('is_unusable', e.target.checked)}
                        />
                        <Flag size={14} style={{ color: 'var(--danger)' }} />
                        Image non exploitable
                    </label>

                    {!annotation.is_unusable && (
                        <>
                            {/* Disease select */}
                            <div className="form-group">
                                <label className="form-label">Diagnostic</label>
                                <select
                                    id="disease-select"
                                    className="form-input form-select"
                                    value={annotation.disease_label}
                                    onChange={(e) => {
                                        const val = e.target.value;
                                        handleFieldChange('disease_label', val);
                                        handleFieldChange('is_healthy', val.toLowerCase().includes('healthy'));
                                    }}
                                >
                                    <option value="">— Sélectionner —</option>
                                    {Object.entries(taxonomyByCulture).map(([culture, items]) => (
                                        <optgroup key={culture} label={culture}>
                                            {items.map(t => (
                                                <option key={t.model_label} value={t.model_label}>
                                                    {t.display_name}
                                                </option>
                                            ))}
                                        </optgroup>
                                    ))}
                                </select>
                            </div>

                            {/* Severity */}
                            {!annotation.is_healthy && annotation.disease_label && (
                                <div className="form-group">
                                    <label className="form-label">Sévérité</label>
                                    <div style={{ display: 'flex', gap: 'var(--sp-sm)' }}>
                                        {['léger', 'modéré', 'sévère'].map((sev) => (
                                            <button
                                                key={sev}
                                                type="button"
                                                className={`btn btn-sm ${annotation.severity === sev ? 'btn-primary' : 'btn-ghost'}`}
                                                onClick={() => handleFieldChange('severity', sev)}
                                                style={annotation.severity === sev ? {
                                                    background: sev === 'léger' ? 'var(--healthy)' :
                                                        sev === 'modéré' ? 'var(--warning)' : 'var(--danger)',
                                                } : {}}
                                            >
                                                {sev}
                                            </button>
                                        ))}
                                    </div>
                                </div>
                            )}
                        </>
                    )}
                </div>

                {/* Comment & Certainty */}
                <div className="card" style={{ padding: 'var(--sp-md)' }}>
                    <div className="form-group">
                        <label className="form-label">Commentaire technique</label>
                        <textarea
                            className="form-input"
                            rows={3}
                            value={annotation.comment}
                            onChange={(e) => handleFieldChange('comment', e.target.value)}
                            placeholder="Observations, doutes, particularités…"
                        />
                    </div>

                    <div className="form-group" style={{ marginBottom: 0 }}>
                        <label className="form-label">
                            Niveau de certitude: <strong>{annotation.certainty}/5</strong>
                        </label>
                        <input
                            type="range"
                            min={1}
                            max={5}
                            value={annotation.certainty}
                            onChange={(e) => handleFieldChange('certainty', parseInt(e.target.value))}
                            style={{ width: '100%', accentColor: 'var(--sage)' }}
                        />
                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.7rem', color: 'var(--text-muted)' }}>
                            <span>Incertain</span>
                            <span>Certain</span>
                        </div>
                    </div>
                </div>

                {/* Actions */}
                <div style={{ display: 'flex', gap: 'var(--sp-sm)', marginTop: 'auto' }}>
                    <button
                        className="btn btn-primary"
                        onClick={handleSubmit}
                        disabled={saving}
                        style={{ flex: 1, justifyContent: 'center' }}
                    >
                        {saving ? <div className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }} /> : <Send size={16} />}
                        Valider <span className="kbd">Ctrl+↵</span>
                    </button>
                    <button
                        className="btn btn-ghost"
                        onClick={handleSkip}
                        title="Passer à la suivante"
                    >
                        <ChevronRight size={16} />
                    </button>
                </div>

                {/* Timer */}
                <Timer annotation={annotation} startTime={startTime} />
            </div>
        </div>
    );
}

function Timer({ startTime }) {
    const [elapsed, setElapsed] = useState(0);

    useEffect(() => {
        const interval = setInterval(() => {
            setElapsed(Math.round((Date.now() - startTime) / 1000));
        }, 1000);
        return () => clearInterval(interval);
    }, [startTime]);

    const color = elapsed < 20 ? 'var(--healthy)' : elapsed < 40 ? 'var(--warning)' : 'var(--danger)';

    return (
        <div style={{
            textAlign: 'center',
            padding: 'var(--sp-sm)',
            fontSize: '0.8rem',
            color,
        }}>
            <Clock size={12} style={{ marginRight: 4, verticalAlign: -1 }} />
            {elapsed}s
            {elapsed > 20 && <span style={{ marginLeft: 4, opacity: 0.7 }}>⚡ Objectif: &lt;20s</span>}
        </div>
    );
}
