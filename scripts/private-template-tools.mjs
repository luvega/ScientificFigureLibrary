#!/usr/bin/env node
// Host-side migration utilities. These never bind a Library, publish, or run plotting code.
import fs from 'node:fs/promises';
import { createReadStream } from 'node:fs';
import path from 'node:path';
import { createHash, randomUUID } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { inflateRawSync } from 'node:zlib';

export const INVENTORY_LIMITS = Object.freeze({
  maxArchiveBytes: 256 * 1024 * 1024, maxEntryBytes: 64 * 1024 * 1024,
  maxInflatedBytes: 4 * 1024 * 1024 * 1024, maxTextBytes: 4 * 1024 * 1024,
  maxArchiveDepth: 4, maxRecords: 100_000,
});
const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const folded = value => value.normalize('NFC').toLowerCase();
const ID = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/u;
const SHA = /^[a-f0-9]{64}$/u;
const RESERVED = /^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/iu;

export function safeRelative(value) {
  if (typeof value !== 'string' || !value || value.includes('\\') || value.includes('\0') ||
      path.posix.isAbsolute(value) || /^[A-Za-z]:/u.test(value) || path.posix.normalize(value) !== value ||
      value.split('/').some(part => !part || part === '.' || part === '..' || part.endsWith('.') ||
        part.endsWith(' ') || /[<>:"|?*\u0000-\u001f]/u.test(part) || RESERVED.test(part))) {
    throw new Error(`unsafe portable relative path: ${value}`);
  }
  return value;
}

async function regularRoot(root) {
  const resolved = path.resolve(root);
  const stat = await fs.lstat(resolved);
  if (!stat.isDirectory() || stat.isSymbolicLink()) throw new Error(`not a regular directory: ${resolved}`);
  return resolved;
}

async function regularFile(root, relative) {
  safeRelative(relative);
  const parts = relative.split('/');
  let current = root;
  for (let index = 0; index < parts.length; index++) {
    current = path.join(current, parts[index]);
    const stat = await fs.lstat(current);
    if (stat.isSymbolicLink() || (index < parts.length - 1 ? !stat.isDirectory() : !stat.isFile())) {
      throw new Error(`not a regular non-symlink file: ${relative}`);
    }
  }
  return current;
}

async function digestFile(file) {
  const digest = createHash('sha256');
  for await (const chunk of createReadStream(file)) digest.update(chunk);
  return digest.digest('hex');
}

const crcTable = Uint32Array.from({ length: 256 }, (_, value) => {
  for (let i = 0; i < 8; i++) value = (value >>> 1) ^ ((value & 1) ? 0xedb88320 : 0);
  return value >>> 0;
});
export function crc32(bytes) {
  let crc = 0xffffffff;
  for (const value of bytes) crc = crcTable[(crc ^ value) & 255] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function archiveName(raw, flags, extra) {
  for (let offset = 0; offset + 4 <= extra.length;) {
    const id = extra.readUInt16LE(offset), length = extra.readUInt16LE(offset + 2);
    if (offset + 4 + length > extra.length) break;
    const field = extra.subarray(offset + 4, offset + 4 + length);
    if (id === 0x7075 && field.length >= 5 && field[0] === 1 && field.readUInt32LE(1) === crc32(raw)) {
      return { name: new TextDecoder('utf-8', { fatal: true }).decode(field.subarray(5)), encoding: 'unicode-path-extra' };
    }
    offset += 4 + length;
  }
  if (flags & 0x800) return { name: new TextDecoder('utf-8', { fatal: true }).decode(raw), encoding: 'utf-8' };
  if (raw.every(value => value < 128)) return { name: new TextDecoder('utf-8').decode(raw), encoding: 'ascii-unflagged' };
  // Legacy Chinese ZIPs often omit the UTF-8 flag. A short GBK name can also
  // be valid UTF-8, so UTF-8 validity alone is not evidence of its encoding.
  let name;
  try { name = new TextDecoder('gb18030', { fatal: true }).decode(raw); }
  catch { return { name: new TextDecoder('utf-8', { fatal: true }).decode(raw), encoding: 'utf-8-unflagged-gb18030-invalid' }; }
  let alternateUtf8Name;
  try { const value = new TextDecoder('utf-8', { fatal: true }).decode(raw); if (value !== name) alternateUtf8Name = value; } catch { /* No UTF-8 alternative. */ }
  return { name, encoding: 'gb18030-unflagged', ...(alternateUtf8Name ? { alternateUtf8Name } : {}) };
}

/** Enumerate central-directory metadata without extracting archive contents to disk. */
export function zipEntries(bytes) {
  const buffer = Buffer.from(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let end = -1;
  for (let offset = buffer.length - 22; offset >= Math.max(0, buffer.length - 65_557); offset--) {
    if (buffer.readUInt32LE(offset) === 0x06054b50 && offset + 22 + buffer.readUInt16LE(offset + 20) === buffer.length) { end = offset; break; }
  }
  if (end < 0) throw new Error('ZIP end-of-central-directory record missing');
  const count = buffer.readUInt16LE(end + 10), size = buffer.readUInt32LE(end + 12), start = buffer.readUInt32LE(end + 16);
  if (buffer.readUInt16LE(end + 4) || buffer.readUInt16LE(end + 6) || buffer.readUInt16LE(end + 8) !== count) throw new Error('split ZIP unsupported');
  if (count === 0xffff || size === 0xffffffff || start === 0xffffffff) throw new Error('ZIP64 unsupported');
  if (start + size > end) throw new Error('ZIP central directory out of bounds');
  const entries = [];
  let offset = start;
  for (let index = 0; index < count; index++) {
    if (offset + 46 > start + size || buffer.readUInt32LE(offset) !== 0x02014b50) throw new Error('invalid ZIP central-directory entry');
    const flags = buffer.readUInt16LE(offset + 8), method = buffer.readUInt16LE(offset + 10);
    const compressedBytes = buffer.readUInt32LE(offset + 20), uncompressedBytes = buffer.readUInt32LE(offset + 24);
    const nameLength = buffer.readUInt16LE(offset + 28), extraLength = buffer.readUInt16LE(offset + 30), commentLength = buffer.readUInt16LE(offset + 32);
    const finish = offset + 46 + nameLength + extraLength + commentLength;
    if (finish > start + size) throw new Error('ZIP filename/extra field out of bounds');
    const decoded = archiveName(buffer.subarray(offset + 46, offset + 46 + nameLength), flags,
      buffer.subarray(offset + 46 + nameLength, offset + 46 + nameLength + extraLength));
    const unixMode = buffer.readUInt32LE(offset + 38) >>> 16;
    entries.push({ ...decoded, flags, method, compressedBytes, uncompressedBytes,
      crc32: buffer.readUInt32LE(offset + 16), localOffset: buffer.readUInt32LE(offset + 42),
      symlink: (unixMode & 0xf000) === 0xa000, directory: decoded.name.endsWith('/') });
    offset = finish;
  }
  if (offset !== start + size) throw new Error('unexpected ZIP central-directory trailing bytes');
  return entries;
}

function entryBytes(bytes, entry) {
  const buffer = Buffer.from(bytes.buffer, bytes.byteOffset, bytes.byteLength), offset = entry.localOffset;
  if (offset + 30 > buffer.length || buffer.readUInt32LE(offset) !== 0x04034b50) throw new Error('invalid ZIP local file header');
  const start = offset + 30 + buffer.readUInt16LE(offset + 26) + buffer.readUInt16LE(offset + 28);
  if (start + entry.compressedBytes > buffer.length) throw new Error('ZIP compressed data out of bounds');
  const compressed = buffer.subarray(start, start + entry.compressedBytes);
  const output = entry.method === 0 ? compressed : entry.method === 8
    ? inflateRawSync(compressed, { maxOutputLength: Math.max(1, entry.uncompressedBytes) }) : undefined;
  if (!output) throw new Error(`unsupported ZIP compression method ${entry.method}`);
  if (output.length !== entry.uncompressedBytes || crc32(output) !== entry.crc32) throw new Error('ZIP size/CRC mismatch');
  return output;
}

export function staticDependencies(text, extension) {
  const dependencies = new Set();
  if (['.r', '.rmd', '.qmd'].includes(extension.toLowerCase())) {
    const code = text.split(/\r?\n/u).filter(line => !/^\s*#/u.test(line)).join('\n');
    for (const match of code.matchAll(/\b(?:library|require|requireNamespace)\s*\(\s*['"]?([A-Za-z][A-Za-z0-9.]*)/gu)) dependencies.add(match[1]);
    for (const match of code.matchAll(/\b([A-Za-z][A-Za-z0-9.]*)\s*::/gu)) dependencies.add(match[1]);
  } else if (extension.toLowerCase() === '.py') {
    for (const line of text.split(/\r?\n/u)) {
      const from = /^\s*from\s+([A-Za-z_][\w.]*)\s+import\b/u.exec(line);
      if (from) dependencies.add(from[1].split('.')[0]);
      const imported = /^\s*import\s+(.+)/u.exec(line);
      if (imported) for (const item of imported[1].split(',')) {
        const name = /^\s*([A-Za-z_][\w.]*)/u.exec(item);
        if (name) dependencies.add(name[1].split('.')[0]);
      }
    }
  }
  return [...dependencies].sort(compare);
}

function classify(name) {
  const ext = path.posix.extname(name).toLowerCase();
  if (['.r', '.rmd', '.py', '.ipynb', '.qmd', '.sh'].includes(ext)) return 'code';
  if (['.png', '.jpg', '.jpeg', '.webp', '.svg', '.pdf', '.tif', '.tiff'].includes(ext)) return 'figure';
  if (['.csv', '.tsv', '.txt', '.xlsx', '.xls', '.rds', '.rda', '.rdata', '.h5ad', '.h5', '.mtx'].includes(ext)) return 'data';
  if (['.zip', '.rar', '.7z', '.tar', '.gz'].includes(ext)) return 'archive';
  if (['.md', '.html', '.docx', '.pptx', '.yml', '.yaml', '.json'].includes(ext)) return 'documentation';
  return 'other';
}

function families(name) {
  const patterns = [
    ['embedding', /umap|tsne|t-sne|降维/iu], ['cell_composition', /比例|构成|堆叠|堆积|composition|proportion/iu],
    ['dotplot', /dotplot|气泡|bubble/iu], ['heatmap', /heatmap|热图/iu], ['violin', /violin|小提琴/iu],
    ['cell_communication', /cellchat|cellphonedb|cpdb|nichenet|通讯|互作/iu], ['chord', /chord|弦图/iu],
    ['trajectory', /monocle|pseudotime|拟时序|轨迹/iu], ['velocity', /velocity|rna速率/iu],
    ['regulon', /scenic|regulon|转录因子|csi/iu], ['spatial', /空间|spatial/iu],
    ['enrichment', /gsea|kegg|富集|通路/iu], ['network', /igraph|string|network|网络/iu],
    ['qc', /质控|quality|qc/iu], ['clonotype', /克隆|clonotype|tcr|bcr/iu],
  ];
  return patterns.filter(([, pattern]) => pattern.test(name)).map(([family]) => family);
}

/** Read-only source scan. Any skipped/unreadable content is an explicit issue. */
export async function inventorySources({ sources, limits: overrides = {} }) {
  if (!Array.isArray(sources) || !sources.length) throw new Error('at least one source is required');
  const limits = { ...INVENTORY_LIMITS, ...overrides };
  for (const [name, value] of Object.entries(limits)) if (!Number.isSafeInteger(value) || value < 0) throw new Error(`invalid inventory limit: ${name}`);
  const records = [], issues = [], sourceRecords = [];
  let inflatedBytes = 0, omittedRecords = 0;
  const issue = (code, locator, message) => issues.push({ code, locator, message });
  const record = item => { if (records.length >= limits.maxRecords) { omittedRecords++; return undefined; } records.push(item); return item; };
  function describe(source, relativePath, archiveChain, bytes) {
    const locator = [relativePath, ...archiveChain].join('!');
    const ext = path.posix.extname(archiveChain.at(-1) ?? relativePath).toLowerCase();
    return { sourceId: source.id, relativePath, archiveChain, locator, extension: ext, category: classify(locator),
      bytes, plotFamilies: families(locator), sourceVersion: /20\d{2}[-./年]\d{1,2}(?:[-./月]\d{1,2})?/u.exec(locator)?.[0] ?? null,
      dependencies: [], dependencyScan: 'not_applicable', sha256: null, status: 'unread' };
  }
  function scanCode(item, bytes) {
    if (['.r', '.rmd', '.qmd', '.py'].includes(item.extension)) {
      if (bytes.length > limits.maxTextBytes) { item.dependencyScan = 'skipped_limit'; issue('code_text_limit', item.locator, `code exceeds ${limits.maxTextBytes} bytes`); return; }
      try { item.dependencies = staticDependencies(new TextDecoder('utf-8', { fatal: true }).decode(bytes), item.extension); item.dependencyScan = 'static_utf8'; }
      catch { item.dependencies = staticDependencies(new TextDecoder('gb18030').decode(bytes), item.extension); item.dependencyScan = 'static_gb18030'; }
    }
  }
  async function scanArchive(source, relativePath, chain, bytes, depth) {
    if (depth > limits.maxArchiveDepth) { issue('archive_depth_limit', [relativePath, ...chain].join('!'), `nested archive depth exceeds ${limits.maxArchiveDepth}`); return; }
    if (bytes.length > limits.maxArchiveBytes) { issue('archive_bytes_limit', [relativePath, ...chain].join('!'), `archive exceeds ${limits.maxArchiveBytes} bytes`); return; }
    let entries;
    try { entries = zipEntries(bytes); } catch (error) { issue('archive_unreadable', [relativePath, ...chain].join('!'), error.message); return; }
    const seen = new Set();
    for (const entry of entries) {
      if (entry.directory) continue;
      const name = entry.name.replaceAll('\\', '/'), archiveChain = [...chain, name];
      const item = record({ ...describe(source, relativePath, archiveChain, entry.uncompressedBytes), nameEncoding: entry.encoding,
        ...(entry.alternateUtf8Name ? { alternateUtf8Name: entry.alternateUtf8Name } : {}), compressedBytes: entry.compressedBytes });
      if (!item) continue;
      try {
        if (name.includes('\0') || name.startsWith('/') || /^[A-Za-z]:/u.test(name) || name.split('/').some(p => p === '..')) throw new Error('unsafe archive entry path');
        if (seen.has(folded(name))) throw new Error('duplicate or case-colliding archive entry path');
        seen.add(folded(name));
        if (entry.symlink) throw new Error('archive symlink not read');
        if (entry.flags & 1) throw new Error('encrypted ZIP entry not read');
        if (entry.uncompressedBytes > limits.maxEntryBytes || inflatedBytes + entry.uncompressedBytes > limits.maxInflatedBytes) {
          item.status = 'skipped_limit'; issue('archive_entry_limit', item.locator, `entry/global inflation limit: ${entry.uncompressedBytes} bytes`); continue;
        }
        inflatedBytes += entry.uncompressedBytes;
        const data = entryBytes(bytes, entry);
        item.sha256 = hash(data); item.status = 'read'; scanCode(item, data);
        if (item.extension === '.zip') await scanArchive(source, relativePath, archiveChain, data, depth + 1);
        else if (item.category === 'archive') issue('archive_format_unsupported', item.locator, `${item.extension} archive enumerated but not expanded`);
      } catch (error) { item.status = 'unreadable'; issue('archive_entry_unreadable', item.locator, error.message); }
    }
  }
  async function walk(source, directory, relative = '') {
    let children;
    try { children = await fs.readdir(directory, { withFileTypes: true }); }
    catch (error) { issue('directory_unreadable', relative || source.root, error.message); return; }
    children.sort((a, b) => compare(a.name, b.name));
    for (const child of children) {
      const rel = relative ? `${relative}/${child.name}` : child.name, file = path.join(directory, child.name);
      if (child.isSymbolicLink()) { issue('source_symlink_skipped', rel, 'symlink not followed'); continue; }
      if (child.isDirectory()) { await walk(source, file, rel); continue; }
      if (!child.isFile()) { issue('source_nonregular_skipped', rel, 'nonregular file not read'); continue; }
      let item;
      try {
        const stat = await fs.lstat(file);
        if (stat.isSymbolicLink() || !stat.isFile()) throw new Error('file changed into a nonregular source');
        item = record(describe(source, rel, [], stat.size));
        if (!item) continue;
        item.sha256 = await digestFile(file); item.status = 'read';
        if (item.extension === '.zip') {
          if (stat.size > limits.maxArchiveBytes) issue('archive_bytes_limit', rel, `archive exceeds ${limits.maxArchiveBytes} bytes`);
          else await scanArchive(source, rel, [], new Uint8Array(await fs.readFile(file)), 1);
        } else if (['.r', '.rmd', '.qmd', '.py'].includes(item.extension)) {
          if (stat.size > limits.maxTextBytes) { item.dependencyScan = 'skipped_limit'; issue('code_text_limit', rel, `code exceeds ${limits.maxTextBytes} bytes`); }
          else scanCode(item, new Uint8Array(await fs.readFile(file)));
        } else if (item.category === 'archive') issue('archive_format_unsupported', rel, `${item.extension} archive enumerated but not expanded`);
      } catch (error) { if (item) item.status = 'unreadable'; issue('file_unreadable', rel, error.message); }
    }
  }
  for (let index = 0; index < sources.length; index++) {
    const source = { id: `source-${index + 1}`, root: path.resolve(sources[index]) }; sourceRecords.push(source);
    try { await regularRoot(source.root); await walk(source, source.root); }
    catch (error) { issue('source_unreadable', source.root, error.message); }
  }
  if (omittedRecords) issue('record_count_limit', '*', `${omittedRecords} records omitted after limit ${limits.maxRecords}`);
  const groups = new Map();
  for (const item of records) if (item.sha256) {
    const group = groups.get(item.sha256) ?? []; group.push({ sourceId: item.sourceId, locator: item.locator }); groups.set(item.sha256, group);
  }
  const duplicateGroups = [...groups].filter(([, members]) => members.length > 1).map(([sha256, members]) => ({ sha256, members }));
  const categories = {}, extensions = {}, plotFamilies = {}, dependencies = {};
  for (const item of records) {
    categories[item.category] = (categories[item.category] ?? 0) + 1;
    extensions[item.extension || '(none)'] = (extensions[item.extension || '(none)'] ?? 0) + 1;
    for (const name of item.plotFamilies) plotFamilies[name] = (plotFamilies[name] ?? 0) + 1;
    for (const name of item.dependencies) dependencies[name] = (dependencies[name] ?? 0) + 1;
  }
  return { schema: 'figure-library.private-source-inventory.v1', generatedAt: new Date().toISOString(), sources: sourceRecords,
    limits, records, duplicateGroups, issues, summary: { records: records.length, omittedRecords, inflatedBytes,
      complete: issues.length === 0, issueCount: issues.length, duplicateGroups: duplicateGroups.length,
      codeDependencyMethod: 'static heuristic; not installation or execution verification',
      categories, extensions, plotFamilies, dependencies } };
}

function csvCell(value) { return `"${String(value ?? '').replaceAll('"', '""')}"`; }
// Resolve aliases even when the requested leaf directories do not exist yet.
// realpath of the nearest existing ancestor preserves Windows junction semantics.
async function physicalPath(value) {
  let ancestor = path.resolve(value);
  const missing = [];
  while (true) {
    try { return path.join(await fs.realpath(ancestor), ...missing.reverse()); }
    catch (error) {
      if (error.code !== 'ENOENT') throw error;
      const parent = path.dirname(ancestor);
      if (parent === ancestor) throw error;
      missing.push(path.basename(ancestor)); ancestor = parent;
    }
  }
}

function assertOutsideSources(root, sources, message = 'inventory output must be outside scanned source roots') {
  for (const source of sources) {
    const rel = path.relative(source, root);
    if (!rel || (!rel.startsWith(`..${path.sep}`) && rel !== '..' && !path.isAbsolute(rel))) {
      throw new Error(message);
    }
  }
}

export async function writeInventoryReport(report, out) {
  const root = await physicalPath(out);
  const sources = await Promise.all(report.sources.map(source => physicalPath(source.root)));
  assertOutsideSources(root, sources);
  await fs.mkdir(root, { recursive: true });
  assertOutsideSources(await fs.realpath(root), sources);
  await fs.writeFile(path.join(root, 'inventory.json'), `${JSON.stringify(report, null, 2)}\n`);
  const columns = ['sourceId', 'relativePath', 'archiveChain', 'extension', 'category', 'bytes', 'sha256', 'status', 'nameEncoding', 'sourceVersion', 'plotFamilies', 'dependencies', 'dependencyScan'];
  const lines = [columns.join(','), ...report.records.map(row => columns.map(key => csvCell(Array.isArray(row[key]) ? row[key].join(' | ') : row[key])).join(','))];
  await fs.writeFile(path.join(root, 'inventory.csv'), `\ufeff${lines.join('\r\n')}\r\n`);
  await fs.writeFile(path.join(root, 'summary.md'), `# 私有来源盘点\n\n记录数：${report.summary.records}。重复内容组：${report.summary.duplicateGroups}。问题数：${report.summary.issueCount}。\n\n` +
    `${report.summary.complete ? '本次扫描未报告跳过或读取错误。' : '本次存在未展开、跳过或读取错误；不代表全部内容已经读完。'}\n\n依赖与图家族来自静态启发式识别，不代表包已安装或代码已验证。详细原因见 inventory.json 的 issues；来源路径、私有名称及文件内容只留在私有盘点目录。\n\n` +
    `类别统计：\n\n${Object.entries(report.summary.categories).map(([name, count]) => `- ${name}: ${count}`).join('\n')}\n`);
  return root;
}

async function allFiles(root, prefix = '') {
  const output = [];
  for (const entry of (await fs.readdir(path.join(root, prefix), { withFileTypes: true })).sort((a, b) => compare(a.name, b.name))) {
    const rel = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isSymbolicLink()) throw new Error(`symlink in private template: ${rel}`);
    if (entry.isDirectory()) output.push(...await allFiles(root, rel));
    else if (entry.isFile()) { safeRelative(rel); output.push(rel); }
    else throw new Error(`nonregular private-template asset: ${rel}`);
  }
  return output;
}

/** Return the exact plan_publish request; do not invent human confirmations or publish. */
export async function buildPrivateCandidate({ template, mode = 'create' }) {
  const root = await regularRoot(template), templateId = path.basename(root);
  if (!ID.test(templateId) || !['create', 'update'].includes(mode)) throw new Error('invalid templateId or candidate mode');
  const details = JSON.parse(await fs.readFile(await regularFile(root, 'details.json'), 'utf8'));
  for (const field of ['title', 'titleEn', 'plotFamily', 'scientificQuestion', 'description', 'application', 'dataProfile', 'visualProfile']) {
    if (typeof details[field] !== 'string' || !details[field].trim()) throw new Error(`details.json requires ${field}`);
  }
  if (!Array.isArray(details.packages) || details.packages.some(item => typeof item !== 'string' || !item.trim())) throw new Error('details.packages must be an array of package names');
  if (!['original', 'derived_example', 'synthetic'].includes(details.dataScope)) throw new Error('invalid details.dataScope');
  if (!Array.isArray(details.inputs) || !Array.isArray(details.sourceRefs) || !Array.isArray(details.semanticDecisions)) throw new Error('details requires inputs/sourceRefs/semanticDecisions arrays');
  const selected = await allFiles(root), code = selected.filter(rel => rel.startsWith('code/') && /\.(r|py)$/iu.test(rel));
  const entrypoint = code.includes('code/plot.R') ? 'code/plot.R' : code.includes('code/plot.py') ? 'code/plot.py' : undefined;
  if (!entrypoint) throw new Error('private template requires code/plot.R or code/plot.py');
  const inputPaths = details.inputs.map(item => {
    if (!item || typeof item.description !== 'string') throw new Error('input requires path and description');
    return safeRelative(item.path);
  });
  if (!inputPaths.includes('params.yml')) inputPaths.push('params.yml');
  const inputSet = new Set();
  for (const rel of inputPaths) { if (inputSet.has(folded(rel))) throw new Error(`duplicate input path: ${rel}`); inputSet.add(folded(rel)); }
  const documentation = ['README.md', 'data_schema.yml', 'provenance.md', 'details.json'];
  for (const rel of [...inputPaths, ...documentation, 'preview.png']) await regularFile(root, rel);
  const evidence = selected.filter(rel => rel.startsWith('evidence/'));
  const optionalDocuments = ['description.md', 'template.yml', 'plot.pdf'].filter(rel => selected.includes(rel));
  // Standalone conversion recipes are preserved as references. They are not
  // plotting dependencies: their external inputs and execution remain host-owned.
  const adapters = selected.filter(rel => rel.startsWith('adapters/'));
  const support = [...new Set([...inputPaths, ...documentation, ...optionalDocuments, ...adapters])];
  const allSelected = [...code, ...support, ...evidence, 'preview.png'];
  const identities = new Map();
  for (const rel of allSelected) identities.set(rel, { path: rel, sha256: await digestFile(await regularFile(root, rel)) });
  const ids = new Set();
  function assetId(rel) {
    let id = rel.replace(/\.[^.]+$/u, '').replaceAll('/', '-').replace(/[^A-Za-z0-9._-]/gu, '-').replace(/^-+/u, '').slice(0, 100) || 'asset';
    if (rel.startsWith('code/')) id = id.replace(/^code-/u, '');
    if (ids.has(folded(id))) id += `-${hash(rel).slice(0, 8)}`;
    if (ids.has(folded(id)) || !ID.test(id)) throw new Error(`assetId collision: ${rel}`);
    ids.add(folded(id)); return id;
  }
  const mapping = new Map(allSelected.map(rel => [rel, assetId(rel)]));
  function asset(rel) { return { assetId: mapping.get(rel), sourcePath: path.join(root, ...rel.split('/')),
    origin: { adapter: 'private-template-migration', stagingPath: rel }, rights: { license: 'unknown', distribution: 'local_only' } }; }
  const logical = (category, rel) => `${category}/${mapping.get(rel)}${path.extname(rel).toLowerCase()}`;
  const warnings = [];
  const scope = { original: 'real_data', derived_example: 'example_data', synthetic: 'synthetic_data' }[details.dataScope];
  let status = 'not_run';
  if (evidence.includes('evidence/render.json')) {
    const render = JSON.parse(await fs.readFile(path.join(root, 'evidence', 'render.json'), 'utf8'));
    const requiredEvidence = [...code, ...inputPaths, 'preview.png'];
    const observed = new Map();
    if (Array.isArray(render.files)) for (const item of render.files) {
      if (!item || !SHA.test(item.sha256) || observed.has(item.path)) throw new Error('render evidence contains invalid or duplicate file identities');
      observed.set(safeRelative(item.path), item.sha256);
    }
    if (render.status === 'passed' && render.scope === scope && requiredEvidence.every(rel => observed.get(rel) === identities.get(rel).sha256)) status = 'passed';
    else warnings.push('Render evidence does not bind all current code, input and preview bytes; plot execution remains not_run.');
  } else warnings.push('No render evidence; plot execution remains not_run.');
  const codeIds = code.map(rel => mapping.get(rel)), previewId = mapping.get('preview.png');
  const sourceRefs = [];
  for (const ref of details.sourceRefs) {
    if (!ref || typeof ref.path !== 'string' || !ref.path) throw new Error('source reference requires a private path');
    const basename = /^[A-Za-z]:[\\/]|^\\\\/u.test(ref.path) ? path.win32.basename(ref.path) : path.basename(ref.path);
    let sha256 = SHA.test(ref.sha256 ?? '') ? ref.sha256 : undefined;
    if (!sha256 && path.isAbsolute(ref.path)) {
      try { const stat = await fs.lstat(ref.path); if (stat.isFile() && !stat.isSymbolicLink()) sha256 = await digestFile(ref.path); }
      catch { /* The prepared package remains self-contained if its source is offline. */ }
    }
    sourceRefs.push({ sourceId: hash(ref.path), basename,
      ...(sha256 ? { sha256 } : {}), ...(ref.archiveEntry ? { archiveEntry: safeRelative(ref.archiveEntry.replaceAll('\\', '/')) } : {}),
      notes: 'Original locator and annotations remain in private details.json and provenance.md.' });
  }
  const candidate = {
    mode, templateId, title: details.title, titleEn: details.titleEn, description: details.description,
    scientificQuestion: details.scientificQuestion, application: details.application, dataProfile: details.dataProfile,
    visualProfile: details.visualProfile, tags: [...new Set([templateId, details.plotFamily, 'single-cell', ...(details.tags ?? [])])],
    packages: [...new Set(details.packages)], license: 'unknown', assetKind: 'plot_template',
    language: entrypoint.endsWith('.R') ? 'R' : 'Python', plotFamily: details.plotFamily, codeStatus: 'scaffold', executionStatus: status,
    visualAssets: [{ ...asset('preview.png'), visualRole: 'rendered_output', mediaType: 'image/png' }],
    codeAssets: code.map(rel => ({ ...asset(rel), language: rel.toLowerCase().endsWith('.r') ? 'R' : 'Python', codeOrigin: 'adapted' })),
    referenceAssets: support.map(asset), evidenceAssets: evidence.map(asset),
    primaryVisualAssetId: previewId, canonicalCodeAssetId: mapping.get(entrypoint),
    figureCodeLinks: [{ visualAssetId: previewId, codeAssetIds: codeIds, relationship: 'generated_output',
      evidence: status === 'passed' ? 'evidence/render.json binds the current code, inputs and generated PNG by SHA-256.' : 'Proposed renderer/output association; current-byte execution evidence is not established.' }],
    validationState: { schema: 'figure-library.validation-state.v1', plotExecution: { status, scope,
      ...(status === 'passed' ? { evidenceAssetIds: evidence.map(rel => mapping.get(rel)) } : {}) },
      upstreamWorkflow: { status: 'not_run' }, scientificValidation: { status: 'not_assessed' } },
    provenance: { adapter: 'private-template-migration', dataScope: details.dataScope, sourceRefs,
      semanticDecisions: details.semanticDecisions, redistribution: 'not_established', stagingOnly: true },
    runtime: { schema: 'figure-library.runtime-closure.v1', entrypoint: logical('code', entrypoint),
      dependencies: code.filter(rel => rel !== entrypoint).map(rel => ({ codePath: rel, assetPath: logical('code', rel) })),
      inputs: inputPaths.map(rel => ({ codePath: rel, assetPath: logical('references', rel), required: true,
        role: details.dataScope === 'original' ? 'source_data' : 'example_data' })),
      output: { previewPath: `visuals/rendered/${previewId}.png`, mediaType: 'image/png' } },
    ...(warnings.length ? { assessment: { warnings: warnings.map((message, index) => ({ code: `private_migration_evidence_${index + 1}`, message })) } } : {}),
  };
  return { target: 'local', candidate };
}

/** Restore mapped runtime files into a new host-owned work folder. Never execute. */
export async function prepareMaterializedWork({ template, out }) {
  const root = await regularRoot(template);
  if (!path.isAbsolute(out)) throw new Error('work output must be an absolute path');
  const target = await physicalPath(out);
  assertOutsideSources(target, [await fs.realpath(root)], 'work output must be outside materialized template root');
  try { await fs.lstat(target); throw new Error('work output already exists'); } catch (error) { if (error.code !== 'ENOENT') throw error; }
  const descriptorBytes = await fs.readFile(await regularFile(root, 'template.json'));
  const descriptor = JSON.parse(descriptorBytes);
  if (descriptor.schema !== 'figure-library.materialized-template.v1' || descriptor.providerId !== 'org.scientificfigurelibrary.local') throw new Error('requires a Local Published materialized template');
  const lock = JSON.parse(await fs.readFile(await regularFile(root, 'template.lock.json'), 'utf8'));
  if (lock.schema !== 'figure-library.template-lock.v1' || lock.providerId !== descriptor.providerId ||
      !['templateId', 'revisionId', 'contentDigest', 'releaseId'].every(key => typeof descriptor.selector?.[key] === 'string' && lock.selector?.[key] === descriptor.selector[key]) ||
      !SHA.test(lock.selector?.releaseDigest ?? '')) throw new Error('materialization lock identity mismatch');
  if (!Array.isArray(lock.files)) throw new Error('materialization lock inventory missing');
  const locked = new Set();
  for (const file of lock.files) {
    const rel = safeRelative(file.file);
    if (locked.has(folded(rel)) || !SHA.test(file.sha256)) throw new Error('invalid or duplicate lock file');
    locked.add(folded(rel));
    const bytes = await fs.readFile(await regularFile(root, rel));
    if (hash(bytes) !== file.sha256 || bytes.length !== file.bytes) throw new Error(`materialized file digest mismatch: ${rel}`);
  }
  if (!locked.has('template.json')) throw new Error('descriptor absent from materialization lock');
  const content = descriptor.content, runtime = content?.runtime;
  if (!runtime || runtime.schema !== 'figure-library.runtime-closure.v1' || !Array.isArray(content.assets) || !Array.isArray(runtime.inputs)) throw new Error('template runtime closure missing');
  const assets = new Map(), payloads = new Map();
  for (const asset of content.assets) {
    const rel = safeRelative(asset.logicalPath);
    if (assets.has(folded(rel))) throw new Error(`case-colliding asset path: ${rel}`);
    assets.set(folded(rel), asset);
    const relative = `assets/${rel}`;
    if (!locked.has(folded(relative))) throw new Error(`asset absent from materialization lock: ${rel}`);
    const bytes = await fs.readFile(await regularFile(root, relative));
    if (hash(bytes) !== asset.sha256 || bytes.length !== asset.bytes) throw new Error(`asset digest mismatch: ${rel}`);
    payloads.set(rel, bytes);
  }
  const output = new Map(), destinationKeys = new Set(), mappedAssets = new Set();
  function add(destination, assetPath, role) {
    safeRelative(destination); safeRelative(assetPath);
    if (destinationKeys.has(folded(destination))) throw new Error(`work destination collision: ${destination}`);
    const asset = assets.get(folded(assetPath));
    if (!asset || asset.logicalPath !== assetPath || (role && asset.role !== role)) throw new Error(`missing or mismatched runtime asset: ${assetPath}`);
    destinationKeys.add(folded(destination)); mappedAssets.add(assetPath);
    output.set(destination, payloads.get(assetPath));
  }
  const entry = assets.get(folded(safeRelative(runtime.entrypoint)));
  if (!entry || content.canonicalImplementation?.assetPath !== runtime.entrypoint) throw new Error('runtime entrypoint differs from canonical code');
  add(entry.origin?.stagingPath ?? runtime.entrypoint, runtime.entrypoint, 'code');
  for (const item of runtime.dependencies ?? []) add(item.codePath, item.assetPath, 'code');
  for (const item of runtime.inputs) { if (item.required !== true) throw new Error('runtime input must be required'); add(item.codePath, item.assetPath, 'reference'); }
  if (runtime.output?.mediaType !== 'image/png' || runtime.output.previewPath !== content.primaryPreview) throw new Error('invalid runtime preview output');
  add('preview.png', runtime.output.previewPath, 'visual');
  for (const asset of content.assets) if (!mappedAssets.has(asset.logicalPath)) add(asset.origin?.stagingPath ?? asset.logicalPath, asset.logicalPath);
  const files = [...output].map(([file, bytes]) => ({ file, bytes: bytes.length, sha256: hash(bytes) })).sort((a, b) => compare(a.file, b.file));
  if (destinationKeys.has('work-origin.json')) throw new Error('reserved work-origin.json destination');
  await fs.mkdir(path.dirname(target), { recursive: true });
  const temp = path.join(path.dirname(target), `.${path.basename(target)}.tmp-${randomUUID()}`);
  await fs.mkdir(temp);
  try {
    for (const [rel, bytes] of output) { const file = path.join(temp, ...rel.split('/')); await fs.mkdir(path.dirname(file), { recursive: true }); await fs.writeFile(file, bytes, { flag: 'wx' }); }
    await fs.writeFile(path.join(temp, 'work-origin.json'), `${JSON.stringify({ schema: 'figure-library.private-work-origin.v1', selector: descriptor.selector,
      codeExecuted: false, immutableAssetsCopied: true, files }, null, 2)}\n`, { flag: 'wx' });
    // Rename does not replace a nonempty directory. Recheck absence immediately before it.
    try { await fs.lstat(target); throw new Error('work output appeared during preparation'); } catch (error) { if (error.code !== 'ENOENT') throw error; }
    await fs.rename(temp, target);
  } catch (error) { await fs.rm(temp, { recursive: true, force: true }); throw error; }
  return { out: target, files, codeExecuted: false };
}

function cliOptions(argv) {
  const [command, ...rest] = argv, options = { command, sources: [] };
  for (let i = 0; i < rest.length; i++) {
    if (!['--source', '--out', '--template', '--mode'].includes(rest[i]) || !rest[i + 1] || rest[i + 1].startsWith('--')) throw new Error(`unsupported or incomplete argument: ${rest[i]}`);
    const name = rest[i++], value = rest[i];
    if (name === '--source') options.sources.push(value); else options[name.slice(2)] = value;
  }
  return options;
}

export async function runPrivateTemplateCli(argv = process.argv.slice(2)) {
  const options = cliOptions(argv);
  if (!options.out) throw new Error('requires --out');
  if (options.command === 'inventory') {
    const report = await inventorySources(options);
    await writeInventoryReport(report, options.out);
    console.log(JSON.stringify({ out: path.resolve(options.out), ...report.summary }, null, 2));
  } else if (options.command === 'candidate') {
    const request = await buildPrivateCandidate(options);
    await fs.mkdir(path.dirname(path.resolve(options.out)), { recursive: true });
    await fs.writeFile(path.resolve(options.out), `${JSON.stringify(request, null, 2)}\n`);
    console.log(JSON.stringify({ out: path.resolve(options.out), templateId: request.candidate.templateId,
      target: request.target, executionStatus: request.candidate.executionStatus, libraryWritten: false }, null, 2));
  } else if (options.command === 'work') console.log(JSON.stringify(await prepareMaterializedWork(options), null, 2));
  else throw new Error('usage: private-template-tools.mjs inventory --source DIR [--source DIR] --out DIR | candidate --template DIR --out FILE | work --template DIR --out ABSENT_ABSOLUTE_DIR');
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  runPrivateTemplateCli().catch(error => { console.error(`PRIVATE_TEMPLATE_TOOLS_FAILED: ${error.message}`); process.exitCode = 1; });
}
