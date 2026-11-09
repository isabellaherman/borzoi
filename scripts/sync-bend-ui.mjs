// Run only after making and checking a change in the real library.
import {readFileSync, writeFileSync, mkdirSync, copyFileSync} from 'node:fs';
import {resolve, dirname} from 'node:path';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
const source=resolve(process.argv[2]??'../../Bend-UI');
const checked=spawnSync('bend',['PROOF.bend'],{cwd:source,stdio:'inherit'});
if(checked.status!==0)throw new Error('Source library proofs failed; snapshot unchanged.');
const names=['AREA.bend','DIAGRAM.bend','ICONS-LICENSE','KEYS.bend','LAWS.bend','MENU.bend','MOTION.bend','PROOF.bend','README.md','SPEC.bend','TOKENS.bend','diagram.js','icons.js','keys.js','package.json','ui.css','ui.js','WORKSPACE.bend','WORKSPACE_LAWS.bend','WORKSPACE_PROOF.bend','workspace.js','workspace.css','CHANGELOG.md','docs/BORZOI-NEEDS.md','docs/workspace.html','docs/workspace.js'];
const files={};
for(const name of names){
  const from=resolve(source,name),to=resolve('vendor/bend-ui',name);
  files[name]=createHash('sha256').update(readFileSync(from)).digest('hex');
  mkdirSync(dirname(to),{recursive:true});copyFileSync(from,to);
}
const sourceLabel='Bend-UI';
const version=JSON.parse(readFileSync(resolve(source,'package.json'),'utf8')).version;
writeFileSync('vendor/bend-ui/SOURCE.lock.json',JSON.stringify({source:sourceLabel,version,state:'Local working tree, pending owner review; not a published release',files},null,2)+'\n');
writeFileSync('vendor/bend-ui/SOURCE.txt',`Bend UI ${version} copied from the ${sourceLabel} working tree.\nLocal working tree awaiting owner review; not a published release.\nSOURCE.lock.json records exact upstream bytes; never edit this snapshot directly.\nRun bun scripts/sync-bend-ui.mjs after editing and checking the real library.\n`);
console.log(`Synchronized ${names.length} files from Bend UI ${version}.`);
