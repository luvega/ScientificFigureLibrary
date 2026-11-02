export interface SourceReference {
  path?: string;
  sha256?: string;
  archiveEntry?: string;
  archiveEntrySha256?: string;
  digestScope?: string;
  [key: string]: unknown;
}
export interface SourceMapping {
  originalPath?: string;
  originalSha256?: string;
  currentPath?: string;
  currentSha256?: string;
  archiveEntry?: string;
  disposition?: string;
  [key: string]: unknown;
}
export interface ResolvedReference {
  original: SourceReference;
  status: string;
  byteIdentical?: boolean;
  transformation?: string;
  reason?: string;
  errors?: Array<{error: string; [key: string]: unknown}>;
  [key: string]: unknown;
}
export function resolveSourceReferences<const T extends readonly SourceReference[]>(options: {
  references: T;
  mappings: SourceMapping[];
  sourceRoots: string[];
}): Promise<{records: {[K in keyof T]: ResolvedReference}; summary: Record<string, number>; [key: string]: unknown}>;
