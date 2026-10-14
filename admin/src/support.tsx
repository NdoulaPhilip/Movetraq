import { useEffect, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Check, ChevronLeft, ChevronRight, ExternalLink, RefreshCw, RotateCcw } from 'lucide-react';
import { request, type StaffUser } from './api';
interface Case { id: string; order_id: string; category: string; description: string; status: string; priority: string;
  internal_notes: string | null; resolution: string | null; created_at: string; }
const words = (value: string) => value.replace(/_/g, ' ');
function SettlementConfirmation({ decision, orderId, resolution, pending, error, onCancel, onConfirm }: {
  decision: string; orderId: string; resolution: string; pending: boolean; error: string | null;
  onCancel: () => void; onConfirm: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => { const element = dialog.current!; element.showModal(); return () => element.close(); }, []);
  return <dialog ref={dialog} className="confirmation-dialog" aria-labelledby="settlement-heading" onCancel={(event) => { event.preventDefault(); if (!pending) onCancel(); }}>
    <h2 id="settlement-heading">{decision === 'refund' ? 'Refund Sender Wallet?' : 'Release Deliverer Earnings?'}</h2>
    <small>Order {orderId}</small><p className="case-description">{resolution}</p>
    {error && <p className="error" role="alert">{error}</p>}
    <div className="confirmation-actions"><button className="secondary-button" autoFocus disabled={pending} onClick={onCancel}>Cancel</button>
      <button className="primary-button" disabled={pending} onClick={onConfirm}><Check size={17} />{pending ? 'Settling...' : 'Confirm settlement'}</button></div>
  </dialog>;
}
export function Support({ user }: { user: StaffUser }) {
  const client = useQueryClient();
  const [offset, setOffset] = useState(0); const [selectedId, setSelectedId] = useState<string | null>(null);
  const [status, setStatus] = useState('investigating'); const [priority, setPriority] = useState('normal');
  const [notes, setNotes] = useState(''); const [resolution, setResolution] = useState(''); const [decision, setDecision] = useState('');
  const [key, setKey] = useState(() => crypto.randomUUID()); const [photoError, setPhotoError] = useState('');
  const [confirming, setConfirming] = useState(false);
  const canReview = user.roles.some((role) => ['support','operations','admin','super_admin'].includes(role));
  const canSettle = user.roles.some((role) => ['finance','admin','super_admin'].includes(role));
  const query = useQuery({ queryKey: ['support', user.uid, offset], queryFn: () => request<{ cases: Case[] }>(`/admin/support/cases?limit=30&offset=${offset}`) });
  const cases = query.data?.cases ?? []; const selected = cases.find((item) => item.id === selectedId);
  const closed = selected && ['resolved','closed'].includes(selected.status);
  const save = useMutation({ mutationFn: (action: string) => {
    if (action === 'review') return request(`/admin/support/cases/${selected!.id}/review`, 'POST', { status, priority, internalNotes: notes, ...(resolution.trim() ? { resolution } : {}) });
    if (action === 'return') return request(`/admin/orders/${selected!.order_id}/returns/approve`, 'POST', { reason: notes });
    return request(`/admin/orders/${selected!.order_id}/dispute-settlement`, 'POST', { decision, resolution }, { 'Idempotency-Key': key });
  }, onSuccess: async () => { await client.invalidateQueries({ queryKey: ['support', user.uid] }); } });
  const photos = useQuery({ queryKey: ['evidence', user.uid, selected?.order_id], enabled: !!selected?.order_id && canReview,
    queryFn: () => request<{ evidence: { id: string; recipient_name: string; captured_at: string }[] }>(`/orders/${selected!.order_id}/evidence`) });
  async function openPhoto(id: string) {
    setPhotoError(''); const tab = window.open('about:blank', '_blank'); if (tab) tab.opener = null;
    try { const data = await request<{ signedUrl: string }>(`/evidence/${id}/download`);
      if (!tab) throw new Error('Allow the document window and retry.'); tab.location.href = data.signedUrl;
    } catch (error) { tab?.close(); setPhotoError((error as Error).message); }
  }
  return <><div className="page-heading"><div><h1>Delivery Support</h1><p>Cases and disputes</p></div><button className="icon-button" title="Refresh cases" aria-label="Refresh cases" onClick={() => void query.refetch()}><RefreshCw size={18} /></button></div>
    {query.isPending ? <p className="state-message">Loading cases...</p> : query.isError ? <p className="error" role="alert">{query.error.message}</p> :
      <div className="review-layout"><section className="application-list" aria-label="Support cases"><div className="table-scroll"><table><thead><tr><th>Case</th><th>Category</th><th>Status</th><th>Priority</th></tr></thead><tbody>
        {cases.map((item) => <tr key={item.id} className={item.id === selectedId ? 'active-row' : ''}><td><button className="row-link" onClick={() => {
          setSelectedId(item.id); setStatus(item.status); setPriority(item.priority); setNotes(item.internal_notes ?? ''); setResolution(item.resolution ?? ''); setDecision(''); setKey(crypto.randomUUID()); save.reset(); setPhotoError('');
        }}>{item.id.slice(0, 8)}</button><small>{new Date(item.created_at).toLocaleDateString()}</small></td><td>{words(item.category)}</td><td><span className="status">{words(item.status)}</span></td><td>{item.priority}</td></tr>)}</tbody></table></div>
        {cases.length === 0 && <p className="state-message">No support cases.</p>}<div className="pagination"><span>Page {offset / 30 + 1}</span><button className="icon-button" title="Previous page" aria-label="Previous page" disabled={!offset} onClick={() => { setOffset(offset - 30); setSelectedId(null); }}><ChevronLeft size={18} /></button><button className="icon-button" title="Next page" aria-label="Next page" disabled={cases.length < 30} onClick={() => { setOffset(offset + 30); setSelectedId(null); }}><ChevronRight size={18} /></button></div>
      </section><aside className="review-panel" aria-label="Case review">{selected ? <><h2>{words(selected.category)}</h2><p className="case-description">{selected.description}</p><small>Order {selected.order_id}</small>
        {selected.resolution && <p className="review-notes">{selected.resolution}</p>}
        {canReview && <><h3>Handover Evidence</h3>{photos.isPending ? <p className="state-message">Loading evidence...</p> : photos.isError ? <p className="error">{photos.error.message}</p> : photos.data?.evidence.length === 0 ? <p className="review-notes">No handover evidence recorded.</p> : photos.data?.evidence.map((photo) => <div className="document-row" key={photo.id}><span>{photo.recipient_name}<small>{new Date(photo.captured_at).toLocaleString()}</small></span><button className="icon-button" title="Open evidence photo" aria-label="Open evidence photo" onClick={() => void openPhoto(photo.id)}><ExternalLink size={17} /></button></div>)}</>}
        {photoError && <p className="error" role="alert">{photoError}</p>}
        {!closed && <div className="review-form">{canReview && <><label>Case status<select value={status} onChange={(event) => setStatus(event.target.value)}>{['open','investigating','waiting_user','waiting_deliverer','resolved','closed'].map((value) => <option key={value} value={value}>{words(value)}</option>)}</select></label><label>Priority<select value={priority} onChange={(event) => setPriority(event.target.value)}>{['low','normal','high','urgent'].map((value) => <option key={value}>{value}</option>)}</select></label><label>Internal notes<textarea value={notes} maxLength={4000} onChange={(event) => setNotes(event.target.value)} /></label>
          <button className="primary-button" disabled={save.isPending || notes.trim().length < 3} onClick={() => save.mutate('review')}><Check size={17} />Save case</button>
          {selected.category === 'return' && <button className="primary-button" disabled={save.isPending || notes.trim().length < 3} onClick={() => save.mutate('return')}><RotateCcw size={17} />Approve return</button>}</>}
          <label>Resolution<textarea value={resolution} maxLength={4000} onChange={(event) => { setResolution(event.target.value); setKey(crypto.randomUUID()); }} /></label>
          {canSettle && <><label>Settlement<select value={decision} onChange={(event) => { setDecision(event.target.value); setKey(crypto.randomUUID()); }}><option value="">Select settlement</option><option value="release">Release deliverer earnings</option><option value="refund">Refund sender wallet</option></select></label><button className="primary-button" disabled={save.isPending || !decision || resolution.trim().length < 3} onClick={() => { save.reset(); setConfirming(true); }}><Check size={17} />Settle dispute</button></>}
        </div>}{save.isError && <p className="error" role="alert">{save.error.message}</p>}{save.isSuccess && <p className="success" role="status">Case updated.</p>}</> : <p className="state-message">No case selected.</p>}</aside></div>}
    {confirming && selected && <SettlementConfirmation decision={decision} orderId={selected.order_id} resolution={resolution} pending={save.isPending}
      error={save.isError ? save.error.message : null} onCancel={() => setConfirming(false)} onConfirm={() => save.mutate('settle', { onSuccess: () => setConfirming(false) })} />}
  </>;
}
