import {test,expect,describe} from 'bun:test';
import D from '../.build/domain.mjs';
import F from '../.build/figures.mjs';
import E from '../.build/editor.mjs';
import M from '../.build/markdown.mjs';
import {array,list,encode,decode} from '../src/workspace/codec.js';

const P=(block,offset)=>({$:'Pos',block,offset});
const B=(kind,text='',align=0,place=0)=>({$:'Block',kind,text,align,place});
const para={$:'Para'},fig=source=>({$:'Figure',lang:'mermaid',source});
const texts=e=>array(e.doc).map(b=>`${b.kind.$}${b.kind.level??''}:${b.text}`);
const snapshot=w=>JSON.stringify(encode(w));
// A project with two diagrams (ids 2 and 3) and one document (id 4).
const seeded=()=>{let w=D.write_source(D.create_project(D.initial(),'Project'),'flowchart TD\nA --> B');w=D.create_diagram(w,1,'Second');w=D.update(w,{$:'Write',source:'flowchart TD\nX --> Y'});return D.create_document(w,1,'Notes');};
const documentOf=w=>array(array(w.projects)[0].documents)[0];

describe('documents in the workspace',()=>{
  test('a new document takes the next id, and the open diagram stays open',()=>{
    const w=seeded();expect(documentOf(w)).toMatchObject({id:4,name:'Notes',source:''});
    expect([w.project,w.diagram,w.next_id]).toEqual([1,3,5]);
  });
  test('writing, renaming and deleting a document never change a diagram',()=>{
    const before=seeded(),diagrams=w=>JSON.stringify(array(array(w.projects)[0].diagrams).map(d=>[d.id,d.name,d.source,array(d.history),array(d.why)]));
    let w=D.update_document(before,1,4,{$:'Write',source:'# Hello'});w=D.update_document(w,1,4,{$:'Checkpoint',stamp:'t1'});
    w=D.update_document(w,1,4,{$:'Rename',name:'Renamed'});expect(diagrams(w)).toBe(diagrams(before));
    expect(documentOf(w)).toMatchObject({name:'Renamed',source:'# Hello'});expect(array(documentOf(w).history)).toHaveLength(1);
    expect(diagrams(D.delete_document(w,1,4))).toBe(diagrams(before));expect(array(array(D.delete_document(w,1,4).projects)[0].documents)).toEqual([]);
  });
  test('restoring a document version keeps the draft and the old version',()=>{
    let w=D.update_document(seeded(),1,4,{$:'Write',source:'old'});w=D.update_document(w,1,4,{$:'Checkpoint',stamp:'t1'});
    w=D.update_document(w,1,4,{$:'Write',source:'draft'});w=D.update_document(w,1,4,{$:'Restore',index:0,stamp:'t2'});
    expect(documentOf(w).source).toBe('old');expect(array(documentOf(w).history).map(v=>v.source)).toEqual(['old','draft','old']);
  });
  test('ids that do not exist change nothing',()=>{
    const w=seeded();expect(snapshot(D.update_document(w,1,99,{$:'Write',source:'x'}))).toBe(snapshot(w));
    expect(snapshot(D.create_document(w,99,'No project'))).toBe(snapshot(w));expect(snapshot(D.delete_document(w,1,99))).toBe(snapshot(w));
  });
  test('a workspace with a document and a Why saves as format 2 and loads back the same',()=>{
    let w=D.update_document(seeded(),1,4,{$:'Write',source:'# Notes\n\n```mermaid\n%% borzoi diagram 2\nflowchart TD\nA --> B\n```'});
    w=D.update(w,{$:'Explain',why:{$:'Why',stamp:'2026-11-18T10:00:00Z',idea:'Keep it small',tradeoff:'Less detail'}});
    const saved=encode(w);expect(saved.version).toBe(2);expect(snapshot(decode(structuredClone(saved)))).toBe(JSON.stringify(saved));
  });
});

