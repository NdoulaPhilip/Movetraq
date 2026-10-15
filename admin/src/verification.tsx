import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Check, ChevronLeft, ChevronRight, ExternalLink, RefreshCw, Search } from 'lucide-react';
import { request, type Application, type StaffUser } from './api';

const words = (value: string) => value.replace(/_/g, ' ');
export function Verification({ user }: { user: StaffUser }) {
  const queryClient = useQueryClient();
  const [offset, setOffset] = useState(0);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [filter, setFilter] = useState('pending');
  const [search, setSearch] = useState('');
  const [action, setAction] = useState('');
  const [notes, setNotes] = useState('');
  const [documentError, setDocumentError] = useState('');
  const [opening, setOpening] = useState<string | null>(null);
  const query = useQuery({ queryKey: ['verification', user.uid, offset], queryFn: () =>
    request<{ applications: Application[] }>(`/admin/verification-applications?limit=30&offset=${offset}`),refetchInterval:10000 });
  const applications = query.data?.applications ?? [];
  const visible = applications.filter((item) => (filter !== 'pending' || ['submitted', 'under_review'].includes(item.status)) &&
    `${item.identity_info.fullName ?? ''} ${item.id}`.toLowerCase().includes(search.toLowerCase()));
  const selected = applications.find((item) => item.id === selectedId);
  const review = useMutation({ mutationFn: () => request(`/admin/verification-applications/${selected!.id}/review`, 'POST', { status: action, notes }),
    onSuccess: async () => { setAction(''); setNotes(''); await queryClient.invalidateQueries({ queryKey: ['verification', user.uid] }); } });
  const actions = selected?.status === 'submitted' ? ['under_review', 'rejected'] : selected?.status === 'under_review' ?
    ['approved', 'rejected'] : selected?.status === 'approved' ? ['suspended'] : selected?.status==='suspended'&&selected.legacy_user_id?['under_review']:[];
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
      <button className={filter === 'pending' ? 'selected' : ''} onClick={() => setFilter('pending')}>Pending</button>
      <button className={filter === 'all' ? 'selected' : ''} onClick={() => setFilter('all')}>All</button></div>
      <label className="search"><Search size={17} /><input aria-label="Search applications" placeholder="Search applications" value={search} onChange={(event) => setSearch(event.target.value)} /></label></div>
    {query.isPending ? <p className="state-message" role="status">Loading applications...</p> : query.isError ? <p className="error" role="alert">{query.error.message}</p> :
      <div className="review-layout"><section className="application-list" aria-label="Applications"><div className="table-scroll"><table><thead><tr><th>Applicant</th><th>Transport</th><th>Status</th><th>Submitted</th></tr></thead>
        <tbody>{visible.map((item) => <tr key={item.id} className={selectedId === item.id ? 'active-row' : ''}>
          <td><button className="row-link" onClick={() => { setSelectedId(item.id); setAction(''); setNotes(''); review.reset(); setDocumentError(''); }}>{item.identity_info.fullName ?? 'Applicant'}</button><small>{item.legacy_user_id?'Mobile account - ':''}{item.id.slice(0, 8)}</small></td>
          <td>{words(item.transport_info.transportType ?? 'Unspecified')}</td><td><span className={`status status-${item.status}`}>{words(item.status)}</span></td>
          <td>{new Date(item.created_at).toLocaleDateString()}</td></tr>)}</tbody></table></div>
        {visible.length === 0 && <p className="state-message">No matching applications.</p>}
        <div className="pagination"><span>Page {offset / 30 + 1}</span><button className="icon-button" title="Previous page" aria-label="Previous page" disabled={offset === 0} onClick={() => { setOffset(Math.max(0, offset - 30)); setSelectedId(null); }}><ChevronLeft size={18} /></button>
          <button className="icon-button" title="Next page" aria-label="Next page" disabled={applications.length < 30} onClick={() => { setOffset(offset + 30); setSelectedId(null); }}><ChevronRight size={18} /></button></div>
      </section><aside className="review-panel" aria-label="Application review">{selected ? <>
        <h2>{selected.identity_info.fullName ?? 'Applicant'}</h2><span className={`status status-${selected.status}`}>{words(selected.status)}</span>
        <dl><dt>Date of birth</dt><dd>{selected.identity_info.dateOfBirth ?? 'Not supplied'}</dd><dt>Transport</dt><dd>{words(selected.transport_info.transportType ?? 'Unspecified')}</dd></dl>
        <h3>Safety Declarations</h3><ul className="declarations">{Object.entries(selected.safety_declarations).map(([name, accepted]) => <li key={name}><Check size={16} className={accepted ? 'accepted' : 'muted'} />{name.replace(/([A-Z])/g, ' $1')}</li>)}</ul>
        <h3>Documents</h3><div className="documents">{selected.documents?.map((document) => <div className="document-row" key={document.id}><span>{words(document.document_type)}<small>{document.upload_verified_at ? `${Math.ceil(document.size_bytes / 1024)} KB` : 'Awaiting upload'}</small></span>
          <button className="icon-button" title="Open document" aria-label={`Open ${words(document.document_type)}`} disabled={!document.upload_verified_at || opening !== null} onClick={() => void openDocument(document.id)}><ExternalLink size={17} /></button></div>)}</div>
        {documentError && <p className="error" role="alert">{documentError}</p>}
        {selected.review_notes && <p className="review-notes">{selected.review_notes}</p>}
        {actions.length > 0 && <form className="review-form" onSubmit={(event) => { event.preventDefault(); review.mutate(); }}>
          <label>Decision<select value={action} onChange={(event) => setAction(event.target.value)} required><option value="">Select a decision</option>{actions.map((value) => <option value={value} key={value}>{words(value)}</option>)}</select></label>
          <label>Review notes<textarea value={notes} minLength={3} maxLength={4000} required onChange={(event) => setNotes(event.target.value)} /></label>
          <button className="primary-button" type="submit" disabled={review.isPending || !action || notes.trim().length < 3}><Check size={17} />{review.isPending ? 'Saving...' : 'Save decision'}</button>
          {review.isError && <p className="error" role="alert">{review.error.message}</p>}{review.isSuccess && <p className="success" role="status">Review saved.</p>}
        </form>}
      </> : <p className="state-message">No application selected.</p>}</aside></div>}
  </>;
}
