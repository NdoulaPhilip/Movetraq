import fs from 'node:fs';
import path from 'node:path';
const root = path.resolve(import.meta.dirname, '..');
const source = fs.readFileSync(path.join(root, 'prototype/MoveTraq premium redesign/MoveTraq.dc.html'), 'utf8');
const block = source.slice(source.indexOf('    this._ic = {'), source.indexOf('    return this._ic;'));
const body = block.slice(block.indexOf('{'), block.lastIndexOf('}') + 1);
const attrs = a => Object.entries(a || {}).map(([k,v]) => ` ${k}="${v}"`).join('');
const P = (d,a) => '<path d="' + d + '"' + attrs(a) + '/>';
const C = (cx,cy,r,a) => '<circle cx="'+cx+'" cy="'+cy+'" r="'+r+'"'+attrs(a)+'/>';
const R = (x,y,width,height,rx,a) => '<rect'+attrs({x,y,width,height,rx,...a})+'/>';
const S = children => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">'+children.join('')+'</svg>';
const React = {createElement:(tag,a,...c) => '<'+tag+attrs(Object.fromEntries(Object.entries(a).filter(([k])=>k!=='style')))+'>'+c.join('')+'</'+tag+'>'};
const dot = cx => C(cx,12,1.6,{fill:'currentColor',stroke:'none'});
// This is the reviewed icon object from the supplied local design, not a downloaded script.
const icons = Function('S','P','C','R','dot','React', 'return ('+body+')')(S,P,C,R,dot,React);
const dir = path.join(root, 'mobile/assets/icons');
fs.mkdirSync(dir,{recursive:true});
for (const [name,svg] of Object.entries(icons)) fs.writeFileSync(path.join(dir,name+'.svg'),svg);
console.log('Copied '+Object.keys(icons).length+' original prototype icons.');

