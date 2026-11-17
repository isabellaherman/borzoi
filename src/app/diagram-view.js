// The diagram screen: the drawing, editing from the diagram, the layout lock, the mode menu and the source panel.
import { setStatusTone } from '../../vendor/bend-ui/workspace.js';
import { mountDiagram } from '../../vendor/bend-ui/diagram.js';
import { tokens as T, done, announce } from '../../vendor/bend-ui/ui.js';
import D from '../workspace/Workspace.bend';
import G from '../diagram/Graph.bend';
import E from '../diagram/Edit.bend';
import { array, MAX_SOURCE } from '../workspace/codec.js';
import { manualNoteSeen, markManualNoteSeen } from '../workspace/storage.js';
import { $, ui, S, graphCache, graphKey, stamp, doc, notice, change, checkpoint } from './state.js';
import { element, button, icon, menuItem, radioItem, colorItem, group } from './ui-kit.js';
import { openModal, nameDialog, shapeDialog, shapeLabel, shapeCode } from './dialogs.js';
import { download } from './backup.js';

export function graphData(result,source){
  const nodes=array(result.nodes),edges=array(result.edges),ids=new Map(nodes.map((n,i)=>[n.id,i]));
  // A node's color is the last of the lib's four tones its Mermaid classes give it (Graph.bend).
  const tones=new Map();for(const t of array(G.tones(source)))tones.set(t.id,t.tone);
  return {ids:nodes.map(n=>n.id),nodes:nodes.map(n=>({label:n.label,tone:tones.get(n.id)??'',shape:G.shape_name(n.shape)})),edges:edges.map(e=>({from:ids.get(e.from),to:ids.get(e.to),label:e.label}))};
}
// Editing from the diagram: the menu on a node, dragging between nodes and the manual layout. Every change is
// Mermaid written by Bend: Graph.bend adds a line at the end, Edit.bend rewrites only the lines that mention
// what changes. A version of the current source is saved to history first (moving a node doesn't make one).
export const currentSource=()=>doc()?.source??'';
export function writeFromDiagram(next,{version=true}={}){
  if(S.locked){notice('This tab is out of date. Download a backup, then reload.',true,true);return;}
  if(G.parse(next).error){notice('That change would make the diagram invalid, so it was not made.',true);return;}
  const firstWrite=!doc();if(version)checkpoint();change(D.write_source(S.workspace,next),{navigation:firstWrite});
  ui.source.value=currentSource();if(!firstWrite)renderGraph();
}
// Colors by their common name, as the Mermaid classes Borzoi writes (`A:::green`); each is one of the lib's
// tones (the second value, what the diagram receives). '' removes the color.
const COLORS=[['blue','accent','Blue'],['green','success','Green'],['yellow','warning','Yellow'],['red','danger','Red'],['','','None']];
const isManual=()=>Boolean(doc())&&Boolean(E.is_manual(currentSource()));
function placesOf(source){const out=new Map();for(const p of array(E.places(source)))out.set(p.id,{x:Number(p.x),y:Number(p.y)});return out;}
function diagramActions(data){
  const id=i=>data.ids[i],allowed=(a,b)=>!S.locked&&Boolean(G.can_connect(currentSource(),id(a),id(b)));
  const next=i=>[...new Set(data.edges.filter(e=>e.from===i).map(e=>e.to))];
  const actions={
    isValidConnection:({source:a,target:b})=>allowed(a,b),
    onConnect:({source:a,target:b})=>writeFromDiagram(G.connect(currentSource(),id(a),id(b))),
    // The node opens the lib's Dropdown menu; its items are built as any Dropdown menu's (Bend-UI 1.0.10).
    nodeMenu:i=>S.locked?[]:[
      menuItem('Add node below','plus',()=>nameDialog('Add node below','',(label,shape)=>writeFromDiagram(G.add_node_below_as(currentSource(),id(i),label,shape)),0)),
      ...next(i).map(j=>menuItem(`Add node before ${data.nodes[j].label}`,'plus',()=>nameDialog('Add node between','',(label,shape)=>writeFromDiagram(E.insert_between_as(currentSource(),id(i),id(j),label,shape)),0))),
      menuItem('Rename','text',()=>nameDialog('Rename node',data.nodes[i].label,label=>writeFromDiagram(E.rename(currentSource(),id(i),label)))),
      menuItem(`Shape: ${shapeLabel(shapeCode(data.nodes[i].shape))}`,'square-round-corner',()=>shapeDialog(shapeCode(data.nodes[i].shape),shape=>writeFromDiagram(E.set_shape(currentSource(),id(i),shape)))),
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
    S.mounted?.nodes.forEach((b,i)=>{const n=S.lastGood?.ids[i];if(n&&!saved.has(n)){const r=b.getBoundingClientRect();next=E.move_node(next,n,Math.max(0,Math.round(r.left-box.left)),Math.max(0,Math.round(r.top-box.top)));}});
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
function displayGraph(data,connectable=false){S.mounted?.destroy();S.mounted=null;ui.diagram.replaceChildren();if(!data.nodes.length){ui.diagram.append(element('p','detail','Add a node to begin your diagram.'));return;}S.mounted=mountDiagram(ui.diagram,data,connectable?diagramActions(data):{});}
export function renderGraph(){
  renderLayout();
  const source=doc()?.source??'';
  if(!source.trim()){
    S.lastGood=null;graphCache.delete(graphKey());S.mounted?.destroy();S.mounted=null;
    ui.diagram.replaceChildren(element('p','detail','Write or paste a flowchart to begin.'));
    $('#graph-stats').textContent='No diagram yet';
    $('#parse-message').textContent='Open Syntax guide for the supported syntax.';setStatusTone($('#parse-message'),false);return;
  }
  let result;try{result=source.length>MAX_SOURCE?{error:'The source is too long (20,000 characters maximum).',line:0}:G.parse(source);}catch{result={error:'This diagram could not be parsed. Your source is still saved.',line:0};}
  const message=$('#parse-message');setStatusTone(message,!!result.error);
  if(result.error){
    if(!S.lastGood){for(const version of array(doc()?.history??{$:'Nil'})){try{const old=G.parse(version.source);if(!old.error){S.lastGood=graphData(old,version.source);graphCache.set(graphKey(),S.lastGood);displayGraph(S.lastGood);$('#graph-stats').textContent=`${S.lastGood.nodes.length} nodes · ${S.lastGood.edges.length} connections`;break;}}catch{}}}
    message.textContent=(result.line?`Line ${result.line}: `:'')+result.error;if(S.lastGood)$('#graph-stats').textContent='Showing the last valid diagram';
    if(!S.lastGood){S.mounted?.destroy();S.mounted=null;ui.diagram.replaceChildren(element('p','detail','Your diagram will appear here when the source is valid.'));$('#graph-stats').textContent='Source needs attention';}return;}
  S.lastGood=graphData(result,source);graphCache.set(graphKey(),S.lastGood);displayGraph(S.lastGood,true);message.textContent='Valid flowchart · Mermaid syntax';$('#graph-stats').textContent=`${S.lastGood.nodes.length} nodes · ${S.lastGood.edges.length} connections`;
}
// View mode / Edit mode: the lib's Dropdown; the trigger shows the current mode (Edit is the default, Workspace.initial).
const MODES=[['view','View mode','eye'],['edit','Edit mode','pencil']];
export function renderMode(){
  const [,label,iconName]=MODES[S.workspace.mode],t=$('#mode-trigger');
  t.replaceChildren(icon(iconName),element('span','',label),icon('chevron-down','icon icon--sm'));
  $('#mode').querySelectorAll('[data-mode]').forEach(b=>b.setAttribute('aria-checked',String(b.dataset.mode===MODES[S.workspace.mode][0])));
}
export function initDiagramView(){
  $('#mode').querySelector('.menu').append(...MODES.map(([mode,label,iconName],i)=>{const b=radioItem(label,iconName,()=>{if(S.workspace.mode!==i){checkpoint();change(D.set_mode(S.workspace,i),{navigation:true});}});b.dataset.mode=mode;return b;}));
  ui.source.maxLength=MAX_SOURCE;
  ui.source.addEventListener('input',()=>{const firstWrite=!doc();change(D.write_source(S.workspace,ui.source.value),{navigation:firstWrite});clearTimeout(S.previewTimer);S.previewTimer=setTimeout(renderGraph,180);});
  ui.source.addEventListener('blur',()=>{if(!S.locked)checkpoint();});
  $('#add-node').onclick=()=>{if(!currentSource().trim()||!G.parse(currentSource()).error)nameDialog('Add node','',(label,shape)=>writeFromDiagram(G.add_node_as(currentSource(),label,shape)),0);else notice('Correct the source before adding nodes.',true);};
  // Press and hold the lock: the lib's status ring fills (data-status="hold", duration_slow); once full it waits,
  // and letting go switches the layout. Letting go early or leaving the button cancels. A plain click does nothing.
  {const lock=$('#layout');let timer=null;
    const start=()=>{if(S.locked||!doc()||lock.dataset.status)return;lock.dataset.status='hold';timer=setTimeout(()=>{lock.dataset.status='warn';},T.duration_slow_ms());};
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
  $('#export').onclick=()=>download(doc().source,`${doc().name.replace(/[^a-zA-Z0-9_-]+/g,'-')||'diagram'}.mmd`,'text/plain;charset=utf-8');
  $('#history').onclick=()=>{
    const body=openModal('Version history'),list=element('div','revision-list');body.append(element('p','detail','Restoring creates a new version and preserves your current draft.'),list);
    const versions=array(doc()?.history??{$:'Nil'});
    if(!versions.length)list.append(element('p','detail','No saved versions yet.'));
    versions.forEach((v,i)=>{const item=element('article',''),head=element('div','revision-list__header'),date=Number.isNaN(Date.parse(v.stamp))?v.stamp:new Date(v.stamp).toLocaleString();const restore=button('Restore',()=>{change(D.update(S.workspace,{$:'Restore',index:i,stamp:stamp()}),{navigation:true});ui.modal.close();notice('Version restored. Your previous work is in history.');});head.append(element('span','item-title',`${i===0?'Latest · ':''}${date}`),restore);item.append(head,element('pre','revision-list__source',v.source));list.append(item);});
  };
  $('#syntax-help').onclick=()=>{const body=openModal('A small, familiar syntax');body.append(element('p','text','Start with flowchart TD or graph TD. Add named nodes, square labels and arrows.'),element('pre','revision-list__source','flowchart TD\n  A[Question] --> B[Evidence]\n  B -->|supports| C[Conclusion]\n  %% A comment\n  D["A label with punctuation"]'),element('p','detail','You can chain arrows, use semicolons and reuse node IDs. Color a node with A:::blue, A:::green, A:::yellow or A:::red (classDef lines are kept for other tools). This first version supports top-to-bottom flows with rectangular nodes, up to 60 nodes and 120 connections. Return loops and arrows from a node to itself are fine. All 14 Mermaid node shapes work: A{Decision?}, A[(Database)], A([Start or end]), A((Circle)), A(Rounded), A[[Subprocess]], A{{Prepare}}, A>Flag], A[/Input/] and the other slants. <br/> starts a new line in a label. Arrow text can be written A -- yes --> B or A -->|yes| B, and #quot; in a label is a double quote. Subgraphs, style lines and other directions are not supported yet. Unsupported source remains saved.'));};
}
