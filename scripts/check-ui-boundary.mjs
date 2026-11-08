import {readFileSync, readdirSync} from 'node:fs';
import {resolve, relative, extname} from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
export function registeredClasses(css){return new Set([...css.matchAll(/\.([a-zA-Z_][\w-]*)/g)].map(m=>m[1]));}
export function inspectSource(name,source,classes){
  const errors=[];
  const fail=why=>errors.push(`${name}: ${why}`);
  if(/\.(css|scss|sass|less)$/i.test(name))fail('Styles belong in Bend UI, not the application.');
  if(/<style\b|\bstyle\s*=|\bstyle\s*:|\.style\b|\[['"]style['"]\]|\bcssText\b|\binsertRule\b|\bCSSStyleSheet\b|adoptedStyleSheets|createElement\(\s*['"]style['"]|setAttribute\(\s*['"]style['"]/i.test(source))fail('Local or injected styles are forbidden; extend Bend UI first.');
  for(const m of source.matchAll(/(?:import\s*(?:[^;\n]*?from\s*)?|href\s*=\s*)['"]([^'"]+\.(?:css|scss|sass|less)(?:\?[^'"]*)?)['"]/g)){
    if(!m[1].includes('vendor/bend-ui/'))fail(`Stylesheet outside Bend UI: ${m[1]}`);
  }
  const classValues=[];
  for(const pattern of [
    /\bclass\s*=\s*['"]([^'"]*)['"]/g,
    /\.className\s*=\s*['"]([^'"]*)['"]/g,
    /\bcls\s*=\s*['"]([^'"]*)['"]/g,
    /\belement\(\s*['"][^'"]*['"]\s*,\s*['"]([^'"]*)['"]/g,
    /\.classList\.(?:add|remove|toggle)\(\s*['"]([^'"]*)['"]/g,
    /setAttribute\(\s*['"]class['"]\s*,\s*['"]([^'"]*)['"]/g,
  ]) for(const match of source.matchAll(pattern))classValues.push(match[1]);
  // Literal class arguments to the application's button/icon factories.
  for(const match of source.matchAll(/['"]((?:btn|icon)(?:\s+[a-zA-Z_][\w-]*)+)['"]/g))classValues.push(match[1]);
  for(const value of classValues)for(const cls of value.split(/\s+/).filter(Boolean))if(!classes.has(cls))fail(`Unregistered visual class: ${cls}. Add and document the component in Bend UI first.`);
  return [...new Set(errors)];
}
export function verifySnapshot(root,lock){
  const errors=[];
  for(const [name,expected] of Object.entries(lock.files)){
    try{if(hash(readFileSync(resolve(root,name)))!==expected)errors.push(`Bend UI snapshot changed: ${name}. Edit the real library, then synchronize.`);}
    catch{errors.push(`Bend UI snapshot file missing: ${name}`);}
  }
  for(const name of walk(root))if(!['SOURCE.txt','SOURCE.lock.json'].includes(name)&&!(name in lock.files))errors.push(`Unregistered Bend UI snapshot file: ${name}`);
  return errors;
}
function walk(root){return readdirSync(root,{withFileTypes:true}).flatMap(entry=>entry.isDirectory()?walk(resolve(root,entry.name)).map(name=>`${entry.name}/${name}`):[entry.name]);}
export function checkBoundary(root=process.cwd()){
  const vendor=resolve(root,'vendor/bend-ui'),lock=JSON.parse(readFileSync(resolve(vendor,'SOURCE.lock.json'),'utf8'));
  const errors=verifySnapshot(vendor,lock);
  const css=Object.keys(lock.files).filter(name=>name.endsWith('.css')).map(name=>readFileSync(resolve(vendor,name),'utf8')).join('\n');
  const classes=registeredClasses(css);
  const names=['index.html',...walk(resolve(root,'src')).map(name=>`src/${name}`)];
  for(const name of names)if(['.html','.js','.mjs','.css','.scss','.sass','.less'].includes(extname(name)))errors.push(...inspectSource(name,readFileSync(resolve(root,name),'utf8'),classes));
  return errors;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const errors=checkBoundary();
  if(errors.length){console.error(errors.join('\n'));process.exit(1);}
  console.log('UI boundary: library snapshot intact; no local styles or unregistered component classes.');
}
