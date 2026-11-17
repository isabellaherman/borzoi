// Small builders for Bend-UI markup: elements, buttons, icons, Dropdown menus and side bar rows.
export const element=(tag,cls,text)=>{const el=document.createElement(tag);if(cls)el.className=cls;if(text!==undefined)el.textContent=text;return el;};
export function button(text,fn,cls='btn btn--ghost btn--sm'){const b=element('button',cls,text);b.type='button';b.addEventListener('click',fn);return b;}
export function icon(name,cls='icon'){
  const svg=document.createElementNS('http://www.w3.org/2000/svg','svg'),use=document.createElementNS('http://www.w3.org/2000/svg','use');
  svg.setAttribute('class',cls);svg.setAttribute('aria-hidden','true');use.setAttribute('href',`#i-${name}`);svg.append(use);return svg;
}
export function navButton(label,fn,iconName){
  const b=button('',fn,'btn btn--ghost');b.title=label;
  if(iconName)b.append(icon(iconName));b.append(element('span','side__text',label));return b;
}
// Dropdown menu items, written as Bend-UI's README writes them: an icon (or an empty one, to keep the text in line),
// the text, and the check last for the current color. A group starts with the lib's separator.
export function menuIcon(name,cls='icon icon--sm'){const svg=icon(name,cls);if(!name)svg.replaceChildren();return svg;}
export function menuItem(label,iconName,onClick){const b=element('button','menu__item');b.type='button';b.setAttribute('role','menuitem');b.append(menuIcon(iconName),element('span','',label));b.addEventListener('click',onClick);return b;}
export function radioItem(label,iconName,onClick){const b=element('button','menu__item');b.type='button';b.setAttribute('role','menuitemradio');b.setAttribute('aria-checked','false');b.append(menuIcon(iconName),element('span','',label),menuIcon('check','icon icon--sm menu__check'));b.addEventListener('click',onClick);return b;}
export function colorItem(name,tone,checked,onClick){
  const b=element('button','menu__item'),text=element('span');b.type='button';b.setAttribute('role','menuitemradio');b.setAttribute('aria-checked',String(checked));
  text.append(element('span',tone?`tag tag--${tone}`:'tag',name));b.append(menuIcon(''),text,menuIcon('check','icon icon--sm menu__check'));b.addEventListener('click',onClick);return b;
}
export const group=items=>items.length?[element('hr','separator'),...items]:[];
export function dropdown(trigger,items,end=false){const dd=element('div','dropdown'),menu=element('div',end?'menu menu--end':'menu');menu.setAttribute('role','menu');menu.hidden=true;menu.append(...items);dd.append(trigger,menu);return dd;}
// A side bar row: the item, then the lib's ⋯ menu at its end (Bend-UI 1.0.12 .side__row). Right-click opens it too.
export function sideRow(item,label,items){
  const more=button('',()=>{},'btn btn--ghost btn--icon btn--sm');more.setAttribute('aria-haspopup','menu');more.setAttribute('aria-expanded','false');more.setAttribute('aria-label',`Actions for ${label}`);more.append(icon('ellipsis'));
  const dd=dropdown(more,items,true);dd.classList.add('side__more');const row=element('div','side__row');row.append(item,dd);return row;
}
