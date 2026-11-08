// IndexedDB I/O adapter. Workspace mutations live in Domain.bend.
export class StorageConflict extends Error { constructor(){super('This workspace changed in another tab. Download your current backup, then reload to continue.');this.name='StorageConflict';} }
export async function openStorage(factory=globalThis.indexedDB) {
  if(!factory)throw new Error('Local storage is unavailable in this browser.');
  const db=await new Promise((resolve,reject)=>{
    const r=factory.open('borzoi-workspace',1);
    r.onupgradeneeded=()=>r.result.createObjectStore('workspace');
    r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);
    r.onblocked=()=>reject(new Error('Close older Borzoi tabs, then reload.'));
  });
  db.onversionchange=()=>db.close();
  return {
    load(){return new Promise((resolve,reject)=>{const tx=db.transaction('workspace','readonly'),r=tx.objectStore('workspace').get('main');r.onsuccess=()=>resolve(r.result??null);r.onerror=()=>reject(r.error);});},
    save(payload,expectedRevision){return new Promise((resolve,reject)=>{
      const tx=db.transaction('workspace','readwrite'),s=tx.objectStore('workspace');let failure=null;
      const r=s.get('main');
      r.onsuccess=()=>{const revision=r.result?.revision??0;if(revision!==expectedRevision){failure=new StorageConflict();tx.abort();return;}s.put({revision:revision+1,payload},'main');};
      tx.oncomplete=()=>resolve(expectedRevision+1);
      tx.onabort=()=>reject(failure??tx.error??new Error('The local save failed. Download a backup before leaving.'));
      tx.onerror=()=>{failure=tx.error;};
    });},
    close(){db.close();}
  };
}
