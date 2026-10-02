import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { createHash } from 'node:crypto';
import test from 'node:test';
import { zipSync, strToU8 } from 'fflate';
import { OperationRegistry } from '../src/service/operations.ts';
import { definePublishOperations } from '../src/publish-tools.ts';
import { VersionedTemplateLibrary } from '../src/versioned-library.ts';
import { ensureLibraryRootMarker } from '../src/library-runtime.ts';
import { assertRuntimeReads } from '../src/runtime-closure.ts';
// @ts-expect-error -- host-side migration scripts are plain JavaScript ESM.
import { buildPrivateCandidate, crc32, inventorySources, prepareMaterializedWork, safeRelative, staticDependencies, writeInventoryReport } from '../scripts/private-template-tools.mjs';

const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=', 'base64');
const digest = (bytes: Uint8Array | string) => createHash('sha256').update(bytes).digest('hex');
const temporary = () => fs.mkdtemp(path.join(os.tmpdir(), 'sfl-private-migration-'));

function storedZip(name: Uint8Array, data: Uint8Array) {
  const local = Buffer.alloc(30), central = Buffer.alloc(46), end = Buffer.alloc(22);
  local.writeUInt32LE(0x04034b50); local.writeUInt16LE(20, 4);
  local.writeUInt32LE(crc32(data), 14); local.writeUInt32LE(data.length, 18); local.writeUInt32LE(data.length, 22); local.writeUInt16LE(name.length, 26);
  central.writeUInt32LE(0x02014b50); central.writeUInt16LE(20, 4); central.writeUInt16LE(20, 6);
  central.writeUInt32LE(crc32(data), 16); central.writeUInt32LE(data.length, 20); central.writeUInt32LE(data.length, 24); central.writeUInt16LE(name.length, 28);
  end.writeUInt32LE(0x06054b50); end.writeUInt16LE(1, 8); end.writeUInt16LE(1, 10);
  end.writeUInt32LE(central.length + name.length, 12); end.writeUInt32LE(local.length + name.length + data.length, 16);
  return Buffer.concat([local, name, data, central, name, end]);
}

async function fixture(root: string) {
  const template = path.join(root, 'sc-fixture');
  const files: Record<string, Uint8Array | string> = {
    'code/plot.R': "source('code/common.R')\nx <- read.csv('data/input.csv')\nplot(x$x, x$y)\n",
    'code/common.R': "params <- yaml::read_yaml('params.yml')\n",
    'data/input.csv': 'x,y\n1,2\n2,3\n', 'params.yml': 'width: 6\n',
    'README.md': '# Private fixture\n', 'data_schema.yml': 'columns: [x, y]\n',
    'description.md': '# 中文模板说明\n\n可复用接口与解释边界。\n', 'template.yml': 'schema: private-staging\n',
    'provenance.md': 'Synthetic fixture for adapter tests; no actual plotting execution is claimed by this test.\n',
    'preview.png': PNG, 'plot.pdf': '%PDF-1.4\n', 'evidence/sessionInfo.txt': 'Fixture runtime information\n',
  };
  for (const [rel, bytes] of Object.entries(files)) { await fs.mkdir(path.dirname(path.join(template, rel)), { recursive: true }); await fs.writeFile(path.join(template, rel), bytes); }
  await fs.writeFile(path.join(template, 'details.json'), JSON.stringify({ title: '测试图', titleEn: 'Test figure',
    description: 'Reusable fixture.', application: 'Demonstrate a plotting adapter.', scientificQuestion: 'How do fixture observations vary?',
    visualProfile: 'Scatter layout.', dataProfile: 'An x/y table.', plotFamily: 'scatter', packages: ['yaml'],
    dataScope: 'synthetic', inputs: [{ path: 'data/input.csv', description: 'Synthetic x/y input.' }], sourceRefs: [], semanticDecisions: [] }));
  await fs.writeFile(path.join(template, 'evidence', 'render.json'), JSON.stringify({ status: 'passed', scope: 'synthetic_data',
    files: ['code/plot.R', 'code/common.R', 'data/input.csv', 'params.yml', 'preview.png'].map(rel => ({ path: rel, sha256: digest(files[rel]!) })) }));
  return template;
}

