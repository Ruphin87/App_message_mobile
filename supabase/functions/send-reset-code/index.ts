// Edge Function : send-reset-code
// Étape 1 du flux "mot de passe oublié".
// Reçoit un email, génère un code à 6 chiffres, le stocke (haché) et
// l'envoie par email via un serveur SMTP classique (PAS le système
// d'email intégré de Supabase Auth).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { SMTPClient } from 'https://deno.land/x/denomailer@1.6.0/mod.ts';
import { generateSixDigitCode, sha256Hex, jsonResponse } from '../_shared/password-reset-utils.ts';

const CODE_VALIDITY_MINUTES = 10;

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return jsonResponse({ ok: false, error: 'Méthode non autorisée' }, 405);
  }

  try {
    const { email } = await req.json();

    if (!email || typeof email !== 'string' || !email.includes('@')) {
      return jsonResponse({ ok: false, error: 'Adresse email invalide' }, 400);
    }

    const normalizedEmail = email.trim().toLowerCase();

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // On vérifie si un compte existe avec cet email, mais on renvoie
    // TOUJOURS la même réponse au client (avec ou sans compte trouvé),
    // pour ne pas permettre à quelqu'un de deviner quels emails sont
    // inscrits (anti-énumération).
    const { data: existingUser } = await supabase
      .from('users')
      .select('id')
      .eq('email', normalizedEmail)
      .maybeSingle();

    if (existingUser) {
      const code = generateSixDigitCode();
      const codeHash = await sha256Hex(code);
      const expiresAt = new Date(Date.now() + CODE_VALIDITY_MINUTES * 60_000).toISOString();

      // Invalide les codes précédents non utilisés pour cet email, pour
      // qu'un seul code à la fois soit valide.
      await supabase
        .from('password_reset_codes')
        .update({ used: true })
        .eq('email', normalizedEmail)
        .eq('used', false);

      await supabase.from('password_reset_codes').insert({
        email: normalizedEmail,
        code_hash: codeHash,
        expires_at: expiresAt,
      });

      await sendCodeByEmail(normalizedEmail, code);
    }

    return jsonResponse({ ok: true });
  } catch (error) {
    console.error('send-reset-code error:', error);
    return jsonResponse({ ok: false, error: "Erreur lors de l'envoi du code" }, 500);
  }
});

async function sendCodeByEmail(email: string, code: string): Promise<void> {
  const client = new SMTPClient({
    connection: {
      hostname: Deno.env.get('SMTP_HOST')!,
      port: Number(Deno.env.get('SMTP_PORT') ?? '587'),
      tls: (Deno.env.get('SMTP_SECURE') ?? 'true') === 'true',
      auth: {
        username: Deno.env.get('SMTP_USER')!,
        password: Deno.env.get('SMTP_PASSWORD')!,
      },
    },
  });

  const fromName = Deno.env.get('SMTP_FROM_NAME') ?? 'Message KO';
  const fromEmail = Deno.env.get('SMTP_FROM_EMAIL') ?? Deno.env.get('SMTP_USER')!;

  try {
    await client.send({
      from: `${fromName} <${fromEmail}>`,
      to: email,
      subject: 'Votre code de vérification',
      content: `Votre code de vérification est : ${code}\n\nCe code est valable ${CODE_VALIDITY_MINUTES} minutes.\n\nSi vous n'êtes pas à l'origine de cette demande, ignorez cet email.`,
      html: `
        <div style="font-family: sans-serif; max-width: 480px; margin: auto;">
          <h2>Réinitialisation de votre mot de passe</h2>
          <p>Voici votre code de vérification :</p>
          <p style="font-size: 32px; font-weight: bold; letter-spacing: 8px; text-align: center;">${code}</p>
          <p>Ce code est valable <strong>${CODE_VALIDITY_MINUTES} minutes</strong>.</p>
          <p style="color: #888; font-size: 12px;">Si vous n'êtes pas à l'origine de cette demande, ignorez cet email.</p>
        </div>
      `,
    });
  } catch (sendError) {
    // On journalise puis on relance TEL QUEL, sans passer par le
    // finally/close ci-dessous qui pourrait masquer cette erreur.
    console.error('Échec de l\'envoi SMTP:', sendError);
    throw sendError;
  } finally {
    // Si la connexion n'a jamais été établie (host/port invalide,
    // DNS, etc.), client.close() lève lui-même une erreur qui
    // écraserait l'erreur d'origine ci-dessus si on ne l'attrape pas.
    try {
      await client.close();
    } catch (closeError) {
      console.error('Erreur (sans gravité) à la fermeture du client SMTP:', closeError);
    }
  }
}