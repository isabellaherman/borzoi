// Dialogs in the lib's dialog: names, node shapes and delete confirmations.
import { SHAPES } from '../../vendor/bend-ui/diagram.js';
import G from '../diagram/Graph.bend';
import { ui, modal } from './state.js';
import { element, button, icon, menuIcon, dropdown } from './ui-kit.js';

export function openModal(title){return modal.open(title);}
// Node shapes: Borzoi's numbers (Parser.bend), most used first; the name is Mermaid's description (Bend-UI SHAPES).
export const SHAPE_ORDER=[0,1,5,3,2,4,6,7,8,9,10,11,12,13];
export const shapeLabel=code=>code===0?'Process':SHAPES[G.shape_name(code)]?.[1]??'Process';
export const shapeCode=name=>SHAPE_ORDER.find(code=>G.shape_name(code)===(name??''))??0;
// A Shape field: the lib's Dropdown, one menuitemradio per shape with its Mermaid syntax as a tag.
export function shapeField(initial){
  let chosen=initial;const field=element('div','field'),caption=element('span','field__label','Shape');caption.id='shape-caption';
  const trigger=element('button','btn');trigger.type='button';trigger.setAttribute('aria-haspopup','menu');trigger.setAttribute('aria-expanded','false');
  const show=()=>{trigger.replaceChildren(element('span','',shapeLabel(chosen)),icon('chevron-down','icon icon--sm'));trigger.setAttribute('aria-label',`Shape: ${shapeLabel(chosen)}`);};
  const items=SHAPE_ORDER.map(code=>{
    const b=element('button','menu__item'),text=element('span','',shapeLabel(code));b.type='button';b.setAttribute('role','menuitemradio');b.setAttribute('aria-checked',String(code===chosen));b.dataset.shape=String(code);
    b.append(menuIcon(''),text,element('span','tag tag--mono',`${G.shape_open(code)} ${G.shape_close(code)}`),menuIcon('check','icon icon--sm menu__check'));
    b.addEventListener('click',()=>{chosen=code;items.forEach(x=>x.setAttribute('aria-checked',String(x.dataset.shape===String(code))));show();});return b;
  });
  show();field.append(caption,dropdown(trigger,items));return {element:field,value:()=>chosen};
}
export function shapeDialog(initial,onSubmit){
  const body=openModal('Node shape'),form=element('form','form'),shape=shapeField(initial);
  const actions=element('div','actions'),submit=element('button','btn btn--primary','Save');submit.type='submit';actions.append(button('Cancel',()=>ui.modal.close()),submit);
  form.append(shape.element,actions);body.append(form);
  form.addEventListener('submit',e=>{e.preventDefault();ui.modal.close();if(shape.value()!==initial)onSubmit(shape.value());});
}
// With a shape (a node being added), the dialog also has a Shape field; onSubmit gets (name, shape).
export function nameDialog(title,initial,onSubmit,shape=null){
  const body=openModal(title),form=element('form','form'),label=element('label','field'),caption=element('span','field__label','Name'),input=element('input','input');input.value=initial;input.required=true;input.maxLength=120;label.append(caption,input);
  const picker=shape===null?null:shapeField(shape);
  const actions=element('div','actions'),cancel=button('Cancel',()=>ui.modal.close()),submit=element('button','btn btn--primary','Save');submit.type='submit';actions.append(cancel,submit);form.append(label,...(picker?[picker.element]:[]),actions);body.append(form);
  form.addEventListener('submit',e=>{e.preventDefault();const value=input.value.trim();if(!value){input.setCustomValidity('Enter a name.');input.reportValidity();return;}ui.modal.close();onSubmit(value,picker?.value()??0);});input.addEventListener('input',()=>input.setCustomValidity(''));input.focus();input.select();
}
export function confirmDelete(title,text,onDelete){
  const body=openModal(title),actions=element('div','actions');
  actions.append(button('Cancel',()=>ui.modal.close()),button('Delete',()=>{ui.modal.close();onDelete();},'btn btn--primary'));
  body.append(element('p','text',text),element('p','detail','This can\'t be undone. Download a backup first if you may need it.'),actions);
}
