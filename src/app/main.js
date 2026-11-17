// Borzoi starts here: it wires the parts together, draws the screen and opens the saved workspace.
import D from '../workspace/Workspace.bend';
import metadata from '../../package.json';
import { decode } from '../workspace/codec.js';
import { openStorage } from '../workspace/storage.js';
import { $, ui, S, hooks, sidebar, doc, project, notice, setStatus, persist, checkpoint } from './state.js';
import { renderNavigation, initSidebar } from './sidebar.js';
import { renderGraph, renderMode, initDiagramView } from './diagram-view.js';
import { checkInboxes } from './agent.js';
import { initBackup } from './backup.js';

$('#app-version').textContent=`Borzoi · ${metadata.version}`;
function render(){
  const d=doc(),p=project(),title=d?.name??'New diagram';
  renderNavigation();$('#project-name').textContent=p?.name??'';$('#project-separator').hidden=!p;
  $('#diagram-crumb').textContent=title;ui.source.value=d?.source??'';ui.source.disabled=S.locked;$('#editor-panel').hidden=S.workspace.mode===0;
  for(const id of ['export','checkpoint']){$('#'+id).hidden=!d;$('#'+id).disabled=S.locked;}$('#actions-separator').hidden=!d;
  renderMode();renderGraph();document.title='Borzoi — Diagrams';
}
hooks.render=render;
initSidebar();
initDiagramView();
initBackup();
document.addEventListener('keydown',e=>{if((e.metaKey||e.ctrlKey)&&e.key.toLowerCase()==='s'){e.preventDefault();notice(checkpoint()?'Version saved to history.':'Write source before saving a version.');}});
window.addEventListener('beforeunload',e=>{if(S.dirty||S.pending){e.preventDefault();e.returnValue='';}});

async function start(){
  $('#app').inert=true;
  try{S.store=await openStorage();const saved=await S.store.load();if(saved){
    S.recoveryPayload=saved.payload;const loaded=decode(saved.payload);S.workspace=D.remove_legacy_demo(loaded);S.revision=saved.revision;S.recoveryPayload=null;
    if(D.is_legacy_demo(loaded))await persist();
  }else setStatus('Ready');}
  catch(error){S.locked=true;S.saveError=true;setStatus('Storage unavailable',true);notice(`Could not open local data: ${error.message} Your stored data has not been replaced.`,true,true);}
  $('#app').inert=false;sidebar.closeOnNarrow();render();
  checkInboxes();setInterval(checkInboxes,60000);document.addEventListener('visibilitychange',checkInboxes);
}
start();