describe('Why',()=>{
  test('a Why entry never changes the diagram source or its versions, and the newest comes first',()=>{
    let w=D.update(seeded(),{$:'Checkpoint',stamp:'t0'});const d=D.current(w).value;
    w=D.update(w,{$:'Explain',why:{$:'Why',stamp:'2026-11-17T10:00:00Z',idea:'One',tradeoff:'a'}});
    w=D.update(w,{$:'Explain',why:{$:'Why',stamp:'2026-11-18T10:00:00Z',idea:'Two',tradeoff:'b'}});
    const now=D.current(w).value;expect(now.source).toBe(d.source);expect(array(now.history)).toEqual(array(d.history));
    expect(array(now.why).map(y=>y.idea)).toEqual(['Two','One']);
  });
  test('for an agent the entries are %% lines above the Mermaid, oldest first, on one line each',()=>{
    let w=D.update(seeded(),{$:'Explain',why:{$:'Why',stamp:'2026-11-17T10:00:00Z',idea:'One\ntree',tradeoff:'Less\ndetail'}});
    expect(F.for_agent(D.current(w).value)).toBe('%% why\n%% 2026-11-17 One tree. Trade-off: Less detail\nflowchart TD\nX --> Y');
  });
});

describe('figures: diagrams inside documents',()=>{
  test('a figure points to its diagram and shows it as it is now',()=>{
    const w=seeded(),ds=array(w.projects)[0].diagrams;
    const doc=list([B(para,'Intro'),B(fig(F.with_ref(2,'stale copy')),'Caption')]),synced=array(F.sync(doc,ds));
    expect(F.ref_of(synced[1].kind.source)).toBe(2);expect(F.body_of(synced[1].kind.source)).toBe('flowchart TD\nA --> B');
    expect(synced[1].text).toBe('Caption');
  });
  test('a figure whose diagram was deleted keeps the copy saved in the document',()=>{
    const w=D.delete_diagram(seeded(),1,2),ds=array(w.projects)[0].diagrams;
    const synced=array(F.sync(list([B(fig(F.with_ref(2,'flowchart TD\nA --> B')))]),ds));
    expect(F.body_of(synced[0].kind.source)).toBe('flowchart TD\nA --> B');
  });
  test('an imported project keeps each figure on its own diagram',()=>{
    let w=seeded();const md=M.write(list([B(fig(F.with_ref(2,'flowchart TD\nA --> B'))),B(fig(F.with_ref(3,'flowchart TD\nX --> Y')))]));
    w=D.update_document(w,1,4,{$:'Write',source:md});
    const merged=D.import_projects(seeded(),decode(structuredClone(encode(w))).projects),p=array(merged.projects)[1];
    const names=new Map(array(p.diagrams).map(d=>[d.id,d.source]));
    for(const b of array(M.read(array(p.documents)[0].source)))expect(names.get(F.ref_of(b.kind.source))).toBe(F.body_of(b.kind.source));
    expect(new Set(array(merged.projects).flatMap(q=>[q.id,...array(q.diagrams).map(d=>d.id),...array(q.documents).map(x=>x.id)])).size).toBe(8);
  });
  test('a document copied for other tools has no Borzoi lines; for an agent it has the Why',()=>{
    let w=D.open(seeded(),1,2);w=D.update(w,{$:'Explain',why:{$:'Why',stamp:'2026-11-17T10:00:00Z',idea:'One tree',tradeoff:'Less detail'}});
    const ds=array(w.projects)[0].diagrams,doc=list([B(para,'Intro'),B(fig(F.with_ref(2,'old')))]);
    expect(F.export('Notes',doc,ds,false)).toBe('# Notes\n\nIntro\n\n```mermaid\nflowchart TD\nA --> B\n```');
    expect(F.export('Notes',doc,ds,true)).toContain('```mermaid\n%% why\n%% 2026-11-17 One tree. Trade-off: Less detail\nflowchart TD');
  });
});

