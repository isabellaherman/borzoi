import {test,expect} from 'bun:test';
import {readFileSync} from 'node:fs';
import W from '../.build/workspace.mjs';
import T from '../.build/tokens.mjs';
// Exercise the shipped JS/Bend boundary. Formal proofs do not check JS argument representations.
function adapter(){
  const css={},timers=[],events={};
  const element=()=>({dataset:{},hidden:true,classList:{add(){}},setAttribute(){},addEventListener(){},replaceChildren(){}});
  const document={documentElement:{style:{setProperty:(k,v)=>css[k]=v}},createElement:element};
  const viewport={matches:false,addEventListener:(name,fn)=>events[name]=fn};
  const source=readFileSync('vendor/bend-ui/workspace.js','utf8').replace(/^import .*;\n/gm,'').replace(/export function/g,'function');
  const api=new Function('W','T','document','matchMedia','setTimeout','clearTimeout',source+'\nreturn {setStatusTone,createFeedback};')(W,T,document,()=>viewport,(fn,delay)=>{timers.push(delay);return timers.length;},()=>{});
  return {api,css,timers,viewport,events,element};
}
test('actual adapter sends native booleans to compiled Bend',()=>{
  const a=adapter(),status=a.element();
  a.api.setStatusTone(status,false);expect(status.dataset.tone).toBe('info');
  a.api.setStatusTone(status,true);expect(status.dataset.tone).toBe('error');
  expect(a.css['--workbench-direction']).toBe('row');
  a.viewport.matches=true;a.events.change();expect(a.css['--workbench-direction']).toBe('column');
});
test('feedback adapter schedules ordinary notices but keeps errors visible',()=>{
  const a=adapter(),root=a.element(),feedback=a.api.createFeedback(root);
  feedback.show('Saved');expect(a.timers).toEqual([T.feedback_duration_ms()]);expect(root.dataset.tone).toBe('info');
  feedback.show('Could not save',{error:true});expect(a.timers.length).toBe(1);expect(root.dataset.tone).toBe('error');expect(root.hidden).toBe(false);
  feedback.show('Recovery available',{persistent:true});expect(a.timers.length).toBe(1);
});
