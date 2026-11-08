// Browser boundary: JSON <-> the exact data constructors accepted by Bend.
export const FORMAT = 'borzoi';
export const MAX_SOURCE = 20000;
export const MAX_BACKUP_BYTES = 20 * 1024 * 1024;
export const list = xs => xs.reduceRight((tail, head) => ({ $: 'Con', head, tail }), { $: 'Nil' });
export function array(xs) { const out=[]; for(let p=xs;p.$==='Con';p=p.tail)out.push(p.head); return out; }
export function encode(w) {
  return {format:FORMAT,version:1,workspace:{nextId:w.next_id,projectId:w.project,documentId:w.document,mode:w.mode,
    projects:array(w.projects).map(p=>({id:p.id,name:p.name,diagrams:array(p.documents).map(d=>({id:d.id,name:d.name,source:d.source,history:array(d.history).map(v=>({source:v.source,stamp:v.stamp}))}))}))}};
}
function object(x, at) { if(!x || typeof x!=='object' || Array.isArray(x))throw new Error(`${at} must be an object.`); return x; }
function text(x, at, limit) { if(typeof x!=='string' || x.length>limit)throw new Error(`${at} must be text, at most ${limit} characters.`);return x; }
function name(x, at) { const s=text(x,at,120);if(!s.trim())throw new Error(`${at} cannot be empty.`);return s; }
function id(x) { if(!Number.isSafeInteger(x)||x<1)throw new Error('Invalid project or diagram ID.');return x; }
function items(x, at) { if(!Array.isArray(x))throw new Error(`${at} must be a list.`);return x; }
export function decode(raw) {
  object(raw,'Backup');
  if(raw.format!==FORMAT || raw.version!==1)throw new Error('This is not a supported Borzoi backup (version 1).');
  const w=object(raw.workspace,'Workspace'), seen=new Set();let maximum=0, selected=false;
  function unique(value) {const n=id(value);if(seen.has(n))throw new Error('The backup contains duplicate IDs.');seen.add(n);maximum=Math.max(maximum,n);return n;}
  const projects=items(w.projects,'Projects').map(p=>{
    object(p,'Project');const pid=unique(p.id);
    const docs=items(p.diagrams,'Diagrams').map(d=>{
      object(d,'Diagram');const did=unique(d.id);
      if(pid===w.projectId && did===w.documentId)selected=true;
      return {$:'Document',id:did,name:name(d.name,'Diagram name'),source:text(d.source,'Diagram source',MAX_SOURCE),history:list(items(d.history,'History').map(v=>{object(v,'Version');return {$:'Version',source:text(v.source,'Version source',MAX_SOURCE),stamp:text(v.stamp,'Version date',120)};}))};
    });
    if(!docs.length)throw new Error('Each project needs at least one diagram.');
    return {$:'Project',id:pid,name:name(p.name,'Project name'),documents:list(docs)};
  });
  if(!projects.length || !selected)throw new Error('The selected diagram is missing from the backup.');
  if(!Number.isSafeInteger(w.nextId)||w.nextId<=maximum)throw new Error('The backup contains an invalid ID counter.');
  if(w.mode!==0 && w.mode!==1)throw new Error('Invalid editor mode.');
  return {$:'Workspace',projects:list(projects),next_id:w.nextId,project:w.projectId,document:w.documentId,mode:w.mode};
}
export function parseBackup(value) {
  if(new TextEncoder().encode(value).byteLength>MAX_BACKUP_BYTES)throw new Error('This backup is too large (20 MB maximum).');
  let raw;try{raw=JSON.parse(value);}catch{throw new Error('The file is not valid JSON. Nothing was imported.');}
  return decode(raw);
}
