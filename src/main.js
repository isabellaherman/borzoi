import { createFeedback, createDialog, configureSourceEditor, createSidebar, setStatusTone } from '../vendor/bend-ui/workspace.js';
import { mountDiagram } from '../vendor/bend-ui/diagram.js';
import { tokens as T, done, announce } from '../vendor/bend-ui/ui.js';
import D from './Domain.bend';
import metadata from '../package.json';
import G from './Graph.bend';
import E from './Edit.bend';
import { array, encode, decode, parseBackup, MAX_SOURCE, MAX_BACKUP_BYTES } from './codec.js';
import { openStorage, StorageConflict, manualNoteSeen, markManualNoteSeen } from './storage.js';

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
    const group=element('div','side__section'),head=element('button','btn btn--ghost side__toggle'),items=element('div','side__items');
    head.type='button';head.title=p.name;head.setAttribute('aria-expanded','true');
    head.append(icon(p.inbox?'wand-sparkles':'file-text'),element('span','side__text',p.name),icon('chevron-down','icon icon--sm side__chevron'));
    for(const d of array(p.documents)){
      const from=D.sender(d.source),b=navButton(d.name,()=>switchTo(p.id,d.id),from?'wand-sparkles':undefined);if(from)b.title=`${d.name} · from ${from}`;
      if(d.id===workspace.document&&p.id===workspace.project)b.setAttribute('aria-current','page');
      items.append(sideRow(b,d.name,[
        menuItem('Rename','pencil',()=>nameDialog('Rename diagram',d.name,value=>change(D.rename_diagram(workspace,p.id,d.id,value),{navigation:true}))),
        element('hr','separator'),menuItem('Delete','trash-2',()=>deleteDiagram(p,d)),
      ]));
    }
    items.append(navButton('New diagram',()=>nameDialog('New diagram','Untitled diagram',value=>{checkpoint();change(D.create_diagram(workspace,p.id,value),{navigation:true});}),'plus'));
    group.append(sideRow(head,p.name,[
      ...(p.inbox?[menuItem('Agent instructions','copy',()=>agentInstructions(p.id)),menuItem('New key','refresh-cw',()=>replaceKey(p)),element('hr','separator')]:[]),
      menuItem('Rename','pencil',()=>nameDialog('Rename project',p.name,value=>change(D.rename_project(workspace,p.id,value),{navigation:true}))),
      element('hr','separator'),menuItem('Delete','trash-2',()=>deleteProject(p)),
    ]),items);root.append(group);
  }
}
function graphData(result,source){
  const nodes=array(result.nodes),edges=array(result.edges),ids=new Map(nodes.map((n,i)=>[n.id,i]));
  // A node's color is the last of the lib's four tones its Mermaid classes give it (Graph.bend).
  const tones=new Map();for(const t of array(G.tones(source)))tones.set(t.id,t.tone);
  return {ids:nodes.map(n=>n.id),nodes:nodes.map(n=>({label:n.label,tone:tones.get(n.id)??''})),edges:edges.map(e=>({from:ids.get(e.from),to:ids.get(e.to),label:e.label}))};
}
// Editing from the diagram: the menu on a node, dragging between nodes and the manual layout. Every change is
// Mermaid written by Bend: Graph.bend adds a line at the end, Edit.bend rewrites only the lines that mention
// what changes. A version of the current source is saved to history first (moving a node doesn't make one).
const currentSource=()=>doc()?.source??'';
function writeFromDiagram(next,{version=true}={}){
  if(locked){notice('This tab is out of date. Download a backup, then reload.',true,true);return;}
  if(G.parse(next).error){notice('That change would make the diagram invalid, so it was not made.',true);return;}
  const firstWrite=!doc();if(version)checkpoint();change(D.write_source(workspace,next),{navigation:firstWrite});
  ui.source.value=currentSource();if(!firstWrite)renderGraph();
}
// Colors by their common name, as the Mermaid classes Borzoi writes (`A:::green`); each is one of the lib's
// tones (the second value, what the diagram receives). '' removes the color.
const COLORS=[['blue','accent','Blue'],['green','success','Green'],['yellow','warning','Yellow'],['red','danger','Red'],['','','None']];
const isManual=()=>Boolean(doc())&&Boolean(E.is_manual(currentSource()));
function placesOf(source){const out=new Map();for(const p of array(E.places(source)))out.set(p.id,{x:Number(p.x),y:Number(p.y)});return out;}
// Dropdown menu items, written as Bend-UI's README writes them: an icon (or an empty one, to keep the text in line),
// the text, and the check last for the current color. A group starts with the lib's separator.
function menuIcon(name,cls='icon icon--sm'){const svg=icon(name,cls);if(!name)svg.replaceChildren();return svg;}
function menuItem(label,iconName,onClick){const b=element('button','menu__item');b.type='button';b.setAttribute('role','menuitem');b.append(menuIcon(iconName),element('span','',label));b.addEventListener('click',onClick);return b;}
function radioItem(label,iconName,onClick){const b=element('button','menu__item');b.type='button';b.setAttribute('role','menuitemradio');b.setAttribute('aria-checked','false');b.append(menuIcon(iconName),element('span','',label),menuIcon('check','icon icon--sm menu__check'));b.addEventListener('click',onClick);return b;}
function colorItem(name,tone,checked,onClick){
  const b=element('button','menu__item'),text=element('span');b.type='button';b.setAttribute('role','menuitemradio');b.setAttribute('aria-checked',String(checked));
  text.append(element('span',tone?`tag tag--${tone}`:'tag',name));b.append(menuIcon(''),text,menuIcon('check','icon icon--sm menu__check'));b.addEventListener('click',onClick);return b;
}
const group=items=>items.length?[element('hr','separator'),...items]:[];
function dropdown(trigger,items,end=false){const dd=element('div','dropdown'),menu=element('div',end?'menu menu--end':'menu');menu.setAttribute('role','menu');menu.hidden=true;menu.append(...items);dd.append(trigger,menu);return dd;}
// A side bar row: the item, then the lib's ⋯ menu at its end (Bend-UI 1.0.12 .side__row). Right-click opens it too.
function sideRow(item,label,items){
  const more=button('',()=>{},'btn btn--ghost btn--icon btn--sm');more.setAttribute('aria-haspopup','menu');more.setAttribute('aria-expanded','false');more.setAttribute('aria-label',`Actions for ${label}`);more.append(icon('ellipsis'));
  const dd=dropdown(more,items,true);dd.classList.add('side__more');const row=element('div','side__row');row.append(item,dd);return row;
}
function diagramActions(data){
  const id=i=>data.ids[i],allowed=(a,b)=>!locked&&Boolean(G.can_connect(currentSource(),id(a),id(b)));
  const next=i=>[...new Set(data.edges.filter(e=>e.from===i).map(e=>e.to))];
  const actions={
    isValidConnection:({source:a,target:b})=>allowed(a,b),
    onConnect:({source:a,target:b})=>writeFromDiagram(G.connect(currentSource(),id(a),id(b))),
    // The node opens the lib's Dropdown menu; its items are built as any Dropdown menu's (Bend-UI 1.0.10).
    nodeMenu:i=>locked?[]:[
      menuItem('Add node below','plus',()=>nameDialog('Add node below','',label=>writeFromDiagram(G.add_node_below(currentSource(),id(i),label)))),
      ...next(i).map(j=>menuItem(`Add node before ${data.nodes[j].label}`,'plus',()=>nameDialog('Add node between','',label=>writeFromDiagram(E.insert_between(currentSource(),id(i),id(j),label))))),
      menuItem('Rename','text',()=>nameDialog('Rename node',data.nodes[i].label,label=>writeFromDiagram(E.rename(currentSource(),id(i),label)))),
      ...group(data.nodes.map((n,j)=>allowed(i,j)?menuItem(i===j?'Connect to itself':`Connect to ${n.label}`,'',()=>writeFromDiagram(G.connect(currentSource(),id(i),id(j)))):null).filter(Boolean)),
      ...group(COLORS.map(([color,tone,name])=>colorItem(name,tone,tone===data.nodes[i].tone,()=>{if(tone!==data.nodes[i].tone)writeFromDiagram(E.set_tone(currentSource(),id(i),color));}))),
      ...group([...next(i).map(j=>menuItem(`Remove arrow to ${data.nodes[j].label}`,'x',()=>writeFromDiagram(E.remove_edge(currentSource(),id(i),id(j))))),menuItem('Delete node','x',()=>writeFromDiagram(E.delete_node(currentSource(),id(i))))]),
    ],
  };
  if(isManual()){
    // Nodes with no saved position yet (added elsewhere) wait at the top left, one under the other.
    const places=placesOf(currentSource());let waiting=0;
    actions.positions=data.ids.map(n=>places.get(n)??{x:16,y:16+48*waiting++});
    actions.onNodeMove=(i,p)=>writeFromDiagram(E.move_node(currentSource(),id(i),Math.round(p.x),Math.round(p.y)),{version:false});
  }
  return actions;
}
// Manual layout is one click away: explained the first time, then marked by a tag in the toolbar.
function explainManual(onUse){
  const body=openModal(onUse?'Switch to manual layout?':'About manual layout'),list=element('ul','prose');
  for(const [lead,text] of [['You gain: ','any node anywhere, and your arrangement is saved with the diagram.'],['Still standard Mermaid: ','positions are saved as %% comment lines. Other tools and agents read the same diagram and lay it out on their own.'],['Good to know: ','a node added from another tool waits at the top left until you move it. Back to Auto layout, every node is placed automatically again; your positions stay in the source for when you come back.']]){const item=element('li');item.append(element('strong','',lead),text);list.append(item);}
  body.append(element('p','text','You place every node yourself, and Borzoi keeps your arrangement.'),list);
  if(!onUse)return;
  const actions=element('div','actions');actions.append(button('Keep auto layout',()=>ui.modal.close()),button('Use manual layout',()=>{ui.modal.close();markManualNoteSeen();onUse();},'btn btn--primary'));body.append(actions);
}
function setLayout(manual){
  if(!doc()||manual===isManual())return;
  if(!manual){writeFromDiagram(E.set_manual(currentSource(),false));return;}
  const useManual=()=>{
    // Nodes keep the place they have now; a node that was placed before goes back there.
    let next=E.set_manual(currentSource(),true);const saved=placesOf(currentSource()),box=ui.diagram.getBoundingClientRect();
    mounted?.nodes.forEach((b,i)=>{const n=lastGood?.ids[i];if(n&&!saved.has(n)){const r=b.getBoundingClientRect();next=E.move_node(next,n,Math.max(0,Math.round(r.left-box.left)),Math.max(0,Math.round(r.top-box.top)));}});
    writeFromDiagram(next);
  };
  if(manualNoteSeen())useManual();else explainManual(useManual);
}
function renderLayout(){
  const manual=isManual();$('#layout').hidden=!doc();$('#manual-note').hidden=!manual;
  // The lock: closed is auto layout, open is manual. Pressed means manual (unlocked).
  const lock=$('#layout');lock.setAttribute('aria-pressed',String(manual));lock.querySelector('use').setAttribute('href',manual?'#i-lock-open':'#i-lock');
  lock.title=manual?'Manual layout · press and hold to lock (auto layout)':'Auto layout · press and hold to unlock (manual layout)';
}
function displayGraph(data,connectable=false){mounted?.destroy();mounted=null;ui.diagram.replaceChildren();if(!data.nodes.length){ui.diagram.append(element('p','detail','Add a node to begin your diagram.'));return;}mounted=mountDiagram(ui.diagram,data,connectable?diagramActions(data):{});}
function renderGraph(){
  renderLayout();
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
    if(!lastGood){for(const version of array(doc()?.history??{$:'Nil'})){try{const old=G.parse(version.source);if(!old.error){lastGood=graphData(old,version.source);graphCache.set(graphKey(),lastGood);displayGraph(lastGood);$('#graph-stats').textContent=`${lastGood.nodes.length} nodes · ${lastGood.edges.length} connections`;break;}}catch{}}}
    message.textContent=(result.line?`Line ${result.line}: `:'')+result.error;if(lastGood)$('#graph-stats').textContent='Showing the last valid diagram';
    if(!lastGood){mounted?.destroy();mounted=null;ui.diagram.replaceChildren(element('p','detail','Your diagram will appear here when the source is valid.'));$('#graph-stats').textContent='Source needs attention';}return;}
  lastGood=graphData(result,source);graphCache.set(graphKey(),lastGood);displayGraph(lastGood,true);message.textContent='Valid flowchart · Mermaid syntax';$('#graph-stats').textContent=`${lastGood.nodes.length} nodes · ${lastGood.edges.length} connections`;
}
function render(){
  const d=doc(),p=project(),title=d?.name??'New diagram';
  renderNavigation();$('#project-name').textContent=p?.name??'';$('#project-separator').hidden=!p;
  $('#diagram-crumb').textContent=title;ui.source.value=d?.source??'';ui.source.disabled=locked;$('#editor-panel').hidden=workspace.mode===0;
  for(const id of ['export','checkpoint']){$('#'+id).hidden=!d;$('#'+id).disabled=locked;}$('#actions-separator').hidden=!d;
  renderMode();renderGraph();document.title='Borzoi — Diagrams';
}
function openModal(title){return modal.open(title);}
function nameDialog(title,initial,onSubmit){
  const body=openModal(title),form=element('form','form'),label=element('label','field'),caption=element('span','field__label','Name'),input=element('input','input');input.value=initial;input.required=true;input.maxLength=120;label.append(caption,input);
  const actions=element('div','actions'),cancel=button('Cancel',()=>ui.modal.close()),submit=element('button','btn btn--primary','Save');submit.type='submit';actions.append(cancel,submit);form.append(label,actions);body.append(form);
  form.addEventListener('submit',e=>{e.preventDefault();const value=input.value.trim();if(!value){input.setCustomValidity('Enter a name.');input.reportValidity();return;}ui.modal.close();onSubmit(value);});input.addEventListener('input',()=>input.setCustomValidity(''));input.focus();input.select();
}
function confirmDelete(title,text,onDelete){
  const body=openModal(title),actions=element('div','actions');
  actions.append(button('Cancel',()=>ui.modal.close()),button('Delete',()=>{ui.modal.close();onDelete();},'btn btn--primary'));
  body.append(element('p','text',text),element('p','detail','This can\'t be undone. Download a backup first if you may need it.'),actions);
}
const diagrams=n=>n===1?'1 diagram':`${n} diagrams`;
function deleteProject(p){const n=array(p.documents).length;confirmDelete('Delete project?',`Delete “${p.name}” and its ${diagrams(n)}, with their history?`,()=>{checkpoint();change(D.delete_project(workspace,p.id),{navigation:true});notice('Project deleted.');});}
function deleteDiagram(p,d){confirmDelete('Delete diagram?',`Delete “${d.name}” and its history?`,()=>{change(D.delete_diagram(workspace,p.id,d.id),{navigation:true});notice('Diagram deleted.');});}
function download(data,filename,type){const url=URL.createObjectURL(new Blob([data],{type})),a=document.createElement('a');a.href=url;a.download=filename;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);}
function backup(){download(JSON.stringify(recoveryPayload??{...encode(workspace),exportedAt:stamp()},null,2),`borzoi-${recoveryPayload?'recovery':'backup'}-${new Date().toISOString().slice(0,10)}.json`,'application/json');}
$('#new-project').querySelector('.menu').append(
  menuItem('Project','file-text',()=>nameDialog('New project','',name=>{checkpoint();change(D.create_project(workspace,name),{navigation:true});})),
  menuItem('Agent project','wand-sparkles',()=>nameDialog('New agent project','',name=>{const id=workspace.next_id;checkpoint();change(D.create_agent_project(workspace,name,newKey()),{navigation:true});agentInstructions(id);})),
);
// Agent projects: agents send plain Mermaid to the project's inbox on ntfy.sh, a free public message relay. The key is
// the inbox's name, made at random here. Borzoi fetches what arrived; Domain.bend turns each message into a new
// diagram in that project only (it never changes a diagram that exists). ntfy.sh keeps messages for about 12 hours.
const INBOX='https://ntfy.sh/';
function newKey(){const abc='abcdefghijkmnpqrstuvwxyz23456789';return 'bz-'+Array.from(crypto.getRandomValues(new Uint8Array(20)),b=>abc[b%32]).join('');}
const projectById=id=>array(workspace.projects).find(p=>p.id===id);
function instructionsFor(p){return `You can send diagrams to my Borzoi project "${p.name}".

How to send one:
- Make an HTTP POST request to ${INBOX}${p.inbox}
- Body: the diagram as plain Mermaid text, with real line breaks.
- Header "Title": the diagram's name.

Write the diagram like this:
%% borzoi from <your name>
flowchart TD
  A[First step] --> B[Next step]
  B -->|label on the arrow| C[Another step]:::red

Rules:
- Use only flowchart TD, nodes like A[Text], arrows --> and arrow labels -->|text|.
- Color a node with :::red, :::yellow, :::green or :::blue.
- No subgraphs, no other directions (such as LR), no rounded or diamond shapes.
- Keep each diagram under 4,000 characters.
- Send each diagram once, and send nothing else to this address.

Anyone with this address can add diagrams to this project, so keep it private.`;}
function agentInstructions(id){
  const p=projectById(id);if(!p?.inbox)return;
  const body=openModal('Agent instructions'),text=instructionsFor(p),pre=element('pre','revision-list__source',text),actions=element('div','actions');
  const copy=button('Copy instructions',async()=>{try{await navigator.clipboard.writeText(text);ui.modal.close();notice('Instructions copied. Paste them to your agent.');}catch{const r=document.createRange();r.selectNodeContents(pre);getSelection().removeAllRanges();getSelection().addRange(r);notice('Copy the selected text with Cmd+C or Ctrl+C.');}},'btn btn--primary');
  actions.append(button('Close',()=>ui.modal.close()),copy);
  body.append(element('p','text','Give these instructions to your agent once. Each diagram it sends becomes a new diagram in this project. Agents can only add diagrams; they never change yours.'),pre,element('p','detail','Diagrams arrive while Borzoi is open, or the next time you open it within about 12 hours.'),actions);
}
function replaceKey(p){
  const body=openModal('Make a new key?'),actions=element('div','actions');
  actions.append(button('Cancel',()=>ui.modal.close()),button('Make new key',()=>{ui.modal.close();change(D.new_key(workspace,p.id,newKey()),{navigation:true});agentInstructions(p.id);},'btn btn--primary'));
  body.append(element('p','text',`The current key for “${p.name}” stops working. Agents that have the old instructions can't send diagrams any more until you give them the new ones.`),actions);
}
let checking=false;
async function messagesFor(p){
  const r=await fetch(`${INBOX}${encodeURIComponent(p.inbox)}/json?poll=1&since=${encodeURIComponent(p.seen||'all')}`);
  if(!r.ok)throw new Error(`The inbox answered ${r.status}.`);
  const out=[];for(const line of (await r.text()).split('\n')){if(!line.trim())continue;try{const m=JSON.parse(line);if(m.event==='message')out.push(m);}catch{}}
  // A message over 4 KB arrives as a file; read it when the relay allows it.
  for(const m of out)if(m.attachment?.url){try{const a=await fetch(m.attachment.url);if(a.ok)m.message=await a.text();}catch{}}
  return out;
}
async function checkInboxes(){
  if(locked||checking||document.hidden)return;checking=true;
  try{
    let arrived=0;
    for(const p of array(workspace.projects).filter(p=>p.inbox)){
      let messages;try{messages=await messagesFor(p);}catch{continue;}
      let next=workspace;
      for(const m of messages)next=D.receive(next,p.id,p.inbox,String(m.id??''),String(m.title??''),String(m.message??''));
      if(next.next_id!==workspace.next_id&&!locked){arrived+=next.next_id-workspace.next_id;change(next);}
    }
    if(arrived){renderNavigation();notice(arrived===1?'A new diagram arrived from an agent.':`${arrived} new diagrams arrived from agents.`);}
  }finally{checking=false;}
}
// View mode / Edit mode: the lib's Dropdown; the trigger shows the current mode (Edit is the default, Domain.initial).
const MODES=[['view','View mode','eye'],['edit','Edit mode','pencil']];
function renderMode(){
  const [,label,iconName]=MODES[workspace.mode],t=$('#mode-trigger');
  t.replaceChildren(icon(iconName),element('span','',label),icon('chevron-down','icon icon--sm'));
  $('#mode').querySelectorAll('[data-mode]').forEach(b=>b.setAttribute('aria-checked',String(b.dataset.mode===MODES[workspace.mode][0])));
}
$('#mode').querySelector('.menu').append(...MODES.map(([mode,label,iconName],i)=>{const b=radioItem(label,iconName,()=>{if(workspace.mode!==i){checkpoint();change(D.set_mode(workspace,i),{navigation:true});}});b.dataset.mode=mode;return b;}));
ui.source.maxLength=MAX_SOURCE;
ui.source.addEventListener('input',()=>{const firstWrite=!doc();change(D.write_source(workspace,ui.source.value),{navigation:firstWrite});clearTimeout(previewTimer);previewTimer=setTimeout(renderGraph,180);});
ui.source.addEventListener('blur',()=>{if(!locked)checkpoint();});
$('#add-node').onclick=()=>{if(!currentSource().trim()||!G.parse(currentSource()).error)nameDialog('Add node','',label=>writeFromDiagram(G.add_node(currentSource(),label)));else notice('Correct the source before adding nodes.',true);};
// Press and hold the lock: the lib's status ring fills (data-status="hold", duration_slow); once full it waits,
// and letting go switches the layout. Letting go early or leaving the button cancels. A plain click does nothing.
{const lock=$('#layout');let timer=null;
  const start=()=>{if(locked||!doc()||lock.dataset.status)return;lock.dataset.status='hold';timer=setTimeout(()=>{lock.dataset.status='warn';},T.duration_slow_ms());};
  const stop=commit=>{clearTimeout(timer);const full=lock.dataset.status==='warn';delete lock.dataset.status;if(commit&&full)setLayout(!isManual());};
  lock.addEventListener('pointerdown',e=>{if(e.button===0){lock.setPointerCapture(e.pointerId);start();}});
  lock.addEventListener('pointerup',()=>stop(true));
  lock.addEventListener('pointercancel',()=>stop(false));
  lock.addEventListener('lostpointercapture',()=>stop(false));
  lock.addEventListener('keydown',e=>{if((e.key===' '||e.key==='Enter')&&!e.repeat){e.preventDefault();start();}});
  lock.addEventListener('keyup',e=>{if(e.key===' '||e.key==='Enter'){e.preventDefault();stop(true);}});
  lock.addEventListener('blur',()=>stop(false));}
