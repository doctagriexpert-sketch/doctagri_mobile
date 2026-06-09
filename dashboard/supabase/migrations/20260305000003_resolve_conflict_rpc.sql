-- ============================================================
-- DoctAgri Expert Dashboard — Atomic Conflict Resolution
-- ============================================================
-- Migration 003: RPC function to resolve conflicts atomically
-- Replaces 3 separate client-side calls with a single transaction
-- ============================================================

CREATE OR REPLACE FUNCTION public.resolve_conflict(
    p_image_id     UUID,
    p_final_label  TEXT,
    p_final_severity TEXT DEFAULT NULL,
    p_resolution   TEXT DEFAULT 'accepted_1',
    p_comment      TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_senior_id UUID := auth.uid();
    v_role      user_role;
    v_result    JSONB;
BEGIN
    -- 1. Verify the caller is senior or admin
    SELECT role INTO v_role FROM public.profiles WHERE id = v_senior_id;
    IF v_role NOT IN ('senior', 'admin') THEN
        RAISE EXCEPTION 'Permission denied: only senior experts and admins can resolve conflicts'
            USING ERRCODE = '42501';
    END IF;

    -- 2. Verify the image exists and is in conflict status
    IF NOT EXISTS (
        SELECT 1 FROM public.images WHERE id = p_image_id AND status = 'conflict'
    ) THEN
        RAISE EXCEPTION 'Image not found or not in conflict status'
            USING ERRCODE = 'P0002';
    END IF;

    -- 3. Insert validation record
    INSERT INTO public.validations (
        image_id,
        senior_id,
        final_label,
        final_severity,
        resolution,
        decision_comment
    ) VALUES (
        p_image_id,
        v_senior_id,
        p_final_label,
        p_final_severity,
        p_resolution,
        p_comment
    );

    -- 4. Update image status to validated
    UPDATE public.images
    SET status = 'validated'
    WHERE id = p_image_id;

    -- 5. Log audit trail
    INSERT INTO public.audit_logs (
        user_id,
        action,
        entity_type,
        entity_id,
        new_data
    ) VALUES (
        v_senior_id,
        'resolve_conflict',
        'image',
        p_image_id,
        jsonb_build_object(
            'final_label', p_final_label,
            'final_severity', p_final_severity,
            'resolution', p_resolution,
            'comment', p_comment
        )
    );

    -- 6. Return success
    v_result := jsonb_build_object(
        'success', true,
        'image_id', p_image_id,
        'final_label', p_final_label,
        'resolved_by', v_senior_id
    );

    RETURN v_result;
END;
$$;

-- Grant execute permission to authenticated users (RLS + function logic handle authorization)
GRANT EXECUTE ON FUNCTION public.resolve_conflict TO authenticated;