async function publishedFixture(root: string, standaloneAdapter = false) {
  const template = await fixture(root);
  if (standaloneAdapter) {
    await fs.mkdir(path.join(template, 'adapters'));
    await fs.writeFile(path.join(template, 'adapters', 'prepare.R'),
      "# Standalone conversion recipe; never executed by SFL.\nargs <- commandArgs(trailingOnly=TRUE)\nx <- readRDS(args[1])\nstop('Host must explicitly run this recipe')\n");
  }
  const request = await buildPrivateCandidate({ template });
  const libraryRoot = path.join(root, 'isolated-library'); await ensureLibraryRootMarker(libraryRoot);
  const library = new VersionedTemplateLibrary(libraryRoot), ops = new OperationRegistry();
  definePublishOperations({ operations: ops, currentLibrary: async () => library });
  const planned = (await ops.execute('figure_library_plan_publish', request)).structuredContent as any;
  assert.equal(planned.envelope.code, 'publish_plan_ready', JSON.stringify(planned));
  assert.equal(await library.getSeries('sc-fixture'), undefined);
  const applied = (await ops.execute('figure_library_apply_publish', { planDigest: planned.plan.planDigest, operationId: 'test-private-publication' })).structuredContent as any;
  assert.equal(applied.envelope.outcome, 'applied', JSON.stringify(applied));
  const release = (await library.history('sc-fixture')).releases[0]!;
  const materialized = await library.materializeRevision({ templateId: release.templateId, revisionId: release.revisionId,
    contentDigest: release.contentDigest, releaseId: release.releaseId, destination: path.join(root, 'materialized'), operationId: 'test-materialization', planDigest: digest('host-test-plan') });
  return { template, request, library, materialized };
}

test('inventory reads nested GBK-named ZIP code and detects cross-source content duplicates', async t => {
  const root = await temporary(); t.after(() => fs.rm(root, { recursive: true, force: true }));
  const source = path.join(root, 'source'); await fs.mkdir(source);
  const code = strToU8('library(ggplot2)\nyaml::read_yaml("params.yml")\n');
  const inner = storedZip(Uint8Array.from([0xcd, 0xbc, 0x2e, 0x52]), code); // GBK: 图.R
  await fs.writeFile(path.join(source, 'case.zip'), zipSync({ 'nested.zip': inner, 'duplicate.R': code }));
  await fs.writeFile(path.join(source, 'same.R'), code);
  await fs.writeFile(path.join(source, 'unflagged-utf8.zip'), storedZip(strToU8('图.R'), strToU8('plot(2)')));
  const report = await inventorySources({ sources: [source] });
  const nested = report.records.find((row: any) => row.locator === 'case.zip!nested.zip!图.R');
  assert.ok(nested, JSON.stringify({ locators: report.records.map((row: any) => row.locator), issues: report.issues })); assert.equal(nested.nameEncoding, 'gb18030-unflagged');
  assert.deepEqual(nested.dependencies, ['ggplot2', 'yaml']); assert.equal(nested.sha256, digest(code));
  assert.equal(report.summary.complete, true);
  assert.equal(report.records.find((row: any) => row.locator === 'unflagged-utf8.zip!图.R').nameEncoding, 'utf-8-unflagged-gb18030-invalid');
  assert.equal(report.duplicateGroups.find((group: any) => group.sha256 === digest(code)).members.length, 3);
  await writeInventoryReport(report, path.join(root, 'inventory'));
  assert.match(await fs.readFile(path.join(root, 'inventory', 'inventory.csv'), 'utf8'), /图.R/u);
  await assert.rejects(writeInventoryReport(report, path.join(source, 'inventory')), /outside scanned source/u);
});

