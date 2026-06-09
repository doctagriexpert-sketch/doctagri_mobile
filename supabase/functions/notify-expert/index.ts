// notify-expert
// Webhook vers experts quand confidence < seuil
Deno.serve(async (req: Request) => {
  try {
    const { diagnosis_id, user_id, predicted_label, confidence, image_path } =
      await req.json();

    if (!diagnosis_id || !user_id) {
      return new Response(
        JSON.stringify({ error: 'diagnosis_id et user_id requis' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Trouver experts dans l'organisation de l'utilisateur
    const { data: profile } = await supabase
      .from('profiles')
      .select('organization_id')
      .eq('id', user_id)
      .single();

    if (!profile) {
      return new Response(
        JSON.stringify({ error: 'Profil non trouvé' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Trouver experts disponibles
    const { data: experts } = await supabase
      .from('profiles')
      .select('id, phone')
      .eq('organization_id', profile.organization_id)
      .eq('role', 'expert');

    if (!experts || experts.length === 0) {
      return new Response(
        JSON.stringify({ notified: 0, message: 'Aucun expert disponible' }),
        { headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Insérer dans la queue de validation
    const { error: insertError } = await supabase.from('validation_queue').insert({
      diagnosis_id,
      expert_id: experts[0].id, // TODO: round-robin ou queue
      status: 'pending',
      priority: confidence < 0.5 ? 'high' : 'normal',
    });

    if (insertError) {
      console.error('Erreur insertion queue:', insertError);
    }

    // TODO: Envoyer notification push/SMS à l'expert
    // Via Supabase Edge Functions ou service externe

    return new Response(
      JSON.stringify({
        notified: experts.length,
        experts: experts.map((e: any) => e.id),
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