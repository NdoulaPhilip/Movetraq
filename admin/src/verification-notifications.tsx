import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Bell } from 'lucide-react';
import { request, type StaffUser } from './api';
interface Notice { id:string; type:string; title:string; read_at:string|null; }
interface Inbox { notifications:Notice[]; unreadCount:number; legacyInboxAvailable?:boolean; }

// Durable inbox rows are inserted atomically by the submission transaction.
export function VerificationNotifications({user,onReview}:{user:StaffUser;onReview:()=>void}) {
  const client=useQueryClient();
  const key=['verification-notifications',user.uid];
  const inbox=useQuery({queryKey:key,queryFn:()=>request<Inbox>('/admin/verification-notifications?limit=100'),
    refetchInterval:5000,staleTime:0});
  const pending=(inbox.data?.notifications??[]).filter(item=>item.type==='deliverer_application'&&!item.read_at);
  const read=useMutation({mutationFn:async()=>{
    for(const item of pending)await request(`/notifications/${item.id}/read`,'POST');
  },onSuccess:()=>client.invalidateQueries({queryKey:key})});
  if(inbox.isError)return <p className="error" role="alert">Application notifications could not be refreshed. <button onClick={()=>void inbox.refetch()}>Retry</button></p>;
  if(inbox.data?.legacyInboxAvailable===false)return <p role="status">The legacy staff account has no linked notification inbox. Check the Verification queue for applications.</p>;
  if(!pending.length)return null;
  return <aside className="verification-notice" aria-label="New deliverer applications">
    <Bell size={21}/><div><strong role="status">{inbox.data?.unreadCount??pending.length} new deliverer application{(inbox.data?.unreadCount??pending.length)===1?'':'s'}</strong>
      <p>New applications are ready for identity and document review.</p></div>
    <button className="secondary-button" disabled={read.isPending} onClick={()=>{onReview();read.mutate();}}>Review applications</button>
    {read.isError&&<p className="error" role="alert">Could not mark application notifications read. Please retry.</p>}
  </aside>;
}
