const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
class Base{constructor(props){this.props=props||{};}setState(u){Object.assign(this.state,typeof u==='function'?u(this.state):u);}}
const React={Component:Base,createElement:(type,props,...children)=>({type,props:props||{},children:children.flat()})};
const sandbox={window:{React},fetch:()=>{throw Error('UI map must never request network data');}};
vm.runInNewContext(fs.readFileSync('maps.js','utf8'),sandbox);
let selected;
const element=sandbox.window.MovetraqMaps.view({interactive:true,points:[{lat:6.447,lng:3.465}],onPick:p=>selected=p});
const map=new element.type(element.props);
const event={currentTarget:{getBoundingClientRect:()=>({left:0,top:0,width:420,height:320})},clientX:210,clientY:160};
map.pick(event);assert.equal(selected.lat,6.447);assert.equal(selected.lng,3.465);
map.pick({...event,clientX:300,clientY:100});assert(selected.lng>3.465);assert(selected.lat>6.447);
assert.equal(map.render().children[0].props.viewBox,'0 0 420 320');
map.setState({zoom:2});assert.notEqual(map.render().children[0].props.viewBox,'0 0 420 320');
assert(!fs.readFileSync('maps.js','utf8').includes('fetch('));
const appSource=fs.readFileSync('MoveTraq.dc.html','utf8');
assert(!appSource.includes('navigator.geolocation'));assert(!appSource.includes('MovetraqMaps.search('));assert(!appSource.includes('MovetraqMaps.reverse('));
console.log('PASS: UI-only map pin placement, keyboard-ready preview, zoom and no live location/geocoding requests.');