test('inventory reports malformed paths, unsupported archives, unreadable ZIPs and limits explicitly', async t => {
  const root = await temporary(); t.after(() => fs.rm(root, { recursive: true, force: true }));
  const source = path.join(root, 'source'); await fs.mkdir(source);
  await fs.writeFile(path.join(source, 'unsafe.zip'), storedZip(strToU8('../escape.R'), strToU8('plot(1)')));
  await fs.writeFile(path.join(source, 'invalid.zip'), 'not a ZIP');
  await fs.writeFile(path.join(source, 'unsupported.7z'), '7z fixture');
  await fs.writeFile(path.join(source, 'large.zip'), zipSync({ 'too-large.csv': strToU8('a'.repeat(40)) }));
  const report = await inventorySources({ sources: [source], limits: { maxEntryBytes: 16 } });
  assert.equal(report.summary.complete, false);
  for (const expected of ['archive_entry_unreadable', 'archive_unreadable', 'archive_format_unsupported', 'archive_entry_limit']) assert.ok(report.issues.some((issue: any) => issue.code === expected));
  assert.equal(report.records.find((row: any) => row.locator === 'unsafe.zip!../escape.R').sha256, null);
  const bounded = await inventorySources({ sources: [source], limits: { maxRecords: 1 } });
  assert.ok(bounded.summary.omittedRecords > 0); assert.ok(bounded.issues.some((issue: any) => issue.code === 'record_count_limit'));
});

test('inventory rejects undersized deflate declarations even when CRC matches the truncated prefix and accepts empty entries', async t => {
  const root = await temporary(); t.after(() => fs.rm(root, { recursive: true, force: true }));
  const source = path.join(root, 'source'); await fs.mkdir(source);
  const bytes = Buffer.from(zipSync({ 'input.txt': strToU8('abcdefgh') }));
  assert.equal(bytes.readUInt16LE(8), 8);
  const central = bytes.readUInt32LE(bytes.length - 22 + 16), prefixCrc = crc32(strToU8('abc'));
  bytes.writeUInt32LE(3, central + 24); bytes.writeUInt32LE(prefixCrc, central + 16);
  bytes.writeUInt32LE(3, 22); bytes.writeUInt32LE(prefixCrc, 14);
  await fs.writeFile(path.join(source, 'undersized.zip'), bytes);
  const empty = Buffer.from(zipSync({ 'empty.csv': new Uint8Array() }));
  assert.equal(empty.readUInt16LE(8), 8);
  await fs.writeFile(path.join(source, 'empty.zip'), empty);
  const report = await inventorySources({ sources: [source] });
  const invalid = report.records.find((row: any) => row.locator === 'undersized.zip!input.txt');
  assert.equal(invalid.status, 'unreadable'); assert.equal(invalid.sha256, null);
  assert.ok(report.issues.some((issue: any) => issue.code === 'archive_entry_unreadable' && issue.locator === invalid.locator));
  const valid = report.records.find((row: any) => row.locator === 'empty.zip!empty.csv');
  assert.equal(valid.status, 'read'); assert.equal(valid.bytes, 0); assert.equal(valid.sha256, digest(''));
  assert.equal(report.summary.complete, false);
});

