import { useEffect,useState } from 'react';
import { useQuery,useQueryClient } from '@tanstack/react-query';
import { ChevronLeft,ChevronRight,RefreshCw } from 'lucide-react';
import { request,watchActivity } from './api';
interface Event {id:string;user_id?:string;actor_id?:string;admin_id?:string;event_type?:string;action?:string;category?:string;description?:string;outcome?:string;previous_status?:string;new_status?:string;order_id?:string;reference?:string;error_code?:string;entity:string;entity_id:string;created_at:string;previous_state?:unknown;new_state?:unknown;metadata?:unknown;}
interface Daily {day:string;orders:number;payments:number;revenue_minor:string;users:number;}
interface Metrics {series:Daily[];[key:string]:number|Daily[];}
function Trend({title,series,field}:{title:string;series:Daily[];field:'orders'|'payments'|'users'|'revenue_minor'}) {
  const values=series.map(day=>BigInt(day[field]));const magnitude=(n:bigint)=>n<0n?-n:n;const maximum=values.reduce((a,b)=>a>magnitude(b)?a:magnitude(b),1n);
  return <section className="activity-trend"><h2>{title}</h2><div className="trend-bars" role="img" aria-label={`${title} over the last 14 UTC days`}>{series.map((day,index)=><div key={day.day} title={`${day.day}: ${field==='revenue_minor'?'NGN minor units ':''}${values[index]}`}><span style={{height:`${Number(magnitude(values[index])*10000n/maximum)/100}%`,...(values[index]<0n?{backgroundColor:'#b53d47'}:{})}}/><small>{day.day.slice(8,10)}</small></div>)}</div>
    <details><summary>Daily values</summary><table><tbody>{series.map(day=><tr key={day.day}><td>{day.day}</td><td>{String(day[field])}{field==='revenue_minor'?' kobo':''}</td></tr>)}</tbody></table></details></section>;
}
export function Activity({audit=false}:{audit?:boolean}) {
  const client=useQueryClient();const [filters,setFilters]=useState<Record<string,string>>({});const [page,setPage]=useState(0);
  const [selected,setSelected]=useState<Event|null>(null);const [live,setLive]=useState('Connecting');
  const params=new URLSearchParams({page:String(page)});
  Object.entries(filters).forEach(([key,value])=>{if(value)params.set(key,key==='from'||key==='to'?new Date(`${value}T${key==='from'?'00:00:00':'23:59:59.999'}Z`).toISOString():value);});
  const feed=useQuery({queryKey:['platform-events',audit,params.toString()],queryFn:()=>request<{events:Event[];total:number}>(`/admin/platform/${audit?'audit':'activity'}?${params}`)});
  const analytics=useQuery({queryKey:['platform-analytics'],enabled:!audit,queryFn:()=>request<Record<string,number>>('/admin/platform/analytics')});
  const metrics=useQuery({queryKey:['platform-metrics'],enabled:!audit,queryFn:()=>request<Metrics>('/admin/platform/metrics')});
  const record=useQuery({queryKey:['activity-record',selected?.id],enabled:!!selected&&!audit,queryFn:()=>request<{entity?:string;record:unknown}>(`/admin/platform/activity/${selected!.id}/record`)});
  useEffect(()=>{
    let disposed=false;let connection:AbortController|undefined;let retry:ReturnType<typeof setTimeout>|undefined;
    let refresh:ReturnType<typeof setTimeout>|undefined;let backoff=1000;let generation=0;
    const invalidate=()=>{
      if(refresh)return;
      refresh=setTimeout(()=>{refresh=undefined;void client.invalidateQueries({queryKey:['platform-events']});void client.invalidateQueries({queryKey:['platform-analytics']});void client.invalidateQueries({queryKey:['platform-metrics']});void client.invalidateQueries({queryKey:['activity-record']});},750);
    };
    const connect=()=>{
      if(disposed||document.hidden)return;const version=++generation;connection?.abort();connection=new AbortController();const controller=connection;setLive('Connecting');
      void watchActivity(connection.signal,event=>{
        if(disposed||version!==generation)return;
        if(event==='ready'){setLive('Live');backoff=1000;invalidate();}
        if(event==='invalidate')invalidate();
        if(event==='unavailable'||event==='unauthorized'){setLive(event==='unauthorized'?'Access expired':'Disconnected');controller.abort();}
      }).catch(()=>{if(!disposed&&version===generation)setLive('Disconnected');}).finally(()=>{
        if(!disposed&&!document.hidden&&version===generation){setLive('Disconnected');retry=setTimeout(connect,backoff);backoff=Math.min(backoff*2,30000);}
      });
    };
    const visibility=()=>{if(document.hidden){generation++;connection?.abort();if(retry)clearTimeout(retry);setLive('Paused');}else connect();};
    connect();document.addEventListener('visibilitychange',visibility);
    return ()=>{disposed=true;connection?.abort();if(retry)clearTimeout(retry);if(refresh)clearTimeout(refresh);document.removeEventListener('visibilitychange',visibility);};
  },[client]);
  const labels:Record<string,string>={totalUsers:'Registered users',enabledUsers:'Enabled accounts',suspendedUsers:'Suspended accounts',administrators:'Administrators',newRegistrations:'Registrations (7 days)',onlineVerifiedDeliverers:'Online verified deliverers',activeUsers7d:'Active users (7 days)',totalOrders:'Total orders',activeDeliveries:'Active deliveries',completedOrders:'Completed orders',pendingPayments:'Pending payments',successfulPayments:'Successful payments',failedTransactions:'Failed payments',openDisputes:'Open disputes',pendingPayouts:'Pending payouts',registrations7d:'Registrations (7 days)'};
  const filter=(key:string,value:string)=>{setFilters(previous=>({...previous,[key]:value}));setPage(0);};
  const summaries={...analytics.data,...metrics.data};
  return <><header className="page-heading"><h1>{audit?'Security & Audit Logs':'Platform Activity'}</h1><div className="toolbar"><span className="status" role="status">{live}</span><button className="icon-button" title="Refresh activity" onClick={()=>{void feed.refetch();if(!audit){void analytics.refetch();void metrics.refetch();}}}><RefreshCw size={18}/></button></div></header>
    {!audit && <section className="analytics-band">{Object.entries(summaries).filter(([,value])=>typeof value==='number').map(([key,value])=><div key={key}><span>{labels[key]??key}</span><strong>{(value as number).toLocaleString()}</strong></div>)}</section>}
    {!audit && (analytics.error||metrics.error) && <p className="error" role="alert">{(analytics.error??metrics.error)?.message}</p>}
    {!audit && metrics.data?.series && <div className="activity-charts">{(['orders','payments','revenue_minor','users'] as const).map(field=><Trend key={field} title={{orders:'Order volume',payments:'Verified payments',revenue_minor:'Platform revenue (kobo)',users:'User activity'}[field]} series={metrics.data!.series} field={field}/>)}</div>}
    <div className="activity-filters">
      <label>Activity type<input value={filters.type??''} onChange={e=>filter('type',e.target.value.replace(/[^a-z_]/g,''))}/></label>
      <label>User / actor ID<input value={filters.userId??''} onChange={e=>filter('userId',e.target.value)}/></label>
      <label>From (UTC)<input type="date" value={filters.from??''} onChange={e=>filter('from',e.target.value)}/></label><label>To (UTC)<input type="date" value={filters.to??''} onChange={e=>filter('to',e.target.value)}/></label>
      {!audit && <><label>Category<select aria-label="Category" value={filters.category??''} onChange={e=>filter('category',e.target.value)}><option value="">All categories</option>{['orders','finance','accounts','deliverers','communication','support','security','system'].map(c=><option key={c}>{c}</option>)}</select></label>
        <label>Outcome<select aria-label="Outcome" value={filters.outcome??''} onChange={e=>filter('outcome',e.target.value)}><option value="">All outcomes</option>{['successful','failed','pending','rejected'].map(c=><option key={c}>{c}</option>)}</select></label>
        <label>Order ID<input value={filters.orderId??''} onChange={e=>filter('orderId',e.target.value)}/></label><label>Transaction reference<input value={filters.reference??''} onChange={e=>filter('reference',e.target.value)}/></label>
        <label>New status<input value={filters.status??''} onChange={e=>filter('status',e.target.value.replace(/[^a-z_]/g,''))}/></label><label>Search<input type="search" value={filters.q??''} onChange={e=>filter('q',e.target.value)}/></label></>}
    </div>
    {feed.isPending && <p className="state-message">Loading activity...</p>}{feed.error && <p className="error" role="alert">{feed.error.message}</p>}
    <div className="table-scroll"><table className="activity-table"><thead><tr><th>Event</th><th>Actor / account</th><th>Outcome & status</th><th>Related record</th><th>Time</th></tr></thead><tbody>{feed.data?.events.map(event=><tr key={event.id}><td><button className="row-link" onClick={()=>setSelected(event)}>{event.action??event.event_type}</button><small>{event.description}</small></td><td>{event.actor_id??event.admin_id??'System / unknown'}<small>{event.user_id}</small></td><td>{event.outcome??''}<small>{event.previous_status?`${event.previous_status} to `:''}{event.new_status}</small></td><td>{event.entity}<small>{event.entity_id}</small><small>{event.reference}</small></td><td>{new Date(event.created_at).toLocaleString()}</td></tr>)}</tbody></table></div>
    {feed.data && !feed.data.events.length && <p className="state-message">No matching events</p>}
    <div className="pagination"><span>{feed.data?.total??0} events</span><button className="icon-button" title="Previous page" disabled={!page} onClick={()=>setPage(page-1)}><ChevronLeft size={18}/></button><span>Page {page+1}</span><button className="icon-button" title="Next page" disabled={!feed.data||(page+1)*25>=feed.data.total} onClick={()=>setPage(page+1)}><ChevronRight size={18}/></button></div>
    {selected && <section className="user-detail"><h2>{selected.action??selected.event_type}</h2><dl><dt>Actor</dt><dd>{selected.actor_id??selected.admin_id??'System / unknown'}</dd><dt>Outcome</dt><dd>{selected.outcome}</dd><dt>Error code</dt><dd>{selected.error_code??'None'}</dd><dt>Order</dt><dd>{selected.order_id??'None'}</dd></dl>{audit?<><h3>Previous state</h3><pre>{JSON.stringify(selected.previous_state,null,2)}</pre><h3>New state</h3><pre>{JSON.stringify(selected.new_state,null,2)}</pre></>:<><h3>Associated record</h3>{record.isPending?<p>Loading record...</p>:record.error?<p className="error" role="alert">{record.error.message}</p>:<pre>{record.data?.record?JSON.stringify(record.data.record,null,2):'Record unavailable or metadata-only event.'}</pre>}</>}
      <h3>Metadata</h3><pre>{JSON.stringify(selected.metadata,null,2)}</pre><button className="secondary-button" onClick={()=>setSelected(null)}>Close</button></section>}
  </>;
}
