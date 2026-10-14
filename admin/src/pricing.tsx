import { useEffect, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Save, RefreshCw } from 'lucide-react';
import { request, type PricingRule, type PricingConfiguration, type StaffUser } from './api';

const fields: { key: Exclude<keyof PricingConfiguration, 'vehicleBps'>; label: string; min: number; max: number }[] = [
  { key: 'baseMinor', label: 'Base fee (kobo)', min: 0, max: 100000000 }, { key: 'perKmMinor', label: 'Per kilometre (kobo)', min: 0, max: 100000000 },
  { key: 'perMinuteMinor', label: 'Per minute (kobo)', min: 0, max: 100000000 }, { key: 'minimumMinor', label: 'Minimum fee (kobo)', min: 1, max: 100000000 },
  { key: 'helperMinor', label: 'Per helper (kobo)', min: 0, max: 100000000 }, { key: 'stairsMinor', label: 'Stairs per end (kobo)', min: 0, max: 100000000 },
  { key: 'platformFeeBps', label: 'Platform fee (basis points)', min: 0, max: 9999 }, { key: 'surgeBps', label: 'Surge (basis points)', min: 10000, max: 50000 },
  { key: 'maxDistanceMeters', label: 'Maximum distance (metres)', min: 1, max: 1000000 },
];
export function Pricing({ user }: { user: StaffUser }) {
  const queryClient = useQueryClient();
  const [serviceType, setServiceType] = useState('express');
  const [draft, setDraft] = useState<Record<string, string>>({});
  const query = useQuery({ queryKey: ['pricing', user.uid], queryFn: () => request<{ rules: PricingRule[] }>('/admin/pricing-rules') });
  const current = query.data?.rules.find((rule) => rule.service_type === serviceType);
  useEffect(() => {
    const configuration = current?.configuration;
    const next: Record<string, string> = {};
    for (const field of fields) next[field.key] = configuration ? String(configuration[field.key]) : '';
    for (const vehicle of ['car', 'van', 'large_van'] as const) next[vehicle] = configuration ? String(configuration.vehicleBps[vehicle]) : '';
    setDraft(next);
  }, [serviceType, current]);
  const save = useMutation({ mutationFn: () => {
    const configuration = Object.fromEntries(fields.map((field) => [field.key, Number(draft[field.key])])) as unknown as PricingConfiguration;
    configuration.vehicleBps = { car: Number(draft.car), van: Number(draft.van), large_van: Number(draft.large_van) };
    return request('/admin/pricing-rules', 'POST', { serviceType, configuration });
  }, onSuccess: async () => { await queryClient.invalidateQueries({ queryKey: ['pricing', user.uid] }); } });
  return <><div className="page-heading"><div><h1>Service Pricing</h1><p>NGN tariffs</p></div><button className="icon-button" title="Refresh pricing" aria-label="Refresh pricing" onClick={() => void query.refetch()} disabled={query.isFetching}><RefreshCw size={18} /></button></div>
    <div className="toolbar"><label className="service-select">Service<select value={serviceType} onChange={(event) => { setServiceType(event.target.value); save.reset(); }}><option value="p2p">P2P</option><option value="express">Express</option><option value="errand">Errands</option><option value="big_move">Big moves</option></select></label>
      {query.data && <span className={`status ${current ? 'status-approved' : 'status-not_started'}`}>{current ? 'Active tariff' : 'Not configured'}</span>}</div>
    {query.isPending ? <p className="state-message">Loading tariffs...</p> : query.isError ? <p className="error" role="alert">{query.error.message}</p> :
      <form className="pricing-form" onSubmit={(event) => { event.preventDefault(); save.mutate(); }}>
        <div className="pricing-fields">{fields.map((field) => <label key={field.key}>{field.label}<input type="number" step="1" required min={field.min} max={field.max} value={draft[field.key] ?? ''} onChange={(event) => setDraft({ ...draft, [field.key]: event.target.value })} /></label>)}</div>
        <h2>Vehicle Multipliers</h2><div className="pricing-fields">{(['car', 'van', 'large_van'] as const).map((vehicle) => <label key={vehicle}>{vehicle.replace(/_/g, ' ')} (basis points)<input type="number" step="1" required min={10000} max={50000} value={draft[vehicle] ?? ''} onChange={(event) => setDraft({ ...draft, [vehicle]: event.target.value })} /></label>)}</div>
        <button className="primary-button" disabled={save.isPending} type="submit"><Save size={17} />{save.isPending ? 'Saving...' : 'Activate tariff'}</button>
        {save.isError && <p className="error" role="alert">{save.error.message}</p>}{save.isSuccess && <p className="success" role="status">Tariff activated.</p>}
      </form>}
  </>;
}
