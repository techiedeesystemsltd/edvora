"use client";
import {useEffect,useState} from 'react';
import AppShell from '../../components/AppShell';
import {LoadingState} from '../../components/DataStates';
import {createClient} from '../../lib/supabase';
import {getCurrentContext} from '../../lib/school';
export default function Profile(){
 const [ctx,setCtx]=useState(null),[form,setForm]=useState({full_name:'',phone:''}),[email,setEmail]=useState(''),[notice,setNotice]=useState(''),[loading,setLoading]=useState(true),[saving,setSaving]=useState(false);
 async function load(){try{const c=await getCurrentContext();setCtx(c);setEmail(c.user.email||'');const {data:p}=await c.supabase.from('profiles').select('*').eq('id',c.user.id).maybeSingle();setForm({full_name:p?.full_name||c.user.user_metadata?.full_name||'',phone:p?.phone||''})}catch(e){setNotice(e.message)}finally{setLoading(false)}}
 useEffect(()=>{load()},[]);
 async function save(e){e.preventDefault();setSaving(true);try{const s=createClient();const {data:{user}}=await s.auth.getUser();const {error}=await s.from('profiles').upsert({id:user.id,full_name:form.full_name,phone:form.phone,email:user.email,updated_at:new Date().toISOString()});if(error)throw error;await s.auth.updateUser({data:{full_name:form.full_name}});setNotice('Profile saved.')}catch(e){setNotice(e.message)}finally{setSaving(false)}}
 async function password(){const {error}=await createClient().auth.resetPasswordForEmail(email,{redirectTo:`${window.location.origin}/reset-password`});setNotice(error?error.message:'Password reset instructions sent to your email.')}
 if(loading)return <LoadingState label="Loading profile…"/>;
 return <AppShell active="Profile" schoolName={ctx?.school?.name} role={ctx?.role==='parent'?'Parent':ctx?.role==='student'?'Student':ctx?.role||'Account'}><div className="app-page-head"><div><h1>Profile</h1><p>Manage your Edvora account details and password.</p></div></div>{notice&&<div className="notice">{notice}</div>}<div className="app-panel"><form onSubmit={save} className="data-form"><div className="form-label full"><label>Email</label><input value={email} disabled/></div><div className="form-label"><label>Full name</label><input value={form.full_name} onChange={e=>setForm({...form,full_name:e.target.value})}/></div><div className="form-label"><label>Phone</label><input value={form.phone} onChange={e=>setForm({...form,phone:e.target.value})}/></div><div className="form-actions"><button className="app-button primary" disabled={saving}>{saving?'Saving…':'Save profile'}</button><button type="button" className="app-button" onClick={password}>Send password reset</button></div></form></div></AppShell>
}
