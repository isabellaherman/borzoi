import {test,expect} from 'bun:test';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {checkBoundary,inspectSource,registeredClasses,verifySnapshot} from '../scripts/check-ui-boundary.mjs';
const known=registeredClasses('.btn {} .input {} .side {} .is-open {}');
test('application uses only the synchronized library',()=>expect(checkBoundary()).toEqual([]));
test('original CSS override failure cannot reenter the app',()=>{
  for(const [name,source] of [
    ['src/app.css','.side {width: 999px}'],
    ['index.html','<style>.input {border:0}</style>'],
    ['index.html','<input class="input" style="border:0">'],
    ['src/main.js',"input.style.border='0'"],
    ['src/main.js',"input.setAttribute('style','border:0')"],
    ['src/main.js',"document.adoptedStyleSheets=[sheet]"],
    ['src/main.js',"import './custom.css'"],
    ['src/main.js',"element('div','brand-symbol','B')"],
    ['src/main.js',"el.className='project-header'"],
    ['src/main.js',"el.classList.add('my-override')"],
  ])expect(inspectSource(name,source,known).length).toBeGreaterThan(0);
});
test('registered component composition passes',()=>{
  expect(inspectSource('src/main.js',"element('input','input'); button.classList.add('btn'); side.classList.toggle('is-open');",known)).toEqual([]);
});
test('snapshot mutations, omissions and extra styles fail',()=>{
  const dir=mkdtempSync(join(tmpdir(),'borzoi-ui-boundary-'));
  try{
    const original='.input {border: var(--border-width)}';
    const lock={files:{'ui.css':createHash('sha256').update(original).digest('hex')}};
    writeFileSync(join(dir,'ui.css'),original);expect(verifySnapshot(dir,lock)).toEqual([]);
    writeFileSync(join(dir,'ui.css'),'.input {border:0}');expect(verifySnapshot(dir,lock)[0]).toContain('changed');
    rmSync(join(dir,'ui.css'));expect(verifySnapshot(dir,lock)[0]).toContain('missing');
    writeFileSync(join(dir,'override.css'),'.side {width: 999px}');expect(verifySnapshot(dir,lock).some(e=>e.includes('Unregistered'))).toBe(true);
  }finally{rmSync(dir,{recursive:true,force:true});}
});
