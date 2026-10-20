class DelivererAccess {
  constructor({origin,secret,request=fetch}){this.origin=origin;this.secret=secret;this.request=request;}
  async command(user,command,input={}){
    try {
      const url=new URL('/internal/mobile-deliverer',this.origin);
      if(url.protocol!=='https:'||url.username||url.password||!this.secret)throw Error();
      const response=await this.request(url,{method:'POST',headers:{Authorization:`Bearer ${this.secret}`,'Content-Type':'application/json'},
        body:JSON.stringify({userId:user.uid,command,input:command==='start'?{...input,accountEmail:user.email}:input}),redirect:'error',signal:AbortSignal.timeout(12000)});
      const result=await response.json();
      if(!response.ok||!result.success){const error=new Error(result.error?.message||'Delivery verification is unavailable.');error.status=response.status>=400&&response.status<500?response.status:503;throw error;}
      if(!result.data||typeof result.data!=='object'||(command==='status'&&typeof result.data.status!=='string'))throw Error();
      return result.data;
    } catch(error){if(error.status)throw error;throw Object.assign(new Error('Could not verify delivery approval. Sender access remains available.'),{status:503});}
  }
  async requireApproved(user){const state=await this.command(user,'status');if(state.status!=='approved'||state.canDeliver!==true)throw Object.assign(new Error('Administrator approval is required for delivery work.'),{status:403});return state;}
  async profile(user,currentState){
    let state;
    try{state=currentState||await this.command(user,'status');}catch{state={status:'unavailable',canDeliver:false};}
    user.canDeliver=state.status==='approved'&&state.canDeliver===true;
    user.delivererVerificationStatus=state.status;
    user.delivererApplicationId=state.id||null;
    user.verified=user.canDeliver;
    if(state.transportType)user.vehicleType=state.transportType;
    if(!user.canDeliver){user.activeRole='sender';user.delivererOnline=false;}
    return user;
  }
}
// Supabase notification IDs are stable so polling cannot duplicate decisions or reset read state.
function mergeVerificationNotifications(current, state) {
  const merged=current.map(item=>({...item}));
  for(const event of state.notifications||[]) {
    if(!/^[0-9a-f-]{36}$/i.test(event.id)||event.type!=='verification_update')continue;
    const id=`verification:${event.id}`;
    const previous=merged.find(item=>item.id===id);
    if(previous){previous.read=previous.read||!!event.read_at;continue;}
    merged.push({id,title:event.title,body:event.body,type:event.type,read:!!event.read_at,createdAt:event.created_at});
  }
  return merged;
}
module.exports={DelivererAccess,mergeVerificationNotifications};
