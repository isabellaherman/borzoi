import { join, resolve } from 'node:path';
const root=resolve(process.cwd(),'dist');
const server=Bun.serve({hostname:'127.0.0.1',port:4173,async fetch(req){const path=decodeURIComponent(new URL(req.url).pathname);const file=join(root,path==='/'?'index.html':path);if(!file.startsWith(root+'/'))return new Response('Not found',{status:404});const f=Bun.file(file);return await f.exists()?new Response(f,{headers:{'Cache-Control':'no-store'}}):new Response('Not found',{status:404});}});
console.log(`Local: http://localhost:${server.port}`);
