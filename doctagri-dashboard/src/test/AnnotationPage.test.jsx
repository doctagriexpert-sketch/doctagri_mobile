import { beforeEach, describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import AnnotationPage from '../pages/AnnotationPage';

const mocks = vi.hoisted(() => ({
    auth: { profile: { id: 'expert-1' } },
    insert: vi.fn(),
    rpc: vi.fn(),
    navigate: vi.fn(),
}));
vi.mock('../auth/useAuth', () => ({ useAuth: () => mocks.auth }));
vi.mock('react-router-dom', () => ({
    useParams: () => ({ id: 'image-1' }),
    useNavigate: () => mocks.navigate,
}));
vi.mock('react-hot-toast', () => ({ toast: { error: vi.fn(), success: vi.fn() } }));
vi.mock('../lib/supabase', () => ({
    supabase: {
        rpc: mocks.rpc,
        from: (table) => ({
            insert: mocks.insert,
            select: () => ({ eq: () => table === 'images'
                ? { single: async () => ({ data: { id: 'image-1', ml_predicted_label: 'Healthy' } }) }
                : { order: () => ({ order: async () => ({ data: [] }) }) },
            }),
        }),
    },
}));

describe('Annotation keyboard submission', () => {
    beforeEach(() => {
        vi.clearAllMocks();
        mocks.auth.profile = { id: 'expert-1' };
        mocks.insert.mockResolvedValue({ error: null });
        mocks.rpc.mockResolvedValue({ data: null, error: null });
    });

    it('uses the current profile after a rerender and removes the shortcut on unmount', async () => {
        const view = render(<AnnotationPage />);
        await screen.findByText("Pas d'image disponible");
        mocks.auth.profile = { id: 'expert-2' };
        view.rerender(<AnnotationPage />);
        fireEvent.keyDown(window, { key: 'Enter', ctrlKey: true });
        await waitFor(() => expect(mocks.insert).toHaveBeenCalledWith(expect.objectContaining({
            image_id: 'image-1', expert_id: 'expert-2', disease_label: 'Healthy',
        })));
        await waitFor(() => expect(mocks.navigate).toHaveBeenCalledWith('/queue'));
        view.unmount();
        fireEvent.keyDown(window, { key: 'Enter', ctrlKey: true });
        expect(mocks.insert).toHaveBeenCalledTimes(1);
    });
});
