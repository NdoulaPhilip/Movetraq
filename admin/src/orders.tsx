import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { ChevronLeft, ChevronRight, RefreshCw, X } from 'lucide-react';
import { request } from './api';

interface Order {
  id: string; public_ref: string; service_type: string; status: string;
  total_amount_minor: number; currency: string; payment_status: string; escrow_status: string; created_at: string;
  [key: string]: unknown;
}
interface OrderEvent { id: string; event_type: string; previous_status: string | null; new_status: string | null; created_at: string; }
const statuses = ['draft','pending_payment','awaiting_deliverer','offer_received','deliverer_assigned','accepted',
  'heading_to_pickup','arrived_pickup','picked_up','heading_to_dropoff','arrived_dropoff',
  'awaiting_confirmation','completed','cancelled','rejected','failed','returning','returned','disputed'];
const label = (value: string) => value.replace(/_/g, ' ');
const date = (value: unknown) => typeof value === 'string' ? new Date(value).toLocaleString() : 'Not recorded';
const money = (order: Order) => new Intl.NumberFormat('en-NG', { style: 'currency', currency: order.currency }).format(order.total_amount_minor / 100);
function Fields({ order, fields }: { order: Order; fields: string[] }) {
  return <dl>{fields.map(field => <div className="order-field" key={field}><dt>{label(field)}</dt><dd>{String(order[field] ?? 'Not recorded')}</dd></div>)}</dl>;
}

export function Orders() {
  const [reference, setReference] = useState(''); const [search, setSearch] = useState('');
  const [status, setStatus] = useState(''); const [serviceType, setServiceType] = useState('');
  const [page, setPage] = useState(0); const [selected, setSelected] = useState<string | null>(null);
  const params = new URLSearchParams({ page: String(page) });
  if (search) params.set('reference', search);
  if (status) params.set('status', status);
  if (serviceType) params.set('serviceType', serviceType);
  const list = useQuery({ queryKey: ['managed-orders', params.toString()],
    queryFn: () => request<{ orders: Order[]; total: number }>(`/admin/orders?${params}`) });
  const detail = useQuery({ queryKey: ['managed-order', selected], enabled: !!selected,
    queryFn: () => request<{ order: Order; timeline: OrderEvent[] }>(`/admin/orders/${selected}`) });
  const order = detail.data?.order;
  return <>
    <header className="page-heading"><h1>Order Management</h1><button className="icon-button" title="Refresh orders" onClick={() => { void list.refetch(); if (selected) void detail.refetch(); }}><RefreshCw size={18}/></button></header>
    <form className="toolbar" onSubmit={event => { event.preventDefault(); setSearch(reference.trim()); setPage(0); }}>
      <label>Order reference<input type="search" maxLength={128} pattern="[A-Za-z0-9-]*" value={reference} onChange={event => setReference(event.target.value)}/></label>
      <label>Status<select value={status} onChange={event => { setStatus(event.target.value); setPage(0); }}><option value="">All statuses</option>{statuses.map(value => <option key={value} value={value}>{label(value)}</option>)}</select></label>
      <label>Service<select value={serviceType} onChange={event => { setServiceType(event.target.value); setPage(0); }}><option value="">All services</option>{['p2p','express','errand','big_move'].map(value => <option key={value} value={value}>{label(value)}</option>)}</select></label>
      <button type="submit" className="secondary-button">Search</button>
    </form>
    {list.isPending && <p className="state-message">Loading orders...</p>}
    {list.error && <p className="error" role="alert">{list.error.message}</p>}
    {list.data && <><div className="table-scroll"><table className="directory-table"><thead><tr><th>Reference</th><th>Service</th><th>Status</th><th>Total</th><th>Payment</th><th>Created</th></tr></thead><tbody>{list.data.orders.map(value => <tr key={value.id}><td><button className="row-link" onClick={() => setSelected(value.id)}>{value.public_ref}</button></td><td>{label(value.service_type)}</td><td><span className="status">{label(value.status)}</span></td><td>{money(value)}</td><td>{label(value.payment_status)}</td><td>{date(value.created_at)}</td></tr>)}</tbody></table></div>
      {!list.data.orders.length && <p className="state-message">No matching orders</p>}
      <div className="pagination"><span>{list.data.total} orders</span><button className="icon-button" title="Previous orders" disabled={!page} onClick={() => setPage(page - 1)}><ChevronLeft size={18}/></button><span>Page {page + 1}</span><button className="icon-button" title="Next orders" disabled={(page + 1) * 25 >= list.data.total} onClick={() => setPage(page + 1)}><ChevronRight size={18}/></button></div></>}
    {selected && <section className="user-detail" aria-label="Order inspection"><header className="page-heading"><h2>{order?.public_ref ?? 'Order inspection'}</h2><button className="icon-button" title="Close order" onClick={() => setSelected(null)}><X size={18}/></button></header>
      {detail.isPending && <p className="state-message">Loading order...</p>}
      {detail.error && <p className="error" role="alert">{detail.error.message}</p>}
      {order && <><div className="analytics-band"><div><span>Total</span><strong>{money(order)}</strong></div><div><span>Payment</span><strong>{label(order.payment_status)}</strong></div><div><span>Held funds</span><strong>{label(order.escrow_status)}</strong></div></div>
        <h3>Route</h3><Fields order={order} fields={['pickup_address','destination_address','recipient_name','recipient_phone']}/>
        <h3>Delivery</h3><Fields order={order} fields={['sender_id','deliverer_id','status','evidence_status','issue_status','scheduled_at','scheduled_timezone','cancellation_reason']}/>
        <h3>Timeline (latest 100)</h3>{!detail.data?.timeline.length && <p className="state-message">No recorded events</p>}
        <ol className="order-timeline">{detail.data?.timeline.map(event => <li key={event.id}><strong>{label(event.event_type)}</strong><p>{label(event.previous_status ?? 'none')} to {label(event.new_status ?? 'unchanged')}</p><time dateTime={event.created_at}>{date(event.created_at)}</time></li>)}</ol></>}
    </section>}
  </>;
}
