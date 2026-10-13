-- Run against a test database AFTER the migration. All data is rolled back.
BEGIN;

SET LOCAL ROLE anon;
SELECT public.register_app_installation(
    'af53ce27-0a3a-4ea2-b4eb-200000000001', '2026-10-02T12:00:00Z',
    'Test manufacturer', 'Test phone', '14', '1.0.0'
);
-- A replay must neither duplicate nor overwrite the original record.
SELECT public.register_app_installation(
    'af53ce27-0a3a-4ea2-b4eb-200000000001', '2026-10-02T13:00:00Z',
    'Changed manufacturer', 'Changed phone', '15', '2.0.0'
);

DO $$
BEGIN
    BEGIN
        PERFORM * FROM public.app_installations;
        RAISE EXCEPTION 'Anonymous reads must be denied';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        DELETE FROM public.app_installations;
        RAISE EXCEPTION 'Anonymous deletes must be denied';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        PERFORM public.register_app_installation(
            'af53ce27-0a3a-4ea2-b4eb-200000000002', now(),
            repeat('x', 101), 'Test phone', '14', '1.0.0'
        );
        RAISE EXCEPTION 'Oversized fields must be rejected';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
END;
$$;

RESET ROLE;
DO $$
BEGIN
    IF (SELECT count(*) FROM public.app_installations
        WHERE installation_id = 'af53ce27-0a3a-4ea2-b4eb-200000000001') <> 1 THEN
        RAISE EXCEPTION 'Expected exactly one installation';
    END IF;
    IF (SELECT model FROM public.app_installations
        WHERE installation_id = 'af53ce27-0a3a-4ea2-b4eb-200000000001') <> 'Test phone' THEN
        RAISE EXCEPTION 'Replay overwrote original metadata';
    END IF;
END;
$$;
ROLLBACK;
