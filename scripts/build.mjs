import {rmSync,renameSync,readFileSync,writeFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
import {checkBoundary} from './check-ui-boundary.mjs';
const errors=checkBoundary();
if(errors.length)throw new Error(errors.join('\n'));
function run(args){const result=spawnSync('bend',args,{stdio:'inherit'});if(result.error)throw result.error;if(result.status!==0)process.exit(result.status??1);}
rmSync(resolve('dist'),{recursive:true,force:true});
run(['index.html','-o','dist']);
run(['vendor/bend-ui/docs/workspace.html','-o','dist/components']);
renameSync('dist/components/workspace.html','dist/components/index.html');

// Normalize bundler whitespace before checking generated files into Pages.
for(const file of ['dist/index.html','dist/components/index.html'])writeFileSync(file,readFileSync(file,'utf8').replace(/[ \t]+$/gm,''));
