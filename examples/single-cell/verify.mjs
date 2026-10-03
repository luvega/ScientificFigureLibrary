// Read-only byte verification of the public example collection; no plotting.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const root=import.meta.dirname;
const sha=b=>createHash('sha256').update(b).digest('hex');
function within(base,relative){
  assert.ok(typeof relative==='string'&&!relative.includes('\\')&&!path.isAbsolute(relative));
  assert.ok(relative.split('/').every(part=>part&&part!=='.'&&part!=='..'));
  const file=path.resolve(base,relative),rel=path.relative(base,file);
  assert.ok(rel&&!rel.startsWith('..')&&!path.isAbsolute(rel));return file;
}
async function regular(base,relative){
  const parts=relative.split('/');let file=base;
  for(const part of parts){file=path.join(file,part);assert.ok(!(await fs.lstat(file)).isSymbolicLink(),'Symlinks are not example assets');}
  assert.ok((await fs.lstat(file)).isFile());return fs.readFile(file);
}
const catalog=JSON.parse(await fs.readFile(path.join(root,'catalog.json'),'utf8'));
assert.equal(catalog.schema,'single-cell.public-examples.v1');assert.equal(catalog.templates.length,catalog.templateCount);
const ids=new Set();let files=0,bytes=0;
for(const template of catalog.templates){
  assert.match(template.id,/^sc-[a-z0-9-]+$/);assert.ok(!ids.has(template.id));ids.add(template.id);
  assert.equal(template.license,'unknown');assert.equal(template.distribution,'public_copy');
  const base=within(root,`templates/${template.id}`),observed=new Map();
  for(const file of template.files){
    within(base,file.path);assert.ok(!observed.has(file.path));
    const data=await regular(base,file.path);assert.equal(data.length,file.bytes,`${template.id}/${file.path}: size`);
    assert.equal(sha(data),file.sha256,`${template.id}/${file.path}: hash`);
    if(/\.(?:R|csv|json|yml|md|txt)$/.test(file.path))assert.ok(!/\b[A-Za-z]:[\\/]|\/Users\/|\/home\/|planDigest|libraryId|approvalEvidence/.test(data.toString('utf8')),`${template.id}/${file.path}: private machine locator`);
    observed.set(file.path,file.sha256);files++;bytes+=data.length;
  }
  const details=JSON.parse(await regular(base,'details.json'));
  const evidence=JSON.parse(await regular(base,'evidence/render.json'));
  assert.equal(evidence.status,'passed');assert.equal(evidence.exitCode,0);
  const rendered=new Map(evidence.files.map(row=>[row.path,row.sha256]));
  for(const relative of ['code/plot.R','code/common.R','params.yml',...details.inputs.map(i=>i.path),'preview.png','plot.pdf']){
    assert.ok(observed.has(relative),`${template.id}: missing ${relative}`);
    assert.equal(rendered.get(relative),observed.get(relative),`${template.id}/${relative}: stale render evidence`);
  }
}
const directories=(await fs.readdir(path.join(root,'templates'),{withFileTypes:true})).filter(e=>e.isDirectory()).map(e=>e.name).sort();
assert.deepEqual([...ids].sort(),directories);
console.log(JSON.stringify({passed:true,templates:ids.size,files,bytes,plotCodeExecuted:false}));