describe('the block editor',()=>{
  test('typing, a Markdown shortcut, Enter and Backspace',()=>{
    let e=E.start(list([]));e=E.write(e,0,'# Title',7,0);expect(texts(e)).toEqual(['Head1:Title']);
    e=E.enter(e,P(0,5),P(0,5),10);e=E.write(e,1,'Body',4,20);expect(texts(e)).toEqual(['Head1:Title','Para:Body']);
    e=E.backspace(e,P(1,0),P(1,0),30);expect(texts(e)).toEqual(['Head1:TitleBody']);expect(e.caret).toMatchObject({block:0,offset:5});
  });
  test('undo and redo walk the whole history, and a new change clears redo',()=>{
    let e=E.start(list([B(para,'one')]));const first=texts(e);
    e=E.enter(e,P(0,3),P(0,3),0);e=E.write(e,1,'two',3,5000);const second=texts(e);
    e=E.undo(E.undo(e));expect(texts(e)).toEqual(first);expect(E.can_undo(e)).toBe(false);
    e=E.redo(E.redo(e));expect(texts(e)).toEqual(second);expect(E.can_redo(e)).toBe(false);
    e=E.write(E.undo(e),0,'one!',4,9000);expect(E.can_redo(e)).toBe(false);
  });
  test('a selection across blocks is one undo',()=>{
    const doc=list([B({$:'Head',level:1},'Title'),B(para,'Hello world'),B(fig('x'),'Flow'),B({$:'Bullet'},'item')]);
    let e=E.put(E.start(doc),P(0,2),P(3,2),'-',0);expect(texts(e)).toEqual(['Head1:Ti-em']);
    expect(JSON.stringify(array(E.undo(e).doc))).toBe(JSON.stringify(array(doc)));
  });
  test('letters outside the basic plane count as one letter each',()=>{
    let e=E.write(E.start(list([])),0,'a😀b',3,0);e=E.enter(e,P(0,2),P(0,2),10);expect(texts(e)).toEqual(['Para:a😀','Para:b']);
  });
  test('a very long block and a very long document do not run out of stack',()=>{
    const long='word '.repeat(20000);let e=E.write(E.start(list([])),0,long,5,0);e=E.enter(e,P(0,50000),P(0,50000),10);
    expect(array(e.doc).map(b=>b.text.length)).toEqual([50000,50000]);
    const many=list(Array.from({length:5000},(_,i)=>B(para,`line ${i}`)));e=E.put(E.start(many),P(1,0),P(4998,0),'x',0);
    expect(array(e.doc)).toHaveLength(3);expect(array(E.undo(e).doc)).toHaveLength(5000);
    expect(array(M.read(M.write(many)))).toHaveLength(5000);
  });
});

describe('documents as Markdown',()=>{
  const doc=()=>list([B({$:'Head',level:2},'Plan'),B(para,'Text  with two spaces.'),B({$:'Bullet'},'one'),B({$:'Bullet'},'two'),B({$:'Number'},'first'),B({$:'Number'},'second'),
    B({$:'Quote'},'said',1),B(para,'# not a heading'),B(para,'1. not a list'),B(para,'\\ a backslash'),B(fig('%% borzoi diagram 4\nflowchart TD\n  A --> B'),'How it flows',2,1),B(fig('flowchart TD\n  X'))]);
  test('every block is read back as it was written',()=>{
    expect(JSON.stringify(array(M.read(M.write(doc()))))).toBe(JSON.stringify(array(doc())));
  });
  test('what Borzoi writes is what it writes again after reading',()=>{
    const text=M.write(doc());expect(M.write(M.read(text))).toBe(text);
    expect(text).toContain('::: {.figure .right .top}\n```mermaid\n%% borzoi diagram 4');expect(text).toContain('- one\n- two\n\n1. first\n2. second');
  });
  test('Markdown from elsewhere is read: other fences are kept as figures, unknown lines as paragraphs',()=>{
    const read=array(M.read('Intro\n\n```js\nconst a = 1;\n```\n\n* star item\n\n| a | b |'));
    expect(read.map(b=>b.kind.$)).toEqual(['Para','Figure','Bullet','Para']);expect(read[1].kind).toMatchObject({lang:'js',source:'const a = 1;'});
  });
});
