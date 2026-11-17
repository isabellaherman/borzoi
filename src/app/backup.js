// Backups: download the whole workspace as JSON, and import one (its projects are added; yours are kept).
import D from '../workspace/Workspace.bend';
import { array, encode, parseBackup, MAX_BACKUP_BYTES } from '../workspace/codec.js';
import { $, ui, S, stamp, notice, change, checkpoint } from './state.js';
import { element, button } from './ui-kit.js';
import { openModal } from './dialogs.js';

export function download(data,filename,type){const url=URL.createObjectURL(new Blob([data],{type})),a=document.createElement('a');a.href=url;a.download=filename;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);}
function backup(){download(JSON.stringify(S.recoveryPayload??{...encode(S.workspace),exportedAt:stamp()},null,2),`borzoi-${S.recoveryPayload?'recovery':'backup'}-${new Date().toISOString().slice(0,10)}.json`,'application/json');}
export function initBackup(){
  $('#backup').onclick=backup;
  $('#import').onclick=()=>{if(!S.locked)$('#import-file').click();else notice('Reload this tab before importing.',true);};
  $('#import-file').addEventListener('change',async e=>{
    const file=e.target.files[0];e.target.value='';if(!file)return;
    try{if(file.size>MAX_BACKUP_BYTES)throw new Error('This backup is too large (20 MB maximum).');const incoming=parseBackup(await file.text());const body=openModal('Import backup');body.append(element('p','text',`Add ${array(incoming.projects).length} project(s) from this backup? Your current projects and history will be kept. Imported projects receive new IDs.`));const actions=element('div','actions');actions.append(button('Cancel',()=>ui.modal.close()),button('Import projects',()=>{checkpoint();change(D.import_projects(S.workspace,incoming.projects),{navigation:true});ui.modal.close();notice('Backup imported. Existing projects were kept.');},'btn btn--primary'));body.append(actions);}catch(error){notice(error.message,true,true);}
  });
}
