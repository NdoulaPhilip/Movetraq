// Only the authenticated legacy server supplies the account and order identity.
class MobileMaps {
  constructor({origin, secret, request=fetch}) { this.origin=origin; this.secret=secret; this.request=request; }
  async command(user, command, input={}) {
    try {
      const url=new URL('/internal/mobile-maps',this.origin);
      if(url.protocol!=='https:'||url.username||url.password||!this.secret)throw Error();
      const response=await this.request(url,{method:'POST',headers:{Authorization:`Bearer ${this.secret}`,'Content-Type':'application/json'},
        body:JSON.stringify({userId:user.uid,command,input}),redirect:'error',signal:AbortSignal.timeout(20000)});
      const result=await response.json();
      if(!response.ok||!result.success)throw Object.assign(new Error(result.error?.message||'Live location service is unavailable.'),{status:response.status>=400&&response.status<500?response.status:503});
      if(!result.data||typeof result.data!=='object')throw Error();
      return result.data;
    } catch(error) { if(error.status)throw error;throw Object.assign(new Error('Live location service is unavailable. Please retry.'),{status:503}); }
  }
}
module.exports={MobileMaps};
