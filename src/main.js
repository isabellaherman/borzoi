import { createFeedback, createDialog, configureSourceEditor, createSidebar, setStatusTone } from '../vendor/bend-ui/workspace.js';
import { mountDiagram } from '../vendor/bend-ui/diagram.js';
import D from './Domain.bend';
import metadata from '../package.json';
import G from './Graph.bend';
import { array, encode, decode, parseBackup, MAX_SOURCE, MAX_BACKUP_BYTES } from './codec.js';
import { openStorage, StorageConflict } from './storage.js';

const $=s=>document.querySelector(s);
const ui={source:$('#source'),diagram:$('#diagram'),notice:$('#notice'),status:$('#save-status'),modal:$('#modal')};
const feedback=createFeedback(ui.notice);
const modal=createDialog(ui.modal,{title:$('#modal-title'),body:$('#modal-content'),close:$('#close-modal')});
const sidebar=createSidebar($('#sidebar'),$('#menu'));
configureSourceEditor(ui.source);
$('#app-version').textContent=`Borzoi · ${metadata.version}`;
let workspace=D.initial(),store,revision=0,saves=Promise.resolve(),pending=0,dirty=false,locked=false,saveError=false;
let mounted=null,lastGood=null,previewTimer=null,recoveryPayload=null;
const graphCache=new Map();
const graphKey=()=>`${workspace.project}:${workspace.document}`;
const stamp=()=>new Date().toISOString();
const doc=()=>{const v=D.current(workspace);return v.$==='Some'?v.value:null;};
const project=()=>array(workspace.projects).find(p=>p.id===workspace.project);
const element=(tag,cls,text)=>{const el=document.createElement(tag);if(cls)el.className=cls;if(text!==undefined)el.textContent=text;return el;};
function button(text,fn,cls='btn btn--ghost btn--sm'){const b=element('button',cls,text);b.type='button';b.addEventListener('click',fn);return b;}
function notice(message,error=false,permanent=false){feedback.show(message,{error,persistent:permanent});}
function setStatus(text,error=false){ui.status.textContent=text;setStatusTone(ui.status,error);}
function persist(){
  dirty=true;pending++;const payload=encode(workspace);setStatus('Saving…');
  saves=saves.then(async()=>{
    if(locked)throw new StorageConflict();
    if(!store)throw new Error('Local storage is unavailable. Download a backup before closing this page.');
    revision=await store.save(payload,revision);saveError=false;
  }).catch(error=>{saveError=true;if(error instanceof StorageConflict){locked=true;ui.source.disabled=true;}notice(error.message||'Unable to save. Download a backup before leaving.',true,true);})
  .finally(()=>{pending--;if(!pending){dirty=saveError;setStatus(saveError?'Not saved — download backup':'Saved locally',saveError);}});
  return saves;
}
function change(next,{navigation=false}={}){
  if(locked){notice('This tab is out of date. Download a backup, then reload.',true,true);return;}
  workspace=next;persist();if(navigation){lastGood=graphCache.get(graphKey())??null;render();}
}
function checkpoint(){const d=doc();if(!d||(!d.source&&!array(d.history).length)||locked)return false;change(D.update(workspace,{$:'Checkpoint',stamp:stamp()}));return true;}
function switchTo(pid,did){checkpoint();change(D.open(workspace,pid,did),{navigation:true});sidebar.closeOnNarrow();}
function icon(name,cls='icon'){
  const svg=document.createElementNS('http://www.w3.org/2000/svg','svg'),use=document.createElementNS('http://www.w3.org/2000/svg','use');
  svg.setAttribute('class',cls);svg.setAttribute('aria-hidden','true');use.setAttribute('href',`#i-${name}`);svg.append(use);return svg;
}
function navButton(label,fn,iconName){
  const b=button('',fn,'btn btn--ghost');b.title=label;
  if(iconName)b.append(icon(iconName));b.append(element('span','side__text',label));return b;
}
function renderNavigation(){
  const root=$('#project-list');root.replaceChildren();
  for(const p of array(workspace.projects)){
    const group=element('div','side__group'),head=element('button','btn btn--ghost side__toggle'),items=element('div','side__items');
    head.type='button';head.title=p.name;head.setAttribute('aria-expanded','true');
    head.append(icon('file-text'),element('span','side__text',p.name),icon('chevron-down','icon icon--sm side__chevron'));
    for(const d of array(p.documents)){
      const b=navButton(d.name,()=>switchTo(p.id,d.id));
      if(d.id===workspace.document&&p.id===workspace.project)b.setAttribute('aria-current','page');items.append(b);
    }
    items.append(navButton('New diagram',()=>nameDialog('New diagram','Untitled diagram',value=>{checkpoint();change(D.create_diagram(workspace,p.id,value),{navigation:true});}),'plus'));
    items.append(navButton('Rename project',()=>nameDialog('Rename project',p.name,value=>change(D.rename_project(workspace,p.id,value),{navigation:true}))));
    group.append(head,items);root.append(group);
  }
}
function graphData(result){
  const nodes=array(result.nodes),edges=array(result.edges),ids=new Map(nodes.map((n,i)=>[n.id,i]));
  return {ids:nodes.map(n=>n.id),nodes:nodes.map(n=>({label:n.label})),edges:edges.map(e=>({from:ids.get(e.from),to:ids.get(e.to),label:e.label}))};
}
// Editing from the diagram: the menu on a node and dragging between nodes. Every action is one Mermaid line
// written at the end of the source (Graph.bend), after a version of the current source is saved to history.
const currentSource=()=>doc()?.source??'';
function writeFromDiagram(next){
  if(locked){notice('This tab is out of date. Download a backup, then reload.',true,true);return;}
  if(G.parse(next).error){notice('That change would make the diagram invalid, so it was not made.',true);return;}
  const firstWrite=!doc();checkpoint();change(D.write_source(workspace,next),{navigation:firstWrite});
  ui.source.value=currentSource();if(!firstWrite)renderGraph();
}
function diagramActions(data){
  const id=i=>data.ids[i],allowed=(a,b)=>!locked&&Boolean(G.can_connect(currentSource(),id(a),id(b)));
  return {
    isValidConnection:({source:a,target:b})=>allowed(a,b),
    onConnect:({source:a,target:b})=>writeFromDiagram(G.connect(currentSource(),id(a),id(b))),
    nodeMenu:i=>locked?[]:[
      {label:'Add node below',onSelect:()=>nameDialog('Add node below','',label=>writeFromDiagram(G.add_node_below(currentSource(),id(i),label)))},
      {label:'Rename',onSelect:()=>nameDialog('Rename node',data.nodes[i].label,label=>writeFromDiagram(G.rename_node(currentSource(),id(i),label)))},
      ...data.nodes.map((n,j)=>allowed(i,j)?{label:`Connect to ${n.label}`,onSelect:()=>writeFromDiagram(G.connect(currentSource(),id(i),id(j)))}:null).filter(Boolean),
    ],
  };
}
function displayGraph(data,connectable=false){mounted?.destroy();mounted=null;ui.diagram.replaceChildren();if(!data.nodes.length){ui.diagram.append(element('p','detail','Add a node to begin your diagram.'));return;}mounted=mountDiagram(ui.diagram,data,connectable?diagramActions(data):{});}
function renderGraph(){
  const source=doc()?.source??'';
  if(!source.trim()){
    lastGood=null;graphCache.delete(graphKey());mounted?.destroy();mounted=null;
    ui.diagram.replaceChildren(element('p','detail','Write or paste a flowchart to begin.'));
    $('#graph-stats').textContent='No diagram yet';
    $('#parse-message').textContent='Open Syntax guide for the supported syntax.';setStatusTone($('#parse-message'),false);return;
  }
  let result;try{result=source.length>MAX_SOURCE?{error:'The source is too long (20,000 characters maximum).',line:0}:G.parse(source);}catch{result={error:'This diagram could not be parsed. Your source is still saved.',line:0};}
  const message=$('#parse-message');setStatusTone(message,!!result.error);
  if(result.error){
    if(!lastGood){for(const version of array(doc()?.history??{$:'Nil'})){try{const old=G.parse(version.source);if(!old.error){lastGood=graphData(old);graphCache.set(graphKey(),lastGood);displayGraph(lastGood);$('#graph-stats').textContent=`${lastGood.nodes.length} nodes · ${lastGood.edges.length} connections`;break;}}catch{}}}
    message.textContent=(result.line?`Line ${result.line}: `:'')+result.error;if(lastGood)$('#graph-stats').textContent='Showing the last valid diagram';
    if(!lastGood){mounted?.destroy();mounted=null;ui.diagram.replaceChildren(element('p','detail','Your diagram will appear here when the source is valid.'));$('#graph-stats').textContent='Source needs attention';}return;}
  lastGood=graphData(result);graphCache.set(graphKey(),lastGood);displayGraph(lastGood,true);message.textContent='Valid flowchart · Mermaid syntax';$('#graph-stats').textContent=`${lastGood.nodes.length} nodes · ${lastGood.edges.length} connections`;
}
function render(){
  const d=doc(),p=project(),title=d?.name??'New diagram';
  renderNavigation();$('#project-name').textContent=p?.name??'';$('#project-separator').hidden=!p;
  $('#diagram-crumb').textContent=title;ui.source.value=d?.source??'';ui.source.disabled=locked;$('#editor-panel').hidden=workspace.mode===0;
  for(const id of ['rename-diagram','export','checkpoint']){$('#'+id).hidden=!d;$('#'+id).disabled=locked;}$('#actions-separator').hidden=!d;
  document.querySelectorAll('[data-mode]').forEach(b=>b.setAttribute('aria-pressed',Number(b.dataset.mode==='edit')===workspace.mode));renderGraph();document.title='Borzoi — Diagrams';
}
function openModal(title){return modal.open(title);}
function nameDialog(title,initial,onSubmit){
  const body=openModal(title),form=element('form','form'),label=element('label','field'),caption=element('span','field__label','Name'),input=element('input','input');input.value=initial;input.required=true;input.maxLength=120;label.append(caption,input);
  const actions=element('div','actions'),cancel=button('Cancel',()=>ui.modal.close()),submit=element('button','btn btn--primary','Save');submit.type='submit';actions.append(cancel,submit);form.append(label,actions);body.append(form);
  form.addEventListener('submit',e=>{e.preventDefault();const value=input.value.trim();if(!value){input.setCustomValidity('Enter a name.');input.reportValidity();return;}ui.modal.close();onSubmit(value);});input.addEventListener('input',()=>input.setCustomValidity(''));input.focus();input.select();
}
function download(data,filename,type){const url=URL.createObjectURL(new Blob([data],{type})),a=document.createElement('a');a.href=url;a.download=filename;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);}
function backup(){download(JSON.stringify(recoveryPayload??{...encode(workspace),exportedAt:stamp()},null,2),`borzoi-${recoveryPayload?'recovery':'backup'}-${new Date().toISOString().slice(0,10)}.json`,'application/json');}
$('#new-project').onclick=()=>nameDialog('New project','',name=>{checkpoint();change(D.create_project(workspace,name),{navigation:true});});
$('#rename-diagram').onclick=()=>nameDialog('Rename diagram',doc().name,name=>change(D.update(workspace,{$:'Rename',name}),{navigation:true}));
$('#mode').addEventListener('click',e=>{const b=e.target.closest('[data-mode]');if(!b)return;checkpoint();change(D.set_mode(workspace,b.dataset.mode==='edit'?1:0),{navigation:true});});
ui.source.maxLength=MAX_SOURCE;
ui.source.addEventListener('input',()=>{const firstWrite=!doc();change(D.write_source(workspace,ui.source.value),{navigation:firstWrite});clearTimeout(previewTimer);previewTimer=setTimeout(renderGraph,180);});
ui.source.addEventListener('blur',()=>{if(!locked)checkpoint();});
$('#add-node').onclick=()=>{if(!currentSource().trim()||!G.parse(currentSource()).error)nameDialog('Add node','',label=>writeFromDiagram(G.add_node(currentSource(),label)));else notice('Correct the source before adding nodes.',true);};
$('#checkpoint').onclick=()=>{if(checkpoint())notice('Version saved to history.');};
$('#backup').onclick=backup;
$('#export').onclick=()=>download(doc().source,`${doc().name.replace(/[^a-zA-Z0-9_-]+/g,'-')||'diagram'}.mmd`,'text/plain;charset=utf-8');
$('#fit').onclick=()=>{const scroll=$('#canvas-scroll');scroll.scrollTo({top:0,left:Math.max(0,(scroll.scrollWidth-scroll.clientWidth)/2),behavior:'smooth'});};
$('#history').onclick=()=>{
  const body=openModal('Version history'),list=element('div','revision-list');body.append(element('p','detail','Restoring creates a new version and preserves your current draft.'),list);
  const versions=array(doc()?.history??{$:'Nil'});
  if(!versions.length)list.append(element('p','detail','No saved versions yet.'));
  versions.forEach((v,i)=>{const item=element('article',''),head=element('div','revision-list__header'),date=Number.isNaN(Date.parse(v.stamp))?v.stamp:new Date(v.stamp).toLocaleString();const restore=button('Restore',()=>{change(D.update(workspace,{$:'Restore',index:i,stamp:stamp()}),{navigation:true});ui.modal.close();notice('Version restored. Your previous work is in history.');});head.append(element('span','item-title',`${i===0?'Latest · ':''}${date}`),restore);item.append(head,element('pre','revision-list__source',v.source));list.append(item);});
};
$('#syntax-help').onclick=()=>{const body=openModal('A small, familiar syntax');body.append(element('p','text','Start with flowchart TD or graph TD. Add named nodes, square labels and arrows.'),element('pre','revision-list__source','flowchart TD\n  A[Question] --> B[Evidence]\n  B -->|supports| C[Conclusion]\n  %% A comment\n  D["A label with punctuation"]'),element('p','detail','You can chain arrows, use semicolons and reuse node IDs. This first version supports top-to-bottom flows with rectangular nodes, up to 60 nodes and 120 connections. Other shapes, return loops, subgraphs, styles and other directions are not supported yet. Unsupported source remains saved.'));};
$('#import').onclick=()=>{if(!locked)$('#import-file').click();else notice('Reload this tab before importing.',true);};
$('#import-file').addEventListener('change',async e=>{
  const file=e.target.files[0];e.target.value='';if(!file)return;
  try{if(file.size>MAX_BACKUP_BYTES)throw new Error('This backup is too large (20 MB maximum).');const incoming=parseBackup(await file.text());const body=openModal('Import backup');body.append(element('p','text',`Add ${array(incoming.projects).length} project(s) from this backup? Your current projects and history will be kept. Imported projects receive new IDs.`));const actions=element('div','actions');actions.append(button('Cancel',()=>ui.modal.close()),button('Import projects',()=>{checkpoint();change(D.import_projects(workspace,incoming.projects),{navigation:true});ui.modal.close();notice('Backup imported. Existing projects were kept.');},'btn btn--primary'));body.append(actions);}catch(error){notice(error.message,true,true);}
});
 document.addEventListener('keydown',e=>{if((e.metaKey||e.ctrlKey)&&e.key.toLowerCase()==='s'){e.preventDefault();notice(checkpoint()?'Version saved to history.':'Write source before saving a version.');}});
window.addEventListener('beforeunload',e=>{if(dirty||pending){e.preventDefault();e.returnValue='';}});

async function start(){
  $('#app').inert=true;
  try{store=await openStorage();const saved=await store.load();if(saved){
    recoveryPayload=saved.payload;const loaded=decode(saved.payload);workspace=D.remove_legacy_demo(loaded);revision=saved.revision;recoveryPayload=null;
    if(D.is_legacy_demo(loaded))await persist();
  }else setStatus('Ready');}
  catch(error){locked=true;saveError=true;setStatus('Storage unavailable',true);notice(`Could not open local data: ${error.message} Your stored data has not been replaced.`,true,true);}
  $('#app').inert=false;sidebar.closeOnNarrow();render();
}
start();
