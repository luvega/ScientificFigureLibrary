import test from 'node:test';
import type {TestContext} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {createHash} from 'node:crypto';
import {resolveSourceReferences} from '../scripts/source-path-map.mjs';
const sha=(value:string)=>createHash('sha256').update(value).digest('hex');
async function fixture(t:TestContext) {
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'sfl-source-map-'));
 t.after(async()=>{assert.equal(path.dirname(root),os.tmpdir());assert.ok(path.basename(root).startsWith('sfl-source-map-'));await fs.rm(root,{recursive:true,force:true});});
 return root;
}
test('source overlay verifies relocated bytes without rewriting historical references',async t=>{
 const root=await fixture(t),old=path.join(root,'old.csv'),current=path.join(root,'current.csv');
 await fs.writeFile(current,'value\n1\n');
 const reference={path:old,sha256:sha('value\n1\n')},before=JSON.stringify(reference);
 const result=await resolveSourceReferences({references:[reference],sourceRoots:[root],mappings:[{originalPath:old,originalSha256:reference.sha256,currentPath:current,currentSha256:reference.sha256}]});
 assert.equal(result.records[0].status,'resolved');assert.equal(result.records[0].byteIdentical,true);assert.equal(JSON.stringify(reference),before);
});
test('source overlay retains both digests for documented code normalization',async t=>{
 const root=await fixture(t),old=path.join(root,'old.R'),current=path.join(root,'normalized.R');await fs.writeFile(current,'x <- 1\n');
 const originalSha256=sha('\ufeffx <- 1\r\n'),currentSha256=sha('x <- 1\n');
 const result=await resolveSourceReferences({references:[{path:old,sha256:originalSha256}],sourceRoots:[root],mappings:[{originalPath:old,originalSha256,currentPath:current,currentSha256,disposition:'normalized_code'}]});
 assert.equal(result.records[0].status,'resolved');assert.equal(result.records[0].byteIdentical,false);assert.equal(result.records[0].original.sha256,originalSha256);assert.equal(result.records[0].transformation,'normalized_code');
});
test('source overlay rejects changed current bytes',async t=>{
 const root=await fixture(t),old=path.join(root,'old.csv'),current=path.join(root,'current.csv');await fs.writeFile(current,'changed');
 const result=await resolveSourceReferences({references:[{path:old,sha256:sha('original')}],sourceRoots:[root],mappings:[{originalPath:old,originalSha256:sha('original'),currentPath:current,currentSha256:sha('original')}]});
 assert.equal(result.records[0].status,'stale_mapping');
});
test('source overlay leaves conflicting normalized versions ambiguous',async t=>{
 const root=await fixture(t),old=path.join(root,'old.R'),a=path.join(root,'a.R'),b=path.join(root,'b.R');await fs.writeFile(a,'a');await fs.writeFile(b,'b');
 const result=await resolveSourceReferences({references:[{path:old,sha256:sha('original')}],sourceRoots:[root],mappings:[{originalPath:old,originalSha256:sha('original'),currentPath:a,currentSha256:sha('a')},{originalPath:old,originalSha256:sha('original'),currentPath:b,currentSha256:sha('b')}]});
 assert.equal(result.records[0].status,'ambiguous');
});
test('source overlay cannot read a mapped file outside declared roots',async t=>{
 const root=await fixture(t),allowed=path.join(root,'allowed');await fs.mkdir(allowed);const outside=path.join(root,'outside.csv');await fs.writeFile(outside,'value');
 const result=await resolveSourceReferences({references:[{path:path.join(allowed,'old.csv'),sha256:sha('value')}],sourceRoots:[allowed],mappings:[{originalPath:path.join(allowed,'old.csv'),originalSha256:sha('value'),currentPath:outside,currentSha256:sha('value')}]});
 assert.equal(result.records[0].status,'stale_mapping');assert.match(result.records[0].errors[0].error,/outside/);
});
test('source overlay does not infer a missing historical digest',async t=>{
 const root=await fixture(t),file=path.join(root,'source.csv');await fs.writeFile(file,'value');
 const result=await resolveSourceReferences({references:[{path:file}],sourceRoots:[root],mappings:[]});assert.equal(result.records[0].status,'unverifiable');
});
test('archive metadata cannot substitute for a removed archive or its member',async t=>{
 const root=await fixture(t),old=path.join(root,'removed.zip'),catalog=path.join(root,'archive-catalog.json');await fs.writeFile(catalog,'[]');
 const result=await resolveSourceReferences({references:[{path:old,sha256:sha('archive')}],sourceRoots:[root],mappings:[{originalPath:old,originalSha256:sha('archive'),currentPath:catalog,currentSha256:sha('[]'),disposition:'expanded_container_removed'}]});
 assert.equal(result.records[0].status,'stale_mapping');assert.match(result.records[0].errors[0].error,/not source content/);
});
test('a retained archive member resolves by its own digest while retaining the container identity',async t=>{
 const root=await fixture(t),old=path.join(root,'removed.zip'),current=path.join(root,'data.csv');await fs.writeFile(current,'x\n1\n');
 const reference={path:old,sha256:sha('archive'),archiveEntry:'data.csv',archiveEntrySha256:sha('x\n1\n')};
 const result=await resolveSourceReferences({references:[reference],sourceRoots:[root],mappings:[{originalPath:path.join(root,'unpacked/data.csv'),originalSha256:reference.archiveEntrySha256,currentPath:current,currentSha256:reference.archiveEntrySha256,archiveEntry:'data.csv',disposition:'moved_unique'}]});
 assert.equal(result.records[0].status,'resolved');assert.equal(result.records[0].byteIdentical,true);assert.equal(result.records[0].matchedDigestScope,'archive_member');assert.equal(result.records[0].original.sha256,reference.sha256);
});
