const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync('MoveTraq.dc.html', 'utf8');
// Validate template nesting: logic-only route checks cannot catch a broken screen wrapper.
const templateMarkup=html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'').replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi,'').replace(/<!--[\s\S]*?-->/g,'');
const tags=[];const voidTags=new Set(['meta','link','img','input','br','hr','source','wbr','area','base','col','embed','param','track']);
for(const match of templateMarkup.matchAll(/<(\/?)([a-z][a-z0-9-]*)\b[^>]*>/gi)){
 const tag=match[2].toLowerCase();if(voidTags.has(tag))continue;
 if(match[1])assert.equal(tags.pop(),tag,'Template closing tag must match: '+match[0]);else tags.push(tag);
}
assert.equal(tags.length,0,'All template wrappers must close');
assert(html.includes('<sc-if value="{{ isProfile }}">'));
const source = html.match(/<script type="text\/x-dc"[^>]*>([\s\S]*?)<\/script>/)[1];
class DCLogic {
  props = {};
  setState(update) { Object.assign(this.state, typeof update === 'function' ? update(this.state) : update); }
}
const sandbox = {DCLogic, React:{createElement:(type,props,...children)=>({type,props:props||{},children:children.flat()}),Fragment:'fragment'},requestAnimationFrame:()=>{},URL,AbortController,Date,setTimeout,clearInterval};
const Component = vm.runInNewContext(source+'\nComponent', sandbox);
const app = new Component();
assert.equal(app.cur,'splash');
let launch;
sandbox.setTimeout = fn => { launch=fn; return 1; };
sandbox.clearTimeout = () => {};
sandbox.setInterval = () => 2;
sandbox.document = {createElementNS:()=>({setAttribute(){},getTotalLength:()=>100,getPointAtLength:()=>({x:0,y:0})})};
app.forceUpdate=()=>{};
app.componentDidMount();
assert.equal(app.renderVals().isSplash,true);
launch();
assert.equal(app.cur,'onboard');
assert.equal(app.state.stack.length,1);
app.componentWillUnmount();
const routes = [...new Set([...source.matchAll(/(?:push|tab)\('([^']+)'\)/g)].map(m=>m[1]))];
const extra = ['personal','addresses','addressEdit','security','preferences','support','ticket','forgot','receive','schedule','errand','move','withdraw','payment','share','contact','photo','rating'];
for (const route of [...routes,...extra]) {
  if(route==='completion') app.state.completion={title:'Done',detail:'Test',destination:'home'};
  app.state.stack=[route];
  const values=app.renderVals();
  assert(values.extraScreen || Object.entries(values).some(([k,v])=>/^is[A-Z]/.test(k)&&v===true),`No screen: ${route}`);
}
app.state.stack=['home'];
for(const item of app.renderVals().quick) {item.onTap();assert.notEqual(app.cur,'home');app.tab('home');}
app.tab('profile');
for(const item of app.renderVals().menu) {item.onTap();assert.notEqual(app.cur,'profile');app.tab('profile');}
app.renderVals().parcelTypes.find(p=>p.label==='Fragile').onTap();
assert.equal(app.state.parcelType,'Fragile');
app.renderVals().speeds.find(p=>p.label==='Standard').onTap();
app.state.sendMode='express';
assert.match(app.renderVals().sendCtaLabel,/2,500/);
app.state.chatDraft='Hello courier';app.renderVals().sendMessage();
assert.equal(app.renderVals().messages.at(-1).text,'Hello courier');
assert.equal(app.state.chatDraft,'');
app.state.topup=5000;app.renderVals().completeTopup();assert.equal(app.state.balance,47300);
assert.equal(app.cur,'completion');
app.state.form={pickup:'Test pickup',dropoff:'Test dropoff',pickupDate:'2026-10-01',pickupTime:'10:00'};
assert.equal(app.renderVals().draftPickup,'Test pickup');
assert.match(app.renderVals().bookingSummary,/2026-10-01/);
function walk(node,type) { if(!node || typeof node!=='object') return null; if(node.type===type) return node; for(const c of node.children||[]) {const found=walk(c,type);if(found)return found;}return null; }
function submit(route,form) {app.state.stack=[route];app.state.form=form;const tree=app.extraScreen();const el=walk(tree,'form');assert(el,route+' has form');el.props.onSubmit({preventDefault(){}});}
submit('personal',{name:'Test User',email:'test@example.com',phone:'08000000000'});
assert.equal(app.renderVals().profileName,'Test User');
submit('payment',{cardLabel:'Test card',cardLast4:'1234',cardExpiry:'12/39'});
assert(app.renderVals().methods.some(m=>m.label==='Test card'));
const addedPayment=app.savedPaymentMethods.find(m=>m.label==='Test card');
app.editPaymentMethod(addedPayment);app.state.form.cardLabel='Updated card';app.savePaymentMethod();assert.equal(app.savedPaymentMethods.find(m=>m.id===addedPayment.id).label,'Updated card');
app.state.defaultPayment=addedPayment.id;app.state.checkoutMethod=addedPayment.id;app.removePaymentMethod(addedPayment.id);assert(!app.savedPaymentMethods.some(m=>m.id===addedPayment.id));assert.equal(app.state.defaultPayment,'wallet');assert.equal(app.state.checkoutMethod,'wallet');

submit('receive',{tracking:'INVALID'});assert.equal(app.cur,'receive');assert(app.state.form.trackingError);
submit('receive',{tracking:'MT-4821'});assert.equal(app.cur,'orderTracking');
const balance=app.state.balance;
submit('withdraw',{withdrawAmount:balance+1});assert.equal(app.state.balance,balance);
submit('withdraw',{withdrawAmount:1000});assert.equal(app.state.balance,balance-1000);
submit('security',{newPin:'1234',confirmPin:'5678'});assert.equal(app.cur,'security');
submit('security',{newPin:'1234',confirmPin:'1234'});assert.equal(app.state.form.newPin,'');
// Location selection carries into the draft; checkout never charges before payment.
app.renderVals().openLocation();assert.equal(app.cur,'locations');
function nodes(tree,type){if(!tree||typeof tree!=='object')return [];return [...(tree.type===type?[tree]:[]),...(tree.children||[]).flatMap(c=>nodes(c,type))];}
function label(tree){if(typeof tree==='string')return tree;return (tree?.children||[]).map(label).join(' ');}
app.selectMapPlace({lat:6.43,lng:3.46,label:'Lekki, Lagos',name:'Lekki'});
assert.equal(app.cur,'deliveryChoice');assert.equal(app.state.form.dropoff,'Lekki, Lagos');
app.chooseDeliveryMode('express');assert.equal(app.cur,'send');assert.equal(app.state.sendMode,'express');
app.state.form={pickup:'Ikeja',dropoff:'Lekki',recipientPhone:'08012345678',description:'Books'};
app.state.sendMode='express';app.state.speed='Express';app.state.balance=100;
app.renderVals().sendConfirm();assert.equal(app.cur,'expressReview');assert.equal(app.state.balance,100);
assert.equal(app.state.checkout.total,4000);
nodes(app.extraScreen(),'button').find(n=>label(n)==='Continue to payment').props.onClick();assert.equal(app.cur,'expressPayment');
app.payExpress();assert.equal(app.cur,'expressPayment');assert.equal(app.state.balance,100);
assert.match(app.state.toast.message,/Insufficient balance/);assert.equal((app.state.bookings||[]).length,0);
nodes(app.toastView(),'button').find(n=>label(n)==='Add money').props.onClick();assert.equal(app.cur,'topup');
app.state.topup=5000;app.renderVals().completeTopup();assert.equal(app.cur,'expressPayment');
assert.equal(app.state.checkout.description,'Books');assert.equal(app.state.balance,5100);
app.payExpress();assert.equal(app.cur,'expressReceipt');assert.equal(app.state.balance,1100);
assert.equal(app.state.bookings.length,1);assert(app.renderVals().allOrders.some(o=>o.id===app.state.receipt.id));
app.payExpress();assert.equal(app.state.balance,1100);assert.equal(app.state.bookings.length,1);
app.state.form.pickup='';app.reviewExpress();assert.match(app.state.toast.message,/Add pickup/);
app.state.form.pickup='Ikeja';app.reviewExpress();app.state.checkoutMethod='card';app.beginPayment();assert.equal(app.cur,'paymentAuthorize');app.state.paymentCode='000000';app.confirmDemoPayment();assert.equal(app.state.bookings.length,1);assert(app.state.paymentError);app.state.paymentCode='123456';app.confirmDemoPayment();
assert.equal(app.state.balance,1100);assert.equal(app.state.bookings.length,2);
app.renderVals().openSettings();assert.equal(app.cur,'settings');
assert(nodes(app.extraScreen(),'button').some(n=>label(n).includes('Notifications')));
app.state.preferences.animations=false;assert.match(app.renderVals().phoneClass,/mt-reduce-motion/);
assert(!html.includes('{{ noop }}'));
const template=html.split('<script type="text/x-dc"')[0];
app.tab('home');const vals=app.renderVals();
for(const match of template.matchAll(/on(?:Click|Change)="{{\s*(\w+)\s*}}"/g)) assert.equal(typeof vals[match[1]],'function',`Missing handler ${match[1]}`);
assert(fs.existsSync('assets/movetraq-brand.png'));
app.tab('onboard');app.state.preferences.animations=true;
app.state.welcomeSlide=0;app.state.welcomePaused=false;
app.advanceWelcome();assert.equal(app.state.welcomeSlide,1);
app.selectWelcome(3);app.advanceWelcome();assert.equal(app.state.welcomeSlide,3);
app.state.welcomePaused=false;app.advanceWelcome();assert.equal(app.state.welcomeSlide,0);
app.state.preferences.animations=false;app.advanceWelcome();assert.equal(app.state.welcomeSlide,0);
app.state.preferences.animations=true;app.tab('signin');app.advanceWelcome();assert.equal(app.state.welcomeSlide,0);
app.tab('onboard');const carousel=app.welcomeCarousel();
carousel.props.onTouchStart({touches:[{clientX:200,clientY:100}]});
carousel.props.onTouchEnd({changedTouches:[{clientX:90,clientY:104}]});
assert.equal(app.state.welcomeSlide,1);assert.equal(app.state.welcomePaused,true);
assert.equal(nodes(app.welcomeCarousel(),'div').filter(n=>n.props['aria-hidden']===false).length,1);
// P2P confirms the negotiated rate before charging and preserves it through top-up.
app.state.form={pickup:'Ikeja',dropoff:'Lekki',recipientPhone:'08012345678'};
app.state.sel={name:'Blessing Ade',priceNum:2800,first:'Blessing',total:'₦3,300'};
app.state.balance=100;app.state.sendMode='p2p';app.tab('confirmOrder');
app.renderVals().sendConfirmFinal();assert.equal(app.cur,'expressPayment');
assert.equal(app.state.balance,100);assert.equal(app.state.checkout.total,3300);assert.equal(app.state.checkout.courier,'Blessing Ade');
const beforeP2P=app.state.bookings.length;app.payExpress();assert.equal(app.state.bookings.length,beforeP2P);
nodes(app.toastView(),'button').find(n=>label(n)==='Add money').props.onClick();
app.state.topup=5000;app.renderVals().completeTopup();assert.equal(app.cur,'expressPayment');
assert.equal(app.state.stack[1],'confirmOrder');app.back();assert.equal(app.cur,'confirmOrder');
app.renderVals().sendConfirmFinal();app.payExpress();assert.equal(app.state.balance,1800);
assert.equal(app.state.receipt.courier,'Blessing Ade');assert.equal(app.state.receipt.status,'Courier assigned');
// Screening remains available, with every field and requirement optional.
app.state.role='sender';app.state.application=undefined;app.state.form={};
app.renderVals().goDeliver();assert.equal(app.cur,'delivererApply');
app.switchRole('sender');
app.renderVals().menu.find(m=>m.label==='Delivery opportunities').onTap();assert.equal(app.cur,'roles');
app.state.form={};app.reviewApplication();assert.equal(app.cur,'applicationReview');
assert.equal(app.state.applicationDraft.name,'Not provided');
app.state.toast={message:'Old validation message'};app.submitApplication();
assert.equal(app.cur,'dHome');assert.equal(app.state.role,'deliverer');assert.equal(app.state.toast,null);
assert.equal(app.state.application.status,'approved');
assert(!html.includes('Complete your contact, vehicle and emergency contact details.'));
for(const transport of ['Bicycle','Trekking / walking','Other non-motor transport']){
  app.state.form={appVehicle:transport};app.state.applicationStep=1;
  const checklist=label(app.applicationFormUI());assert(!checklist.includes('Driving licence expiry'));assert(!checklist.includes('Skip to deliverer dashboard'));
}
app.switchRole('sender');
const profileLabels=app.renderVals().menu.map(m=>m.label);
assert(!profileLabels.includes('Security & PIN'));assert(!profileLabels.includes('Notifications'));
app.tab('settings');const settingLabels=nodes(app.extraScreen(),'button').map(label).join('|');
assert(!settingLabels.includes('Personal details'));assert(!settingLabels.includes('Payment methods'));assert(settingLabels.includes('Security & PIN'));
// Auth forms validate sample details and clear passwords on completion/navigation.
app.openAuth('create');const signupTree=app.authScreen();
assert.equal(nodes(signupTree,'input').length,4);
app.state.auth={};app.submitAuth();assert.equal(app.cur,'emailOtp');assert.equal(app.state.pendingAccount.name,'Demo Member');app.verifyEmail();assert.equal(app.cur,'home');
app.openAuth('signin');app.state.auth={};app.submitAuth();assert.equal(app.cur,'home');assert.equal(app.state.toast,null);
app.openAuth('create');
app.state.auth={name:'Demo Member',email:'member@example.com',phone:'08012345678',password:'sample-only'};
app.submitAuth();assert.equal(app.cur,'emailOtp');assert.equal(app.state.pendingAccount.name,'Demo Member');assert(!app.state.auth.password);
app.state.emailCode='000000';app.verifyEmail();assert.equal(app.cur,'emailOtp');assert(app.state.emailCodeError);
app.state.emailCode='123456';app.verifyEmail();assert.equal(app.cur,'home');assert.equal(app.state.profile.emailVerified,true);
app.openAuth('signin');assert.equal(nodes(app.authScreen(),'input').length,2);
app.state.auth={email:'member@example.com',password:'sample-only'};
nodes(app.authScreen(),'button').find(n=>n.props['aria-label']==='Show password').props.onClick();
assert.equal(nodes(app.authScreen(),'input').find(n=>n.props.name==='password').props.type,'text');
app.openAuth('create');assert(!app.state.auth.password);assert.equal(app.state.showAuthPassword,false);
assert(!nodes(app.welcomeCarousel(),'button').some(n=>/Pause|Play/.test(label(n))));
// Current addresses support edit, select-to-home, removal and an empty state.
app.tab('addresses');app.editAddress(app.addressBook[0]);
app.state.form.address='Test Road, Lagos';app.saveAddress();assert.equal(app.addressBook[0].address,'Test Road, Lagos');
app.selectCurrentAddress(app.addressBook[1]);assert.equal(app.cur,'home');assert.match(app.renderVals().currentLocationLabel,/Victoria/);
app.deleteAddress('work');assert.equal(app.addressBook.length,1);assert.equal(app.currentAddress.id,'home');
app.deleteAddress('home');assert.equal(app.addressBook.length,0);assert.equal(app.currentAddress,null);
app.tab('addresses');app.editAddress(null);app.state.form={addressLabel:'New home',address:'Lekki Phase 1',addressPhone:'08012345678'};
app.saveAddress();assert.equal(app.addressBook.length,1);
assert(app.locationSuggestions('Ikeja').some(p=>p.name==='Ikeja City Mall'));
app.openPinPicker('pickup','Pickup address');app.state.pinPoint={label:'Picked point',lat:6.5,lng:3.4};app.useMapPin();
assert.equal(app.state.form.pickup,'Picked point');
// Clear all, undo and individual dismiss never delete order history.
app.tab('notifs');const notifs=app.renderVals().notifications;const bookingCount=app.state.bookings.length;
nodes(app.renderVals().notificationScreen,'button').find(n=>label(n)==='Clear all').props.onClick();
assert.equal(app.renderVals().notifications.length,0);assert.equal(app.state.bookings.length,bookingCount);
nodes(app.renderVals().notificationScreen,'button').find(n=>label(n)==='Undo').props.onClick();assert.equal(app.renderVals().notifications.length,notifs.length);
nodes(app.renderVals().notificationScreen,'button').find(n=>n.props['aria-label']?.startsWith('Clear ')).props.onClick();
assert.equal(app.renderVals().notifications.length,notifs.length-1);
assert(!nodes(app.profileOverview(),'div').some(n=>n.props.className==='mt-brand'));
// Bank confirmation, duplicate protection, and empty saved-method state.
const bankDemo=new Component();bankDemo.state.checkout={total:2500,parcel:'Documents',speed:'Express'};bankDemo.state.checkoutMethod='bank';bankDemo.beginPayment();assert.equal(bankDemo.cur,'paymentAuthorize');bankDemo.confirmDemoPayment();assert.equal(bankDemo.cur,'expressReceipt');assert.equal(bankDemo.state.balance,42300);assert.match(bankDemo.state.receipt.paymentLabel,/GTBank/);bankDemo.confirmDemoPayment();assert.equal(bankDemo.state.bookings.length,1);
for(const m of [...bankDemo.savedPaymentMethods])bankDemo.removePaymentMethod(m.id);assert.equal(bankDemo.savedPaymentMethods.length,0);assert.equal(bankDemo.state.checkoutMethod,'wallet');
// Deletion requires the explicit phrase, resets private session state and relocks delivery.
app.state.profile={name:'Delete Demo'};app.state.deleteConfirmation='';app.deletePreviewAccount();assert.equal(app.state.profile.name,'Delete Demo');
app.state.deleteConfirmation='DELETE';app.deletePreviewAccount();assert.equal(app.cur,'onboard');assert.equal(app.state.profile,null);assert.equal(app.state.application,null);assert.equal(app.state.pendingAccount,null);assert.equal(Object.keys(app.state.form).length,0);assert.equal(app.state.bookings,undefined);assert.equal(app.state.addressBook,undefined);assert.equal(app.guardScreen('dHome'),'dHome');
// Profile role switch changes dashboards and keeps delivery preferences.
app.switchRole('deliverer');app.tab('profile');
let roleSwitch=nodes(app.profileOverview(),'button').find(n=>n.props.role==='switch');
assert.equal(roleSwitch.props['aria-checked'],true);roleSwitch.props.onClick();assert.equal(app.cur,'home');assert.equal(app.state.role,'sender');
roleSwitch=nodes(app.profileOverview(),'button').find(n=>n.props.role==='switch');roleSwitch.props.onClick();assert.equal(app.cur,'dHome');
assert(app.renderVals().menu.some(m=>m.label==='Earnings & payouts'));assert(!app.renderVals().menu.some(m=>m.label==='Saved addresses'));
app.tab('courierPrefs');nodes(app.extraScreen(),'select')[0].props.onChange({target:{value:'Bicycle'}});
assert.equal(app.state.preferences.transport,'Bicycle');assert(label(app.profileOverview()).includes('Bicycle'));
app.tab('settings');assert(label(app.extraScreen()).includes('Delivery work preferences'));
app.switchRole('sender');app.tab('settings');assert(!label(app.extraScreen()).includes('Delivery work preferences'));
assert.equal(app.state.preferences.transport,'Bicycle');
// Analytics periods and separate delivery conversations.
for(const days of [1,7,30]){app.state.analyticsPeriod=days;const data=app.deliveryAnalytics();assert.equal(data.values.length,days);assert.equal(data.total,data.values.reduce((a,b)=>a+b,0));}
app.switchRole('deliverer');app.state.delivererOrders=app.delivererOrders.map((o,i)=>i===0?{...o,status:'Pickup'}:o);app.openDeliveryContact('sender','dChat');app.sendDeliveryMessage('I have arrived');
app.openDeliveryContact('sender','dChat');app.sendDeliveryMessage('On my way');
assert.equal(app.state.deliveryThreads['MT-4821:sender'][0].text,'I have arrived');assert.equal(app.state.deliveryThreads['MT-4821:sender'][1].text,'On my way');
app.sendDeliveryMessage('   ');assert.equal(app.state.deliveryThreads['MT-4821:sender'].length,2);
for(const route of ['dAnalytics','dContacts','dChat','dCall']){app.tab(route);assert(app.extraScreen());}
app.openDeliveryContact('recipient','dCall');
nodes(app.extraScreen(),'button').find(n=>label(n)==='Start demo call').props.onClick();assert.equal(app.state.callConnected,true);
nodes(app.extraScreen(),'button').find(n=>label(n)==='Mute').props.onClick();assert.equal(app.state.callMuted,true);
nodes(app.extraScreen(),'button').find(n=>label(n)==='End call').props.onClick();assert.equal(app.state.callConnected,false);
app.state.dStage=1;app.renderVals().goChat();assert.equal(app.cur,'dChat');assert.equal(app.state.deliveryContact,'sender');
// Orders retain their own progress and customer conversations.
app.state.delivererOrders=app.delivererOrders.map((o,i)=>({...o,status:i===1?'Pickup':'Available'}));app.state.selectedDeliveryId='MT-4822';app.openDeliveryContact('sender','dChat');assert(!app.state.deliveryThreads['MT-4822:sender']);app.sendDeliveryMessage('Second order');
assert.equal(app.state.deliveryThreads['MT-4821:sender'][0].text,'I have arrived');
for(const status of ['In transit','Completed']){if(status==='Completed')app.state.proofs={[app.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};app.advanceDelivery();assert.equal(app.selectedDelivery.status,status);}
app.advanceDelivery();assert.equal(app.selectedDelivery.status,'Completed');assert.equal(app.delivererOrders[0].status,'Available');
for(const route of ['dOrders','dOrderDetail']){app.tab(route);assert(app.extraScreen());}
app.tab('dOrders');app.state.deliveryFilter='Completed';assert(label(app.extraScreen()).includes('Legal Documents'));assert(!label(app.extraScreen()).includes('Birthday Gift'));
app.state.deliverySearch='no match';assert(label(app.extraScreen()).includes('No orders match'));
assert.equal(app.renderVals().tabs.map(t=>t.label).join(','),'Deliveries,My work,Analytics,Messages,Profile');
// Accepted jobs remain accessible from Jobs and receive a sample inbox message.
const flow=new Component();flow.switchRole('deliverer');flow.openDelivery('MT-4821');if(flow.selectedDelivery.status==='In transit')flow.state.proofs={[flow.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};flow.advanceDelivery();
assert.equal(flow.selectedDelivery.status,'Pickup');assert.equal(flow.renderVals().jobs.length,3);
assert(label(flow.activeDeliveryPanel()).includes('Open delivery'));assert(label(flow.activeDeliveryPanel()).includes('Ikeja City Mall'));
assert.equal(flow.deliveryInbox()[0].unread,true);
flow.openDeliveryContact('sender','dChat');assert.equal(flow.deliveryInbox()[0].unread,false);
if(flow.selectedDelivery.status==='In transit')flow.state.proofs={[flow.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};flow.advanceDelivery();assert(label(flow.activeDeliveryPanel()).includes('Lekki Phase 1'));if(flow.selectedDelivery.status==='In transit')flow.state.proofs={[flow.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};flow.advanceDelivery();
flow.tab('dContacts');assert(label(flow.extraScreen()).includes('The parcel is ready'));
assert(!nodes(flow.extraScreen(),'button').some(n=>['Pending','All','View orders'].includes(label(n))));
assert(!label(flow.activeDeliveryPanel()).includes('Birthday Gift'));
app.tab('dOrderDetail');assert.equal(nodes(app.extraScreen(),'button').filter(n=>label(n).trim()==='Chat').length,0);assert(!label(app.extraScreen()).includes('Bola'));
// Guided stages resume at the correct screen.
const guided=new Component();guided.switchRole('deliverer');guided.openDelivery('MT-4821');if(guided.selectedDelivery.status==='In transit')guided.state.proofs={[guided.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};guided.nextDeliveryStep();assert.equal(guided.cur,'dPickup');
guided.tab('dHome');guided.openDelivery('MT-4821');assert.equal(guided.cur,'dPickup');if(guided.selectedDelivery.status==='In transit')guided.state.proofs={[guided.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};guided.nextDeliveryStep();assert.equal(guided.cur,'dDropoff');if(guided.selectedDelivery.status==='In transit')guided.state.proofs={[guided.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};guided.nextDeliveryStep();assert.equal(guided.cur,'dDone');
// Ads publish into the sender marketplace and retain the offered price.
guided.editP2pAd();guided.state.adDraft.price=-1;guided.previewP2pAd();assert(guided.state.adError);guided.state.adDraft.price=2700;guided.previewP2pAd();assert.equal(guided.cur,'p2pPreview');guided.publishP2pAd();assert.equal(guided.state.p2pAds[0].status,'Live');
guided.switchRole('sender');guided.tab('p2pBrowse');nodes(guided.extraScreen(),'button').find(n=>label(n)==='Choose this offer').props.onClick();assert.equal(guided.cur,'send');assert.equal(guided.state.sel.priceNum,2700);
guided.state.form.recipientPhone='08012345678';guided.renderVals().sendConfirm();assert.equal(guided.cur,'expressPayment');assert.equal(guided.state.checkout.total,3200);
for(const route of ['dPickup','dDropoff','dDone','p2pAds','p2pEdit','p2pPreview','p2pBrowse']){guided.tab(route);assert(guided.extraScreen());}
// Search, filters, loading and Express fallback.
const matching=new Component();matching.tab('pickDeliverer');assert.equal(matching.renderVals().pickCount,4);
matching.state.pickQuery='Daniel';assert.equal(matching.renderVals().pickCount,1);
matching.state.pickQuery='';matching.state.matchFilters={maxPrice:100};assert.equal(matching.renderVals().pickCount,0);assert(label(matching.renderVals().matchingControls).includes('Continue with Express'));
matching.state.matchFilters={};matching.state.previewNoPeers=true;assert(label(matching.renderVals().matchingControls).includes('No P2P available here'));
matching.state.previewNoPeers=false;matching.startMatching();assert.equal(matching.state.matching,true);assert.equal(matching.renderVals().deliverers.length,0);
matching.state.form={pickup:'Ikeja',dropoff:'Lekki'};matching.useExpressFallback();assert.equal(matching.state.sendMode,'express');assert.equal(matching.cur,'send');assert.equal(matching.state.form.dropoff,'Lekki');assert.equal(matching.state.matching,false);
// Multiple ads retain distinct IDs and a working dashboard return path.
const ads=new Component();ads.switchRole('deliverer');assert(ads.roleTransitionView());
for(let i=0;i<2;i++){ads.editP2pAd();ads.publishP2pAd();}
assert.equal(ads.state.p2pAds.length,2);assert.notEqual(ads.state.p2pAds[0].id,ads.state.p2pAds[1].id);
assert(nodes(ads.extraScreen(),'button').some(n=>n.props['aria-label']==='Create a new ad'));ads.back();assert.equal(ads.cur,'dHome');
ads.tab('p2pAds');ads.back();assert.equal(ads.cur,'dHome');ads.switchRole('sender');assert.equal(ads.roleTransitionView(),null);
matching.state.previewNoPeers=false;matching.state.form={pickup:'Wuse 2, Abuja',dropoff:'Garki, Abuja'};
assert.equal(matching.renderVals().pickCount,0);assert(label(matching.renderVals().matchingControls).includes('Wuse 2, Abuja'));
matching.useExpressFallback();assert.equal(matching.state.form.pickup,'Wuse 2, Abuja');assert.equal(matching.state.form.dropoff,'Garki, Abuja');
matching.state.form.pickup='Ikeja City Mall';assert.equal(matching.renderVals().pickCount,2);
matching.state.matchFiltersOpen=true;matching.state.matchDraft={maxPrice:3000};assert.equal(matching.renderVals().pickCount,2);
assert(nodes(matching.renderVals().matchingControls,'section').some(n=>n.props.role==='dialog'));
// Blocking prevents contact and hides available jobs without removing history.
const safety=new Component();safety.switchRole('deliverer');safety.openSafety('Adeola J.','MT-4821');safety.saveReport();assert(safety.state.reportError);
safety.state.reportReason='Unsafe behavior';safety.saveReport();assert.equal(safety.state.reports.length,1);
safety.blockPerson();assert(safety.isBlocked('Adeola J.'));assert.equal(safety.renderVals().jobs.length,3);assert.equal(safety.delivererOrders.length,5);
safety.openDeliveryContact('sender','dChat');assert.equal(safety.cur,'safetyActions');safety.sendDeliveryMessage('blocked');assert(!safety.state.deliveryThreads?.['MT-4821:sender']);
safety.tab('blockedPeople');nodes(safety.extraScreen(),'button').find(n=>label(n)==='Unblock').props.onClick();assert(!safety.isBlocked('Adeola J.'));
// New bookings open their own tracking and share URLs.
app.state.bookings=[{id:'MT-9000',parcel:'Documents',pickup:'Ikeja',dropoff:'Lekki',status:'Awaiting courier',total:2500}];
app.openTracking('MT-9000');assert.equal(app.cur,'orderTracking');assert.equal(app.trackedOrder.dropoff,'Lekki');assert(app.trackingLink().includes('#track=MT-9000&status=Awaiting%20courier'));
app.tab('orders');const tracked=app.renderVals().allOrders.find(o=>o.id==='MT-9000');tracked.onShare();assert.equal(app.cur,'share');assert(label(app.extraScreen()).includes('Copy link'));
// Ads post for free, support edits and pay only after acceptance.
const request=new Component();const initialBalance=request.state.balance;
request.startSenderRequest();request.reviewSenderRequest();request.postSenderRequest();const requestId=request.state.bookings[0].id;
assert.equal(request.state.balance,initialBalance);assert(!request.state.transactions);assert.equal(request.state.bookings[0].funded,false);
request.startSenderRequest(request.state.bookings[0]);request.state.requestDraft.price=3100;request.postSenderRequest();assert.equal(request.state.bookings.length,1);assert.equal(request.delivererOrders.find(o=>o.id===requestId).amount,3100);
request.manageSenderAd(requestId,'toggle');assert.equal(request.state.bookings[0].status,'Paused');request.manageSenderAd(requestId,'toggle');
request.switchRole('deliverer');request.openDelivery(requestId);if(request.selectedDelivery.status==='In transit')request.state.proofs={[request.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};request.nextDeliveryStep();assert.equal(request.selectedDelivery.status,'Awaiting payment');if(request.selectedDelivery.status==='In transit')request.state.proofs={[request.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};request.advanceDelivery();assert.equal(request.selectedDelivery.status,'Awaiting payment');
request.switchRole('sender');request.fundSenderRequest(requestId);request.beginPayment();assert.equal(request.state.balance,initialBalance-3600);assert.equal(request.state.bookings.length,1);assert.equal(request.state.transactions.length,1);request.payExpress();assert.equal(request.state.transactions.length,1);
request.switchRole('deliverer');request.openDelivery(requestId);assert.equal(request.cur,'dPickup');if(request.selectedDelivery.status==='In transit')request.state.proofs={[request.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};request.nextDeliveryStep();if(request.selectedDelivery.status==='In transit')request.state.proofs={[request.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};request.nextDeliveryStep();assert.equal(request.state.bookings[0].status,'Delivered');
request.switchRole('sender');request.startSenderRequest();request.postSenderRequest();const deleteId=request.state.bookings[0].id;assert.equal(request.state.bookings.length,2);request.manageSenderAd(deleteId,'delete');assert.equal(request.state.bookings.length,1);assert(!request.delivererOrders.some(o=>o.id===deleteId));
const orderTabs=new Component();
for(const filter of ['Active','Delivered','Cancelled']){orderTabs.state.senderOrderSection=filter==='Active'?'current':'history';orderTabs.state.senderOrderFilter=filter;const rows=orderTabs.renderVals().visibleSenderOrders;assert(rows.length>0);assert(rows.every(o=>filter==='Active'?!['Delivered','Cancelled'].includes(o.statusLabel):o.statusLabel===filter));rows[0].onOpen();assert.equal(orderTabs.cur,'senderOrderDetail');assert(label(orderTabs.extraScreen()).includes('Share order link'));}
const recent=new Component();recent.state.bookings=[{id:'MT-NEW',total:3000,parcel:'Latest parcel',status:'Awaiting courier'},{id:'MT-OLD',total:2000,parcel:'Old parcel',status:'Delivered'}];assert.equal(recent.renderVals().recentOrderTitle,'Latest parcel');recent.renderVals().trackRecentOrder();assert.equal(recent.state.trackId,'MT-NEW');assert.equal(recent.cur,'orderTracking');
console.log(`PASS: ${new Set([...routes,...extra]).size} routes render; navigation, booking, chat, profile, payment, balance and validation checks pass.`);




// Wallet previews and history use the same records; filters preserve role/order scope.
const historyApp=new Component();
historyApp.state.role='sender';
historyApp.state.transactions=[
 {id:'TX-1',title:'Wallet top-up',amount:5000,direction:'credit',role:'sender',status:'Completed',timestamp:new Date(2026,8,1,12).getTime(),date:'Sep 1'},
 {id:'TX-2',title:'Delivery payment',amount:2500,direction:'debit',orderId:'MT-TEST',role:'sender',status:'Completed',timestamp:new Date(2026,8,5,12).getTime(),date:'Sep 5'},
 {id:'TX-3',title:'Withdrawal',amount:1000,direction:'debit',role:'sender',status:'Completed',timestamp:new Date(2026,8,8,12).getTime(),date:'Sep 8'},
 {id:'TX-4',title:'Wallet top-up',amount:2000,direction:'credit',role:'sender',status:'Completed',timestamp:new Date(2026,8,9,12).getTime(),date:'Sep 9'},
 {id:'TX-5',title:'Delivery earnings',amount:9000,direction:'credit',role:'deliverer',status:'Completed',timestamp:new Date(2026,8,10,12).getTime(),date:'Sep 10'}
];
assert.equal(historyApp.transactionRecords().length,4);
assert.equal(historyApp.renderVals().walletTx.length,3);
assert.equal(historyApp.renderVals().walletTx[0].title,'Wallet top-up');
historyApp.state.transactionFilters={direction:'debit',from:'2026-09-01',to:'2026-09-06'};
assert.equal(historyApp.filteredTransactions().length,1);
assert.equal(historyApp.filteredTransactions()[0].id,'TX-2');
historyApp.state.transactionFilters={query:'mt-test',status:'Completed',type:'Delivery payment'};
assert.equal(historyApp.filteredTransactions()[0].id,'TX-2');
historyApp.state.transactionFilters={sort:'highest'};
assert.equal(historyApp.filteredTransactions()[0].amount,5000);
historyApp.state.transactionOrder='MT-TEST';
assert.equal(historyApp.filteredTransactions().length,1);
historyApp.state.transactionOrder=null;historyApp.state.transactionFilters={query:'missing'};
assert.equal(historyApp.filteredTransactions().length,0);
assert(!historyApp.renderVals().menu.some(m=>/Transaction (records|history)/.test(m.label)));
console.log('PASS: recent transactions, history filters, sorting and profile navigation.');

const serviceApp=new Component();
serviceApp.state.stack=['errand'];
serviceApp.serviceNext('errand');assert(serviceApp.state.serviceError);
for(const [k,v] of Object.entries({instructions:'Buy bread and milk',budget:'5000'}))serviceApp.updateServiceDraft('errand',k,v);
serviceApp.serviceNext('errand');assert.equal(serviceApp.state.serviceSteps.errand,1);
serviceApp.serviceNext('errand');assert.equal(serviceApp.state.serviceSteps.errand,1);
for(const [k,v] of Object.entries({pickup:'Ikeja shop',dropoff:'Yaba home',phone:'08012345678'}))serviceApp.updateServiceDraft('errand',k,v);
serviceApp.serviceNext('errand');assert.equal(serviceApp.state.serviceSteps.errand,2);
serviceApp.serviceNext('errand');assert.equal(serviceApp.state.serviceSteps.errand,3);
serviceApp.serviceCheckout('errand');assert.equal(serviceApp.cur,'expressPayment');assert.equal(serviceApp.state.checkout.total,3000);assert.equal(serviceApp.state.checkout.serviceDetails.budget,'5000');
serviceApp.state.balance=10000;serviceApp.payExpress();assert.equal(serviceApp.state.balance,7000);assert.equal(serviceApp.state.bookings[0].description,'Buy bread and milk');
serviceApp.state.stack=['move'];
for(const [k,v] of Object.entries({instructions:'Sofa and six boxes',vehicle:'Small truck',helpers:'2',pickup:'Lekki',dropoff:'Ikeja',phone:'08012345678',pickupAccess:'Upstairs, stairs only'}))serviceApp.updateServiceDraft('move',k,v);
serviceApp.serviceNext('move');serviceApp.serviceNext('move');assert.equal(serviceApp.state.serviceSteps.move,2);
serviceApp.updateServiceDraft('move','date','2000-01-01');serviceApp.updateServiceDraft('move','time','12:00');serviceApp.serviceNext('move');assert.equal(serviceApp.state.serviceSteps.move,2);
serviceApp.updateServiceDraft('move','date','2099-01-01');serviceApp.serviceNext('move');assert.equal(serviceApp.state.serviceSteps.move,3);
serviceApp.serviceCheckout('move');assert.equal(serviceApp.state.checkout.total,26500);assert.equal(serviceApp.state.checkout.serviceDetails.pickupAccess,'Upstairs, stairs only');assert.equal(serviceApp.state.checkout.schedule,'2099-01-01 / 12:00');
assert.equal(serviceApp.serviceDraft('errand').instructions,'Buy bread and milk');
console.log('PASS: errand and move validation, scheduling, separate drafts, quotes and checkout.');

const peopleApp=new Component();peopleApp.state.role='deliverer';
assert.equal(peopleApp.pastCustomers().length,0);
peopleApp.state.selectedDeliveryId=peopleApp.delivererOrders[0].id;
if(peopleApp.selectedDelivery.status==='In transit')peopleApp.state.proofs={[peopleApp.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};peopleApp.advanceDelivery();if(peopleApp.selectedDelivery.status==='In transit')peopleApp.state.proofs={[peopleApp.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};peopleApp.advanceDelivery();if(peopleApp.selectedDelivery.status==='In transit')peopleApp.state.proofs={[peopleApp.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};peopleApp.advanceDelivery();
assert.equal(peopleApp.pastCustomers().length,1);
assert(peopleApp.pastCustomers()[0].lastCompleted>0);
const finished=peopleApp.delivererOrders.find(o=>o.status==='Completed');
peopleApp.state.delivererOrders=[...peopleApp.delivererOrders,{...finished,id:'REPEAT-1',completedAt:Date.now()+1}];
assert.equal(peopleApp.pastCustomers().length,1);assert.equal(peopleApp.pastCustomers()[0].orders.length,2);
peopleApp.state.pastCustomerKey=peopleApp.pastCustomers()[0].key;peopleApp.state.stack=['dCustomerHistory'];
assert(label(peopleApp.extraScreen()).includes('REPEAT-1'));
peopleApp.state.stack=['profile'];assert(peopleApp.renderVals().menu.some(m=>m.label==='My performance'));assert(peopleApp.renderVals().menu.some(m=>m.label==='Past customers'));
console.log('PASS: performance navigation and completed customer history.');

const workApp=new Component();workApp.state.role='deliverer';workApp.openDelivery('MT-4821');
assert(!nodes(workApp.extraScreen(),'button').some(n=>['Chat','Call'].includes(label(n))));
workApp.openDeliveryContact('sender','dChat');assert.equal(workApp.cur,'dOrderDetail');
workApp.sendDeliveryMessage('Blocked before acceptance');assert(!workApp.state.deliveryThreads?.['MT-4821:sender']);
workApp.acceptDeliveryOffer();assert.equal(workApp.cur,'dPickup');assert.equal(workApp.selectedDelivery.status,'Pickup');
assert.equal(workApp.renderVals().jobs.length,3);assert(label(workApp.activeDeliveryPanel()).includes('Birthday Gift'));
workApp.openDeliveryContact('sender','dChat');assert.equal(workApp.cur,'dChat');
workApp.sendDeliveryMessage('Accepted and on my way');assert.equal(workApp.deliveryInbox()[0].last.text,'Accepted and on my way');
console.log('PASS: acceptance opens pickup, unlocks contact and retains the order in My work.');

if(workApp.selectedDelivery.status==='In transit')workApp.state.proofs={[workApp.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};workApp.advanceDelivery();if(workApp.selectedDelivery.status==='In transit')workApp.state.proofs={[workApp.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};workApp.advanceDelivery();assert.equal(workApp.selectedDelivery.status,'Completed');
assert(workApp.pendingSenderConfirmation(workApp.selectedDelivery));
assert(!workApp.state.transactions?.some(t=>t.title==='Delivery earnings'));
workApp.tab('dDone');assert(label(workApp.extraScreen()).includes('Your payment will be released once the sender confirms'));
assert(nodes(workApp.extraScreen(),'button').some(n=>label(n).trim()==='Message sender'));
assert(nodes(workApp.extraScreen(),'button').some(n=>label(n).trim()==='Call sender'));
workApp.openDeliveryContact('sender','dCall');assert.equal(workApp.cur,'dCall');
workApp.openDeliveryContact('sender','dChat');workApp.sendDeliveryMessage('Please confirm receipt');assert.equal(workApp.state.deliveryThreads['MT-4821:sender'].at(-1).text,'Please confirm receipt');
const beforeRelease=workApp.state.balance;
workApp.confirmSenderDelivery('MT-4821');assert.equal(workApp.state.balance,beforeRelease,'Only sender may release');
workApp.creditDelivery(workApp.selectedDelivery);assert.equal(workApp.state.balance,beforeRelease,'P2P credit requires release');
workApp.switchRole('sender');workApp.tab('activity');assert(label(workApp.renderVals().senderActivity).includes('Confirm delivery'));
workApp.openSenderConfirmation('MT-4821');assert(label(workApp.extraScreen()).includes('Confirm delivery & release payment'));
workApp.confirmSenderDelivery('MT-4821');assert.equal(workApp.state.balance,beforeRelease+4500);assert(workApp.state.bookings.find(b=>b.id==='MT-4821').paymentReleased);
workApp.confirmSenderDelivery('MT-4821');assert.equal(workApp.state.balance,beforeRelease+4500);assert.equal(workApp.state.transactions.filter(t=>t.title==='Delivery earnings').length,1);
workApp.switchRole('deliverer');workApp.openDelivery('MT-4821');assert(label(workApp.extraScreen()).includes('Payment released'));
const closedCount=workApp.state.deliveryThreads['MT-4821:sender'].length;
workApp.openDeliveryContact('sender','dChat');assert.equal(workApp.cur,'dChat');
assert(label(workApp.extraScreen()).includes('This conversation is closed'));
assert.equal(nodes(workApp.extraScreen(),'textarea').length,0);
workApp.sendDeliveryMessage('Cannot send');assert.equal(workApp.state.deliveryThreads['MT-4821:sender'].length,closedCount);
workApp.openDeliveryContact('sender','dCall');assert.equal(workApp.cur,'dChat');
workApp.tab('dCall');assert(!nodes(workApp.extraScreen(),'button').some(n=>label(n)==='Start demo call'));
assert(workApp.deliveryInbox().some(t=>t.order.id==='MT-4821'));
console.log('PASS: completed conversations stay readable while messaging and calls are closed.');

const awaitingApp=new Component();awaitingApp.state.role='deliverer';awaitingApp.state.delivererOrders=[{...awaitingApp.delivererOrders[0],request:true}];awaitingApp.openDelivery('MT-4821');awaitingApp.acceptDeliveryOffer();
assert.equal(awaitingApp.cur,'dOrderDetail');assert.equal(awaitingApp.selectedDelivery.status,'Awaiting payment');
assert(label(awaitingApp.extraScreen()).includes('Pickup starts after the sender completes payment'));
assert(!nodes(awaitingApp.extraScreen(),'button').some(n=>label(n)==='Go to My work'));

const pickupChoice=new Component();pickupChoice.switchRole('deliverer');pickupChoice.openDelivery('MT-4821');pickupChoice.acceptDeliveryOffer();
assert.match(JSON.stringify(pickupChoice.extraScreen()),/Go to pickup/);
assert.match(JSON.stringify(pickupChoice.extraScreen()),/Reject order/);
pickupChoice.startPickup();assert.equal(pickupChoice.selectedDelivery.pickupStarted,true);
assert.match(JSON.stringify(pickupChoice.extraScreen()),/Item collected/);
assert(!nodes(pickupChoice.extraScreen(),'button').some(n=>label(n)==='Reject order'));
pickupChoice.tab('dHome');pickupChoice.openDelivery('MT-4821');assert.equal(pickupChoice.selectedDelivery.pickupStarted,true);
pickupChoice.rejectDelivery();assert.equal(pickupChoice.selectedDelivery.status,'Pickup');assert.equal(pickupChoice.selectedDelivery.pickupStarted,true);
pickupChoice.state.delivererOrders=pickupChoice.delivererOrders.map(o=>o.id===pickupChoice.selectedDelivery.id?{...o,pickupStarted:false}:o);pickupChoice.rejectDelivery();assert.equal(pickupChoice.selectedDelivery.status,'Available');
pickupChoice.openDelivery('MT-4821');pickupChoice.acceptDeliveryOffer();assert.match(JSON.stringify(pickupChoice.extraScreen()),/Go to pickup/);
pickupChoice.startPickup();pickupChoice.nextDeliveryStep();pickupChoice.rejectDelivery();assert.equal(pickupChoice.selectedDelivery.status,'In transit');
const paidReassignment=new Component();paidReassignment.state.delivererOrders=[{...paidReassignment.delivererOrders[0],request:true,status:'Pickup'}];paidReassignment.state.bookings=[{id:'MT-4821',funded:true,status:'Picking up'}];
paidReassignment.rejectDelivery();assert.equal(paidReassignment.state.bookings[0].status,'Awaiting courier');assert.equal(paidReassignment.state.bookings[0].funded,true);paidReassignment.acceptDeliveryOffer();assert.equal(paidReassignment.selectedDelivery.status,'Pickup');
console.log('PASS: pickup choice, resume, rejection, collection guard and funded reassignment.');

const expressComplete=new Component();expressComplete.switchRole('deliverer');expressComplete.openDelivery('MT-4822');const expressBalance=expressComplete.state.balance;expressComplete.acceptDeliveryOffer();expressComplete.startPickup();if(expressComplete.selectedDelivery.status==='In transit')expressComplete.state.proofs={[expressComplete.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};expressComplete.nextDeliveryStep();if(expressComplete.selectedDelivery.status==='In transit')expressComplete.state.proofs={[expressComplete.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};expressComplete.nextDeliveryStep();
assert.equal(expressComplete.cur,'dDone');assert.equal(expressComplete.state.balance,expressBalance+2800);assert.equal(expressComplete.selectedDelivery.payoutStatus,'Paid');assert(label(expressComplete.extraScreen()).includes('Your payment will be added to your balance.'));assert(!label(expressComplete.extraScreen()).includes('Awaiting sender confirmation'));if(expressComplete.selectedDelivery.status==='In transit')expressComplete.state.proofs={[expressComplete.selectedDelivery.id]:{recipient:'Recipient',method:'Recipient code'}};expressComplete.nextDeliveryStep();assert.equal(expressComplete.state.balance,expressBalance+2800);
const senderActivity=new Component();senderActivity.tab('activity');assert(label(senderActivity.renderVals().senderActivity).includes('Your next delivery starts here'));senderActivity.state.bookings=[{id:'ACTION',parcel:'Books',pickup:'Ikeja',dropoff:'Lekki',price:1500,total:2000,status:'Awaiting payment',p2pRequest:true}];
let activityTree=senderActivity.renderVals().senderActivity;nodes(activityTree,'button').find(n=>label(n)==='Pay accepted offer').props.onClick();assert.equal(senderActivity.cur,'expressPayment');assert.equal(senderActivity.state.checkout.requestId,'ACTION');
senderActivity.recordTransaction('Wallet top-up',1000,'credit','','sender');senderActivity.state.activityFilter='Payments';assert(label(senderActivity.senderActivityScreen()).includes('Wallet top-up'));senderActivity.state.activityFilter='Deliveries';assert(!label(senderActivity.senderActivityScreen()).includes('Wallet top-up'));assert(label(senderActivity.senderActivityScreen()).includes('Books'));
console.log('PASS: pending P2P payment, sender release once, completed contact, Express balance credit, pickup actions and actionable sender Activity.');

const conversationPreview=new Component();conversationPreview.switchRole('deliverer');conversationPreview.tab('dContacts');assert(label(conversationPreview.extraScreen()).includes('Tobi A.'));assert(label(conversationPreview.extraScreen()).includes('Please call when you reach the gate'));
const ongoingThread=conversationPreview.deliveryInbox().find(t=>t.order.id==='MT-4819');assert.equal(ongoingThread.order.status,'In transit');assert(ongoingThread.unread);conversationPreview.state.selectedDeliveryId='MT-4819';conversationPreview.openDeliveryContact('sender','dChat');assert.equal(nodes(conversationPreview.extraScreen(),'textarea').length,1);assert(!conversationPreview.deliveryInbox().find(t=>t.order.id==='MT-4819').unread);conversationPreview.sendDeliveryMessage('I am at the gate now.');assert.equal(conversationPreview.state.deliveryThreads['MT-4819:sender'].length,7);assert.equal(conversationPreview.state.deliveryThreads['MT-4819:sender'].at(-1).text,'I am at the gate now.');
console.log('PASS: ongoing conversation appears in Messages, marks read and supports replies.');
// Delivery evidence gates completion and supports a recoverable validation error.
const evidence=new Component();evidence.switchRole('deliverer');evidence.openDelivery('MT-4819');const evidenceBalance=evidence.state.balance;
evidence.nextDeliveryStep();assert.equal(evidence.cur,'deliveryProof');assert.equal(evidence.selectedDelivery.status,'In transit');
evidence.state.proofName='Amaka';evidence.state.proofCode='0000';evidence.saveProof();assert(evidence.state.proofError);assert.equal(evidence.state.balance,evidenceBalance);
evidence.state.proofCode=evidence.deliveryCode('MT-4819');evidence.saveProof();assert.equal(evidence.cur,'dDone');assert.equal(evidence.selectedDelivery.status,'Completed');assert.equal(evidence.state.balance,evidenceBalance+3000);assert(label(evidence.extraScreen()).includes('Received by Amaka'));
evidence.saveProof();assert.equal(evidence.state.balance,evidenceBalance+3000);
// An unresolved issue blocks completion; an agreed return never pays as a delivery.
const problem=new Component();problem.switchRole('deliverer');problem.openDelivery('MT-4819');problem.openDeliveryIssue('MT-4819');problem.saveDeliveryIssue();assert(problem.state.issueError);
problem.state.issueNotes='Recipient is not answering the phone.';problem.saveDeliveryIssue();assert.equal(problem.cur,'deliveryIssueStatus');problem.state.proofName='Amaka';problem.state.proofCode='4819';problem.saveProof();assert.equal(problem.selectedDelivery.status,'In transit');assert.equal(problem.cur,'deliveryIssueStatus');
problem.updateDeliveryIssue('Returning to sender');problem.updateDeliveryIssue('Returned to sender');assert.equal(problem.selectedDelivery.status,'Returned');assert(!problem.state.transactions);problem.openDelivery('MT-4819');assert.equal(problem.cur,'deliveryIssueStatus');
// Reviews do not release funds; the sender must resolve reported delivery problems first.
const review=new Component();review.switchRole('deliverer');review.openDelivery('MT-4821');review.acceptDeliveryOffer();review.startPickup();review.nextDeliveryStep();review.state.proofName='Recipient';review.state.proofCode='4821';review.saveProof();const heldBalance=review.state.balance;
review.openPaymentReview('MT-4821');review.savePaymentReview();assert(review.state.reviewError);review.state.reviewNotes='Delivered this afternoon, waiting for confirmation.';review.savePaymentReview();assert.equal(review.state.paymentReviews['MT-4821'].status,'Awaiting review');assert.equal(review.state.balance,heldBalance);review.tab('dEarnings');assert(label(review.extraScreen()).includes('NGN 4,500'));
review.switchRole('sender');review.openDeliveryIssue('MT-4821');review.state.issueNotes='Checking with recipient.';review.saveDeliveryIssue();review.confirmSenderDelivery('MT-4821');assert.equal(review.state.balance,heldBalance);review.updateDeliveryIssue('Resolved');review.confirmSenderDelivery('MT-4821');assert.equal(review.state.balance,heldBalance+4500);assert.equal(review.state.paymentReviews['MT-4821'].status,'Resolved by sender confirmation');
// Offline messages retain text and retry in place without duplication.
const disconnected=new Component();disconnected.switchRole('deliverer');disconnected.openDelivery('MT-4819');disconnected.openDeliveryContact('sender','dChat');disconnected.state.networkOffline=true;disconnected.sendDeliveryMessage('At the main gate.');const thread='MT-4819:sender';assert(disconnected.state.deliveryThreads[thread][6].failed);assert(label(disconnected.extraScreen()).includes('Not sent'));disconnected.retryDeliveryMessage(thread,6);assert(disconnected.state.deliveryThreads[thread][6].failed);disconnected.state.networkOffline=false;disconnected.retryDeliveryMessage(thread,6);assert.equal(disconnected.state.deliveryThreads[thread].length,7);assert.equal(disconnected.state.deliveryThreads[thread][6].failed,false);
// Refresh starts a fresh UI session; previous browser data is never restored.
const freshPreview=new Component();assert.equal(freshPreview.cur,'splash');assert.equal(freshPreview.state.role,'sender');assert.equal(freshPreview.state.balance,42300);assert(!source.includes('localStorage'));
console.log('PASS: handover proof, failed delivery and returns, held payment review, message retry and fresh preview state.');
const customOffer=new Component();customOffer.tab('send');customOffer.updateOffer('1500');assert(customOffer.offerValidation().includes('2,000'));customOffer.renderVals().sendConfirm();assert.equal(customOffer.cur,'send');assert(label(customOffer.customOfferField()).includes('Increase your amount'));customOffer.updateOffer('');assert(customOffer.offerValidation());customOffer.updateOffer('2500.50');assert(customOffer.offerValidation().includes('whole naira'));customOffer.updateOffer('2750');assert.equal(customOffer.offerValidation(),'');assert.equal(customOffer.state.offer,2750);assert(customOffer.renderVals().sendCtaLabel.includes('2,750'));customOffer.renderVals().offerPresets[0].onTap();assert.equal(customOffer.state.customOffer,'2000');assert.equal(customOffer.offerValidation(),'');
console.log('PASS: custom offer input, live minimum feedback, whole-naira validation and preset synchronization.');
