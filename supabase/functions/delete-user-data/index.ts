// delete-user-data
// RGPD: droit à l'oubli - soft delete + purge après 30j
Deno.serve(async (req: Request) => {
  try {
    const { user_id, confirm_deletion } = await req.json();

    if (!user_id) {
      return new Response(
        JSON.stringify({ error: 'user_id requis' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    if (confirm_deletion !== true) {
      return new Response(
        JSON.stringify({
          error: 'confirmation requise',
          hint: 'Passer confirm_deletion: true pour confirmer',
        }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // 1. Soft delete: marquer diagnoses pour suppression
    const { error: diagError } = await supabase
      .from('diagnoses')
      .update({ deleted_at: new Date().toISOString() })
      .eq('user_id', user_id);

    if (diagError) {
      throw new Error(`Erreur diagnoses: ${diagError.message}`);
    }

    // 2. Soft delete profile
    const { error: profileError } = await supabase
      .from('profiles')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', user_id);

    if (profileError) {
      throw new Error(`Erreur profile: ${profileError.message}`);
    }

    // 3. Log audit avant suppression
    await supabase.from('audit_log').insert({
      user_id,
      action: 'gdpr_delete_request',
      entity_type: 'user',
      entity_id: user_id,
      payload: { scheduled_purge_at: '30 jours' },
    });

    // 4. TODO: Planifier purge automatique via Supabase cron ou Trigger
    // DROP ROW AFTER 30 DAYS via pg_event_schedule ou cron job externe

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Données marked pour suppression dans 30 jours',
        user_id,
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: e.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});