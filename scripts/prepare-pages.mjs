// Publish only the compiled application. Library review artifacts stay in dist/components.
import {copyFileSync,existsSync,mkdirSync,readdirSync,rmSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
if(!existsSync('dist/index.html'))throw new Error('Build the application before preparing GitHub Pages.');
const files=readdirSync('dist',{withFileTypes:true}).filter(entry=>entry.isFile()&&/\.(html|js|css)$/.test(entry.name));
rmSync('docs',{recursive:true,force:true});mkdirSync('docs');
for(const file of files)copyFileSync(join('dist',file.name),join('docs',file.name));
writeFileSync('docs/.nojekyll','');
console.log(`Prepared ${files.length} compiled application files in docs/ for GitHub Pages.`);
