/* Opt-in device-location map for accepted deliveries. */
(()=>{
  let LiveMap;
  window.MovetraqDeliveryMap={view(props){
    const R=window.React,h=R.createElement;
    if(!LiveMap)LiveMap=class extends R.Component{
      constructor(p){super(p);this.state={tracking:false,point:null,error:'',loading:false,mapAttempt:0,mapUnavailable:false,offline:typeof navigator!=='undefined'&&navigator.onLine===false};this.run=0;}
      stop(){this.run++;if(this.watch!=null){navigator.geolocation.clearWatch(this.watch);this.watch=null;}}
      componentDidMount(){this.connection=()=>this.setState({offline:navigator.onLine===false});window.addEventListener('online',this.connection);window.addEventListener('offline',this.connection);}
      componentWillUnmount(){this.stop();if(this.connection){window.removeEventListener('online',this.connection);window.removeEventListener('offline',this.connection);}}
      start(){
        this.stop();
        if(!window.isSecureContext||!navigator.geolocation){this.setState({error:'Location requires HTTPS or localhost and a browser with location support.'});return;}
        const run=this.run;this.setState({tracking:true,loading:true,error:'',point:null});
        try{this.watch=navigator.geolocation.watchPosition(position=>{
          if(run!==this.run)return;
          const {latitude:lat,longitude:lng,accuracy}=position.coords;
          if(!Number.isFinite(lat)||!Number.isFinite(lng))return;
          const now=Date.now(),old=this.state.point;
          const refresh=!old||now-old.updated>=10000;
          this.setState({loading:false,error:'',point:refresh?{lat,lng,accuracy,updated:now}:old});
        },error=>{
          if(run!==this.run)return;
          this.stop();this.setState({tracking:false,loading:false,point:null,error:error.code===1?'Location permission was denied. Allow location in your browser settings, then try again.':error.code===3?'Location timed out. Check your signal and try again.':'Your location is unavailable. Try again outdoors or use navigation.'});
        },{enableHighAccuracy:true,timeout:15000,maximumAge:5000});}
        catch(e){this.stop();this.setState({tracking:false,loading:false,error:'Location could not start. Check your browser permissions and try again.'});}
      }
      render(){
        const p=this.state.point,destination=this.props.destination;
        const src=p?'https://www.openstreetmap.org/export/embed.html?bbox='+[p.lng-.008,p.lat-.006,p.lng+.008,p.lat+.006].join('%2C')+'&layer=mapnik&marker='+p.lat+'%2C'+p.lng:null;
        return h('section',{className:'mt-live-map'},h('h3',null,this.props.stage==='pickup'?'Pickup destination':'Drop-off destination'),h('p',{className:'mt-live-map-destination'},destination),this.state.offline||this.state.mapUnavailable?h('div',{className:'mt-recovery-notice',role:'status'},h('strong',null,this.state.offline?'Map unavailable offline':'Having trouble loading the map?'),h('p',null,'Your destination is saved above. Check your connection and try again.'),h('button',{type:'button',onClick:()=>this.setState({offline:navigator.onLine===false,mapUnavailable:false,mapAttempt:this.state.mapAttempt+1})},'Retry map')):h('iframe',{key:this.state.mapAttempt,onError:()=>this.setState({mapUnavailable:true}),title:'Map of '+this.props.stage+' destination',src:'https://maps.google.com/maps?q='+encodeURIComponent(destination)+'&output=embed',loading:'lazy',referrerPolicy:'no-referrer',style:{width:'100%',height:260,border:0,borderRadius:16}}),h('button',{type:'button',className:'mt-auth-text-button',onClick:()=>this.setState({mapUnavailable:true})},'Map not loading?'),h('div',{className:'mt-live-map-heading'},h('strong',null,'Your location'),h('small',{role:'status'},this.state.loading?'Finding location...':this.state.tracking?'Tracking on':'Tracking off')),
          p?h('iframe',{title:'Live map of your device location',src,loading:'lazy',referrerPolicy:'no-referrer',style:{width:'100%',height:260,border:0,borderRadius:16}}):null,
          p?h('p',{className:'mt-live-map-note'},'Accuracy: about '+Math.round(p.accuracy)+' m. Updated '+new Date(p.updated).toLocaleTimeString()+'.'):null,
          this.state.error?h('p',{role:'alert',className:'mt-auth-error'},this.state.error):null,
          h('div',{className:'mt-live-map-actions'},h('button',{type:'button',onClick:()=>this.state.tracking?(this.stop(),this.setState({tracking:false,loading:false,point:null})):this.start()},this.state.tracking?'Stop tracking':'Track my location'),h('a',{href:'https://www.google.com/maps/dir/?api=1&destination='+encodeURIComponent(destination),target:'_blank',rel:'noopener noreferrer'},'Navigate to '+this.props.stage)),
          h('p',{className:'mt-live-map-note'},'Location is used while this map is open. The map loads from OpenStreetMap using your coordinates. The destination map and navigation use Google Maps.'),h('p',{className:'mt-live-map-destination'},this.props.stage==='pickup'?'Pickup: ':'Drop-off: ',destination));
      }
    };
    return h(LiveMap,props);
  }};
})();