test('inventory resolves output junctions or symlinks and missing descendants without writing to sources', async t => {
  const root = await temporary(); t.after(() => fs.rm(root, { recursive: true, force: true }));
  const source = path.join(root, 'source'), alias = path.join(root, 'outside-source-alias');
  const safe = path.join(root, 'safe-output'), safeAlias = path.join(root, 'safe-output-alias');
  await fs.mkdir(source); await fs.mkdir(safe);
  await fs.writeFile(path.join(source, 'input.R'), 'plot(1)\n');
  const originalFiles = await fs.readdir(source);
  const linkType = process.platform === 'win32' ? 'junction' : 'dir';
  await fs.symlink(source, alias, linkType); await fs.symlink(safe, safeAlias, linkType);
  const report = await inventorySources({ sources: [source] });
  await assert.rejects(writeInventoryReport(report, alias), /outside scanned source/u);
  await assert.rejects(writeInventoryReport(report, path.join(alias, 'absent-parent', 'inventory')), /outside scanned source/u);
  const aliasedSources = { ...report, sources: report.sources.map((item: any) => ({ ...item, root: alias })) };
  await assert.rejects(writeInventoryReport(aliasedSources, path.join(source, 'inventory')), /outside scanned source/u);
  assert.deepEqual(await fs.readdir(source), originalFiles);
  assert.equal(await fs.readFile(path.join(source, 'input.R'), 'utf8'), 'plot(1)\n');
  await writeInventoryReport(report, path.join(safeAlias, 'absent-parent', 'inventory'));
  assert.ok((await fs.readdir(path.join(safe, 'absent-parent', 'inventory'))).includes('inventory.json'));
  assert.deepEqual(await fs.readdir(source), originalFiles);
});

test('static dependency extraction and portable path validation do not execute source code', () => {
  assert.deepEqual(staticDependencies('import scanpy as sc, pandas\nfrom matplotlib.pyplot import plot\n# import ignored', '.py'), ['matplotlib', 'pandas', 'scanpy']);
  for (const value of ['../escape', 'data/../../escape', 'C:/escape', '/escape', 'data\\x.csv', 'data/CON.txt', 'data/x.']) assert.throws(() => safeRelative(value), /unsafe/u);
});

test('candidate uses private rights, exact lowercased storage paths, evidence and no invented approval', async t => {
  const root = await temporary(); t.after(() => fs.rm(root, { recursive: true, force: true }));
  const template = await fixture(root), request = await buildPrivateCandidate({ template });
  assert.equal(request.target, 'local'); assert.equal(request.candidate.license, 'unknown');
  assert.equal(request.candidate.runtime.entrypoint, 'code/plot.r');
  assert.deepEqual(request.candidate.runtime.dependencies, [{ codePath: 'code/common.R', assetPath: 'code/common.r' }]);
  assert.equal(request.candidate.executionStatus, 'passed');
  assert.equal(request.candidate.confirmations, undefined); assert.equal(request.candidate.figureCodeLinks[0].confirmedBy, undefined);
  assert.ok(request.candidate.referenceAssets.every((asset: any) => asset.rights.distribution === 'local_only'));
  const originalSource = path.join(root, 'original-source.csv'); await fs.writeFile(originalSource, 'x,y\n1,2\n');
  const sourceDetails = JSON.parse(await fs.readFile(path.join(template, 'details.json'), 'utf8'));
  sourceDetails.sourceRefs = [{ path: originalSource, notes: `Private source at ${originalSource}` }];
  await fs.writeFile(path.join(template, 'details.json'), JSON.stringify(sourceDetails));
  const privateSource = await buildPrivateCandidate({ template });
  assert.equal(privateSource.candidate.provenance.sourceRefs[0].basename, 'original-source.csv');
  assert.equal(privateSource.candidate.provenance.sourceRefs[0].sha256, digest('x,y\n1,2\n'));
  assert.ok(!JSON.stringify(privateSource.candidate.provenance).includes(originalSource));
  const libraryRoot = path.join(root, 'source-provenance-library'); await ensureLibraryRootMarker(libraryRoot);
  const ops = new OperationRegistry(); definePublishOperations({ operations: ops, currentLibrary: async () => new VersionedTemplateLibrary(libraryRoot) });
  const withPrivateSource = (await ops.execute('figure_library_plan_publish', privateSource)).structuredContent as any;
  assert.equal(withPrivateSource.envelope.code, 'publish_plan_ready', JSON.stringify(withPrivateSource));
  await fs.appendFile(path.join(template, 'data', 'input.csv'), '3,4\n');
  const stale = await buildPrivateCandidate({ template });
  assert.equal(stale.candidate.executionStatus, 'not_run'); assert.ok(stale.candidate.assessment.warnings.length);
  const details = JSON.parse(await fs.readFile(path.join(template, 'details.json'), 'utf8'));
  details.inputs[0].path = '../escape.csv'; await fs.writeFile(path.join(template, 'details.json'), JSON.stringify(details));
  await assert.rejects(buildPrivateCandidate({ template }), /unsafe/u);
});

