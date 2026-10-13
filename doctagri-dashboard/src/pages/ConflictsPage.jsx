import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '../lib/supabase';
import { useAuth } from '../auth/useAuth';
import {
    AlertTriangle, Check, X, Edit3, MessageSquare,
} from 'lucide-react';
import { toast } from 'react-hot-toast';

export default function ConflictsPage() {
    const { isSenior } = useAuth();
    const [resolving, setResolving] = useState(null);

    // --- useQuery : fetch des conflits avec annotations jointes ---
    const { data: conflicts = [], isLoading } = useQuery({
        queryKey: ['conflicts'],
        queryFn: async () => {
            const { data, error } = await supabase
                .from('images')
                .select(`
                    *,
                    annotations (
                      *,
                      expert:profiles!annotations_expert_id_fkey (full_name, role)
                    )
                `)
                .eq('status', 'conflict')
                .order('priority', { ascending: false })
                .order('created_at', { ascending: true });

            if (error) throw error;
            return data || [];
        },
    });

    if (isLoading) {
        return <div className="loading-page"><div className="spinner" /></div>;
    }

    return (
        <div>
            <div className="page-header">
                <div>
                    <h1>Conflits d'annotation</h1>
                    <p>{conflicts.length} conflit{conflicts.length !== 1 ? 's' : ''} en attente</p>
                </div>
            </div>

            {conflicts.length === 0 ? (
                <div className="empty-state">
                    <Check size={48} />
                    <h3>Aucun conflit</h3>
                    <p>Tous les conflits ont été résolus. Bravo !</p>
                </div>
            ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--sp-lg)' }}>
                    {conflicts.map((img) => (
                        <ConflictCard
                            key={img.id}
                            image={img}
                            isSenior={isSenior}
                            resolving={resolving === img.id}
                            onResolve={() => setResolving(img.id)}
                            onResolved={() => setResolving(null)}
                        />
                    ))}
                </div>
            )}
        </div>
    );
}

