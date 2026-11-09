import {test,expect,describe} from 'bun:test';
import D from '../.build/domain.mjs';
import G from '../.build/graph.mjs';
import E from '../.build/edit.mjs';
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
    // A project left with no diagrams (its last one deleted) still loads, as Domain.bend allows it.
    const e=encode(D.delete_diagram(seeded(),array(seeded().projects)[0].id,array(array(seeded().projects)[0].documents)[0].id));
    expect(()=>decode(e)).not.toThrow();expect(snapshot(decode(e))).toBe(snapshot(decode(encode(decode(e)))));
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
    for(const s of ['sequenceDiagram\nA->>B:hello','flowchart LR\nA-->B','flowchart TD\nA((Round)) --> B','flowchart TD\nA{{Hexagon}} --> B','flowchart TD\nA -- no end\nB','flowchart TD\nA -->','flowchart TD\nA[broken','flowchart TD\nA -.-> B'])expect(G.parse(s).error.length).toBeGreaterThan(0);
  });
  test('return loops and an arrow to the same node are valid, as in Mermaid',()=>{
    expect(G.parse('flowchart TD\nA-->B-->A').error).toBe('');expect(array(G.parse('flowchart TD\nA-->B-->C-->A').edges).length).toBe(3);
    expect(G.parse('flowchart TD\nA-->A').error).toBe('');expect(array(G.parse('flowchart TD\nA-->|again| A').edges)[0].label).toBe('again');
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
    expect(G.can_connect(source,'B','A')).toBe(true);
    expect(G.can_connect(source,'A','B')).toBe(false);
    expect(G.can_connect(source,'A','A')).toBe(true);expect(G.can_connect(G.connect(source,'A','A'),'A','A')).toBe(false);
    expect(G.can_connect('flowchart TD\nA[broken','A','B')).toBe(false);
  });
  test('a connection that would pass the size limit is refused',()=>{
    const full='flowchart TD\n'+Array.from({length:60},(_,i)=>`N${i}`).join('\n')+'\n'+Array.from({length:120},(_,i)=>`N${i%59} --> N${i%59+1}`).join('\n');
    expect(G.parse(full).error).toBe('');expect(G.can_connect(full,'N0','N59')).toBe(false);
  });
});

describe('node menu',()=>{
  test('a new node gets a readable id from its name and the source stays valid',()=>{
    const first=G.add_node('','Start');expect(first).toBe('flowchart TD\n  Start["Start"]');
    const below=G.add_node_below(first,'Start','Next ação');expect(below).toBe(first+'\n  Start --> Next_acao["Next ação"]');
    expect(G.add_node(below,'Start')).toBe(below+'\n  Start_2["Start"]');
    expect(G.parse(G.add_node(below,'end')).error).toBe('');
  });
  test('labels with brackets and quotes cannot break the source',()=>{
    const next=G.add_node('flowchart TD\nA','a [b] "c"');expect(G.parse(next).error).toBe('');
    expect(array(G.parse(next).nodes)[1].label).toBe('a [b] "c"');
  });
});

describe('edits in place',()=>{
  const source='flowchart TD\n  %% keep me\n  A[Idea] --> B[Draft]\n  B --> C[Review]\n  C -->|ok| D\n  E["Loose"]';
  const lines=s=>s.split('\n');
  const untouched=(before,after,changed)=>lines(before).filter(l=>!changed.some(c=>l.includes(c))).forEach(l=>expect(lines(after)).toContain(l));
  const graph=s=>{const g=G.parse(s);expect(g.error).toBe('');return {nodes:array(g.nodes).map(n=>`${n.id}:${n.label}`),edges:array(g.edges).map(e=>`${e.from}>${e.to}${e.label?':'+e.label:''}`)};};
  test('rename changes only the line that labels the node',()=>{
    const next=E.rename(source,'B','Plan');untouched(source,next,['B[']);
    expect(graph(next).nodes).toContain('B:Plan');expect(graph(next).edges).toEqual(graph(source).edges);
    expect(E.rename(source,'D','Done')).toBe(source+'\n  D["Done"]');
  });
  test('delete removes the node, its arrows and its position; nothing else is lost',()=>{
    const next=E.delete_node(E.move_node(source,'B',4,5),'B');untouched(source,next,['B']);
    expect(graph(next).nodes.map(n=>n.split(':')[0])).toEqual(['A','C','D','E']);expect(graph(next).edges).toEqual(['C>D:ok']);
    expect(next).not.toContain('borzoi B');
  });
  test('remove an arrow, and add a node between two',()=>{
    expect(graph(E.remove_edge(source,'B','C')).edges).toEqual(['A>B','C>D:ok']);
    const between=E.insert_between(source,'C','D','Check');untouched(source,between,['C -->|ok| D']);
    expect(graph(between).edges).toEqual(['A>B','B>C','C>Check:ok','Check>D']);
  });
  test('manual layout lives in %% lines that Mermaid ignores',()=>{
    let m=E.set_manual(source,true);expect(E.is_manual(m)).toBe(true);
    m=E.move_node(E.move_node(m,'A',10,20),'A',30,40);
    expect(array(E.places(m)).map(p=>`${p.id} ${p.x} ${p.y}`)).toEqual(['A 30 40']);
    expect(G.parse(m)).toEqual(G.parse(source));
    expect(E.is_manual(E.set_manual(m,false))).toBe(false);expect(array(E.places(E.set_manual(m,false))).length).toBe(1);
  });
});

