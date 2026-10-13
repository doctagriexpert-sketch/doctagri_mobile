import { useState, useRef, useEffect, useCallback } from 'react';
import { useQuery, useMutation } from '@tanstack/react-query';
import { useVirtualizer } from '@tanstack/react-virtual';
import { supabase } from '../lib/supabase';
import { useAuth } from '../auth/useAuth';
import { Link, useNavigate } from 'react-router-dom';
import { toast } from 'react-hot-toast';
import {
    Image, Filter, Search, ChevronLeft, ChevronRight, PlayCircle, Loader2,
} from 'lucide-react';

const PAGE_SIZE = 24;
const CARD_MIN_WIDTH = 240;
const GAP = 14; // --sp-base
const ROW_HEIGHT = 260; // 160 (image) + ~80 (content) + 20 (margin)

export default function AnnotationQueuePage() {
    const { profile } = useAuth();
    const navigate = useNavigate();
    const [page, setPage] = useState(0);
    const [filters, setFilters] = useState({
        status: '',
        culture: '',
        search: '',
    });

    // --- Mesure dynamique de la largeur du conteneur ---
    const scrollRef = useRef(null);
    const [columnCount, setColumnCount] = useState(4);

    const updateColumns = useCallback(() => {
        if (!scrollRef.current) return;
        const width = scrollRef.current.offsetWidth;
        const cols = Math.max(1, Math.floor((width + GAP) / (CARD_MIN_WIDTH + GAP)));
        setColumnCount(cols);
    }, []);

    useEffect(() => {
        updateColumns();
        const el = scrollRef.current;
        if (!el) return;
        const observer = new ResizeObserver(updateColumns);
        observer.observe(el);
        return () => observer.disconnect();
    }, [updateColumns]);

    // --- useQuery : fetch images avec pagination + filtres ---
    const { data: queryData, isLoading: loading } = useQuery({
        queryKey: ['images', page, filters],
        queryFn: async () => {
            let query = supabase
                .from('images')
                .select('*', { count: 'exact' })
                .order('priority', { ascending: false })
                .order('created_at', { ascending: true })
                .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);

            if (filters.status) query = query.eq('status', filters.status);
            if (filters.culture) query = query.eq('culture', filters.culture);
            if (filters.search) query = query.ilike('id', `%${filters.search}%`);

            const { data, count, error } = await query;
            if (error) throw error;
            return { images: data || [], total: count || 0 };
        },
    });

    const images = queryData?.images || [];
    const total = queryData?.total || 0;

    // --- Grouper les images en lignes de N colonnes ---
    const rows = [];
    for (let i = 0; i < images.length; i += columnCount) {
        rows.push(images.slice(i, i + columnCount));
    }

    // --- Virtualizer : ne rendre que les lignes visibles ---
    const virtualizer = useVirtualizer({
        count: rows.length,
        getScrollElement: () => scrollRef.current,
        estimateSize: () => ROW_HEIGHT,
        overscan: 2,
    });

    // --- useMutation : annoter prochaine image ---
    const nextImageMutation = useMutation({
        mutationFn: async () => {
            const { data, error } = await supabase.rpc('get_next_image', {
                p_expert_id: profile.id,
            });
            if (error) throw error;
            return data;
        },
        onSuccess: (data) => {
            if (data) {
                navigate(`/annotation/${data}`);
            } else {
                toast.error('Aucune image disponible pour annotation.');
            }
        },
        onError: () => {
            toast.error('Erreur lors de la récupération de la prochaine image.');
        },
    });

    const totalPages = Math.ceil(total / PAGE_SIZE);

    const statusOptions = [
        { value: '', label: 'Tous les statuts' },
        { value: 'pending', label: 'Non annotées' },
        { value: 'annotating', label: 'En cours' },
        { value: 'conflict', label: 'En conflit' },
        { value: 'validated', label: 'Validées' },
        { value: 'rejected', label: 'Rejetées' },
    ];

    return (
        <div>
            <div className="page-header">
                <div>
                    <h1>File d'annotation</h1>
                    <p>{total} images au total</p>
                </div>
                <button
                    className="btn btn-accent btn-lg"
                    onClick={() => nextImageMutation.mutate()}
                    disabled={nextImageMutation.isPending}
                >
                    {nextImageMutation.isPending ? <Loader2 size={18} className="spin" /> : <PlayCircle size={18} />}
                    Annoter prochaine image
                </button>
            </div>

            {/* Filters */}
            <div className="filters-bar">
                <Filter size={16} style={{ color: 'var(--text-muted)' }} />
                <select
                    className="form-input form-select"
                    value={filters.status}
                    onChange={(e) => { setFilters({ ...filters, status: e.target.value }); setPage(0); }}
                >
                    {statusOptions.map(({ value, label }) => (
                        <option key={value} value={value}>{label}</option>
                    ))}
                </select>
                <input
                    type="text"
                    className="form-input"
                    placeholder="Culture..."
                    value={filters.culture}
                    onChange={(e) => { setFilters({ ...filters, culture: e.target.value }); setPage(0); }}
                    style={{ width: 150 }}
                />
                <div style={{ position: 'relative', flex: 1 }}>
                    <Search size={14} style={{ position: 'absolute', left: 10, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                    <input
                        type="text"
                        className="form-input"
                        placeholder="Recherche par ID..."
                        value={filters.search}
                        onChange={(e) => { setFilters({ ...filters, search: e.target.value }); setPage(0); }}
                        style={{ paddingLeft: 32 }}
                    />
                </div>
            </div>

            {/* Virtualized Images Grid */}
            {loading ? (
                <div className="loading-page" style={{ minHeight: 300 }}>
                    <div className="spinner" />
                </div>
            ) : images.length === 0 ? (
                <div className="empty-state">
                    <Image size={48} />
                    <h3>Aucune image</h3>
                    <p>Ajustez les filtres ou revenez plus tard</p>
                </div>
            ) : (
                <>
                    <div
                        ref={scrollRef}
                        style={{
                            height: Math.min(rows.length * ROW_HEIGHT, 80 * window.innerHeight / 100),
                            overflow: 'auto',
                        }}
                    >
                        <div
                            style={{
                                height: virtualizer.getTotalSize(),
                                width: '100%',
                                position: 'relative',
                            }}
                        >
                            {virtualizer.getVirtualItems().map((virtualRow) => {
                                const rowImages = rows[virtualRow.index];
                                return (
                                    <div
                                        key={virtualRow.index}
                                        style={{
                                            position: 'absolute',
                                            top: 0,
                                            left: 0,
                                            width: '100%',
                                            height: virtualRow.size,
                                            transform: `translateY(${virtualRow.start}px)`,
                                            display: 'grid',
                                            gridTemplateColumns: `repeat(${columnCount}, 1fr)`,
                                            gap: GAP,
                                        }}
                                    >
                                        {rowImages.map((img) => (
                                            <ImageCard key={img.id} img={img} />
                                        ))}
                                    </div>
                                );
                            })}
                        </div>
                    </div>

                    {/* Pagination */}
                    {totalPages > 1 && (
                        <div className="pagination">
                            <button
                                className="btn-icon"
                                onClick={() => setPage(Math.max(0, page - 1))}
                                disabled={page === 0}
                            >
                                <ChevronLeft size={16} />
                            </button>
                            <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
                                Page {page + 1} / {totalPages}
                            </span>
                            <button
                                className="btn-icon"
                                onClick={() => setPage(Math.min(totalPages - 1, page + 1))}
                                disabled={page >= totalPages - 1}
                            >
                                <ChevronRight size={16} />
                            </button>
                        </div>
                    )}
                </>
            )}
        </div>
    );
}

function ImageCard({ img }) {
    return (
        <Link
            to={`/annotation/${img.id}`}
            style={{ textDecoration: 'none' }}
        >
            <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
                <div style={{
                    height: 160,
                    background: '#111',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    overflow: 'hidden',
                }}>
                    {img.file_path ? (
                        <img
                            src={`${import.meta.env.VITE_SUPABASE_URL}/storage/v1/object/public/diagnosis-images/${img.file_path}`}
                            alt="Crop"
                            loading="lazy"
                            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                            onError={(e) => { e.target.style.display = 'none'; }}
                        />
                    ) : (
                        <Image size={32} style={{ color: 'var(--text-muted)' }} />
                    )}
                </div>
                <div style={{ padding: 'var(--sp-md)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <span className={`badge badge--${img.status}`}>{img.status}</span>
                        {img.culture && (
                            <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{img.culture}</span>
                        )}
                    </div>
                    <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', marginTop: 6 }}>
                        {img.id.slice(0, 8)}…
                    </div>
                    {img.ml_predicted_label && (
                        <div style={{ fontSize: '0.75rem', color: 'var(--sage)', marginTop: 4 }}>
                            ML: {img.ml_predicted_label.replace(/_/g, ' ')}
                            {img.ml_confidence && ` (${Math.round(img.ml_confidence * 100)}%)`}
                        </div>
                    )}
                </div>
            </div>
        </Link>
    );
}
