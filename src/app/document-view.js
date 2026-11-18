// The document screen: text and the project's diagrams, written in blocks. The editor (src/editor) holds the
// blocks in Bend; this file gives it the project's diagrams to show, saves the document as Markdown
// (Workspace.bend) and has the document's own actions: insert a diagram, copy, versions.
import { mountDiagram } from '../../vendor/bend-ui/diagram.js';
import D from '../workspace/Workspace.bend';
import F from '../workspace/Figures.bend';
import G from '../diagram/Graph.bend';
import M from '../editor/Markdown.bend';
import { mountEditor } from '../editor/editor.js';
import { array, MAX_DOCUMENT } from '../workspace/codec.js';
import { $, ui, S, hooks, sidebar, stamp, notice, change, switchTo } from './state.js';
import { element, button, icon } from './ui-kit.js';
import { openModal } from './dialogs.js';
import { graphData } from './diagram-view.js';
import { copyText } from './why.js';

let mounted=null,timer=null; // mounted: the document being written, {id, editor}
const projectOf=pid=>array(S.workspace.projects).find(p=>p.id===pid);
const diagrams=()=>projectOf(S.docProject)?.diagrams??{$:'Nil'};
export const currentDocument=()=>{const p=S.docId===null?null:projectOf(S.docProject);return p?array(p.documents).find(x=>x.id===S.docId)??null:null;};

// Save what is written. Each figure is saved with its diagram as it is now, so the document stands on its own.
function save(){
  clearTimeout(timer);timer=null;const x=currentDocument();if(!mounted||!x||mounted.id!==x.id||S.locked)return;
  const text=M.write(F.sync(mounted.editor.blocks(),diagrams()));
  if(text===x.source)return;
  if(text.length>MAX_DOCUMENT){notice('This document is full (200,000 characters), so the last change was undone.',true);mounted.editor.undo();return;}
  change(D.update_document(S.workspace,S.docProject,x.id,{$:'Write',source:text}));
}
export const flushDocument=()=>{if(timer)save();};
export function checkpointDocument(){
  save();const x=currentDocument();if(!x||S.locked||(!x.source&&!array(x.history).length))return false;
  change(D.update_document(S.workspace,S.docProject,x.id,{$:'Checkpoint',stamp:stamp()}));return true;
}
function unmount(){mounted?.editor.destroy();mounted=null;clearTimeout(timer);timer=null;}
// The document closes without saving again (it was deleted).
export function discardDocument(){unmount();S.docId=null;}
export function openDocument(pid,id){hooks.leave();S.docProject=pid;S.docId=id;S.backTo=null;sidebar.closeOnNarrow();hooks.render();}

// A figure: the diagram as it is now, with the way to edit it. A diagram that was deleted shows the copy the
// document kept.
function drawing(source){
  const mount=element('div','');
  try{const r=G.parse(source);if(!r.error&&array(r.nodes).length)mountDiagram(mount,graphData(r,source));else mount.append(element('p','detail',r.error?'This diagram has an error in its source.':'This diagram is empty.'));}
  catch{mount.append(element('p','detail','This diagram could not be drawn.'));}
  return mount;
}
function figureView(block,editor){
  const f=element('figure','panel'),head=element('header','panel__header'),body=element('div','panel__body'),tools=element('div','actions'),caption=element('p','detail');
  const mermaid=block.kind.lang==='mermaid',id=mermaid?F.ref_of(block.kind.source):0,d=id?array(diagrams()).find(q=>q.id===id):null;
  const why=d?array(d.why).length:0,project=S.docProject,from=S.docId;
  const title=d?d.name+(why?` · Why ${why}`:''):mermaid?(id?'Diagram no longer in this project':'Diagram'):(block.kind.lang||'Code');
  const tool=(label,name,fn)=>{const b=button('',fn,'btn btn--ghost btn--icon btn--sm');b.title=label;b.setAttribute('aria-label',label);b.append(icon(name));return b;};
  tools.append(tool('Write a caption','text',()=>editor.caption(f)),...(d?[button('Edit diagram',()=>switchTo(project,d.id,{project,id:from}))]:[]),tool('Remove from document','x',()=>editor.remove(f)));
  head.append(element('span','item-title',title),tools);
  body.append(mermaid?drawing(d?d.source:F.body_of(block.kind.source)):element('pre','revision-list__source',block.kind.source),caption);
  f.append(head,body);return {element:f,caption};
}
function tools(){const e=mounted?.editor;$('#doc-undo').disabled=!e?.canUndo();$('#doc-redo').disabled=!e?.canRedo();}
function changed(){tools();clearTimeout(timer);timer=setTimeout(save,300);}
function mount(x){
  unmount();
  const editor=mountEditor($('#doc-text'),{blocks:F.sync(M.read(x.source),diagrams()),figure:figureView,onChange:changed,onSlash:insertDialog,
    onError:()=>notice('That change could not be made. Your document is as it was.',true)});
  mounted={id:x.id,editor};tools();
}
export function renderDocument(){
  const x=currentDocument(),on=Boolean(x);if(!on&&S.docId!==null)discardDocument();
  $('#doc-view').hidden=!on;$('#doc-toolbar').hidden=!on;$('#canvas-scroll').hidden=on;$('#diagram-toolbar').hidden=on;
  if(on){
    $('#editor-panel').hidden=true;$('#diagram-crumb').textContent=x.name;$('#project-name').textContent=projectOf(S.docProject)?.name??'';$('#project-separator').hidden=false;
    // The same document, drawn again after something else changed: its figures show the diagrams of now.
    if(mounted?.id===x.id){mounted.editor.replace(F.sync(mounted.editor.blocks(),diagrams()));tools();}else mount(x);
  }
  const back=S.backTo&&array(projectOf(S.backTo.project)?.documents??{$:'Nil'}).find(q=>q.id===S.backTo.id);
  $('#back-to-doc').hidden=on||!back;if(back)$('#back-to-doc').lastChild.textContent=back.name;
}