describe('colors',()=>{
  test('a node takes one of the four tones from its Mermaid class, and the last one wins',()=>{
    const src='flowchart TD\n  A[Idea]:::blue --> B\n  B:::fancy\n  A:::yellow';
    expect(array(G.tones(src)).map(t=>`${t.id}=${t.tone}`)).toEqual(['A=accent','A=warning']);
    expect(G.parse(src).error).toBe('');
  });
  test('coloring keeps other lines, the shape and a user\'s own classes',()=>{
    const src='flowchart TD\n  %% note\n  A[Idea]:::fancy --> B\n  classDef fancy fill:#fff';
    const next=E.set_tone(src,'B','red');
    expect(next.startsWith(src)).toBe(true);expect(G.parse(next)).toEqual(G.parse(src));
    expect(E.set_tone(next,'B','')).toBe(src);
  });
  test('bad class syntax is explained',()=>{
    expect(G.parse('flowchart TD\n  A:::').error).toContain('class name');
    expect(G.parse('flowchart TD\n  A::b').error).toContain(':::');
  });
});

describe('deleting projects and diagrams',()=>{
  const two=()=>{let w=seeded();w=D.create_diagram(w,w.project,'Second');w=D.update(w,{$:'Write',source:'flowchart TD\nX --> Y'});w=D.create_project(w,'Other');return w;};
  test('deleting a project that is not open keeps the open diagram and the rest',()=>{
    const w=two(),first=encode(w).workspace.projects[1];
    const next=D.delete_project(w,first.id);
    expect(array(next.projects).map(p=>p.name)).toEqual(['Other']);
    expect(next.project).toBe(w.project);expect(next.document).toBe(w.document);
  });
  test('deleting the open diagram opens another, and its history goes with it',()=>{
    let w=two();const test=array(w.projects)[1],[second,start]=array(test.documents);
    w=D.open(w,test.id,second.id);const next=D.delete_diagram(w,test.id,second.id);
    expect(array(array(next.projects)[1].documents).map(d=>d.name)).toEqual([start.name]);
    // The first diagram left in the list opens: here, the newer project's.
    const other=array(next.projects)[0];
    expect(next.project).toBe(other.id);expect(next.document).toBe(array(other.documents)[0].id);
  });
  test('ids are never reused after a delete',()=>{
    const w=D.delete_project(two(),two().project),next=D.create_project(w,'New');
    expect(next.project).toBe(w.next_id);
  });
  test('deleting something missing changes nothing',()=>{
    const w=two();expect(snapshot(D.delete_project(w,999))).toBe(snapshot(w));expect(snapshot(D.delete_diagram(w,w.project,999))).toBe(snapshot(w));
  });
});

describe('agent projects',()=>{
  const agent=()=>D.create_agent_project(seeded(),'Agent test','bz-testkey');
  const agentId=w=>array(w.projects).find(p=>p.inbox).id;
  test('a message becomes a new diagram in that project only, and backups keep the key',()=>{
    const w=agent(),before=encode(w).workspace.projects.find(p=>!p.inbox);
    const next=D.receive(w,agentId(w),'bz-testkey','m1','Test title','flowchart TD\n  A --> B','t');
    const saved=encode(next).workspace.projects;
    expect(saved.find(p=>!p.inbox)).toEqual(before);
    const inbox=saved.find(p=>p.inbox);
    expect(inbox).toMatchObject({inbox:'bz-testkey',seen:'m1'});
    expect(inbox.diagrams[0]).toMatchObject({name:'Test title',source:'%% borzoi from agent\nflowchart TD\n  A --> B'});
    expect(snapshot(decode(encode(next)))).toBe(snapshot(next));
    expect(next.project).toBe(w.project);expect(next.document).toBe(w.document);
  });
  test('long titles are cut to fit the backup limits',()=>{
    const w=agent(),next=D.receive(w,agentId(w),'bz-testkey','m1','x'.repeat(500),'flowchart TD','t');
    expect(()=>decode(encode(next))).not.toThrow();
  });
  test('older backups without keys still load as normal projects',()=>{
    const raw=encode(seeded());expect(array(decode(raw).projects).every(p=>p.inbox==='')).toBe(true);
  });
});
