"use client";
import {useEffect,useState} from 'react';
import AppShell from '../../components/AppShell';
import {useSchoolContext} from '../../lib/useSchoolContext';
import {LoadingState,ErrorState} from '../../components/DataStates';

export default function Operations(){
 const {supabase,school,schoolId,role,loading,error,reload}=useSchoolContext();
 const [data,setData]=useState({notifications:[],webhooks:[],backups:[],incidents:[],exports:[],imports:[]}); const [notice,setNotice]=useState('');
 async function load(){if(!supabase||!schoolId)return; const q=async(table,order='created_at')=>{const r=await supabase.from(table).select('*').eq('school_id',schoolId).order(order,{ascending:false}).limit(12);return r.error?[]:r.data||[]};
  const [notifications,webhooks,backups,incidents,exports,imports]=await Promise.all([q('notification_deliveries'),q('webhook_events'),q('backup_operations'),q('system_incidents'),q('data_exports'),q('import_jobs')]); setData({notifications,webhooks,backups,incidents,exports,imports});
 }
 useEffect(()=>{load().catch(e=>setNotice(e.message)); if(!supabase||!schoolId)return; const channel=supabase.channel(`ops-${schoolId}`).on('postgres_changes',{event:'*',schema:'public',table:'notification_deliveries',filter:`school_id=eq.${schoolId}`},()=>load()).on('postgres_changes',{event:'*',schema:'public',table:'system_incidents'},()=>load()).subscribe(); return()=>{supabase.removeChannel(channel)}},[supabase,schoolId]);
 if(loading)return <LoadingState label="Loading operations…"/>; if(error)return <ErrorState message={error} onRetry={reload}/>;
 const failed=data.notifications.filter(x=>['failed','bounced'].includes(x.status)).length;
 return <AppShell active="Operations" schoolName={school?.name} role={role}><div className="app-page-head"><div><h1>Operations</h1><p>One place to see delivery, imports, backups, incidents and platform health.</p></div><button className="app-button" onClick={()=>load()}>Refresh</button></div>{notice&&<div className="notice error">{notice}</div>}
 <div className="app-grid-4"><div className="app-stat"><small>Notification failures</small><strong>{failed}</strong><em>{failed?'Review delivery queue':'No recent failures'}</em></div><div className="app-stat"><small>Webhook events</small><strong>{data.webhooks.length}</strong><em>Recent provider events</em></div><div className="app-stat"><small>Backups</small><strong>{data.backups.length}</strong><em>Recorded operations</em></div><div className="app-stat"><small>Open incidents</small><strong>{data.incidents.filter(x=>!['resolved','closed'].includes(x.status)).length}</strong><em>Needs attention</em></div></div>
 <div className="app-content-grid" style={{marginTop:14}}><section className="app-panel"><div className="app-panel-head"><h2>Delivery queue</h2><span>{data.notifications.length} recent</span></div>{data.notifications.length?data.notifications.map(x=><div className="data-row" key={x.id}><div><strong>{x.channel||'notification'} · {x.status||'queued'}</strong><small>{x.recipient||x.recipient_address||'Recipient not recorded'}</small></div><span>{x.created_at?new Date(x.created_at).toLocaleString():''}</span></div>):<p className="muted-copy">No notification deliveries recorded yet.</p>}</section>
 <section className="app-panel"><div className="app-panel-head"><h2>Reliability</h2><span>Recent signals</span></div>{[...data.imports,...data.backups,...data.exports].slice(0,12).map((x,i)=><div className="data-row" key={x.id||i}><div><strong>{x.status||'queued'}</strong><small>{x.file_name||x.operation_type||x.export_type||'Operation'}</small></div><span>{x.created_at?new Date(x.created_at).toLocaleString():''}</span></div>)}{!data.imports.length&&!data.backups.length&&!data.exports.length&&<p className="muted-copy">No operational jobs recorded yet.</p>}</section></div>
 <section className="app-panel" style={{marginTop:14}}><div className="app-panel-head"><h2>Incident register</h2><span>School-scoped</span></div>{data.incidents.length?data.incidents.map(x=><div className="data-row" key={x.id}><div><strong>{x.title||x.incident_type||'Incident'}</strong><small>{x.status} · {x.severity||'normal'}</small></div><span>{x.created_at?new Date(x.created_at).toLocaleString():''}</span></div>):<p className="muted-copy">No incidents recorded.</p>}</section>
 </AppShell>
}