function ConflictCard({ image, isSenior, resolving, onResolve, onResolved }) {
    const queryClient = useQueryClient();
    const [resolution, setResolution] = useState({ type: '', label: '', severity: '', comment: '' });

    const annotations = image.annotations || [];
    const ann1 = annotations[0];
    const ann2 = annotations[1];

    const imageUrl = image.file_path
        ? `${import.meta.env.VITE_SUPABASE_URL}/storage/v1/object/public/diagnosis-images/${image.file_path}`
        : null;

    // --- useMutation avec Optimistic Update ---
    const resolveMutation = useMutation({
        mutationFn: async (resolutionData) => {
            const { data, error } = await supabase.rpc('resolve_conflict', {
                p_image_id: image.id,
                p_final_label: resolutionData.label,
                p_final_severity: resolutionData.severity || null,
                p_resolution: resolutionData.type,
                p_comment: resolutionData.comment || null,
            });
            if (error) throw error;
            if (!data?.success) throw new Error('Échec de la résolution');
            return data;
        },
        // Optimistic Update : retirer le conflit de la liste immédiatement
        onMutate: async () => {
            // Annuler les refetch en cours pour ne pas écraser l'optimistic update
            await queryClient.cancelQueries({ queryKey: ['conflicts'] });

            // Sauvegarder l'état précédent pour rollback
            const previousConflicts = queryClient.getQueryData(['conflicts']);

            // Retirer immédiatement ce conflit de la liste
            queryClient.setQueryData(['conflicts'], (old) =>
                (old || []).filter((c) => c.id !== image.id)
            );

            return { previousConflicts };
        },
        onSuccess: () => {
            onResolved();
            toast.success('Conflit résolu !');
            // Invalider aussi la liste des images (si la page queue est en cache)
            queryClient.invalidateQueries({ queryKey: ['images'] });
        },
        onError: (error, _variables, context) => {
            // Rollback vers l'état précédent en cas d'erreur
            if (context?.previousConflicts) {
                queryClient.setQueryData(['conflicts'], context.previousConflicts);
            }
            toast.error(`Erreur: ${error.message}`);
        },
        onSettled: () => {
            // Refetch pour s'assurer que les données sont à jour
            queryClient.invalidateQueries({ queryKey: ['conflicts'] });
        },
    });

    function handleResolve() {
        if (!resolution.type || !resolution.label) {
            toast.error('Veuillez choisir une résolution et un label final.');
            return;
        }
        resolveMutation.mutate(resolution);
    }

    const differ = ann1 && ann2 && ann1.disease_label !== ann2.disease_label;

    return (
        <div className="card">
            <div style={{ display: 'flex', gap: 'var(--sp-lg)' }}>
                {/* Image thumbnail */}
                <div style={{
                    width: 180, height: 140,
                    background: '#111',
                    borderRadius: 'var(--r-md)',
                    overflow: 'hidden',
                    flexShrink: 0,
                }}>
                    {imageUrl && (
                        <img src={imageUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                    )}
                </div>

                {/* Comparison */}
                <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 'var(--sp-md)' }}>
                        <AlertTriangle size={16} style={{ color: 'var(--warning)' }} />
                        <span style={{ fontWeight: 600 }}>
                            {image.culture && `${image.culture} · `}
                            ID: {image.id.slice(0, 8)}
                        </span>
                    </div>

                    <div className="conflict-comparison">
                        {/* Expert 1 */}
                        <div className={`conflict-side ${differ ? 'conflict-side--different' : ''}`}>
                            <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', marginBottom: 4 }}>
                                Expert 1: {ann1?.expert?.full_name || '?'}
                            </div>
                            <div style={{ fontWeight: 600, fontSize: '0.9rem' }}>
                                {ann1?.disease_label?.replace(/_/g, ' ') || '–'}
                            </div>
                            {ann1?.severity && (
                                <span className={`badge badge--${ann1.severity}`} style={{ marginTop: 4 }}>
                                    {ann1.severity}
                                </span>
                            )}
                            {ann1?.comment && (
                                <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', marginTop: 4 }}>
                                    <MessageSquare size={10} /> {ann1.comment}
                                </div>
                            )}
                        </div>

                        <div className="conflict-vs">VS</div>

                        {/* Expert 2 */}
                        <div className={`conflict-side ${differ ? 'conflict-side--different' : ''}`}>
                            <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', marginBottom: 4 }}>
                                Expert 2: {ann2?.expert?.full_name || '?'}
                            </div>
                            <div style={{ fontWeight: 600, fontSize: '0.9rem' }}>
                                {ann2?.disease_label?.replace(/_/g, ' ') || '–'}
                            </div>
                            {ann2?.severity && (
                                <span className={`badge badge--${ann2.severity}`} style={{ marginTop: 4 }}>
                                    {ann2.severity}
                                </span>
                            )}
                            {ann2?.comment && (
                                <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', marginTop: 4 }}>
                                    <MessageSquare size={10} /> {ann2.comment}
                                </div>
                            )}
                        </div>
                    </div>

                    {/* Resolution form */}
                    {isSenior && resolving && (
                        <div style={{ marginTop: 'var(--sp-base)', padding: 'var(--sp-md)', background: 'var(--bg)', borderRadius: 'var(--r-md)' }}>
                            <div style={{ display: 'flex', gap: 'var(--sp-sm)', marginBottom: 'var(--sp-md)' }}>
                                <button
                                    className={`btn btn-sm ${resolution.type === 'accepted_1' ? 'btn-primary' : 'btn-ghost'}`}
                                    onClick={() => setResolution({ ...resolution, type: 'accepted_1', label: ann1?.disease_label || '' })}
                                >
                                    <Check size={12} /> Expert 1
                                </button>
                                <button
                                    className={`btn btn-sm ${resolution.type === 'accepted_2' ? 'btn-primary' : 'btn-ghost'}`}
                                    onClick={() => setResolution({ ...resolution, type: 'accepted_2', label: ann2?.disease_label || '' })}
                                >
                                    <Check size={12} /> Expert 2
                                </button>
                                <button
                                    className={`btn btn-sm ${resolution.type === 'modified' ? 'btn-accent' : 'btn-ghost'}`}
                                    onClick={() => setResolution({ ...resolution, type: 'modified' })}
                                >
                                    <Edit3 size={12} /> Modifier
                                </button>
                                <button
                                    className={`btn btn-sm ${resolution.type === 'rejected' ? 'btn-ghost' : 'btn-ghost'}`}
                                    onClick={() => setResolution({ ...resolution, type: 'rejected', label: 'REJECTED' })}
                                    style={resolution.type === 'rejected' ? { background: 'var(--danger)', color: 'white' } : {}}
                                >
                                    <X size={12} /> Rejeter
                                </button>
                            </div>

                            {resolution.type === 'modified' && (
                                <div className="form-group">
                                    <label className="form-label">Label final</label>
                                    <input
                                        type="text"
                                        className="form-input"
                                        value={resolution.label}
                                        onChange={(e) => setResolution({ ...resolution, label: e.target.value })}
                                        placeholder="Label corrigé..."
                                    />
                                </div>
                            )}

                            <div className="form-group">
                                <label className="form-label">Commentaire décisionnel</label>
                                <textarea
                                    className="form-input"
                                    rows={2}
                                    value={resolution.comment}
                                    onChange={(e) => setResolution({ ...resolution, comment: e.target.value })}
                                    placeholder="Justification de la décision..."
                                />
                            </div>

                            <button className="btn btn-primary" onClick={handleResolve} disabled={resolveMutation.isPending}>
                                {resolveMutation.isPending ? <div className="spinner" style={{ width: 14, height: 14, borderWidth: 2 }} /> : null}
                                Clôturer le conflit
                            </button>
                        </div>
                    )}

                    {isSenior && !resolving && (
                        <button className="btn btn-accent btn-sm" onClick={onResolve} style={{ marginTop: 'var(--sp-md)' }}>
                            Arbitrer ce conflit
                        </button>
                    )}
                </div>
            </div>
        </div>
    );
}
