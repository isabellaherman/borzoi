import '../vendor/bend-ui/ui.js';
import { isNarrow } from '../vendor/bend-ui/ui.js';
import { mountDiagram } from '../vendor/bend-ui/diagram.js';
import D from './Domain.bend';
import G from './Graph.bend';
import { array, encode, decode, parseBackup, MAX_SOURCE, MAX_BACKUP_BYTES } from './codec.js';
import { openStorage, StorageConflict } from './storage.js';
import './app.css';

const $=s=>document.querySelector(s);
const ui={source:$('#source'),diagram:$('#diagram'),notice:$('#notice'),status:$('#save-status'),modal:$('#modal')};
let workspace=D.initial(),store,revision=0,saves=Promise.resolve(),pending=0,dirty=false,locked=false,saveError=false;
let mounted=null,lastGood=null,previewTimer=null,noticeTimer=null,recoveryPayload=null;
const graphCache=new Map();
const graphKey=()=>`${workspace.project}:${workspace.document}`;
const stamp=()=>new Date().toISOString();
const doc=()=>{const v=D.current(workspace);return v.$==='Some'?v.value:null;};
const project=()=>array(workspace.projects).find(p=>p.id===workspace.project);
const element=(tag,cls,text)=>{const el=document.createElement(tag);if(cls)el.className=cls;if(text!==undefined)el.textContent=text;return el;};
function button(text,fn,cls='btn btn--ghost btn--sm'){const b=element('button',cls,text);b.type='button';b.addEventListener('click',fn);return b;}
function notice(message,error=false,permanent=false){clearTimeout(noticeTimer);ui.notice.textContent=message;ui.notice.hidden=false;ui.notice.classList.toggle('error',error);if(!permanent)noticeTimer=setTimeout(()=>ui.notice.hidden=true,6000);}
function setStatus(text,error=false){ui.status.textContent=text;ui.status.classList.toggle('error',error);}
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
function checkpoint(){change(D.update(workspace,{$:'Checkpoint',stamp:stamp()}));}
function switchTo(pid,did){checkpoint();change(D.open(workspace,pid,did),{navigation:true});if(isNarrow())$('#sidebar').classList.remove('is-open');}
function renderNavigation(){
  const root=$('#project-list');root.replaceChildren();
  for(const p of array(workspace.projects)){
    const group=element('div','project-group'),head=element('div','project-header');
    const name=button(p.name,()=>nameDialog('Rename project',p.name,value=>change(D.rename_project(workspace,p.id,value),{navigation:true})));name.title='Rename project';
    const add=button('＋',()=>nameDialog('New diagram','Untitled diagram',value=>{checkpoint();change(D.create_diagram(workspace,p.id,value),{navigation:true});}));add.setAttribute('aria-label',`New diagram in ${p.name}`);
    head.append(name,add);group.append(head);
    for(const d of array(p.documents)){const b=button(d.name,()=>switchTo(p.id,d.id),'btn btn--ghost diagram-link');if(d.id===workspace.document&&p.id===workspace.project)b.setAttribute('aria-current','page');group.append(b);}
    root.append(group);
  }
}
function graphData(result){
  const nodes=array(result.nodes),edges=array(result.edges),ids=new Map(nodes.map((n,i)=>[n.id,i]));
  return {nodes:nodes.map((n,i)=>({label:n.label,tone:i===0||i===nodes.length-1?'accent':''})),edges:edges.map(e=>({from:ids.get(e.from),to:ids.get(e.to),label:e.label}))};
}
function displayGraph(data){mounted?.destroy();mounted=null;ui.diagram.replaceChildren();if(!data.nodes.length){ui.diagram.append(element('p','detail','Add a node to begin your diagram.'));return;}mounted=mountDiagram(ui.diagram,data);}
function renderGraph(){
  const source=doc()?.source??'';
  let result;try{result=source.length>MAX_SOURCE?{error:'The source is too long (20,000 characters maximum).',line:0}:G.parse(source);}catch{result={error:'This diagram could not be parsed. Your source is still saved.',line:0};}
  const message=$('#parse-message');message.classList.toggle('error',!!result.error);
  if(result.error){
    if(!lastGood){for(const version of array(doc()?.history??{$:'Nil'})){try{const old=G.parse(version.source);if(!old.error){lastGood=graphData(old);graphCache.set(graphKey(),lastGood);displayGraph(lastGood);$('#graph-stats').textContent=`${lastGood.nodes.length} nodes · ${lastGood.edges.length} connections`;break;}}catch{}}}
    message.textContent=(result.line?`Line ${result.line}: `:'')+result.error;$('#graph-caption').textContent=lastGood?'Showing the last valid diagram. Your draft is kept.':'Your draft is kept. Open Edit to correct the source.';
    if(!lastGood){mounted?.destroy();mounted=null;ui.diagram.replaceChildren(element('p','detail','Your diagram will appear here when the source is valid.'));$('#graph-stats').textContent='Source needs attention';}return;}
  lastGood=graphData(result);graphCache.set(graphKey(),lastGood);displayGraph(lastGood);message.textContent='Valid flowchart · Mermaid syntax';$('#graph-stats').textContent=`${lastGood.nodes.length} nodes · ${lastGood.edges.length} connections`;$('#graph-caption').textContent='Start with a question. Follow the connections.';
}
function render(){
  const d=doc(),p=project();if(!d||!p)return;
  renderNavigation();$('#project-name').textContent=p.name;$('#diagram-title').textContent=d.name;$('#diagram-crumb').textContent=d.name;ui.source.value=d.source;ui.source.disabled=locked;$('#editor-panel').hidden=workspace.mode===0;
  document.querySelectorAll('[data-mode]').forEach(b=>b.setAttribute('aria-pressed',Number(b.dataset.mode==='edit')===workspace.mode));renderGraph();document.title=`${d.name} · Borzoi`;
}
function openModal(title){$('#modal-title').textContent=title;$('#modal-content').replaceChildren();if(!ui.modal.open)ui.modal.showModal();return $('#modal-content');}
function nameDialog(title,initial,onSubmit){
  const body=openModal(title),form=element('form','modal-form'),label=element('label','field'),caption=element('span','field__label','Name'),input=element('input','input');input.value=initial;input.required=true;input.maxLength=120;label.append(caption,input);
  const actions=element('div','modal-actions'),cancel=button('Cancel',()=>ui.modal.close()),submit=element('button','btn btn--primary','Save');submit.type='submit';actions.append(cancel,submit);form.append(label,actions);body.append(form);
  form.addEventListener('submit',e=>{e.preventDefault();const value=input.value.trim();if(!value){input.setCustomValidity('Enter a name.');input.reportValidity();return;}ui.modal.close();onSubmit(value);});input.addEventListener('input',()=>input.setCustomValidity(''));input.focus();input.select();
}
function download(data,filename,type){const url=URL.createObjectURL(new Blob([data],{type})),a=document.createElement('a');a.href=url;a.download=filename;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);}
function backup(){download(JSON.stringify(recoveryPayload??{...encode(workspace),exportedAt:stamp()},null,2),`borzoi-${recoveryPayload?'recovery':'backup'}-${new Date().toISOString().slice(0,10)}.json`,'application/json');}
$('#new-project').onclick=()=>nameDialog('New project','',name=>{checkpoint();change(D.create_project(workspace,name),{navigation:true});});
$('#rename-diagram').onclick=()=>nameDialog('Rename diagram',doc().name,name=>change(D.update(workspace,{$:'Rename',name}),{navigation:true}));
$('#mode').addEventListener('click',e=>{const b=e.target.closest('[data-mode]');if(!b)return;checkpoint();change(D.set_mode(workspace,b.dataset.mode==='edit'?1:0),{navigation:true});});
ui.source.maxLength=MAX_SOURCE;
ui.source.addEventListener('input',()=>{change(D.update(workspace,{$:'Write',source:ui.source.value}));clearTimeout(previewTimer);previewTimer=setTimeout(renderGraph,180);});
ui.source.addEventListener('blur',()=>{if(!locked)checkpoint();});
$('#checkpoint').onclick=()=>{checkpoint();notice('Version saved to history.');};
$('#menu').onclick=()=>$('#sidebar').classList.toggle('is-open');
$('#close-modal').onclick=()=>ui.modal.close();
$('#backup').onclick=backup;
$('#export').onclick=()=>download(doc().source,`${doc().name.replace(/[^a-zA-Z0-9_-]+/g,'-')||'diagram'}.mmd`,'text/plain;charset=utf-8');
$('#fit').onclick=()=>{const scroll=$('#canvas-scroll');scroll.scrollTo({top:0,left:Math.max(0,(scroll.scrollWidth-scroll.clientWidth)/2),behavior:'smooth'});};
$('#history').onclick=()=>{
  const body=openModal('Version history');body.append(element('p','detail','Restoring creates a new version and preserves your current draft.'));
  array(doc().history).forEach((v,i)=>{const item=element('div','history-item'),head=element('div','panel-heading'),date=Number.isNaN(Date.parse(v.stamp))?v.stamp:new Date(v.stamp).toLocaleString();const restore=button('Restore',()=>{change(D.update(workspace,{$:'Restore',index:i,stamp:stamp()}),{navigation:true});ui.modal.close();notice('Version restored. Your previous work is in history.');});head.append(element('span','item-title',`${i===0?'Latest · ':''}${date}`),restore);item.append(head,element('pre','',v.source));body.append(item);});
};
$('#syntax-help').onclick=()=>{const body=openModal('A small, familiar syntax');body.append(element('p','text','Start with flowchart TD or graph TD. Add named nodes, square labels and arrows.'),element('pre','block block--code','flowchart TD\n  A[Question] --> B[Evidence]\n  B -->|supports| C[Conclusion]\n  %% A comment\n  D["A label with punctuation"]'),element('p','detail','You can chain arrows, use semicolons and reuse node IDs. This first version supports top-to-bottom flows with rectangular nodes, up to 60 nodes and 120 connections. Other shapes, return loops, subgraphs, styles and other directions are not supported yet. Unsupported source remains saved.'));};
$('#import').onclick=()=>{if(!locked)$('#import-file').click();else notice('Reload this tab before importing.',true);};
$('#import-file').addEventListener('change',async e=>{
  const file=e.target.files[0];e.target.value='';if(!file)return;
  try{if(file.size>MAX_BACKUP_BYTES)throw new Error('This backup is too large (20 MB maximum).');const incoming=parseBackup(await file.text());const body=openModal('Import backup');body.append(element('p','text',`Add ${array(incoming.projects).length} project(s) from this backup? Your current projects and history will be kept. Imported projects receive new IDs.`));const actions=element('div','modal-actions');actions.append(button('Cancel',()=>ui.modal.close()),button('Import projects',()=>{checkpoint();change(D.import_projects(workspace,incoming.projects),{navigation:true});ui.modal.close();notice('Backup imported. Existing projects were kept.');},'btn btn--primary'));body.append(actions);}catch(error){notice(error.message,true,true);}
});
 document.addEventListener('keydown',e=>{if((e.metaKey||e.ctrlKey)&&e.key.toLowerCase()==='s'){e.preventDefault();checkpoint();notice('Version saved to history.');}});
window.addEventListener('beforeunload',e=>{if(dirty||pending){e.preventDefault();e.returnValue='';}});
document.addEventListener('click',e=>{if(isNarrow()&&!e.target.closest('#sidebar')&&!e.target.closest('#menu'))$('#sidebar').classList.remove('is-open');});
async function start(){
  $('.app').inert=true;
  try{store=await openStorage();const saved=await store.load();if(saved){recoveryPayload=saved.payload;workspace=decode(saved.payload);revision=saved.revision;recoveryPayload=null;}else await persist();}
  catch(error){locked=true;saveError=true;setStatus('Storage unavailable',true);notice(`Could not open local data: ${error.message} Your stored data has not been replaced.`,true,true);}
  $('.app').inert=false;if(isNarrow())$('#sidebar').classList.remove('is-open');render();
}
start();
