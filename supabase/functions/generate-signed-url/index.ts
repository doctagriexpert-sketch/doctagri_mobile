// generate-signed-url
// Génère une URL signée pour upload d'image (expire dans 1h)
import { StorageClient } from 'https://esm.sh/@supabase/storage-js@2.5.0';

Deno.serve(async (req: Request) => {
  try {
    const { user_id, file_name } = await req.json();

    if (!user_id || !file_name) {
      return new Response(
        JSON.stringify({ error: 'user_id et file_name requis' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const storagePath = `${user_id}/diagnoses/${Date.now()}_${file_name}`;

    const { data, error } = await supabase.storage
      .from('diagnosis-images')
      .createSignedUrl(storagePath, 3600);

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ signed_url: data.signedUrl, storage_path: storagePath }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: e.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});