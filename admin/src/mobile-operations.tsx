import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { ChevronLeft,ChevronRight,RefreshCw } from 'lucide-react';
import { request } from './api';
interface Row {id?:string;entity?:string;entity_id?:string;user_id?:string;actor_id?:string;staff_id?:string;order_id?:string;event_type?:string;route?:string;method?:string;category?:string;outcome?:string;new_status?:string;reference?:string;created_at:string;record?:Record<string,unknown>;metadata?:Record<string,unknown>;}
interface Feed {source:string;rows:Row[];total:number;stats:Record<string,number>;checkedAt:string;}
const views:Record<string,string>={activity:'Activity',attempts:'Operations & failures',payments:'Payments',ledger:'Wallet ledger',orders:'Orders & escrow',users:'Users & deliverers',messages:'Messages',notifications:'Notifications',support_tickets:'Support',wallet_transactions:'Wallet history',saved_addresses:'Addresses',security_settings:'Account settings'};
function amount(record:Record<string,unknown>) {
  const value=record.amount_minor ?? record.amount;
  if(value===undefined)return '';
  if(record.amount_minor!==undefined){try{const minor=BigInt(String(value));const n=minor<0n?-minor:minor;return `${minor<0n?'-':''}NGN ${n/100n}.${String(n%100n).padStart(2,'0')}`;}catch{return 'Invalid recorded amount';}}
  return `NGN ${String(value)}`;
}
export function MobileOperations({initialView='activity'}:{initialView?:string}) {
  const [view,setView]=useState(initialView);const [page,setPage]=useState(0);const [search,setSearch]=useState('');const [selected,setSelected]=useState<Row|null>(null);
  const query=new URLSearchParams({view,page:String(page),q:search});
  const feed=useQuery({queryKey:['mobile-operations',view,page,search],queryFn:async()=>{
    const result=await request<Feed>(`/admin/mobile/monitoring?${query}`);
    if(result?.source!=='mobile_postgres'||!Array.isArray(result.rows)||!result.stats||!Number.isInteger(result.total))throw new Error('Invalid mobile monitoring response.');
    return result;
  },refetchInterval:10000,refetchIntervalInBackground:false});
  return <><header className="page-heading"><h1>{views[view]}</h1><div className="toolbar"><span className="status" role="status">{feed.isFetching?'Updating':feed.error?'Unavailable':'Auto-updating'}</span><button className="icon-button" title="Refresh mobile records" onClick={()=>void feed.refetch()}><RefreshCw size={18}/></button></div></header>
    {feed.data&&<section className="analytics-band">{Object.entries(feed.data.stats).map(([key,value])=><div key={key}><span>{key.replace(/_/g,' ')}</span><strong>{value.toLocaleString()}</strong></div>)}</section>}
    <div className="activity-filters"><label>Section<select aria-label="Mobile section" value={view} onChange={e=>{setView(e.target.value);setPage(0);setSelected(null);}}>{Object.entries(views).map(([key,label])=><option key={key} value={key}>{label}</option>)}</select></label>
    <label>Reference, user, order or status<input type="search" maxLength={128} value={search} onChange={e=>{setSearch(e.target.value);setPage(0);}}/></label></div>
    {feed.error&&<p className="error" role="alert">{feed.error.message}</p>}{feed.isPending&&<p className="state-message">Loading mobile records...</p>}
    <div className="table-scroll"><table className="activity-table"><thead><tr><th>Event / record</th><th>User / order</th><th>Status</th><th>Amount / reference</th><th>Time</th></tr></thead><tbody>{feed.data?.rows.map((row,index)=>{
      const record=row.record??row.metadata??{};return <tr key={`${row.id??row.entity_id}:${index}`}><td><button className="row-link" onClick={()=>setSelected(row)}>{row.event_type??row.route??String(record.code??record.name??row.entity_id)}</button><small>{row.method??row.entity}</small></td>
      <td>{row.user_id??row.actor_id??row.staff_id??'System / unknown'}<small>{row.order_id??String(record.delivererId??'')}</small></td><td>{row.outcome??String(record.status??'Recorded')}<small>{row.new_status??String(record.provider_status??record.last_error_code??'')}</small></td>
      <td><span>{amount(record)}</span><small>{row.reference??String(record.reference??record.provider_reference??'')}</small></td><td>{new Date(row.created_at).toLocaleString()}<small>{record.created_at||record.createdAt?`Created: ${new Date(String(record.created_at??record.createdAt)).toLocaleString()}`:''}</small></td></tr>;
    })}</tbody></table></div>
    {!feed.error&&feed.data&&!feed.data.rows.length&&<p className="state-message">No matching records</p>}
    <div className="pagination"><span>{feed.data?.total??0} records</span><button className="icon-button" title="Previous page" disabled={page===0} onClick={()=>setPage(page-1)}><ChevronLeft size={18}/></button><span>Page {page+1}</span><button className="icon-button" title="Next page" disabled={!feed.data||(page+1)*25>=feed.data.total} onClick={()=>setPage(page+1)}><ChevronRight size={18}/></button></div>
    {feed.data&&<p className="state-message">Mobile PostgreSQL - Checked {new Date(feed.data.checkedAt).toLocaleTimeString()}</p>}
    {selected&&<section className="user-detail"><h2>Mobile record</h2><pre>{JSON.stringify(selected,null,2)}</pre><button className="secondary-button" onClick={()=>setSelected(null)}>Close</button></section>}
  </>;
}
export function OperationalView({children,initialView='activity'}:{children:React.ReactNode;initialView?:string}) {
  const [source,setSource]=useState('mobile');
  return <><div className="activity-filters"><label>Data source<select aria-label="Data source" value={source} onChange={e=>setSource(e.target.value)}><option value="mobile">Android - Mobile PostgreSQL</option><option value="supabase">Supabase platform</option></select></label></div>{source==='mobile'?<MobileOperations initialView={initialView}/>:children}</>;
}