test('official isolated plan/publish/materialize works and runtime mapping restores code, inputs and documents', async t => {
  const root = await temporary(); t.after(() => fs.rm(root, { recursive: true, force: true }));
  const { template, materialized } = await publishedFixture(root), out = path.join(root, 'host-work');
  const prepared = await prepareMaterializedWork({ template: materialized.target, out });
  assert.equal(prepared.codeExecuted, false);
  for (const rel of ['code/plot.R', 'code/common.R', 'data/input.csv', 'params.yml', 'README.md', 'description.md', 'template.yml', 'data_schema.yml', 'preview.png', 'plot.pdf', 'evidence/render.json']) {
    assert.deepEqual(await fs.readFile(path.join(out, rel)), await fs.readFile(path.join(template, rel)));
  }
  assert.equal(JSON.parse(await fs.readFile(path.join(out, 'work-origin.json'), 'utf8')).codeExecuted, false);
  await assert.rejects(prepareMaterializedWork({ template: materialized.target, out }), /already exists/u);
  await fs.chmod(path.join(materialized.target, 'assets', 'code', 'plot.r'), 0o666);
  await fs.appendFile(path.join(materialized.target, 'assets', 'code', 'plot.r'), '\nchanged\n');
  await assert.rejects(prepareMaterializedWork({ template: materialized.target, out: path.join(root, 'another-work') }), /digest mismatch/u);
  await assert.rejects(fs.access(path.join(root, 'another-work')));
});

test('standalone adapters survive publication and work preparation without becoming plotting dependencies', async t => {
  const root = await temporary(); t.after(() => fs.rm(root, { recursive: true, force: true }));
  const { template, request, materialized } = await publishedFixture(root, true);
  const adapter = request.candidate.referenceAssets.find((asset: any) => asset.origin.stagingPath === 'adapters/prepare.R');
  assert.ok(adapter);
  assert.ok(!request.candidate.codeAssets.some((asset: any) => asset.origin.stagingPath.startsWith('adapters/')));
  assert.ok(!request.candidate.runtime.dependencies.some((asset: any) => asset.codePath.startsWith('adapters/')));
  assert.equal(request.candidate.executionStatus, 'passed');
  const out = path.join(root, 'host-work');
  await prepareMaterializedWork({ template: materialized.target, out });
  assert.deepEqual(await fs.readFile(path.join(out, 'adapters/prepare.R')), await fs.readFile(path.join(template, 'adapters/prepare.R')));
  assert.equal(JSON.parse(await fs.readFile(path.join(out, 'work-origin.json'), 'utf8')).codeExecuted, false);
  const stored = path.join(materialized.target, 'assets', 'references', `${adapter.assetId}.r`);
  await fs.chmod(stored, 0o666); await fs.appendFile(stored, '\nchanged recipe\n');
  await assert.rejects(prepareMaterializedWork({ template: materialized.target, out: path.join(root, 'tampered-work') }), /digest mismatch/u);
  await assert.rejects(fs.access(path.join(root, 'tampered-work')));
});

