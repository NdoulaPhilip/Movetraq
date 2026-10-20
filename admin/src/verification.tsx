import { useEffect, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Check, ChevronLeft, ChevronRight, ExternalLink, RefreshCw, Search } from 'lucide-react';
import { request, type Application, type StaffUser } from './api';

const words = (value: string) => value.replace(/_/g, ' ');
const statusLabel = (value:string) => ['pending_approval','submitted'].includes(value)?'Pending Approval':value==='approved'?'Approved':value==='rejected'?'Rejected':words(value);
export function Verification({ user }: { user: StaffUser }) {
  const queryClient = useQueryClient();
  const [offset, setOffset] = useState(0);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [filter, setFilter] = useState('pending');
  const [search, setSearch] = useState('');
  const reviewPanel = useRef<HTMLElement>(null);
  const [notes, setNotes] = useState('');
  const [documentError, setDocumentError] = useState('');
  const [opening, setOpening] = useState<string | null>(null);
  const query = useQuery({ queryKey: ['verification', user.uid, filter, offset], queryFn: () =>
    request<{ applications: Application[] }>(`/admin/verification-applications?limit=30&offset=${offset}&status=${filter}`),refetchInterval:5000 });
  const applications = query.data?.applications ?? [];
  const visible = applications.filter((item) => (filter !== 'pending' || ['pending_approval','submitted', 'under_review'].includes(item.status)) &&
    `${item.identity_info.fullName ?? ''} ${item.id}`.toLowerCase().includes(search.toLowerCase()));
  const selected = applications.find((item) => item.id === selectedId);
  const selfReview = !!selected && (selected.user_id === user.uid || (!!selected.legacy_user_id &&
    !!user.email && selected.legacy_account_email?.trim().toLowerCase() === user.email.trim().toLowerCase()));
  const review = useMutation({ mutationFn: (status: string) => request(`/admin/verification-applications/${selected!.id}/review`, 'POST', { status, notes: notes.trim() }),
    onSuccess: async () => { setNotes(''); await queryClient.invalidateQueries({ queryKey: ['verification', user.uid] }); } });
  const actions = ['pending_approval','submitted'].includes(selected?.status??'') ? ['under_review', 'rejected'] : selected?.status === 'under_review' ?
    ['approved', 'rejected'] : selected?.status === 'approved' ? ['suspended'] : selected?.status==='suspended'&&selected.legacy_user_id?['under_review']:[];
  useEffect(() => {
    if (selectedId && window.matchMedia('(max-width: 1120px)').matches) reviewPanel.current?.scrollIntoView({ block: 'start' });
  }, [selectedId]);
  function selectApplication(id: string) {
    setSelectedId(id); setNotes(''); review.reset(); setDocumentError('');
  }
  const actionLabels: Record<string,string> = {under_review:'Start review',approved:'Approve application',rejected:'Reject application',suspended:'Suspend deliverer access'};
  async function openDocument(id: string) {
    setDocumentError(''); setOpening(id);
    const tab = window.open('about:blank', '_blank');
    if (tab) tab.opener = null;
    try {
      const data = await request<{ signedUrl: string }>(`/verification-documents/${id}/download`);
      if (!tab) throw new Error('The document window was blocked. Allow this window and retry.');
      tab.location.href = data.signedUrl;
    } catch (error) { tab?.close(); setDocumentError((error as Error).message); }
    finally { setOpening(null); }
  }
  return <>
    <div className="page-heading"><div><h1>Delivery Verification</h1><p>{query.data ? `${applications.length} applications on this page` : 'Applications'}</p></div>
      <button className="icon-button" title="Refresh applications" aria-label="Refresh applications" onClick={() => void query.refetch()} disabled={query.isFetching}><RefreshCw size={18} /></button></div>
    <div className="toolbar"><div className="segmented" role="group" aria-label="Application filter">
      <button className={filter === 'pending' ? 'selected' : ''} onClick={() => {setFilter('pending');setOffset(0);setSelectedId(null);}}>Pending</button>
      <button className={filter === 'all' ? 'selected' : ''} onClick={() => {setFilter('all');setOffset(0);setSelectedId(null);}}>All</button></div>
      <label className="search"><Search size={17} /><input aria-label="Search applications" placeholder="Search applications" value={search} onChange={(event) => setSearch(event.target.value)} /></label></div>
    {review.isSuccess&&<p className="success" role="status">Review saved.</p>}
    {query.isPending ? <p className="state-message" role="status">Loading applications...</p> : query.isError ? <p className="error" role="alert">{query.error.message}</p> :
      <div className="review-layout"><section className="application-list" aria-label="Applications"><div className="table-scroll"><table><thead><tr><th>Applicant</th><th>Transport</th><th>Status</th><th>Submitted</th><th>Review</th></tr></thead>
        <tbody>{visible.map((item) => <tr key={item.id} className={selectedId === item.id ? 'active-row' : ''}>
          <td><button className="row-link" disabled={review.isPending} onClick={() => selectApplication(item.id)}>{item.identity_info.fullName ?? 'Applicant'}</button><small>{item.legacy_user_id?'Mobile account - ':''}{item.id.slice(0, 8)}</small></td>
          <td>{words(item.transport_info.transportType ?? 'Unspecified')}</td><td><span className={`status status-${item.status}`}>{statusLabel(item.status)}</span></td>
          <td>{new Date(item.submitted_at??item.created_at).toLocaleDateString()}</td><td><button className="secondary-button" aria-label={`Review application for ${item.identity_info.fullName ?? 'Applicant'}`} disabled={review.isPending} onClick={() => selectApplication(item.id)}>Review application</button></td></tr>)}</tbody></table></div>
        {visible.length === 0 && <p className="state-message">No matching applications.</p>}
        <div className="pagination"><span>Page {offset / 30 + 1}</span><button className="icon-button" title="Previous page" aria-label="Previous page" disabled={offset === 0} onClick={() => { setOffset(Math.max(0, offset - 30)); setSelectedId(null); }}><ChevronLeft size={18} /></button>
          <button className="icon-button" title="Next page" aria-label="Next page" disabled={applications.length < 30} onClick={() => { setOffset(offset + 30); setSelectedId(null); }}><ChevronRight size={18} /></button></div>
      </section><aside ref={reviewPanel} className="review-panel" aria-label="Application review">{selected ? <>
        <h2>{selected.identity_info.fullName ?? 'Applicant'}</h2><span className={`status status-${selected.status}`}>{statusLabel(selected.status)}</span>
        {selected.legacy_account_email&&<p>{selected.legacy_account_email}</p>}
        <dl><dt>Date of birth</dt><dd>{selected.identity_info.dateOfBirth ?? 'Not supplied'}</dd><dt>Transport</dt><dd>{words(selected.transport_info.transportType ?? 'Unspecified')}</dd></dl>
        <h3>Safety Declarations</h3><ul className="declarations">{Object.entries(selected.safety_declarations).map(([name, accepted]) => <li key={name}><Check size={16} className={accepted ? 'accepted' : 'muted'} />{name.replace(/([A-Z])/g, ' $1')}</li>)}</ul>
        <h3>Documents</h3>{!selected.documents?.length&&<p>No documents uploaded.</p>}<div className="documents">{selected.documents?.map((document) => <div className="document-row" key={document.id}><span>{words(document.document_type)}<small>{document.upload_verified_at ? `${Math.ceil(document.size_bytes / 1024)} KB` : 'Awaiting upload'}</small></span>
          <button className="icon-button" title="Open document" aria-label={`Open ${words(document.document_type)}`} disabled={!document.upload_verified_at || opening !== null} onClick={() => void openDocument(document.id)}><ExternalLink size={17} /></button></div>)}</div>
        {documentError && <p className="error" role="alert">{documentError}</p>}
        {selected.review_notes && <p className="review-notes">{selected.review_notes}</p>}
        {selfReview && <p className="error" role="alert">You cannot review your own deliverer application. Sign in with a different authorized reviewer account. A Super Admin can assign the Verification Agent role to another account under Administrators.</p>}
        {selected.status === 'not_started' && <p className="state-message">This application is a draft. The applicant must upload the required documents and submit it before you can approve or reject it.</p>}
        {selected.status === 'rejected' && <p className="state-message">This application was rejected. The applicant can correct their details and submit it again.</p>}
        {actions.length > 0 && <form className="review-form" onSubmit={(event) => {
          event.preventDefault();
          const decision = ((event.nativeEvent as SubmitEvent).submitter as HTMLButtonElement | null)?.value;
          if (decision && actions.includes(decision) && !review.isPending && !selfReview) review.mutate(decision);
        }}>
          <h3>Review decision</h3>
          <p>{['pending_approval','submitted'].includes(selected.status) ? 'Check the details and documents, then start review to enable approval. You can reject an unsuitable application now.' : selected.status === 'under_review' ? 'Approve only after verifying the identity, documents and safety declarations. Approval grants deliverer access in the app.' : 'Changes to deliverer access take effect in the app after its next status refresh.'}</p>
          <label>Review notes<textarea value={notes} minLength={3} maxLength={4000} required onChange={(event) => setNotes(event.target.value)} /></label>
          <small>Enter at least 3 characters. Rejection notes are shared with the applicant.</small>
          <div className="review-actions">{actions.map(value => <button key={value} className={['rejected','suspended'].includes(value) ? 'secondary-button reject-button' : 'primary-button'} type="submit" value={value} disabled={review.isPending || selfReview || notes.trim().length < 3}>{actionLabels[value]}</button>)}</div>
          {review.isPending && <p role="status">Saving decision...</p>}
          {review.isError && <p className="error" role="alert">{review.error.message}</p>}
        </form>}
      </> : <p className="state-message">Choose Review application beside an applicant to inspect their documents and approve or reject their application.</p>}</aside></div>}
  </>;
}
