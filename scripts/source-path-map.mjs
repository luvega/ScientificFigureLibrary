// Host-side provenance repair. Reads source files; never changes a source or release.
import fs from 'node:fs/promises';
import {createReadStream} from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';

const SHA = /^[a-f0-9]{64}$/i;
const key = value => path.win32.normalize(String(value)).normalize('NFC').toLowerCase();
const entryKey = value => String(value ?? '').replaceAll('\\','/').normalize('NFC');
async function digest(file) {
  const hash = createHash('sha256');
  for await (const bytes of createReadStream(file)) hash.update(bytes);
  return hash.digest('hex');
}
function inside(root, target) {
  const relative = path.relative(root,target);
  return relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative);
}

/** Resolve historical references into a separate, byte-verified overlay.
 * A mapped transformation retains both digests; it is never called byte-identical.
 * mappings: originalPath/originalSha256/currentPath/currentSha256/archiveEntry.
 */
export async function resolveSourceReferences({references, mappings, sourceRoots}) {
  if (!Array.isArray(references) || !Array.isArray(mappings) || !sourceRoots?.length) throw new Error('references, mappings and sourceRoots are required');
  const roots = await Promise.all(sourceRoots.map(root => fs.realpath(path.resolve(root))));
  const byPath = new Map(), byHash = new Map();
  for (const row of mappings) {
    if (!row.originalPath || !SHA.test(row.originalSha256 ?? '') || !row.currentPath || !SHA.test(row.currentSha256 ?? '')) continue;
    const pathKey = key(row.originalPath);
    byPath.set(pathKey,[...(byPath.get(pathKey) ?? []),row]);
    const shaKey = row.originalSha256.toLowerCase();
    byHash.set(shaKey,[...(byHash.get(shaKey) ?? []),row]);
  }
  const cache = new Map();
  async function inspect(file) {
    if (!cache.has(file)) cache.set(file,(async () => {
      const resolved = await fs.realpath(path.resolve(file));
      if (!roots.some(root => inside(root,resolved))) throw new Error('Mapped source is outside the declared source roots');
      const stat = await fs.lstat(path.resolve(file));
      if (!stat.isFile() || stat.isSymbolicLink()) throw new Error('Mapped source is not a regular file');
      return {path:resolved,sha256:await digest(resolved),bytes:stat.size};
    })());
    return cache.get(file);
  }
  const records = [];
  for (const reference of references) {
    const original = {...reference};
    if (!reference.path || !SHA.test(reference.sha256 ?? '')) { records.push({original,status:'unverifiable',reason:'Historical path and SHA256 are required'}); continue; }
    const memberDigest=reference.archiveEntry && reference.digestScope!=='container' && SHA.test(reference.archiveEntrySha256??'') ? reference.archiveEntrySha256 : null;
    const expected = (memberDigest??reference.sha256).toLowerCase();
    if (!reference.archiveEntry || reference.digestScope === 'container') {
      try {
        const current = await inspect(reference.path);
        if (current.sha256 === expected) { records.push({original,status:'resolved',method:'existing_exact_bytes',current,byteIdentical:true}); continue; }
      } catch { /* A removed path can still have a documented migration. */ }
    }
    let candidates = (byPath.get(key(reference.path)) ?? []).filter(row => row.originalSha256.toLowerCase() === expected &&
      (!reference.archiveEntry || reference.digestScope === 'container' || entryKey(row.archiveEntry) === entryKey(reference.archiveEntry)));
    const method = candidates.length ? 'documented_path' : 'historical_content_hash';
    if (!candidates.length) candidates = byHash.get(expected) ?? [];
    const unique = [...new Map(candidates.map(row => [key(row.currentPath)+'\0'+row.currentSha256,row])).values()];
    const verified = [], errors = [];
    for (const mapping of unique) {
      try {
        if(mapping.disposition==='expanded_container_removed')throw new Error('Archive catalog metadata is not source content; resolve a retained member instead');
        const current = await inspect(mapping.currentPath);
        if (current.sha256 !== mapping.currentSha256.toLowerCase()) throw new Error('Current source digest differs from the migration record');
        verified.push({current,mapping});
      } catch (error) { errors.push({path:mapping.currentPath,error:error.message}); }
    }
    if (!verified.length) { records.push({original,status:unique.length ? 'stale_mapping' : 'unresolved',method,errors}); continue; }
    // Do not silently switch versions if the same historical hash maps to different bytes.
    if (new Set(verified.map(row => row.current.sha256)).size !== 1) { records.push({original,status:'ambiguous',method,candidates:verified,errors}); continue; }
    verified.sort((a,b) => a.current.path.localeCompare(b.current.path));
    const selected = verified[0];
    records.push({original,status:'resolved',method,current:selected.current,byteIdentical:selected.current.sha256 === expected,
      matchedDigestScope:memberDigest?'archive_member':reference.digestScope??'file',
      transformation:selected.current.sha256 === expected ? null : (selected.mapping.disposition ?? 'documented_transformation'),
      alternatives:verified.slice(1).map(row => row.current),errors});
  }
  return {schema:'source-path-resolution.v1',generatedAt:new Date().toISOString(),sourceRoots:roots,
    historicalRecordsModified:false,records,summary:records.reduce((counts,row) => {counts[row.status]=(counts[row.status] ?? 0)+1; return counts;},{})};
}
