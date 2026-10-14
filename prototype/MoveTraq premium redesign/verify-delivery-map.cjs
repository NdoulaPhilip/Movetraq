const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
class Base{constructor(props){this.props=props;}setState(update){Object.assign(this.state,update);}}
const React={Component:Base,createElement:(type,props,...children)=>({type,props:props||{},children:children.flat()})};
let success,failure,cleared=[],watches=0;
const sandbox={window:{React,isSecureContext:true},navigator:{geolocation:{watchPosition(ok,fail){success=ok;failure=fail;return ++watches;},clearWatch(id){cleared.push(id);}}},Date,encodeURIComponent};
vm.runInNewContext(fs.readFileSync('delivery-map.js','utf8'),sandbox);
const el=sandbox.window.MovetraqDeliveryMap.view({destination:'Ikeja',stage:'pickup'}),map=new el.type(el.props);
assert.equal(watches,0);map.start();assert.equal(watches,1);
success({coords:{latitude:6.5,longitude:3.4,accuracy:15}});assert.equal(map.state.point.lat,6.5);
map.componentWillUnmount();assert.deepEqual(cleared,[1]);success({coords:{latitude:7,longitude:4,accuracy:15}});assert.equal(map.state.point.lat,6.5);
map.start();failure({code:1});assert.equal(map.state.tracking,false);assert.equal(map.state.point,null);assert.match(map.state.error,/permission/);
sandbox.window.isSecureContext=false;map.start();assert.match(map.state.error,/HTTPS/);
console.log('PASS: opt-in location, updates, permission errors, secure context and watch cleanup.');

const destinationFrame=map.render().children.find(n=>n?.type==='iframe');
assert.equal(destinationFrame.props.title,'Map of pickup destination');assert.match(destinationFrame.props.src,/q=Ikeja&output=embed/);assert.equal(map.state.tracking,false);
console.log('PASS: destination map is shown without device location permission.');
// Destination failures have a retry path and an offline fallback.
map.setState({mapUnavailable:true});assert(JSON.stringify(map.render()).includes('Retry map'));
sandbox.navigator.onLine=false;map.setState({offline:true});assert(JSON.stringify(map.render()).includes('Map unavailable offline'));
console.log('PASS: destination map retry and offline fallback.');
