import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import ConflictsPage from '../pages/ConflictsPage';

// ─── Hoisted mocks (available before vi.mock factory runs) ─────
const {
    mockRpc,
    mockOrderCreated,
    mockAuthValue,
} = vi.hoisted(() => {
    const mockRpc = vi.fn();
    const mockOrderCreated = vi.fn();
    const mockAuthValue = { current: {} };
    return { mockRpc, mockOrderCreated, mockAuthValue };
});

// ─── Mock Supabase ─────────────────────────────────────────────
vi.mock('../lib/supabase', () => {
    const mockSelect = vi.fn();
    const mockEq = vi.fn();
    const mockOrderPriority = vi.fn();

    mockSelect.mockReturnValue({ eq: mockEq });
    mockEq.mockReturnValue({ order: mockOrderPriority });
    mockOrderPriority.mockReturnValue({ order: mockOrderCreated });

    return {
        supabase: {
            from: vi.fn(() => ({ select: mockSelect })),
            rpc: mockRpc,
        },
    };
});

// ─── Mock AuthContext ──────────────────────────────────────────
vi.mock('../auth/AuthContext', () => ({
    useAuth: () => mockAuthValue.current,
}));

// ─── Helpers ───────────────────────────────────────────────────
function createQueryClient() {
    return new QueryClient({
        defaultOptions: {
            queries: { retry: false },
        },
    });
}

function renderWithProviders(ui) {
    const queryClient = createQueryClient();
    return render(
        <QueryClientProvider client={queryClient}>
            {ui}
        </QueryClientProvider>
    );
}

const CONFLICT_FIXTURES = [
    {
        id: 'aaaa-bbbb-cccc-dddd',
        status: 'conflict',
        culture: 'Tomate',
        file_path: 'images/test.jpg',
        priority: 3,
        annotations: [
            {
                id: 'ann-1',
                disease_label: 'Tomato___Late_Blight',
                severity: 'sévère',
                comment: 'Feuilles brunes',
                expert: { full_name: 'Dr. Amadou', role: 'expert' },
            },
            {
                id: 'ann-2',
                disease_label: 'Tomato___Early_Blight',
                severity: 'modéré',
                comment: null,
                expert: { full_name: 'Dr. Fatou', role: 'expert' },
            },
        ],
    },
];

// ─── Tests ─────────────────────────────────────────────────────
describe('ConflictsPage', () => {
    beforeEach(() => {
        vi.clearAllMocks();
        mockAuthValue.current = {
            user: { id: 'senior-id' },
            profile: { role: 'senior' },
            isSenior: true,
            isAdmin: false,
        };
        mockOrderCreated.mockResolvedValue({ data: CONFLICT_FIXTURES, error: null });
    });

    it('affiche le spinner pendant le chargement', () => {
        mockOrderCreated.mockReturnValue(new Promise(() => {}));
        renderWithProviders(<ConflictsPage />);
        expect(document.querySelector('.spinner')).toBeInTheDocument();
    });

    it('affiche "Aucun conflit" quand la liste est vide', async () => {
        mockOrderCreated.mockResolvedValue({ data: [], error: null });
        renderWithProviders(<ConflictsPage />);

        await waitFor(() => {
            expect(screen.getByText('Aucun conflit')).toBeInTheDocument();
        });
        expect(screen.getByText('Tous les conflits ont été résolus. Bravo !')).toBeInTheDocument();
    });

    it('affiche les conflits avec les noms des experts', async () => {
        renderWithProviders(<ConflictsPage />);

        await waitFor(() => {
            expect(screen.getByText(/Dr\. Amadou/)).toBeInTheDocument();
        });
        expect(screen.getByText(/Dr\. Fatou/)).toBeInTheDocument();
    });

    it('affiche les labels de maladie des deux annotations', async () => {
        renderWithProviders(<ConflictsPage />);

        await waitFor(() => {
            expect(screen.getByText('Tomato Late Blight')).toBeInTheDocument();
        });
        expect(screen.getByText('Tomato Early Blight')).toBeInTheDocument();
    });

    it('le bouton "Arbitrer ce conflit" ouvre le formulaire de résolution', async () => {
        const user = userEvent.setup();
        renderWithProviders(<ConflictsPage />);

        await waitFor(() => {
            expect(screen.getByText('Arbitrer ce conflit')).toBeInTheDocument();
        });

        await user.click(screen.getByText('Arbitrer ce conflit'));

        expect(screen.getByText('Expert 1')).toBeInTheDocument();
        expect(screen.getByText('Expert 2')).toBeInTheDocument();
        expect(screen.getByText('Modifier')).toBeInTheDocument();
        expect(screen.getByText('Rejeter')).toBeInTheDocument();
        expect(screen.getByText('Clôturer le conflit')).toBeInTheDocument();
    });

    it('cliquer "Expert 1" puis "Clôturer" appelle resolve_conflict avec accepted_1', async () => {
        const user = userEvent.setup();
        mockRpc.mockResolvedValue({ data: { success: true }, error: null });

        renderWithProviders(<ConflictsPage />);

        await waitFor(() => {
            expect(screen.getByText('Arbitrer ce conflit')).toBeInTheDocument();
        });

        await user.click(screen.getByText('Arbitrer ce conflit'));
        await user.click(screen.getByText('Expert 1'));
        await user.click(screen.getByText('Clôturer le conflit'));

        await waitFor(() => {
            expect(mockRpc).toHaveBeenCalledWith('resolve_conflict', {
                p_image_id: 'aaaa-bbbb-cccc-dddd',
                p_final_label: 'Tomato___Late_Blight',
                p_final_severity: null,
                p_resolution: 'accepted_1',
                p_comment: null,
            });
        });
    });

    it('cliquer "Rejeter" puis "Clôturer" appelle resolve_conflict avec rejected', async () => {
        const user = userEvent.setup();
        mockRpc.mockResolvedValue({ data: { success: true }, error: null });

        renderWithProviders(<ConflictsPage />);

        await waitFor(() => {
            expect(screen.getByText('Arbitrer ce conflit')).toBeInTheDocument();
        });

        await user.click(screen.getByText('Arbitrer ce conflit'));
        await user.click(screen.getByText('Rejeter'));
        await user.click(screen.getByText('Clôturer le conflit'));

        await waitFor(() => {
            expect(mockRpc).toHaveBeenCalledWith('resolve_conflict', {
                p_image_id: 'aaaa-bbbb-cccc-dddd',
                p_final_label: 'REJECTED',
                p_final_severity: null,
                p_resolution: 'rejected',
                p_comment: null,
            });
        });
    });

    it('un expert non-senior ne voit pas le bouton "Arbitrer"', async () => {
        mockAuthValue.current = {
            user: { id: 'expert-id' },
            profile: { role: 'expert' },
            isSenior: false,
            isAdmin: false,
        };

        renderWithProviders(<ConflictsPage />);

        await waitFor(() => {
            expect(screen.getByText(/Dr\. Amadou/)).toBeInTheDocument();
        });

        expect(screen.queryByText('Arbitrer ce conflit')).not.toBeInTheDocument();
    });
});
