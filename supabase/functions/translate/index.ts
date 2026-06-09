// translate — Edge Function DoctAgri
// Appelle facebook/nllb-200-distilled-600M via l'API HuggingFace Inference.
// Entrée  : { texts: string[], targetLang: string, sourceLang?: string }
// Sortie  : { translations: string[], model: string }
//
// Langues supportées (codes NLLB) :
//   Français  → fra_Latn
//   Éwé       → ewe_Latn
//   (Kabyè non disponible dans NLLB-200)

const HF_MODEL = 'facebook/nllb-200-distilled-600M';
const HF_API_URL = `https://api-inference.huggingface.co/models/${HF_MODEL}`;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

interface TranslateRequest {
  texts: string[];
  targetLang: string;
  sourceLang?: string;
}

interface TranslateResponse {
  translations: string[];
  model: string;
  cached?: boolean;
}

async function translateOne(
  text: string,
  srcLang: string,
  tgtLang: string,
  hfToken: string,
): Promise<string> {
  // Retry jusqu'à 3 fois pour le cold-start du modèle HuggingFace (HTTP 503)
  for (let attempt = 0; attempt < 3; attempt++) {
    const resp = await fetch(HF_API_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${hfToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        inputs: text,
        parameters: {
          src_lang: srcLang,
          tgt_lang: tgtLang,
          max_length: 400,
          num_beams: 4,
        },
      }),
    });

    // Modèle en cours de chargement → attendre et réessayer
    if (resp.status === 503) {
      const body = await resp.json().catch(() => ({}));
      const waitMs = (body?.estimated_time ?? 20) * 1000;
      console.log(`[translate] Model loading, waiting ${waitMs}ms (attempt ${attempt + 1})`);
      await new Promise((r) => setTimeout(r, Math.min(waitMs, 25_000)));
      continue;
    }

    if (!resp.ok) {
      const err = await resp.text();
      throw new Error(`HuggingFace API ${resp.status}: ${err.substring(0, 200)}`);
    }

    const data = await resp.json();
    if (Array.isArray(data) && data[0]?.translation_text) {
      return data[0].translation_text as string;
    }
    throw new Error(`Unexpected HF response: ${JSON.stringify(data).substring(0, 200)}`);
  }
  throw new Error('HuggingFace model still loading after 3 attempts');
}

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const hfToken = Deno.env.get('HF_API_TOKEN');
  if (!hfToken) {
    console.error('[translate] HF_API_TOKEN not set');
    return new Response(JSON.stringify({ error: 'HF_API_TOKEN not configured' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  let body: TranslateRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const { texts, targetLang, sourceLang = 'fra_Latn' } = body;

  if (!Array.isArray(texts) || texts.length === 0) {
    return new Response(
      JSON.stringify({ translations: [], model: HF_MODEL }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  // Limite de sécurité : max 20 textes par appel
  const safeTexts = texts.slice(0, 20);

  try {
    console.log(`[translate] ${safeTexts.length} texts → ${targetLang}`);

    // Traduction séquentielle (NLLB-200 n'a pas d'API batch native)
    const translations: string[] = [];
    for (const text of safeTexts) {
      if (!text || text.trim().length === 0) {
        translations.push('');
        continue;
      }
      const translated = await translateOne(text.trim(), sourceLang, targetLang, hfToken);
      translations.push(translated);
    }

    const response: TranslateResponse = { translations, model: HF_MODEL };
    console.log(`[translate] Done — ${translations.length} translations`);

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('[translate] Error:', err);
    return new Response(
      JSON.stringify({ error: (err as Error).message, translations: safeTexts }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }
});
