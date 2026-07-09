// Edge Function : get-turn-credentials
//
// Récupère des identifiants STUN/TURN frais auprès de Metered.ca pour un
// appel WebRTC (audio/vidéo). La clé secrète Metered ne quitte JAMAIS le
// serveur — elle est lue depuis une variable d'environnement (secret Edge
// Function), jamais depuis l'app Flutter. C'est l'app qui appelle cette
// fonction (authentifiée via le JWT Supabase de l'utilisateur connecté),
// et cette fonction seule contacte Metered avec la clé secrète.
//
// Secrets requis (à définir avec `supabase secrets set`, voir le README) :
//   METERED_APP_DOMAIN  -> ex. "messagekoapp"
//   METERED_API_KEY     -> la clé secrète visible dans Metered > Developers

Deno.serve(async (req: Request) => {
  try {
    const meteredAppDomain = Deno.env.get('METERED_APP_DOMAIN');
    const meteredApiKey = Deno.env.get('METERED_API_KEY');

    if (!meteredAppDomain || !meteredApiKey) {
      throw new Error('METERED_APP_DOMAIN ou METERED_API_KEY manquant côté serveur');
    }

    const url = `https://${meteredAppDomain}.metered.live/api/v1/turn/credentials?apiKey=${meteredApiKey}`;
    const meteredResponse = await fetch(url);

    if (!meteredResponse.ok) {
      throw new Error(`Metered a répondu ${meteredResponse.status}`);
    }

    const iceServers = await meteredResponse.json();

    return new Response(JSON.stringify({ ok: true, iceServers }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('get-turn-credentials error:', error);
    return new Response(JSON.stringify({ ok: false, error: String(error) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
