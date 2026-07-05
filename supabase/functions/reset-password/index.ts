// Edge Function : reset-password
// Étape 3 (finale) du flux "mot de passe oublié".
// Vérifie le jeton temporaire délivré par verify-reset-code, puis
// modifie réellement le mot de passe du compte via l'API Admin de
// Supabase (nécessaire car il n'existe aucune session active pendant
// cette procédure : l'utilisateur n'est jamais connecté).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sha256Hex, jsonResponse } from '../_shared/password-reset-utils.ts';

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return jsonResponse({ ok: false, error: 'Méthode non autorisée' }, 405);
  }

  try {
    const { email, reset_token, password } = await req.json();

    if (
      !email || typeof email !== 'string' ||
      !reset_token || typeof reset_token !== 'string' ||
      !password || typeof password !== 'string'
    ) {
      return jsonResponse({ ok: false, error: 'Paramètres manquants' }, 400);
    }

    if (password.length < 6) {
      return jsonResponse(
        { ok: false, error: 'Le mot de passe doit contenir au moins 6 caractères' },
        400,
      );
    }

    const normalizedEmail = email.trim().toLowerCase();

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: row } = await supabase
      .from('password_reset_codes')
      .select('*')
      .eq('email', normalizedEmail)
      .eq('used', false)
      .eq('verified', true)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!row || !row.reset_token_hash || !row.reset_token_expires_at) {
      return jsonResponse(
        { ok: false, error: "Vérifiez d'abord le code reçu par email." },
        400,
      );
    }

    if (new Date(row.reset_token_expires_at) < new Date()) {
      return jsonResponse(
        { ok: false, error: 'Session expirée. Recommencez la procédure.' },
        400,
      );
    }

    const tokenHash = await sha256Hex(reset_token);
    if (tokenHash !== row.reset_token_hash) {
      return jsonResponse(
        { ok: false, error: 'Session invalide. Recommencez la procédure.' },
        400,
      );
    }

    // Retrouve le compte Supabase Auth correspondant à cet email.
    const { data: profile } = await supabase
      .from('users')
      .select('id')
      .eq('email', normalizedEmail)
      .maybeSingle();

    if (!profile) {
      return jsonResponse({ ok: false, error: 'Compte introuvable' }, 400);
    }

    // Modifie le mot de passe réel du compte (auth.users), via l'API
    // Admin — seule la clé service_role permet cette opération.
    const { error: updateError } = await supabase.auth.admin.updateUserById(profile.id, {
      password,
    });

    if (updateError) {
      throw updateError;
    }

    // Jeton à usage unique : on invalide la ligne pour empêcher toute
    // réutilisation (rejouer la requête, etc.).
    await supabase.from('password_reset_codes').update({ used: true }).eq('id', row.id);

    return jsonResponse({ ok: true });
  } catch (error) {
    console.error('reset-password error:', error);
    return jsonResponse(
      { ok: false, error: 'Erreur lors du changement de mot de passe' },
      500,
    );
  }
});
