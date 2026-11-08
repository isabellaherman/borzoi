import {test,expect} from 'bun:test';
import D from '../.build/domain.mjs';
import {array,encode,decode,parseBackup} from '../src/codec.js';
const current=w=>D.current(w).value;
const snapshot=w=>JSON.stringify(encode(w));
const oldSource='flowchart TD\n  A[Ask a question] --> B[Gather evidence]\n  B --> C[Compare approaches]\n  C --> D[Test an idea]\n  D --> E[Record what changed]\n';
function oldDemo(){return decode({format:'borzoi',version:1,workspace:{nextId:3,projectId:1,documentId:2,mode:0,projects:[{id:1,name:'Research notebook',diagrams:[{id:2,name:'A research flow',source:oldSource,history:[{source:oldSource,stamp:'Created'}]}]}]}});}

test('fresh production workspace opens an empty editor without seeded records',()=>{
  const w=D.initial();expect(array(w.projects)).toEqual([]);expect(D.current(w).$).toBe('None');expect(w.mode).toBe(1);
  expect(snapshot(D.write_source(w,''))).toBe(snapshot(w));
  expect(snapshot(D.update(w,{$:'Checkpoint',stamp:'now'}))).toBe(snapshot(w));
  expect(snapshot(parseBackup(JSON.stringify(encode(w))))).toBe(snapshot(w));
});
test('the first user input creates one document and preserves the exact draft',()=>{
  let w=D.write_source(D.initial(),'unfinished → ação');
  expect(array(w.projects)).toHaveLength(1);expect(current(w).source).toBe('unfinished → ação');expect(array(current(w).history)).toEqual([]);
  const id=current(w).id;w=D.write_source(w,'flowchart TD\nA --> B');
  expect(current(w).id).toBe(id);expect(array(w.projects)).toHaveLength(1);
  expect(snapshot(decode(encode(w)))).toBe(snapshot(w));
});
test('new projects and diagrams have no sample source or artificial history',()=>{
  let w=D.create_project(D.initial(),'My project');expect(current(w).source).toBe('');expect(array(current(w).history)).toEqual([]);
  w=D.create_diagram(w,w.project,'My diagram');expect(current(w).source).toBe('');expect(array(current(w).history)).toEqual([]);expect(w.mode).toBe(1);
});
test('clearing authored content remains a restorable version',()=>{
  let w=D.write_source(D.initial(),'flowchart TD\nA --> B');w=D.update(w,{$:'Checkpoint',stamp:'first'});
  w=D.write_source(w,'');w=D.update(w,{$:'Checkpoint',stamp:'cleared'});
  expect(array(current(w).history).map(v=>v.source)).toEqual(['','flowchart TD\nA --> B']);
});
test('import into an empty workspace selects a real imported diagram and reloads',()=>{
  const incoming=D.write_source(D.create_project(D.initial(),'Imported'),'flowchart TD\nA[Mine]');
  const w=D.import_projects(D.initial(),incoming.projects);
  expect(current(w).source).toBe('flowchart TD\nA[Mine]');expect(snapshot(decode(encode(w)))).toBe(snapshot(w));
  expect(snapshot(D.import_projects(w,D.initial().projects))).toBe(snapshot(w));
});
test('empty backups reject invented selections instead of accepting corrupt state',()=>{
  for(const key of ['projectId','documentId']){const data=encode(D.initial());data.workspace[key]=1;expect(()=>decode(data)).toThrow('missing');}
});
test('only the exact untouched old demo is removed, in either editor mode',()=>{
  for(const mode of [0,1])expect(snapshot(D.remove_legacy_demo(D.set_mode(oldDemo(),mode)))).toBe(snapshot(D.initial()));
});
test('startup migration preserves any edited, renamed, extended or imported workspace',()=>{
  const old=oldDemo(),modified=[
    D.update(old,{$:'Write',source:'my unsaved work'}),
    D.update(old,{$:'Write',source:''}),
    D.update(old,{$:'Rename',name:'My title'}),
    D.rename_project(old,1,'My project'),
    D.create_project(old,'Another project'),
    D.create_diagram(old,1,'Another diagram'),
    D.update(D.update(old,{$:'Write',source:'my work'}),{$:'Checkpoint',stamp:'now'}),
    D.import_projects(old,old.projects),
  ];
  for(const w of modified){expect(D.is_legacy_demo(w)).toBe(false);expect(snapshot(D.remove_legacy_demo(w))).toBe(snapshot(w));}
  const data=encode(old);data.workspace.projects[0].diagrams[0].history[0].stamp='user checkpoint';const changedHistory=decode(data);
  expect(snapshot(D.remove_legacy_demo(changedHistory))).toBe(snapshot(changedHistory));
});