test('work rejects materialized-root descendants and alias descendants without changing the original directory', async t => {
  const root = await temporary(); t.after(() => fs.rm(root, { recursive: true, force: true }));
  const { materialized } = await publishedFixture(root);
  const source = materialized.target, alias = path.join(root, 'outside-materialized-alias');
  const originalNames = await fs.readdir(source);
  const lock = JSON.parse(await fs.readFile(path.join(source, 'template.lock.json'), 'utf8'));
  const originals = new Map<string, Buffer>(await Promise.all(
    [...lock.files.map((file: any) => file.file), 'template.lock.json'].map(async (file: string) =>
      [file, await fs.readFile(path.join(source, file))] as [string, Buffer])));
  await fs.symlink(source, alias, process.platform === 'win32' ? 'junction' : 'dir');
  for (const out of [path.join(source, 'host-work'), path.join(alias, 'host-work'), path.join(alias, 'absent-parent', 'host-work')]) {
    await assert.rejects(prepareMaterializedWork({ template: source, out }), /outside materialized template root/u);
  }
  assert.deepEqual(await fs.readdir(source), originalNames);
  for (const [file, bytes] of originals) assert.deepEqual(await fs.readFile(path.join(source, file)), bytes);
  await assert.rejects(fs.access(path.join(source, 'host-work')));
  await assert.rejects(fs.access(path.join(source, 'absent-parent')));
});

test('work refuses destination traversal and case collisions before creating output', async t => {
  const root = await temporary(); t.after(() => fs.rm(root, { recursive: true, force: true }));
  const { materialized } = await publishedFixture(root), descriptorFile = path.join(materialized.target, 'template.json');
  const original = JSON.parse(await fs.readFile(descriptorFile, 'utf8'));
  async function changedDescriptor(value: any) {
    const bytes = Buffer.from(JSON.stringify(value)); await fs.chmod(descriptorFile, 0o666); await fs.writeFile(descriptorFile, bytes);
    const lockFile = path.join(materialized.target, 'template.lock.json'), lock = JSON.parse(await fs.readFile(lockFile, 'utf8'));
    Object.assign(lock.files.find((file: any) => file.file === 'template.json'), { bytes: bytes.length, sha256: digest(bytes) });
    await fs.chmod(lockFile, 0o666); await fs.writeFile(lockFile, JSON.stringify(lock));
  }
  const traversed = structuredClone(original); traversed.content.runtime.inputs[0].codePath = '../escape.csv';
  await changedDescriptor(traversed);
  await assert.rejects(prepareMaterializedWork({ template: materialized.target, out: path.join(root, 'unsafe-work') }), /unsafe/u);
  const colliding = structuredClone(original); colliding.content.runtime.inputs[0].codePath = 'CODE/PLOT.r';
  await changedDescriptor(colliding);
  await assert.rejects(prepareMaterializedWork({ template: materialized.target, out: path.join(root, 'collision-work') }), /collision/u);
  await assert.rejects(fs.access(path.join(root, 'unsafe-work'))); await assert.rejects(fs.access(path.join(root, 'collision-work')));
});

test('official publication rejects a helper with a dynamic reader while fixed literal inputs remain valid', async t => {
  const root = await temporary(); t.after(() => fs.rm(root, { recursive: true, force: true }));
  const template = await fixture(root), libraryRoot = path.join(root, 'isolated-library');
  await ensureLibraryRootMarker(libraryRoot);
  const ops = new OperationRegistry(); definePublishOperations({ operations: ops, currentLibrary: async () => new VersionedTemplateLibrary(libraryRoot) });
  const literal = (await ops.execute('figure_library_plan_publish', await buildPrivateCandidate({ template }))).structuredContent as any;
  assert.equal(literal.envelope.code, 'publish_plan_ready', JSON.stringify(literal));
  await fs.appendFile(path.join(template, 'code', 'common.R'), "\nread_table <- function(file) read.csv(file)\n");
  const dynamic = (await ops.execute('figure_library_plan_publish', await buildPrivateCandidate({ template }))).structuredContent as any;
  assert.equal(dynamic.envelope.outcome, 'blocked'); assert.match(dynamic.envelope.summary, /runtime_input_incomplete/u);
  assert.throws(() => assertRuntimeReads("read_table <- function(file) read.csv(file)", ['data/input.csv'], 'common.R'), /unresolved runtime input/u);
});
