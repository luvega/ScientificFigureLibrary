import { z } from "zod";

/** Exact source-tag filtering; normalization never changes stored metadata. */
export function normalizeRequiredTags(tags: readonly string[] = []): string[] {
  return [...new Set(tags.map((tag) => tag.trim().normalize("NFC")).filter(Boolean))].sort();
}

export const RequiredTagsSchema = z.array(z.string().max(200)).max(100)
  .transform(normalizeRequiredTags).optional()
  .describe("Require every exact source tag (AND). Trimmed, NFC-normalized, deduplicated and sorted; case-sensitive. Missing source tags never match a nonempty filter.");

export function matchesRequiredTags(tags: readonly string[] | undefined, requiredTags?: readonly string[]): boolean {
  const required = normalizeRequiredTags(requiredTags);
  if (!required.length) return true;
  const available = new Set(normalizeRequiredTags(tags));
  return required.every((tag) => available.has(tag));
}
