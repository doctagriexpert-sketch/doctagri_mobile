// export-user-data
// RGPD: exporte toutes les données d'un utilisateur en JSON
Deno.serve(async (req: Request) => {
  try {
    const { user_id } = await req.json();

    if (!user_id) {
      return new Response(
        JSON.stringify({ error: 'user_id requis' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Collecter toutes les données
    const [profile, diagnoses, validationRequests] = await Promise.all([
      supabase.from('profiles').select('*').eq('id', user_id).single(),
      supabase.from('diagnoses').select('*').eq('user_id', user_id),
      supabase.from('validation_requests').select('*').eq('user_id', user_id),
    ]);

    const exportData = {
      exported_at: new Date().toISOString(),
      user_id,
      profile: profile.data,
      diagnoses: diagnoses.data || [],
      validation_requests: validationRequests.data || [],
    };

    // Log dans audit_log
    await supabase.from('audit_log').insert({
      user_id,
      action: 'gdpr_export',
      entity_type: 'user',
      entity_id: user_id,
      payload: { record_count: diagnoses.data?.length || 0 },
    });

    return new Response(JSON.stringify(exportData, null, 2), {
      headers: {
        'Content-Type': 'application/json',
        'Content-Disposition': `attachment; filename="doctagri_data_${user_id}.json"`,
      },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: e.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});