import {test,expect,describe} from 'bun:test';
import D from '../.build/domain.mjs';
import G from '../.build/graph.mjs';
import {array,encode,decode,parseBackup} from '../src/codec.js';

const current=w=>D.current(w).value;
const history=w=>array(current(w).history);
const snapshot=w=>JSON.stringify(encode(w));

// Test data is explicit and confined to tests; production starts with no projects.
const seeded=()=>D.update(D.write_source(D.create_project(D.initial(),'Test project'),'flowchart TD\nA[Start] --> B[End]'),{$:'Checkpoint',stamp:'test version'});

describe('workspace invariants',()=>{
  test('editing one diagram never changes another project',()=>{
    let w=seeded();const first=encode(w).workspace.projects[0];
    w=D.create_project(w,'Second');w=D.update(w,{$:'Write',source:'unfinished -->'});
    expect(encode(w).workspace.projects.find(p=>p.id===first.id)).toEqual(first);
    expect(current(w).source).toBe('unfinished -->');
  });
  test('restore retains an unsnapshotted draft and the original version',()=>{
    let w=seeded();const original=current(w).source;
    w=D.update(w,{$:'Write',source:'a newer unfinished draft'});
    w=D.update(w,{$:'Restore',index:0,stamp:'2026-11-08T00:00:00Z'});
    expect(current(w).source).toBe(original);
    expect(history(w).map(v=>v.source)).toContain('a newer unfinished draft');
    expect(history(w).at(-1).source).toBe(original);
  });
  test('invalid selections and missing restoration leave state intact',()=>{
    const w=seeded();expect(snapshot(D.open(w,999,999))).toBe(snapshot(w));
    expect(snapshot(D.update(w,{$:'Restore',index:999,stamp:'now'}))).toBe(snapshot(w));
    expect(snapshot(D.create_diagram(w,999,'No parent'))).toBe(snapshot(w));
  });
  test('saving unchanged content does not duplicate a version',()=>{
    const w=seeded();expect(snapshot(D.update(w,{$:'Checkpoint',stamp:'now'}))).toBe(snapshot(w));
  });
  test('backup round trip keeps all project content and history',()=>{
    let w=D.create_project(seeded(),'Diagrama ação');
    w=D.update(w,{$:'Write',source:'flowchart TD\nA[結果] --> B[ação]'});
    w=D.update(w,{$:'Checkpoint',stamp:'2026-11-08'});
    expect(snapshot(parseBackup(JSON.stringify(encode(w))))).toBe(snapshot(w));
  });
  test('repeated imports append without collisions or overwrites',()=>{
    let w=seeded();const first=encode(w).workspace.projects[0];
    for(let i=0;i<12;i++)w=D.import_projects(w,seeded().projects);
    const data=encode(w).workspace;expect(data.projects[0]).toEqual(first);expect(data.projects.length).toBe(13);
    const ids=data.projects.flatMap(p=>[p.id,...p.diagrams.map(d=>d.id)]);
    expect(new Set(ids).size).toBe(ids.length);expect(data.nextId).toBeGreaterThan(Math.max(...ids));
    expect(snapshot(decode(encode(w)))).toBe(snapshot(w));
  });
  test('many edit/save/restore sequences never discard earlier sources',()=>{
    let w=seeded();const sources=new Set([current(w).source]);
    for(let i=0;i<80;i++){
      const source=`flowchart TD\nA[Version ${i}] --> B`;
      sources.add(source);w=D.update(w,{$:'Write',source});
      w=D.update(w,{$:'Checkpoint',stamp:String(i)});
      if(i%7===0)w=D.update(w,{$:'Restore',index:2,stamp:String(i)});
    }
    const retained=new Set(history(w).map(v=>v.source));for(const s of sources)expect(retained.has(s)).toBe(true);
  });
  test('malformed backups fail before reaching the domain',()=>{
    expect(()=>parseBackup('{oops')).toThrow();
    const a=encode(seeded());a.version=2;expect(()=>decode(a)).toThrow();
    const b=encode(seeded());b.workspace.projects[0].diagrams[0].id=1;expect(()=>decode(b)).toThrow('duplicate');
    const c=encode(seeded());c.workspace.nextId=1;expect(()=>decode(c)).toThrow('counter');
    const d=encode(seeded());d.workspace.documentId=999;expect(()=>decode(d)).toThrow('missing');
  });
});

