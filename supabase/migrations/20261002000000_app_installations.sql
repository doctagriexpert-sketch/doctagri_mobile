-- Independent of farmer accounts and of the two existing profile schemas.
CREATE TABLE public.app_installations (
    installation_id uuid PRIMARY KEY,
    first_opened_at timestamptz NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    manufacturer text NOT NULL CHECK (length(manufacturer) <= 100),
    model text NOT NULL CHECK (length(model) <= 100),
    os_version text NOT NULL CHECK (length(os_version) <= 50),
    app_version text NOT NULL CHECK (length(app_version) <= 50)
);

ALTER TABLE public.app_installations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_installations FROM anon, authenticated;
GRANT SELECT ON public.app_installations TO service_role;

-- Public clients may only submit bounded, immutable records. No listing,
-- modification or deletion is exposed. A retried request is a no-op.
CREATE FUNCTION public.register_app_installation(
    p_installation_id uuid,
    p_first_opened_at timestamptz,
    p_manufacturer text,
    p_model text,
    p_os_version text,
    p_app_version text
) RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
    INSERT INTO public.app_installations (
        installation_id, first_opened_at, manufacturer, model, os_version, app_version
    ) VALUES (
        p_installation_id, p_first_opened_at, p_manufacturer, p_model, p_os_version, p_app_version
    ) ON CONFLICT (installation_id) DO NOTHING;
$$;

REVOKE ALL ON FUNCTION public.register_app_installation(uuid, timestamptz, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_app_installation(uuid, timestamptz, text, text, text, text) TO anon, authenticated;