$('#why').onclick=()=>explainManual(null);
// Saving shows on the button itself: the lib's done() turns the icon into a check; announce() says it.
$('#checkpoint').onclick=e=>{const b=e.currentTarget;if(!b.classList.contains('is-done')&&checkpoint()){done(b);announce('Version saved');}};
$('#backup').onclick=backup;
$('#export').onclick=()=>download(doc().source,`${doc().name.replace(/[^a-zA-Z0-9_-]+/g,'-')||'diagram'}.mmd`,'text/plain;charset=utf-8');
$('#history').onclick=()=>{
  const body=openModal('Version history'),list=element('div','revision-list');body.append(element('p','detail','Restoring creates a new version and preserves your current draft.'),list);
  const versions=array(doc()?.history??{$:'Nil'});
  if(!versions.length)list.append(element('p','detail','No saved versions yet.'));
  versions.forEach((v,i)=>{const item=element('article',''),head=element('div','revision-list__header'),date=Number.isNaN(Date.parse(v.stamp))?v.stamp:new Date(v.stamp).toLocaleString();const restore=button('Restore',()=>{change(D.update(workspace,{$:'Restore',index:i,stamp:stamp()}),{navigation:true});ui.modal.close();notice('Version restored. Your previous work is in history.');});head.append(element('span','item-title',`${i===0?'Latest · ':''}${date}`),restore);item.append(head,element('pre','revision-list__source',v.source));list.append(item);});
};
$('#syntax-help').onclick=()=>{const body=openModal('A small, familiar syntax');body.append(element('p','text','Start with flowchart TD or graph TD. Add named nodes, square labels and arrows.'),element('pre','revision-list__source','flowchart TD\n  A[Question] --> B[Evidence]\n  B -->|supports| C[Conclusion]\n  %% A comment\n  D["A label with punctuation"]'),element('p','detail','You can chain arrows, use semicolons and reuse node IDs. Color a node with A:::blue, A:::green, A:::yellow or A:::red (classDef lines are kept for other tools). This first version supports top-to-bottom flows with rectangular nodes, up to 60 nodes and 120 connections. Return loops and arrows from a node to itself are fine, and [/slanted/] shapes show as boxes. Rounded and diamond shapes, subgraphs, style lines and other directions are not supported yet. Unsupported source remains saved.'));};
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
  checkInboxes();setInterval(checkInboxes,60000);document.addEventListener('visibilitychange',checkInboxes);
}
start();