function insertDialog(){
  const x=currentDocument();if(!x||!mounted)return;
  const body=openModal('Insert diagram'),list=element('div','form'),all=array(diagrams());
  if(!all.length)body.append(element('p','text','This project has no diagrams yet. Create one in the side bar, then insert it here.'));
  for(const d of all){
    const panel=element('section','panel'),head=element('header','panel__header'),pb=element('div','panel__body');
    head.append(element('span','item-title',d.name),button('Insert',()=>{ui.modal.close();mounted?.editor.insertFigure('mermaid',F.with_ref(d.id,d.source));},'btn btn--filled btn--sm'));
    pb.append(drawing(d.source));panel.append(head,pb);list.append(panel);
  }
  body.append(list);
}
function copyDialog(title,intro,text){
  const body=openModal(title),actions=element('div','actions'),copy=button('Copy',()=>copyText(text,copy),'btn btn--filled btn--sm');
  actions.append(copy);body.append(element('p','text',intro),element('pre','revision-list__source',text),actions);
}
function historyDialog(){
  const x=currentDocument();if(!x)return;save();
  const body=openModal('Version history'),list=element('div','revision-list'),versions=array(currentDocument().history);
  body.append(element('p','detail','Restoring creates a new version and preserves your current draft.'),list);
  if(!versions.length)list.append(element('p','detail','No saved versions yet.'));
  versions.forEach((v,i)=>{
    const item=element('article',''),head=element('div','revision-list__header'),date=Number.isNaN(Date.parse(v.stamp))?v.stamp:new Date(v.stamp).toLocaleString();
    const restore=button('Restore',()=>{unmount();change(D.update_document(S.workspace,S.docProject,x.id,{$:'Restore',index:i,stamp:stamp()}),{navigation:true});ui.modal.close();notice('Version restored. Your previous work is in history.');});
    head.append(element('span','item-title',`${i===0?'Latest · ':''}${date}`),restore);item.append(head,element('pre','revision-list__source',v.source));list.append(item);
  });
}
export function initDocumentView(){
  // Leaving the document: what is written is saved, and saved as a version.
  hooks.leave=()=>{if(S.docId===null)return;checkpointDocument();unmount();};
  $('#doc-text').addEventListener('focusout',()=>flushDocument());
  $('#insert-diagram').onclick=insertDialog;
  $('#doc-undo').onclick=()=>mounted?.editor.undo();
  $('#doc-redo').onclick=()=>mounted?.editor.redo();
  const exported=why=>{save();const x=currentDocument();return x&&mounted?F.export(x.name,mounted.editor.blocks(),diagrams(),why):'';};
  $('#copy-agent').onclick=()=>copyDialog('Copy for agent','The document in Markdown: your text, each diagram as Mermaid, and the Why of each diagram as %% lines.',exported(true));
  $('#copy-markdown').onclick=()=>copyDialog('Copy as Markdown','Your text with each diagram as a mermaid block. GitHub and Obsidian draw it as it is.',exported(false));
  $('#back-to-doc').onclick=()=>{const b=S.backTo;if(b)openDocument(b.project,b.id);};
  // History shows the versions of what is on screen: the document's, or the diagram's.
  const diagramHistory=$('#history').onclick;
  $('#history').onclick=e=>{if(S.docId!==null)historyDialog();else diagramHistory(e);};
}
