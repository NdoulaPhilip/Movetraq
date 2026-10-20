import React, { useState, useSyncExternalStore } from 'react';
import ReactDOM from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Activity as ActivityIcon, Users as UsersIcon, Package, ShieldCheck, BadgeCheck, Banknote, Eye, EyeOff, LifeBuoy, LogIn, LogOut } from 'lucide-react';
import { Orders } from './orders';
import { Users } from './users';
import { Activity } from './activity';
import { MobileOperations,OperationalView } from './mobile-operations';
import { Invitation } from './invitation';
import { authStore, signIn, signOut } from './api';
import { Verification } from './verification';
import { VerificationNotifications } from './verification-notifications';
import { Pricing } from './pricing';
import { Support } from './support';
import brand from '../../assets/brand/movetraq-mark.svg';
import './styles.css';

const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false, refetchOnWindowFocus: true, staleTime: 15000 } } });

function Login() {
  const [email, setEmail] = useState(''); const [password, setPassword] = useState('');
  const [visible, setVisible] = useState(false); const [busy, setBusy] = useState(false); const [error, setError] = useState('');
  return <main className="login-page"><div className="login-brand"><img src={brand} alt="MoveTraq" /><span>MoveTraq Admin</span></div>
    <form className="login-form" onSubmit={async (event) => {
      event.preventDefault(); setBusy(true); setError('');
      try { await signIn(email.trim(), password); setPassword(''); }
      catch (failure) { setError((failure as Error).message); }
      finally { setBusy(false); }
    }}><h1>Staff Sign In</h1><label>Email<input type="email" required autoComplete="username" value={email} onChange={(event) => setEmail(event.target.value)} /></label>
      <label>Password<div className="password-field"><input type={visible ? 'text' : 'password'} required autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} />
        <button type="button" className="icon-button" title={visible ? 'Hide password' : 'Show password'} aria-label={visible ? 'Hide password' : 'Show password'} onClick={() => setVisible(!visible)}>{visible ? <EyeOff size={18} /> : <Eye size={18} />}</button></div></label>
      <button className="primary-button" type="submit" disabled={busy}><LogIn size={18} />{busy ? 'Signing in...' : 'Sign in'}</button>{error && <p className="error" role="alert">{error}</p>}
    </form></main>;
}
function App() {
  const session = useSyncExternalStore(authStore.subscribe, authStore.getSnapshot);
  const [view, setView] = useState('activity');
  if (window.location.pathname==='/accept-invitation') return <Invitation/>;
  if (!session) return <Login />;
  const user = session.user;
  const superAdmin = user.roles.includes('super_admin');
  const orders = user.roles.some((role) => ['operations', 'admin', 'super_admin'].includes(role));
  const verification = user.roles.some((role) => ['verification_agent', 'admin', 'super_admin'].includes(role));
  const pricing = user.roles.some((role) => ['finance', 'admin', 'super_admin'].includes(role));
  const support = user.roles.some((role) => ['support', 'operations', 'finance', 'admin', 'super_admin'].includes(role));
  const views = [superAdmin && 'activity', superAdmin && 'payments', superAdmin && 'users', superAdmin && 'admins', superAdmin && 'audit', verification && 'verification', pricing && 'pricing', support && 'support', orders && 'orders'].filter(Boolean);
  const activeView = views.includes(view) ? view : views[0];
  return <div className="admin-layout"><aside className="sidebar"><div className="console-brand"><img src={brand} alt="MoveTraq" /><span>MoveTraq<small>Admin</small></span></div>
    <nav aria-label="Admin navigation">{verification && <button className={activeView === 'verification' ? 'active' : ''} onClick={() => setView('verification')}><BadgeCheck size={19} />Verification</button>}
      {orders && <button className={activeView === 'orders' ? 'active' : ''} onClick={() => setView('orders')}><Package size={19} />Orders</button>}
      {superAdmin && <button className={activeView === 'payments' ? 'active' : ''} onClick={() => setView('payments')}><Banknote size={19}/>Payments & Wallet</button>}
      {pricing && <button className={activeView === 'pricing' ? 'active' : ''} onClick={() => setView('pricing')}><Banknote size={19} />Pricing</button>}
      {support && <button className={activeView === 'support' ? 'active' : ''} onClick={() => setView('support')}><LifeBuoy size={19} />Support</button>}
      {superAdmin && <><button className={activeView==='activity'?'active':''} onClick={()=>setView('activity')}><ActivityIcon size={19}/>Platform Activity</button><button className={activeView==='users'?'active':''} onClick={()=>setView('users')}><UsersIcon size={19}/>Users</button><button className={activeView==='admins'?'active':''} onClick={()=>setView('admins')}><ShieldCheck size={19}/>Administrators</button><button className={activeView==='audit'?'active':''} onClick={()=>setView('audit')}><ShieldCheck size={19}/>Audit Logs</button></>}</nav>
    <div className="staff-account"><span>{user.name}<small>{user.email}</small></span><button className="icon-button" title="Sign out" aria-label="Sign out" onClick={() => { void queryClient.cancelQueries(); queryClient.clear(); void signOut(); }}><LogOut size={18} /></button></div>
  </aside><main className="workspace">{verification && <VerificationNotifications user={user} onReview={() => setView('verification')}/>}{activeView==='payments'?<MobileOperations key="payments" initialView="payments"/>:activeView==='orders'?(superAdmin?<OperationalView key="orders" initialView="orders"><Orders/></OperationalView>:<Orders/>):activeView==='activity'?<OperationalView key="activity"><Activity/></OperationalView>:activeView==='audit'?<Activity key="audit" audit/>:activeView==='users'?<OperationalView key="users" initialView="users"><Users user={user}/></OperationalView>:activeView==='admins'?<Users key="admins" user={user} staff/>:activeView === 'verification' ? <Verification user={user} /> : activeView === 'pricing' ? <Pricing user={user} /> : superAdmin?<OperationalView key="support" initialView="support_tickets"><Support user={user}/></OperationalView>:<Support user={user}/>}</main></div>;
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}><App /></QueryClientProvider>
  </React.StrictMode>,
);
