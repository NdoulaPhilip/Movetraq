import { useEffect, useRef, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { ChevronLeft, ChevronRight, Plus, RefreshCw, Save, Trash2, X } from 'lucide-react';
import { request, type StaffUser } from './api';

const roles = ['sender','deliverer','support','verification_agent','finance','operations','admin','super_admin'];
interface ManagedUser { id:string; full_name:string; email:string|null; phone:string|null; roles:string[]; account_status:string; created_at:string; recent_activity:string|null; verification_status:string; }
interface RecordRow { id:string; [key:string]:unknown; }
interface Detail { user:ManagedUser; orders:RecordRow[]; transactions:RecordRow[]; verification:RecordRow[]; reports:RecordRow[]; activity:RecordRow[]; }
const date = (value:string|null) => value ? new Date(value).toLocaleString() : 'None';
function History({title,rows,fields}:{title:string;rows:RecordRow[];fields:string[]}) {
  return <section><h3>{title} (latest 25)</h3><div className="table-scroll"><table><thead><tr>{fields.map(f=><th key={f}>{f.replace(/_/g,' ')}</th>)}</tr></thead><tbody>{rows.map(row=><tr key={row.id}>{fields.map(f=><td key={f}>{String(row[f] ?? '')}</td>)}</tr>)}</tbody></table></div>{!rows.length && <p className="state-message">No records</p>}</section>;
}
export function Users({user,staff=false}:{user:StaffUser;staff?:boolean}) {
  const client=useQueryClient();
  const [q,setQ]=useState(''); const [role,setRole]=useState(''); const [status,setStatus]=useState('');
  const [from,setFrom]=useState(''); const [to,setTo]=useState(''); const [page,setPage]=useState(0);
  const [selected,setSelected]=useState<string|null>(null); const [creating,setCreating]=useState(false);
  const [name,setName]=useState(''); const [email,setEmail]=useState(''); const [phone,setPhone]=useState('');
  const [assigned,setAssigned]=useState<string[]>(['sender']); const [accountStatus,setAccountStatus]=useState('active');
  const [reason,setReason]=useState(''); const [busy,setBusy]=useState(false); const [error,setError]=useState('');
  const [confirmation,setConfirmation]=useState<'save'|'deactivate'|null>(null);
  const dialogRef=useRef<HTMLDialogElement>(null);
  useEffect(()=>{if(confirmation && dialogRef.current && !dialogRef.current.open) dialogRef.current.showModal();},[confirmation]);
  const params=new URLSearchParams({page:String(page),staff:String(staff)});
  if(q) params.set('q',q); if(role) params.set('role',role); if(status) params.set('status',status);
  if(from) params.set('from',new Date(`${from}T00:00:00Z`).toISOString());
  if(to) params.set('to',new Date(`${to}T23:59:59.999Z`).toISOString());
  const list=useQuery({queryKey:['managed-users',params.toString()],queryFn:()=>request<{users:ManagedUser[];total:number}>(`/admin/users?${params}`)});
  const detail=useQuery({queryKey:['managed-user',selected],enabled:!!selected,queryFn:()=>request<Detail>(`/admin/users/${selected}`)});
  const canEdit=creating || (!!detail.data && selected!==user.uid && detail.data.user.account_status!=='deactivated');
  function open(value:ManagedUser) {
    setCreating(false); setSelected(value.id); setName(value.full_name);setEmail(value.email ?? '');setPhone(value.phone ?? '');
    setAssigned(value.roles);setAccountStatus(value.account_status);setReason('');setError('');
  }
  async function submit() {
    setBusy(true);setError('');
    try {
      if(confirmation==='deactivate') await request(`/admin/users/${selected}`,'DELETE',{reason,confirmation:'DEACTIVATE'});
      else if(creating) await request('/admin/users','POST',{name,email,roles:assigned,reason});
      else await request(`/admin/users/${selected}`,'PATCH',{name,phone:phone||null,roles:assigned,status:accountStatus,reason});
      setSelected(null);setCreating(false);setConfirmation(null);
      await client.invalidateQueries({queryKey:['managed-users']});
      await client.invalidateQueries({queryKey:['managed-user']});
      await client.invalidateQueries({queryKey:['platform-analytics']});
      await client.invalidateQueries({queryKey:['platform-events']});
    } catch(failure) { setError((failure as Error).message);setConfirmation(null); }
    finally {setBusy(false);}
  }
  return <>
    <header className="page-heading"><h1>{staff?'Administrators & Staff':'User Management'}</h1><button className="primary-button" onClick={()=>{setCreating(true);setSelected(null);setName('');setEmail('');setPhone('');setAssigned(staff?['admin']:['sender']);setReason('');setError('');}}><Plus size={18}/>Add {staff?'staff':'user'}</button></header>
    <div className="toolbar"><label>Search<input type="search" value={q} onChange={e=>{setQ(e.target.value);setPage(0);}}/></label>
      <label>Role<select value={role} onChange={e=>{setRole(e.target.value);setPage(0);}}><option value="">All roles</option>{roles.map(r=><option key={r}>{r}</option>)}</select></label>
      <label>Status<select value={status} onChange={e=>{setStatus(e.target.value);setPage(0);}}><option value="">All statuses</option>{['active','suspended','deactivated'].map(s=><option key={s}>{s}</option>)}</select></label>
      <label>Registered from (UTC)<input type="date" value={from} onChange={e=>{setFrom(e.target.value);setPage(0);}}/></label><label>To (UTC)<input type="date" value={to} onChange={e=>{setTo(e.target.value);setPage(0);}}/></label>
      <button className="icon-button" title="Refresh users" onClick={()=>void list.refetch()}><RefreshCw size={18}/></button></div>
    {list.isPending && <p className="state-message">Loading users...</p>}{list.error && <p className="error" role="alert">{list.error.message}</p>}
    <div className="table-scroll"><table className="directory-table"><thead><tr><th>User</th><th>Roles</th><th>Status</th><th>Registered</th><th>Recent activity</th></tr></thead><tbody>{list.data?.users.map(value=><tr key={value.id}><td><button className="row-link" onClick={()=>open(value)}>{value.full_name}</button><small>{value.email}</small></td><td>{value.roles.join(', ')}</td><td><span className={`status status-${value.account_status}`}>{value.account_status}</span></td><td>{date(value.created_at)}</td><td>{date(value.recent_activity)}</td></tr>)}</tbody></table></div>
    {list.data && !list.data.users.length && <p className="state-message">No matching users</p>}
    <div className="pagination"><span>{list.data?.total ?? 0} users</span><button className="icon-button" title="Previous page" disabled={!page} onClick={()=>setPage(page-1)}><ChevronLeft size={18}/></button><span>Page {page+1}</span><button className="icon-button" title="Next page" disabled={!list.data || (page+1)*25>=list.data.total} onClick={()=>setPage(page+1)}><ChevronRight size={18}/></button></div>
    {(selected || creating) && <section className="user-detail"><header className="page-heading"><h2>{creating?'Invite new account':name}</h2><button className="icon-button" title="Close user" onClick={()=>{setSelected(null);setCreating(false);}}><X size={18}/></button></header>
      {detail.error && !creating && <p className="error" role="alert">{detail.error.message}</p>}
      {detail.isPending && !creating ? <p className="state-message">Loading account...</p> : <>
        <form onSubmit={e=>{e.preventDefault();setConfirmation('save');}} className="user-form">
          <label>Name<input required minLength={2} maxLength={120} value={name} disabled={!canEdit||busy} onChange={e=>setName(e.target.value)}/></label>
          <label>Email<input type="email" required={creating} value={email} disabled={!creating||busy} onChange={e=>setEmail(e.target.value)}/></label>
          {!creating && <label>Phone<input placeholder="+234..." value={phone} disabled={!canEdit||busy} onChange={e=>setPhone(e.target.value)}/></label>}
          {!creating && <label>Status<select value={accountStatus} disabled={!canEdit||busy} onChange={e=>setAccountStatus(e.target.value)}><option value="active">Active</option><option value="suspended">Suspended</option>{accountStatus==='deactivated' && <option>deactivated</option>}</select></label>}
          <fieldset className="role-options"><legend>Role-based permissions</legend>{roles.map(r=><label key={r}><input type="checkbox" checked={assigned.includes(r)} disabled={!canEdit||busy} onChange={e=>setAssigned(e.target.checked?[...assigned,r]:assigned.filter(a=>a!==r))}/>{r.replace(/_/g,' ')}</label>)}</fieldset>
          <label>Reason<textarea required minLength={5} maxLength={500} value={reason} disabled={!canEdit||busy} onChange={e=>setReason(e.target.value)}/></label>
          <div className="confirmation-actions"><button type="submit" className="primary-button" disabled={!canEdit||busy||!assigned.length}><Save size={18}/>{creating?'Send invitation':'Save changes'}</button>{!creating && <button className="secondary-button" type="button" disabled={!canEdit||busy||reason.trim().length<5} onClick={()=>setConfirmation('deactivate')}><Trash2 size={18}/>Deactivate account</button>}</div>
        </form>
        {detail.data && !creating && <><dl><dt>Verification</dt><dd>{detail.data.user.verification_status}</dd><dt>User ID</dt><dd>{selected}</dd></dl><History title="Orders & deliveries" rows={detail.data.orders} fields={['public_ref','status','service_type','total_amount_minor','currency']}/><History title="Wallet ledger" rows={detail.data.transactions} fields={['type','amount_minor','currency','created_at']}/><History title="Verification" rows={detail.data.verification} fields={['status','created_at']}/><History title="Reports" rows={detail.data.reports} fields={['category','status','created_at']}/><History title="Account activity" rows={detail.data.activity} fields={['event_type','created_at']}/></>}
      </>}{error && <p className="error" role="alert">{error}</p>}</section>}
    {confirmation && <dialog ref={dialogRef} onCancel={e=>{e.preventDefault();if(!busy)setConfirmation(null);}} aria-labelledby="user-confirm-title" className="confirmation-dialog"><h2 id="user-confirm-title">{confirmation==='deactivate'?'Deactivate this account?':creating?'Send account invitation?':'Apply account changes?'}</h2>{confirmation==='deactivate' && <p>Access will be revoked. Financial records, delivery history, and audit records will be retained.</p>}<p>{name}</p><div className="confirmation-actions"><button className="secondary-button" disabled={busy} onClick={()=>setConfirmation(null)}>Cancel</button><button className="primary-button" disabled={busy} onClick={()=>void submit()}><Save size={18}/>{busy?'Saving...':'Confirm'}</button></div></dialog>}
  </>;
}
