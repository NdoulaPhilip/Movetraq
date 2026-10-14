/* UI-only map preview: no map, geocoding or device-location network requests. */
(() => {
  let Preview;
  function view(props){
    const R=window.React,h=R.createElement;
    if(!Preview)Preview=class extends R.Component{
      constructor(p){super(p);this.state={zoom:1};}
      center(){if(!this.origin){const p=(this.props.points||[]).find(p=>Number.isFinite(p.lat)&&Number.isFinite(p.lng));this.origin=p?{lat:p.lat,lng:p.lng}:{lat:6.447,lng:3.465};}return this.origin;}
      pick(e){if(!this.props.onPick)return;const b=e.currentTarget.getBoundingClientRect(),c=this.center();this.props.onPick({lat:c.lat+(0.5-(e.clientY-b.top)/b.height)*.08/this.state.zoom,lng:c.lng+((e.clientX-b.left)/b.width-.5)*.1/this.state.zoom});}
      render(){
        const center=this.center(),z=this.state.zoom,points=(this.props.points||[]).filter(p=>Number.isFinite(p.lat)&&Number.isFinite(p.lng));
        const roads=['M-20 72 140 88 260 55 440 70','M-20 165 110 150 245 170 440 150','M-20 258 130 246 270 265 440 240','M65 -10 92 95 76 185 100 320','M190 -10 172 102 194 180 174 330','M310 -10 292 94 320 182 294 330'];
        return h('div',{style:{position:'relative',width:'100%',height:'100%',background:'#edf0e7',overflow:'hidden',isolation:'isolate'}},
          h('svg',{viewBox:`${210-210/z} ${160-160/z} ${420/z} ${320/z}`,preserveAspectRatio:'none',role:'img','aria-label':this.props.label||'Illustrative map preview',tabIndex:this.props.onPick?0:undefined,onClick:e=>this.pick(e),onKeyDown:e=>{if(e.key==='Enter'&&this.props.onPick){e.preventDefault();this.props.onPick({lat:center.lat,lng:center.lng});}},style:{display:'block',width:'100%',height:'100%',cursor:this.props.onPick?'crosshair':'default'}},
            h('rect',{width:420,height:320,fill:'#eff1e9'}),h('path',{d:'M340 0C310 45 373 95 336 156S350 249 301 320H420V0Z',fill:'#cde6eb'}),
            ...[[12,8,48,43],[108,103,53,33],[210,85,54,61],[20,192,45,43],[208,202,61,38],[109,268,47,40]].map(([x,y,width,height],i)=>h('rect',{key:i,x,y,width,height,rx:9,fill:i%2?'#e1e8d6':'#e6e8e0'})),
            ...roads.map((d,i)=>h('path',{key:'road'+i,d,stroke:'#fff',strokeWidth:10,fill:'none'})),
            h('path',{d:'M-10 310 118 186 228 117 346 15',stroke:'#ded8b8',strokeWidth:17,fill:'none'}),h('path',{d:'M-10 310 118 186 228 117 346 15',stroke:'#fff8d8',strokeWidth:11,fill:'none'}),
            ...[[25,57,'RESIDENTIAL AREA'],[216,190,'CENTRAL DISTRICT'],[17,287,'ADMIRALTY WAY'],[349,220,'LAGOON']].map(([x,y,t])=>h('text',{key:t,x,y,fill:'#9aa58f',fontSize:8,fontFamily:'Inter, sans-serif',letterSpacing:1},t)),
            ...points.map((p,i)=>{const x=Math.max(20,Math.min(400,210+(p.lng-center.lng)*4200)),y=Math.max(25,Math.min(295,160-(p.lat-center.lat)*4000));return h('g',{key:i},h('circle',{cx:x,cy:y,r:22,fill:i?'#cbf24a':'#101319',opacity:.12}),h('path',{d:'M0-18a13 13 0 0 1 13 13c0 11-13 23-13 23S-13 6-13-5A13 13 0 0 1 0-18Z',transform:`translate(${x} ${y})`,fill:i?'#a9cd33':'#101319',stroke:'#fff',strokeWidth:2}),h('circle',{cx:x,cy:y-5,r:4,fill:'#fff'}));})),
          this.props.interactive?h('div',{style:{position:'absolute',top:12,left:12,display:'flex',flexDirection:'column',gap:3}},...['+','−'].map((label,i)=>h('button',{key:label,type:'button','aria-label':i?'Zoom out':'Zoom in',onClick:()=>this.setState(s=>({zoom:Math.max(.5,Math.min(4,s.zoom+(i?-.5:.5)))})),style:{border:'1px solid #e4e8dc',background:'white',borderRadius:9,width:32,height:32,cursor:'pointer',fontSize:20}},label))):null,
          h('span',{style:{position:'absolute',right:9,top:10,background:'rgba(255,255,255,.9)',padding:'5px 8px',borderRadius:8,font:'10px Inter,system-ui',color:'#75816b',pointerEvents:'none'}},this.props.onPick?'Tap to drop your pin':'Pickup & destination'),
          h('span',{style:{position:'absolute',right:8,bottom:7,font:'9px Inter,system-ui',color:'#87917f',background:'rgba(255,255,255,.85)',padding:'3px 5px',borderRadius:4}},'Illustrative map · UI preview'));
      }
    };
    return h(Preview,props);
  }
  window.MovetraqMaps={view};
})();
