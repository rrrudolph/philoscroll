export function isAuthorized(
  header: string | string[] | undefined,
  secret: string | undefined,
): boolean {
  if (!secret) return true;
  if (Array.isArray(header)) return header.includes(secret);
  return header === secret;
}
