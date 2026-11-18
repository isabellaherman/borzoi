// Why: the idea behind a diagram and what it gives up, written beside the diagram. Saving one never changes
// the diagram's Mermaid (Workspace.bend, explain). For an agent, the entries go as %% comment lines (Figures.bend).
import { announce } from '../../vendor/bend-ui/ui.js';
import D from '../workspace/Workspace.bend';
import F from '../workspace/Figures.bend';
import { array } from '../workspace/codec.js';
import { $, ui, S, stamp, doc, notice, change } from './state.js';
import { element, button } from './ui-kit.js';
import { openModal } from './dialogs.js';

export const MAX_IDEA=500,MAX_TRADEOFF=4000;
export function renderWhy(){
  const d=doc(),n=d?array(d.why).length:0,b=$('#why-btn');
  b.hidden=!d;b.lastChild.textContent=n?`Why · ${n}`:'Why';
}
export async function copyText(text,control){
  try{await navigator.clipboard.writeText(text);control.textContent='Copied';announce('Copied');}
  catch{notice('Copy is blocked here. Select the text and copy it.',true);}
}
function whyDialog(){
  const d=doc();if(!d)return;
  const body=openModal(`Why “${d.name}”`),entries=array(d.why);
  if(!entries.length)body.append(element('p','text','Nothing written yet. Write the idea behind this diagram and what it gives up. The diagram itself does not change.'));
  else{
    const list=element('div','revision-list');
    for(const y of entries){
      const item=element('article',''),head=element('div','revision-list__header');
      head.append(element('span','item-title',y.idea),element('span','detail',y.stamp.slice(0,10)));item.append(head,element('p','text',`Trade-off: ${y.tradeoff}`));list.append(item);
    }
    body.append(list);
  }
  const form=element('form','form'),ideaField=element('label','field'),idea=element('input','input');idea.required=true;idea.maxLength=MAX_IDEA;
  ideaField.append(element('span','field__label','Idea or decision'),idea);
  const tradeField=element('label','field'),trade=element('textarea','input');trade.rows=3;trade.maxLength=MAX_TRADEOFF;
  tradeField.append(element('span','field__label','Trade-offs'),trade);
  const actions=element('div','actions'),save=element('button','btn btn--primary','Save');save.type='submit';
  const copy=button('Copy for agent',()=>copyText(F.for_agent(doc()),copy));copy.title='The diagram’s Mermaid with the Why entries above it, as %% comment lines';
  actions.append(...(d.source?[copy]:[]),button('Close',()=>ui.modal.close()),save);form.append(ideaField,tradeField,actions);body.append(form);
  form.addEventListener('submit',e=>{
    e.preventDefault();const text=idea.value.trim();if(!text||S.locked)return;
    change(D.update(S.workspace,{$:'Explain',why:{$:'Why',stamp:stamp(),idea:text,tradeoff:trade.value.trim()||'None written.'}}));
    ui.modal.close();renderWhy();notice('Saved. The diagram did not change.');
  });
  idea.focus();
}
export function initWhy(){$('#why-btn').onclick=whyDialog;}
