// Edge Function : verify-reset-code
// Étape 2 du flux "mot de passe oublié".
// Vérifie que le code à 6 chiffres saisi correspond bien à celui
// envoyé par email, qu'il n'a pas expiré et n'a pas déjà été utilisé.
// En cas de succès, renvoie un jeton temporaire à usage unique qui
// autorisera le changement de mot de passe à l'étape 3 (sans ce
// jeton, impossible de sauter directement à "reset-password" sans
// être passé par la vérification du code).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sha256Hex, jsonResponse } from '../_shared/password-reset-utils.ts';

const MAX_ATTEMPTS = 5;
const RESET_TOKEN_VALIDITY_MINUTES = 10;

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return jsonResponse({ ok: false, error: 'Méthode non autorisée' }, 405);
  }

  try {
    const { email, code } = await req.json();

    if (!email || typeof email !== 'string' || !code || typeof code !== 'string') {
      return jsonResponse({ ok: false, error: 'Email et code requis' }, 400);
    }

    const normalizedEmail = email.trim().toLowerCase();
    const normalizedCode = code.trim();

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: row } = await supabase
      .from('password_reset_codes')
      .select('*')
      .eq('email', normalizedEmail)
      .eq('used', false)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!row) {
      return jsonResponse({ ok: false, error: 'Aucun code actif. Demandez un nouveau code.' }, 400);
    }

    if (new Date(row.expires_at) < new Date()) {
      await supabase.from('password_reset_codes').update({ used: true }).eq('id', row.id);
      return jsonResponse({ ok: false, error: 'Code expiré. Demandez un nouveau code.' }, 400);
    }

    if (row.attempts >= MAX_ATTEMPTS) {
      await supabase.from('password_reset_codes').update({ used: true }).eq('id', row.id);
      return jsonResponse(
        { ok: false, error: 'Trop de tentatives incorrectes. Demandez un nouveau code.' },
        400,
      );
    }

    const codeHash = await sha256Hex(normalizedCode);

    if (codeHash !== row.code_hash) {
      await supabase
        .from('password_reset_codes')
        .update({ attempts: row.attempts + 1 })
        .eq('id', row.id);
      return jsonResponse({ ok: false, error: 'Code de vérification incorrect' }, 400);
    }

    // Code correct : on génère le jeton temporaire pour l'étape suivante.
    const resetToken = crypto.randomUUID();
    const resetTokenHash = await sha256Hex(resetToken);
    const resetTokenExpiresAt = new Date(
      Date.now() + RESET_TOKEN_VALIDITY_MINUTES * 60_000,
    ).toISOString();

    await supabase
      .from('password_reset_codes')
      .update({
        verified: true,
        reset_token_hash: resetTokenHash,
        reset_token_expires_at: resetTokenExpiresAt,
      })
      .eq('id', row.id);

    return jsonResponse({ ok: true, reset_token: resetToken });
  } catch (error) {
    console.error('verify-reset-code error:', error);
    return jsonResponse({ ok: false, error: 'Erreur lors de la vérification du code' }, 500);
  }
});
