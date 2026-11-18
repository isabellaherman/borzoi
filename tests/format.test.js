import {test,expect,describe} from 'bun:test';
import D from '../.build/domain.mjs';
import {array,encode,decode,parseBackup} from '../src/workspace/codec.js';

// Save format 2 only adds `why` (per diagram) and `documents` (per project). A workspace that uses neither is
// written as format 1, exactly as before, so data saved by older versions round-trips byte for byte.
const v1={format:'borzoi',version:1,workspace:{nextId:6,projectId:1,documentId:2,mode:1,projects:[
  {id:1,name:'Research',diagrams:[{id:2,name:'Flow',source:'flowchart TD\nA --> B',history:[{source:'flowchart TD\nA',stamp:'2026-11-01T10:00:00Z'}]},{id:3,name:'Other',source:'',history:[]}]},
  {id:4,name:'Agents',inbox:'bz-key',seen:'msg1',diagrams:[{id:5,name:'Sent',source:'%% borzoi from Bot\nflowchart TD\nX --> Y',history:[]}]},
]}};
const v2=()=>{const raw=structuredClone(v1);raw.version=2;
  for(const p of raw.workspace.projects){p.documents=[];for(const d of p.diagrams)d.why=[];}
  raw.workspace.projects[0].diagrams[0].why=[{stamp:'2026-11-17',idea:'Plan before acting',tradeoff:'Slower on small tasks.'}];
  raw.workspace.projects[0].documents=[{id:6,name:'Study',source:'# Study\n\n```mermaid\nflowchart TD\nA --> B\n```',history:[]}];
  raw.workspace.nextId=7;return raw;};

describe('save format',()=>{
  test('a format 1 file loads with empty Why and documents, and saves back byte for byte',()=>{
    const w=decode(structuredClone(v1));
    for(const p of array(w.projects)){expect(array(p.documents)).toEqual([]);for(const d of array(p.diagrams))expect(array(d.why)).toEqual([]);}
    expect(JSON.stringify(encode(w))).toBe(JSON.stringify(v1));
  });
  test('a format 1 file keeps every project, diagram, version, inbox and the selection',()=>{
    const w=decode(structuredClone(v1)),e=encode(w).workspace;
    expect(e.projects.map(p=>p.name)).toEqual(['Research','Agents']);
    expect(e.projects[0].diagrams[0].history).toEqual(v1.workspace.projects[0].diagrams[0].history);
    expect([e.projects[1].inbox,e.projects[1].seen]).toEqual(['bz-key','msg1']);
    expect([w.project,w.diagram,w.next_id]).toEqual([1,2,6]);
  });
  test('format 2 keeps Why and documents through a save',()=>{
    const raw=v2(),w=decode(structuredClone(raw));
    expect(array(array(array(w.projects)[0].diagrams)[0].why).map(y=>y.idea)).toEqual(['Plan before acting']);
    expect(array(array(w.projects)[0].documents).map(x=>x.name)).toEqual(['Study']);
    expect(JSON.stringify(encode(w))).toBe(JSON.stringify(raw));
  });
  test('editing a diagram keeps its Why',()=>{
    let w=decode(v2());w=D.update(w,{$:'Write',source:'flowchart TD\nA --> C'});w=D.update(w,{$:'Checkpoint',stamp:'later'});
    expect(array(D.current(w).value.why)).toHaveLength(1);
  });
  test('importing a format 2 backup gives its documents new ids and keeps them',()=>{
    const mine=decode(structuredClone(v1)),incoming=decode(v2());
    const w=D.import_projects(mine,incoming.projects),e=encode(w).workspace;
    const ids=e.projects.flatMap(p=>[p.id,...p.diagrams.map(d=>d.id),...(p.documents??[]).map(x=>x.id)]);
    expect(new Set(ids).size).toBe(ids.length);expect(Math.max(...ids)).toBeLessThan(e.nextId);
    expect(e.projects.map(p=>(p.documents??[]).map(x=>x.name))).toEqual([[],[],['Study'],[]]);
  });
  test('broken format 2 data is refused before reaching the domain',()=>{
    const dup=v2();dup.workspace.projects[0].documents[0].id=2;expect(()=>decode(dup)).toThrow('duplicate');
    const bad=v2();bad.workspace.projects[0].diagrams[0].why=[{stamp:'x',idea:1,tradeoff:''}];expect(()=>decode(bad)).toThrow();
    const counter=v2();counter.workspace.nextId=6;expect(()=>decode(counter)).toThrow('counter');
  });
});

// Optional check against a real backup, run only on the owner's machine: BORZOI_BACKUP=/path/to/backup.json bun test.
// The backup is never read in CI and never committed.
const real=process.env.BORZOI_BACKUP;
(real?test:test.skip)('a real backup loads and saves back unchanged',async()=>{
  const raw=JSON.parse(await Bun.file(real).text());delete raw.exportedAt;
  const w=parseBackup(JSON.stringify(raw));
  expect(JSON.stringify(encode(w))).toBe(JSON.stringify(raw));
});
