// The app's shared state and the one way to change it: change() saves through the storage adapter and,
// on navigation, draws again. Workspace mutations themselves live in Workspace.bend.
import { createFeedback, createDialog, configureSourceEditor, setStatusTone } from '../../vendor/bend-ui/workspace.js';
import { setSide, isNarrow, tokens as T } from '../../vendor/bend-ui/ui.js';
import D from '../workspace/Workspace.bend';
import { array, encode } from '../workspace/codec.js';
import { StorageConflict } from '../workspace/storage.js';

export const $=s=>document.querySelector(s);
export const ui={source:$('#source'),diagram:$('#diagram'),notice:$('#notice'),status:$('#save-status'),modal:$('#modal')};
export const feedback=createFeedback(ui.notice);
export const modal=createDialog(ui.modal,{title:$('#modal-title'),body:$('#modal-content'),close:$('#close-modal')});
// The side bar is the lib's own (ui.js): beside the page on a wide screen, a drawer on a narrow one. #menu opens and
// closes it (data-side-toggle); a click outside the drawer or Escape closes it. Only one thing may toggle it: with
// workspace.js's createSidebar as well, the lib's click-outside closed the drawer in the same click that opened it.
const fitSide=()=>setSide($('#sidebar'),!isNarrow());
fitSide();matchMedia(`(max-width: ${T.breakpoint()-1}px)`).addEventListener('change',fitSide);
export const sidebar={closeOnNarrow(){if(isNarrow())setSide($('#sidebar'),false);}};
configureSourceEditor(ui.source);

export const S={workspace:D.initial(),store:null,revision:0,saves:Promise.resolve(),pending:0,dirty:false,locked:false,saveError:false,
  mounted:null,lastGood:null,previewTimer:null,recoveryPayload:null,checking:false,
  // The document on screen, if any (its project and its id), and the document to go back to from a diagram.
  // What is open in the saved workspace is always a diagram; this is only what this tab shows.
  docProject:0,docId:null,backTo:null};
// main.js sets render; change() calls it after a navigation. document-view.js sets leave: it saves the
// document on screen before something else opens.
export const hooks={render:()=>{},leave:()=>{}};
export const graphCache=new Map();
export const graphKey=()=>`${S.workspace.project}:${S.workspace.diagram}`;
export const stamp=()=>new Date().toISOString();
export const doc=()=>{const v=D.current(S.workspace);return v.$==='Some'?v.value:null;};
export const project=()=>array(S.workspace.projects).find(p=>p.id===S.workspace.project);

export function notice(message,error=false,permanent=false){feedback.show(message,{error,persistent:permanent});}
export function setStatus(text,error=false){ui.status.textContent=text;setStatusTone(ui.status,error);}
export function persist(){
  S.dirty=true;S.pending++;const payload=encode(S.workspace);setStatus('Saving…');
  S.saves=S.saves.then(async()=>{
    if(S.locked)throw new StorageConflict();
    if(!S.store)throw new Error('Local storage is unavailable. Download a backup before closing this page.');
    S.revision=await S.store.save(payload,S.revision);S.saveError=false;
  }).catch(error=>{S.saveError=true;if(error instanceof StorageConflict){S.locked=true;ui.source.disabled=true;}notice(error.message||'Unable to save. Download a backup before leaving.',true,true);})
  .finally(()=>{S.pending--;if(!S.pending){S.dirty=S.saveError;setStatus(S.saveError?'Not saved — download backup':'Saved locally',S.saveError);}});
  return S.saves;
}
export function change(next,{navigation=false}={}){
  if(S.locked){notice('This tab is out of date. Download a backup, then reload.',true,true);return;}
  S.workspace=next;persist();if(navigation){S.lastGood=graphCache.get(graphKey())??null;hooks.render();}
}
export function checkpoint(){const d=doc();if(!d||(!d.source&&!array(d.history).length)||S.locked)return false;change(D.update(S.workspace,{$:'Checkpoint',stamp:stamp()}));return true;}
// Leave the document on screen (saved first): the diagram that is open shows again.
export function leaveDocument(){hooks.leave();S.docId=null;S.backTo=null;}
// Open a diagram. `from` is the document it was opened from (Edit diagram), to offer the way back.
export function switchTo(pid,did,from=null){leaveDocument();S.backTo=from;checkpoint();change(D.open(S.workspace,pid,did),{navigation:true});sidebar.closeOnNarrow();}
