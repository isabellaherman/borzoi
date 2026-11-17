// The side bar: projects, their diagrams, and the actions in their ⋯ menus.
import D from '../workspace/Workspace.bend';
import A from '../agent/Inbox.bend';
import { array } from '../workspace/codec.js';
import { $, S, notice, change, checkpoint, switchTo } from './state.js';
import { element, icon, navButton, menuItem, sideRow } from './ui-kit.js';
import { nameDialog, confirmDelete } from './dialogs.js';
import { newKey, agentInstructions, replaceKey } from './agent.js';

export function renderNavigation(){
  const root=$('#project-list');root.replaceChildren();
  for(const p of array(S.workspace.projects)){
    const group=element('div','side__section'),head=element('button','btn btn--ghost side__toggle'),items=element('div','side__items');
    head.type='button';head.title=p.name;head.setAttribute('aria-expanded','true');
    head.append(icon(p.inbox?'wand-sparkles':'file-text'),element('span','side__text',p.name),icon('chevron-down','icon icon--sm side__chevron'));
    for(const d of array(p.diagrams)){
      const from=A.sender(d.source),b=navButton(d.name,()=>switchTo(p.id,d.id),from?'wand-sparkles':undefined);if(from)b.title=`${d.name} · from ${from}`;
      if(d.id===S.workspace.diagram&&p.id===S.workspace.project)b.setAttribute('aria-current','page');
      items.append(sideRow(b,d.name,[
        menuItem('Rename','pencil',()=>nameDialog('Rename diagram',d.name,value=>change(D.rename_diagram(S.workspace,p.id,d.id,value),{navigation:true}))),
        element('hr','separator'),menuItem('Delete','trash-2',()=>deleteDiagram(p,d)),
      ]));
    }
    items.append(navButton('New diagram',()=>nameDialog('New diagram','Untitled diagram',value=>{checkpoint();change(D.create_diagram(S.workspace,p.id,value),{navigation:true});}),'plus'));
    group.append(sideRow(head,p.name,[
      ...(p.inbox?[menuItem('Agent instructions','copy',()=>agentInstructions(p.id)),menuItem('New key','refresh-cw',()=>replaceKey(p)),element('hr','separator')]:[menuItem('Receive agent diagrams','wand-sparkles',()=>{change(A.connect_agent(S.workspace,p.id,newKey()),{navigation:true});agentInstructions(p.id);}),element('hr','separator')]),
      menuItem('Rename','pencil',()=>nameDialog('Rename project',p.name,value=>change(D.rename_project(S.workspace,p.id,value),{navigation:true}))),
      element('hr','separator'),menuItem('Delete','trash-2',()=>deleteProject(p)),
    ]),items);root.append(group);
  }
}
const diagrams=n=>n===1?'1 diagram':`${n} diagrams`;
function deleteProject(p){const n=array(p.diagrams).length;confirmDelete('Delete project?',`Delete “${p.name}” and its ${diagrams(n)}, with their history?`,()=>{checkpoint();change(D.delete_project(S.workspace,p.id),{navigation:true});notice('Project deleted.');});}
function deleteDiagram(p,d){confirmDelete('Delete diagram?',`Delete “${d.name}” and its history?`,()=>{change(D.delete_diagram(S.workspace,p.id,d.id),{navigation:true});notice('Diagram deleted.');});}
export function initSidebar(){
  $('#new-project').querySelector('.menu').append(
    menuItem('Project','file-text',()=>nameDialog('New project','',name=>{checkpoint();change(D.create_project(S.workspace,name),{navigation:true});})),
    menuItem('Agent project','wand-sparkles',()=>nameDialog('New agent project','',name=>{const id=S.workspace.next_id;checkpoint();change(A.create_agent_project(S.workspace,name,newKey()),{navigation:true});agentInstructions(id);})),
  );
}