describe('Mermaid flowchart subset',()=>{
  test('directed chain and shared identities',()=>{
    const g=G.parse('flowchart TD\n A[Start]-->B[Middle]-->C[End]\n A --> C');
    expect(g.error).toBe('');expect(array(g.nodes).map(n=>n.id)).toEqual(['A','B','C']);
    expect(array(g.edges).map(e=>[e.from,e.to])).toEqual([['A','B'],['B','C'],['A','C']]);
  });
  test('unicode, edge labels, comments, semicolons, and quoted punctuation',()=>{
    const g=G.parse('%% note\ngraph TB;A["Diagrama; ação [1]"] -->|supports| B[結果]\n%% comment');
    expect(g.error).toBe('');expect(array(g.nodes)[0].label).toBe('Diagrama; ação [1]');expect(array(g.edges)[0].label).toBe('supports');
  });
  test('bare references do not erase explicit labels',()=>{
    const g=G.parse('flowchart TD\nA[One]\nA --> B\nA[Two]');expect(g.error).toBe('');expect(array(g.nodes)[0].label).toBe('Two');
  });
  test('unsupported syntax produces a clear error',()=>{
    for(const s of ['sequenceDiagram\nA->>B:hello','flowchart LR\nA-->B','flowchart TD\nA{Decision} --> B','flowchart TD\nA -->','flowchart TD\nA[broken','flowchart TD\nA -.-> B'])expect(G.parse(s).error.length).toBeGreaterThan(0);
  });
  test('cycles are rejected before entering the initial DAG layout',()=>{
    expect(G.parse('flowchart TD\nA-->B-->A').error).toContain('Return loops');expect(G.parse('flowchart TD\nA-->A').error).toContain('Return loops');
  });
  test('invalid duplicate label syntax and reserved end are rejected',()=>{
    expect(G.parse('flowchart TD\nA[first][second]').error.length).toBeGreaterThan(0);
    expect(G.parse('flowchart TD\nA --> end').error.length).toBeGreaterThan(0);
  });
  test('large graph is bounded',()=>{
    const source='flowchart TD\n'+Array.from({length:61},(_,i)=>`N${i}[Node ${i}]`).join('\n');expect(G.parse(source).error).toContain('60 nodes');
  });
});

describe('drag to connect',()=>{
  const source='flowchart TD\n  A[Question] --> B[Evidence]\n  C[Conclusion]';
  test('a connection is one Mermaid line appended after the untouched source',()=>{
    const next=G.connect(source,'B','C');
    expect(next).toBe(source+'\n  B --> C');expect(next.startsWith(source)).toBe(true);
    expect(G.connect(source+'\n','B','C')).toBe(source+'\n  B --> C');
    expect(array(G.parse(next).edges).map(e=>`${e.from}>${e.to}`)).toEqual(['A>B','B>C']);
  });
  test('the decision crosses into JavaScript as a native boolean',()=>{
    expect(G.can_connect(source,'B','C')).toBe(true);
    expect(G.can_connect(source,'B','A')).toBe(false);
    expect(G.can_connect(source,'A','B')).toBe(false);
    expect(G.can_connect(source,'A','A')).toBe(false);
    expect(G.can_connect('flowchart TD\nA[broken','A','B')).toBe(false);
  });
  test('a connection that would pass the size limit is refused',()=>{
    const full='flowchart TD\n'+Array.from({length:60},(_,i)=>`N${i}`).join('\n')+'\n'+Array.from({length:120},(_,i)=>`N${i%59} --> N${i%59+1}`).join('\n');
    expect(G.parse(full).error).toBe('');expect(G.can_connect(full,'N0','N59')).toBe(false);
  });
});

describe('node menu',()=>{
  test('adding, adding below and renaming each append one line and stay valid',()=>{
    const first=G.add_node('','Start');expect(first).toBe('flowchart TD\n  N1["Start"]');
    const below=G.add_node_below(first,'N1','Next ação');expect(below).toBe(first+'\n  N1 --> N2["Next ação"]');
    const renamed=G.rename_node(below,'N1','Begin');expect(renamed.startsWith(below)).toBe(true);
    const g=G.parse(renamed);expect(g.error).toBe('');
    expect(array(g.nodes).map(n=>`${n.id}:${n.label}`)).toEqual(['N1:Begin','N2:Next ação']);
  });
  test('labels with brackets and quotes cannot break the source',()=>{
    const next=G.add_node('flowchart TD\nA','a [b] "c"');expect(G.parse(next).error).toBe('');
    expect(array(G.parse(next).nodes)[1].label).toBe("a [b] 'c'");
  });
});
