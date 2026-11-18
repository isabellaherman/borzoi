// Browser boundary: JSON <-> the exact data constructors accepted by Bend.
export const FORMAT = 'borzoi';
export const MAX_SOURCE = 20000;
export const MAX_DOCUMENT = 200000;
export const MAX_BACKUP_BYTES = 20 * 1024 * 1024;
export const list = xs => xs.reduceRight((tail, head) => ({ $: 'Con', head, tail }), { $: 'Nil' });
export function array(xs) { const out=[]; for(let p=xs;p.$==='Con';p=p.tail)out.push(p.head); return out; }
const versions=h=>array(h).map(v=>({source:v.source,stamp:v.stamp}));
// Format 2 only adds `why` to each diagram and `documents` to each project. A workspace that uses neither is still
// written as format 1, byte for byte as before, so an older Borzoi can always open it.
export function encode(w) {
  const projects=array(w.projects),v2=projects.some(p=>p.documents.$==='Con'||array(p.diagrams).some(d=>d.why.$==='Con'));
  return {format:FORMAT,version:v2?2:1,workspace:{nextId:w.next_id,projectId:w.project,documentId:w.diagram,mode:w.mode,
    projects:projects.map(p=>({id:p.id,name:p.name,...(p.inbox?{inbox:p.inbox,seen:p.seen}:{}),
      diagrams:array(p.diagrams).map(d=>({id:d.id,name:d.name,source:d.source,history:versions(d.history),...(v2?{why:array(d.why).map(y=>({stamp:y.stamp,idea:y.idea,tradeoff:y.tradeoff}))}:{})})),
      ...(v2?{documents:array(p.documents).map(x=>({id:x.id,name:x.name,source:x.source,history:versions(x.history)}))}:{})}))}};
}
function object(x, at) { if(!x || typeof x!=='object' || Array.isArray(x))throw new Error(`${at} must be an object.`); return x; }
function text(x, at, limit) { if(typeof x!=='string' || x.length>limit)throw new Error(`${at} must be text, at most ${limit} characters.`);return x; }
function name(x, at) { const s=text(x,at,120);if(!s.trim())throw new Error(`${at} cannot be empty.`);return s; }
function id(x) { if(!Number.isSafeInteger(x)||x<1)throw new Error('Invalid project or diagram ID.');return x; }
function items(x, at) { if(!Array.isArray(x))throw new Error(`${at} must be a list.`);return x; }
export function decode(raw) {
  object(raw,'Backup');
  if(raw.format!==FORMAT || (raw.version!==1 && raw.version!==2))throw new Error('This is not a supported Borzoi backup (version 1 or 2).');
  const history=(h,limit)=>list(items(h,'History').map(v=>{object(v,'Version');return {$:'Version',source:text(v.source,'Version source',limit),stamp:text(v.stamp,'Version date',120)};}));
  // Format 1 has no `why` and no `documents`: they load empty, and nothing else changes.
  const optional=(x,at)=>x===undefined?[]:items(x,at);
  const w=object(raw.workspace,'Workspace'), seen=new Set();let maximum=0, selected=false, any=false;
  function unique(value) {const n=id(value);if(seen.has(n))throw new Error('The backup contains duplicate IDs.');seen.add(n);maximum=Math.max(maximum,n);return n;}
  const projects=items(w.projects,'Projects').map(p=>{
    object(p,'Project');const pid=unique(p.id);
    const docs=items(p.diagrams,'Diagrams').map(d=>{
      object(d,'Diagram');const did=unique(d.id);any=true;
      if(pid===w.projectId && did===w.documentId)selected=true;
      const why=list(optional(d.why,'Why').map(y=>{object(y,'Why');return {$:'Why',stamp:text(y.stamp,'Why date',120),idea:text(y.idea,'Why idea',500),tradeoff:text(y.tradeoff,'Why trade-off',4000)};}));
      return {$:'Diagram',id:did,name:name(d.name,'Diagram name'),source:text(d.source,'Diagram source',MAX_SOURCE),history:history(d.history,MAX_SOURCE),why};
    });
    // An agent project carries its inbox key and the last message received (Workspace.bend); older backups have neither.
    const documents=optional(p.documents,'Documents').map(x=>{object(x,'Document');return {$:'Document',id:unique(x.id),name:name(x.name,'Document name'),source:text(x.source,'Document text',MAX_DOCUMENT),history:history(x.history,MAX_DOCUMENT)};});
    return {$:'Project',id:pid,name:name(p.name,'Project name'),diagrams:list(docs),inbox:p.inbox===undefined?'':text(p.inbox,'Inbox key',120),seen:p.seen===undefined?'':text(p.seen,'Last message',120),documents:list(documents)};
  });
  // A project may have no diagrams (Workspace.bend allows it: deleting its last one). With no diagram anywhere, nothing is open.
  if(any ? !selected : w.projectId!==0 || w.documentId!==0)throw new Error('The selected diagram is missing from the backup.');
  if(!Number.isSafeInteger(w.nextId)||w.nextId<=maximum)throw new Error('The backup contains an invalid ID counter.');
  if(w.mode!==0 && w.mode!==1)throw new Error('Invalid editor mode.');
  return {$:'Workspace',projects:list(projects),next_id:w.nextId,project:w.projectId,diagram:w.documentId,mode:w.mode};
}
export function parseBackup(value) {
  if(new TextEncoder().encode(value).byteLength>MAX_BACKUP_BYTES)throw new Error('This backup is too large (20 MB maximum).');
  let raw;try{raw=JSON.parse(value);}catch{throw new Error('The file is not valid JSON. Nothing was imported.');}
  return decode(raw);
}
