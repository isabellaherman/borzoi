// Agent projects: agents send plain Mermaid to the project's inbox on ntfy.sh, a free public message relay. The key is
// the inbox's name, made at random here. Borzoi fetches what arrived; Inbox.bend turns each message into a new
// diagram in that project only (it never changes a diagram that exists). ntfy.sh keeps messages for about 12 hours.
import A from '../agent/Inbox.bend';
import { array } from '../workspace/codec.js';
import { ui, S, hooks, stamp, notice, change } from './state.js';
import { element, button } from './ui-kit.js';
import { openModal } from './dialogs.js';
import { renderNavigation } from './sidebar.js';

const INBOX='https://ntfy.sh/';
export function newKey(){const abc='abcdefghijkmnpqrstuvwxyz23456789';return 'bz-'+Array.from(crypto.getRandomValues(new Uint8Array(20)),b=>abc[b%32]).join('');}
const projectById=id=>array(S.workspace.projects).find(p=>p.id===id);
function instructionsFor(p){return `You can send diagrams to my Borzoi project "${p.name}".

You can send as many diagrams as you like, one per message. The "Title" decides what happens:
- A new title makes a new diagram in this project.
- The title of a diagram you sent before updates that diagram. Its previous version is kept in its history.

How to send one:
- Make an HTTP POST request to ${INBOX}${p.inbox}
- Body: the diagram as plain Mermaid text, with real line breaks.
- Header "Title": the diagram's name (keep it the same to update a diagram).

Write the diagram like this:
%% borzoi from <your name>
flowchart TD
  A[First step] --> B[Next step]
  B -->|label on the arrow| C[Another step]:::red

Rules:
- Use only flowchart TD, nodes like A[Text], arrows --> and arrow labels -->|text|. Mermaid node shapes are fine where they help: A{Decision?}, A[(Database)], A([Start or end]).
- Color a node with :::red, :::yellow, :::green or :::blue.
- Make one tree that reads top to bottom: a single starting node, and every other node reachable from it. Never leave a second group with no arrow to the first.
- At most 4 arrows out of any node. With more items, group them under intermediate nodes (for example "High priority", "Medium priority").
- Keep labels short: nodes up to about 4 words, arrow labels 1 or 2 words. Put numbers in the node, such as B[Started a run 51].
- Put problems and ideas in their own diagram, or under one node such as "Problems", not beside the main flow.
- No subgraphs, no other directions (such as LR), no rounded or diamond shapes.
- Keep each diagram under 4,000 characters.
- Send each version once, and send nothing else to this address.

Anyone with this address can add diagrams to this project, so keep it private.`;}
export function agentInstructions(id){
  const p=projectById(id);if(!p?.inbox)return;
  const body=openModal('Agent instructions'),text=instructionsFor(p),pre=element('pre','revision-list__source',text),actions=element('div','actions');
  const copy=button('Copy instructions',async()=>{try{await navigator.clipboard.writeText(text);ui.modal.close();notice('Instructions copied. Paste them to your agent.');}catch{const r=document.createRange();r.selectNodeContents(pre);getSelection().removeAllRanges();getSelection().addRange(r);notice('Copy the selected text with Cmd+C or Ctrl+C.');}},'btn btn--primary');
  actions.append(button('Close',()=>ui.modal.close()),copy);
  body.append(element('p','text','Give these instructions to your agent once. Each diagram it sends becomes a new diagram in this project, or a new version of one it sent before (the old one stays in History). Agents never change the diagrams you made.'),pre,element('p','detail','Diagrams arrive while Borzoi is open, or the next time you open it within about 12 hours.'),actions);
}
export function replaceKey(p){
  const body=openModal('Make a new key?'),actions=element('div','actions');
  actions.append(button('Cancel',()=>ui.modal.close()),button('Make new key',()=>{ui.modal.close();change(A.new_key(S.workspace,p.id,newKey()),{navigation:true});agentInstructions(p.id);},'btn btn--primary'));
  body.append(element('p','text',`The current key for “${p.name}” stops working. Agents that have the old instructions can't send diagrams any more until you give them the new ones.`),actions);
}
async function messagesFor(p){
  const r=await fetch(`${INBOX}${encodeURIComponent(p.inbox)}/json?poll=1&since=${encodeURIComponent(p.seen||'all')}`);
  if(!r.ok)throw new Error(`The inbox answered ${r.status}.`);
  const out=[];for(const line of (await r.text()).split('\n')){if(!line.trim())continue;try{const m=JSON.parse(line);if(m.event==='message')out.push(m);}catch{}}
  // A message over 4 KB arrives as a file; read it when the relay allows it.
  for(const m of out)if(m.attachment?.url){try{const a=await fetch(m.attachment.url);if(a.ok)m.message=await a.text();}catch{}}
  return out;
}
export async function checkInboxes(){
  if(S.locked||S.checking||document.hidden)return;S.checking=true;
  try{
    let arrived=0,updated=0;
    for(const p of array(S.workspace.projects).filter(p=>p.inbox)){
      let messages;try{messages=await messagesFor(p);}catch{continue;}
      let next=S.workspace;const seen=w=>array(w.projects).find(q=>q.id===p.id)?.seen;
      for(const m of messages){
        const before=next,time=Number.isFinite(m.time)?new Date(m.time*1000).toISOString():stamp();
        next=A.receive(next,p.id,p.inbox,String(m.id??''),String(m.title??''),String(m.message??''),time);
        if(seen(next)!==seen(before)){if(next.next_id!==before.next_id)arrived++;else updated++;}
      }
      if(next!==S.workspace&&!S.locked)change(next);
    }
    const said=[arrived&&(arrived===1?'1 new diagram':`${arrived} new diagrams`),updated&&(updated===1?'1 diagram updated':`${updated} diagrams updated`)].filter(Boolean);
    // An update may be the diagram that is open: show its new text (your previous text is in History).
    if(updated)hooks.render();else if(arrived)renderNavigation();
    if(said.length)notice(`From agents: ${said.join(', ')}.`);
  }finally{S.checking=false;}
}
