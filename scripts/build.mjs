import {rmSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
rmSync(resolve('dist'),{recursive:true,force:true});
const result=spawnSync('bend',['index.html','-o','dist'],{stdio:'inherit'});
if(result.error)throw result.error;
process.exit(result.status??1);
