// Utilitaires partagés entre les 3 Edge Functions du flux
// "mot de passe oublié" (send-reset-code, verify-reset-code,
// reset-password).

/** Génère un code à 6 chiffres (000000-999999) via un tirage cryptographique. */
export function generateSixDigitCode(): string {
  const array = new Uint32Array(1);
  crypto.getRandomValues(array);
  return (array[0] % 1_000_000).toString().padStart(6, '0');
}

/** Hache une chaîne en SHA-256 (hex). Le code et le jeton de reset ne
 * sont jamais stockés en clair en base. */
export async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

export function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
