import { useEffect,useState } from 'react';
import { KeyRound } from 'lucide-react';
import { setInvitedPassword } from './api';
import brand from '../../assets/brand/movetraq-mark.svg';

export function Invitation() {
  const [token]=useState(()=>{
    const fragment=new URLSearchParams(window.location.hash.slice(1));
    return fragment.get('type')==='invite' ? fragment.get('access_token') : null;
  });
  const [password,setPassword]=useState('');const [confirmation,setConfirmation]=useState('');
  const [busy,setBusy]=useState(false);const [done,setDone]=useState(false);const [error,setError]=useState('');
  useEffect(()=>{window.history.replaceState(null,'','/accept-invitation');},[]);
  return <main className="login-page"><div className="login-brand"><img src={brand} alt="MoveTraq"/><span>MoveTraq</span></div>
    <form className="login-form" onSubmit={async event=>{
      event.preventDefault();if(!token || busy)return;
      if(password!==confirmation){setError('Passwords do not match.');return;}
      setBusy(true);setError('');
      try{await setInvitedPassword(token,password);setPassword('');setConfirmation('');setDone(true);}
      catch(failure){setError((failure as Error).message);}finally{setBusy(false);}
    }}><h1>{done?'Account Ready':'Accept Invitation'}</h1>
      {done?<><p>Your password has been set.</p><a href="/">Sign in</a></>:!token?<><p className="error" role="alert">This invitation is missing or invalid. Request a new invitation.</p><a href="/">Return to sign in</a></>:<>
        <label>Password<input required type="password" minLength={12} maxLength={128} autoComplete="new-password" value={password} disabled={busy} onChange={event=>setPassword(event.target.value)}/></label>
        <label>Confirm password<input required type="password" minLength={12} maxLength={128} autoComplete="new-password" value={confirmation} disabled={busy} onChange={event=>setConfirmation(event.target.value)}/></label>
        <button className="primary-button" disabled={busy}><KeyRound size={18}/>{busy?'Saving...':'Set password'}</button>
      </>}{error&&<p className="error" role="alert">{error}</p>}</form>
  </main>;
}
