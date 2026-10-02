"use client";
import {useEffect,useState} from 'react';
import AppShell from '../../components/AppShell';
import {useSchoolContext} from '../../lib/useSchoolContext';
import {createClient} from '../../lib/supabase';
import {EmptyState,LoadingState} from '../../components/DataStates';

export default function Assignments(){
 const {school,role}=useSchoolContext();
 const [rows,setRows]=useState([]),[classes,setClasses]=useState([]),[subjects,setSubjects]=useState([]),[students,setStudents]=useState([]),[submissions,setSubmissions]=useState([]);
 const [form,setForm]=useState({title:'',description:'',class_id:'',subject_id:'',due_at:'',max_score:100});
 const [schoolId,setSchoolId]=useState(null),[busy,setBusy]=useState(false),[error,setError]=useState(''),[notice,setNotice]=useState(''),[selected,setSelected]=useState(null);
 const canManage=['School Owner','Admin','Bursar','admin','school_owner'].includes(role)||String(role||'').toLowerCase().includes('admin');
 async function load(){
  const s=createClient();const {data:{user}}=await s.auth.getUser();if(!user)return;
  const {data:m}=await s.from('school_memberships').select('school_id,role').eq('user_id',user.id).eq('status','active').limit(1).maybeSingle();if(!m)return;
  setSchoolId(m.school_id);
  const [a,c,sub,st]=await Promise.all([
   s.from('assignments').select('*,classes(name),subjects(name)').eq('school_id',m.school_id).order('created_at',{ascending:false}),
   s.from('classes').select('id,name').eq('school_id',m.school_id).order('name'),
   s.from('subjects').select('id,name').eq('school_id',m.school_id).order('name'),
   s.from('students').select('id,first_name,last_name,admission_number,class_id').eq('school_id',m.school_id).order('last_name').order('first_name')
  ]);
  if(a.error)throw a.error;if(c.error)throw c.error;if(sub.error)throw sub.error;if(st.error)throw st.error;
  setRows(a.data||[]);setClasses(c.data||[]);setSubjects(sub.data||[]);setStudents(st.data||[]);
 }
 async function loadSubmissions(assignment){
  setSelected(assignment);setNotice('');setError('');
  const s=createClient();const {data,error}=await s.from('assignment_submissions').select('*,students(first_name,last_name,admission_number)').eq('school_id',schoolId).eq('assignment_id',assignment.id).order('created_at');
  if(error)setError(error.message);else setSubmissions(data||[]);
 }
 useEffect(()=>{load().catch(e=>setError(e.message))},[]);
 async function create(e){e.preventDefault();setBusy(true);setError('');setNotice('');const s=createClient();const {data:{user}}=await s.auth.getUser();const {error}=await s.from('assignments').insert({...form,school_id:schoolId,teacher_id:user?.id,status:'published',max_score:Number(form.max_score)||100});if(error)setError(error.message);else{setNotice('Assignment published.');setForm({title:'',description:'',class_id:'',subject_id:'',due_at:'',max_score:100});await load()}setBusy(false)}
 async function grade(id,score,feedback){
  const s=createClient();const n=Number(score);if(Number.isNaN(n)||n<0||n>Number(selected.max_score||100)){setError(`Score must be between 0 and ${selected.max_score||100}.`);return}
  const {data:{user}}=await s.auth.getUser();const {error}=await s.from('assignment_submissions').update({score:n,feedback:feedback||null,graded_by:user?.id,graded_at:new Date().toISOString(),status:'returned'}).eq('id',id).eq('school_id',schoolId);if(error)setError(error.message);else{setNotice('Submission graded.');await loadSubmissions(selected)}
 }
 return <AppShell active="Assignments" schoolName={school?.name} role={role}>
  <div className="app-page-head"><div><h1>Assignments</h1><p>Create, publish, collect and grade classwork in one workflow.</p></div></div>
  {error&&<div className="notice error">{error}</div>}{notice&&<div className="notice success">{notice}</div>}
  <div className="split-grid">
   <section className="app-panel"><h2>Create assignment</h2>{canManage||String(role||'').toLowerCase().includes('teacher')?<form className="data-form" onSubmit={create}><div className="form-label"><label>Title</label><input required value={form.title} onChange={e=>setForm({...form,title:e.target.value})}/></div><div className="form-label"><label>Due</label><input type="datetime-local" value={form.due_at} onChange={e=>setForm({...form,due_at:e.target.value})}/></div><div className="form-label"><label>Class</label><select required value={form.class_id} onChange={e=>setForm({...form,class_id:e.target.value})}><option value="">Choose class</option>{classes.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></div><div className="form-label"><label>Subject</label><select required value={form.subject_id} onChange={e=>setForm({...form,subject_id:e.target.value})}><option value="">Choose subject</option>{subjects.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></div><div className="form-label full"><label>Instructions</label><textarea rows="4" value={form.description} onChange={e=>setForm({...form,description:e.target.value})}/></div><div className="form-label"><label>Maximum score</label><input type="number" min="1" value={form.max_score} onChange={e=>setForm({...form,max_score:e.target.value})}/></div><div className="form-actions"><button className="app-button primary" disabled={busy}>{busy?'Publishing…':'Publish assignment'}</button></div></form>:<EmptyState title="Teacher access required" description="Assignments are created by teachers or school administrators."/>}</section>
   <section className="app-panel"><div className="app-panel-head"><h2>Recent assignments</h2><span>{rows.length}</span></div>{rows.length===0?<EmptyState title="No assignments yet" description="Create your first assignment to start tracking student work."/>:<div className="data-list">{rows.map(r=><button type="button" className="data-row" key={r.id} onClick={()=>loadSubmissions(r)} style={{width:'100%',textAlign:'left',background:'transparent',border:0,cursor:'pointer'}}><div><strong>{r.title}</strong><small>{r.subjects?.name||'Subject'} · {r.classes?.name||'Class'} · {r.status} · {r.due_at?new Date(r.due_at).toLocaleString():'No due date'}</small></div><span>{r.max_score||100} pts</span></button>)}</div>}</section>
  </div>
  {selected&&<section className="app-panel" style={{marginTop:14}}><div className="app-panel-head"><div><h2>Submissions: {selected.title}</h2><span>{submissions.length} submission{submissions.length===1?'':'s'}</span></div><button className="app-button" onClick={()=>setSelected(null)}>Close</button></div>{submissions.length===0?<EmptyState title="No submissions yet" description="Students will appear here after they submit this assignment."/>:<div className="data-list">{submissions.map(x=><SubmissionRow key={x.id} row={x} maxScore={selected.max_score||100} onGrade={grade}/>)}</div>}</section>}
 </AppShell>
}
function SubmissionRow({row,maxScore,onGrade}){const [score,setScore]=useState(row.score??''),[feedback,setFeedback]=useState(row.feedback||'');return <div className="data-row" style={{alignItems:'flex-start',gap:16}}><div style={{minWidth:180}}><strong>{row.students?.first_name} {row.students?.last_name}</strong><small>{row.students?.admission_number||''} · {row.status} · {row.submitted_at?new Date(row.submitted_at).toLocaleString():'Not submitted'}</small></div><div style={{flex:1}}><div style={{fontSize:13,whiteSpace:'pre-wrap',marginBottom:8}}>{row.content||'No written response.'}</div>{row.status!=='draft'&&<div className="data-form" style={{gridTemplateColumns:'120px 1fr auto',alignItems:'end'}}><div className="form-label"><label>Score / {maxScore}</label><input type="number" min="0" max={maxScore} value={score} onChange={e=>setScore(e.target.value)}/></div><div className="form-label"><label>Feedback</label><input value={feedback} onChange={e=>setFeedback(e.target.value)} placeholder="Optional feedback"/></div><button className="app-button primary" type="button" onClick={()=>onGrade(row.id,score,feedback)}>Save grade</button></div>}</div></div>}
