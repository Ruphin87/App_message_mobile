import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface RequestPayload {
  recipient_id: string;
  sender_id: string;
  message: string;
  conversation_id: string;
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

// ==================== JWT / OAuth2 pour FCM HTTP v1 ====================

/** Encode une chaîne en base64url (sans padding), requis pour les JWT. */
function base64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : new Uint8Array(input);
  let str = '';
  for (const byte of bytes) str += String.fromCharCode(byte);
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** Importe la clé privée PEM du compte de service pour signer en RS256. */
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  return crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

/**
 * Génère un access token OAuth2 pour le scope FCM, en suivant le flux
 * "JWT Bearer Token" décrit par la documentation Firebase : on signe un JWT
 * avec la clé privée du compte de service, puis on l'échange contre un
 * access token auprès de Google.
 */
async function getFcmAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  };

  const unsignedToken = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;
  const key = await importPrivateKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsignedToken));
  const jwt = `${unsignedToken}.${base64url(signature)}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Échec de l'obtention du token OAuth2 FCM: ${errorText}`);
  }

  const data = await response.json();
  return data.access_token as string;
}

// ==================== Envoi FCM ====================

async function sendFcmNotification(opts: {
  accessToken: string;
  projectId: string;
  fcmToken: string;
  title: string;
  body: string;
  data: Record<string, string>;
}): Promise<{ ok: boolean; error?: string }> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${opts.projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${opts.accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token: opts.fcmToken,
          notification: {
            title: opts.title,
            body: opts.body,
          },
          data: opts.data,
          android: {
            priority: 'high',
            notification: {
              channel_id: 'high_importance_channel',
            },
          },
        },
      }),
    },
  );

  if (!response.ok) {
    const errorText = await response.text();
    return { ok: false, error: errorText };
  }
  return { ok: true };
}

// ==================== Handler principal ====================

Deno.serve(async (req: Request) => {
  try {
    const payload: RequestPayload = await req.json();
    const { recipient_id, sender_id, message, conversation_id } = payload;

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // 1) Récupère le nom de l'expéditeur pour personnaliser le titre
    const { data: sender } = await supabase
      .from('users')
      .select('nom')
      .eq('id', sender_id)
      .single();

    const senderName = sender?.nom ?? 'Nouveau message';
    const truncatedMessage = message.length > 100 ? `${message.slice(0, 100)}…` : message;

    // 2) Crée la ligne dans `notifications` (historique + badge de compteur)
    await supabase.from('notifications').insert({
      user_id: recipient_id,
      title: senderName,
      body: truncatedMessage,
      is_read: false,
      data: { type: 'message', conversation_id, sender_id },
    });

    // 3) Récupère tous les tokens d'appareil du destinataire
    const { data: tokens } = await supabase
      .from('device_tokens')
      .select('fcm_token')
      .eq('user_id', recipient_id);

    if (!tokens || tokens.length === 0) {
      // Pas d'appareil enregistré (jamais connecté, ou notifications
      // refusées) : la notification reste visible dans l'historique
      // in-app, mais aucun push n'est envoyé.
      return new Response(JSON.stringify({ ok: true, pushed: 0 }), { status: 200 });
    }

    // 4) Authentifie auprès de FCM (un seul token OAuth2 réutilisé pour
    //    tous les appareils de cet envoi)
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!serviceAccountJson) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON secret manquant');
    }
    const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson);
    const accessToken = await getFcmAccessToken(serviceAccount);

    // 5) Envoie la notification push à chaque appareil
    let pushed = 0;
    const invalidTokens: string[] = [];

    for (const { fcm_token } of tokens) {
      const result = await sendFcmNotification({
        accessToken,
        projectId: serviceAccount.project_id,
        fcmToken: fcm_token,
        title: senderName,
        body: truncatedMessage,
        data: { type: 'message', conversation_id, sender_id },
      });

      if (result.ok) {
        pushed++;
      } else if (result.error?.includes('UNREGISTERED') || result.error?.includes('NOT_FOUND')) {
        // Token périmé (app désinstallée, etc.) : à nettoyer.
        invalidTokens.push(fcm_token);
      }
    }

    // 6) Nettoie les tokens invalides détectés
    if (invalidTokens.length > 0) {
      await supabase.from('device_tokens').delete().in('fcm_token', invalidTokens);
    }

    return new Response(JSON.stringify({ ok: true, pushed }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('send-push-notification error:', error);
    return new Response(JSON.stringify({ ok: false, error: String(error) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});