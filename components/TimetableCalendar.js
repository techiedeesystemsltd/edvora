"use client";
import {useEffect,useMemo,useState} from 'react';
import {LoadingState,ErrorState,EmptyState} from './DataStates';
import {useSchoolContext} from '../lib/useSchoolContext';

const days=[['1','Monday'],['2','Tuesday'],['3','Wednesday'],['4','Thursday'],['5','Friday']];
const blank={class_id:'',subject_id:'',teacher_user_id:'',day_of_week:'1',period_label:'Period 1',starts_at:'08:00',ends_at:'09:00',room:''};
function minutes(value){const [h,m]=String(value||'00:00').split(':').map(Number);return (h||0)*60+(m||0)}
function formatTime(value){if(!value)return '';const [h,m]=String(value).slice(0,5).split(':').map(Number);const d=new Date(2000,0,1,h,m);return d.toLocaleTimeString([], {hour:'numeric',minute:'2-digit'})}

export default function TimetableCalendar(){
 const {supabase,school,schoolId,user,role,loading,error,reload}=useSchoolContext();
 const admin=['owner','admin'].includes(role);
 const teacher=role==='teacher';
 const [classes,setClasses]=useState([]),[subjects,setSubjects]=useState([]),[teachers,setTeachers]=useState([]),[rows,setRows]=useState([]),[assignments,setAssignments]=useState([]);
 const [selectedClass,setSelectedClass]=useState(''),[editing,setEditing]=useState(null),[form,setForm]=useState(blank),[saving,setSaving]=useState(false),[notice,setNotice]=useState(''),[busy,setBusy]=useState(true);
 async function load(){
   if(!supabase||!schoolId)return;
   setBusy(true);setNotice('');
   try{
     const queries=[
       supabase.from('timetables').select('*,classes(name),subjects(name),teacher_user_id').eq('school_id',schoolId).order('day_of_week').order('starts_at'),
       supabase.from('subjects').select('id,name').eq('school_id',schoolId).order('name')
     ];
     if(admin) queries.push(supabase.from('classes').select('id,name').eq('school_id',schoolId).order('name'));
     if(admin) queries.push(supabase.from('staff_profiles').select('user_id,full_name').eq('school_id',schoolId).eq('staff_type','teacher').not('user_id','is',null).order('full_name'));
     if(teacher) queries.push(supabase.from('teacher_subject_assignments').select('subject_id,class_id,subjects(name),classes(name)').eq('school_id',schoolId).eq('teacher_user_id',user.id));
     const results=await Promise.all(queries);
     for(const r of results)if(r.error)throw r.error;
     const [t,s,c,st,a]=results;
     setRows(t.data||[]);setSubjects(s.data||[]);
     if(admin){setClasses(c?.data||[]);setTeachers(st?.data||[]);if(!selectedClass&&c?.data?.[0])setSelectedClass(c.data[0].id)}
     if(teacher)setAssignments(a?.data||[]);
   }catch(e){setNotice(e.message||'Unable to load timetable.')}finally{setBusy(false)}
 }
 useEffect(()=>{load()},[supabase,schoolId,role,user?.id]);
 const visibleRows=useMemo(()=>{
   if(admin)return rows.filter(r=>!selectedClass||r.class_id===selectedClass);
   if(teacher){
     if(!assignments.length)return [];
     return rows.filter(r=>assignments.some(a=>a.subject_id===r.subject_id&&(!a.class_id||a.class_id===r.class_id)));
   }
   return rows;
 },[rows,selectedClass,assignments,admin,teacher]);
 const slots=useMemo(()=>Array.from(new Map(visibleRows.map(r=>[`${r.starts_at}-${r.ends_at}`,{starts_at:r.starts_at,ends_at:r.ends_at}])).values()).sort((a,b)=>minutes(a.starts_at)-minutes(b.starts_at)),[visibleRows]);
 function openNew(day='1',slot){setEditing('new');setForm({...blank,class_id:selectedClass||classes[0]?.id||'',day_of_week:day,starts_at:slot?.starts_at||'08:00',ends_at:slot?.ends_at||'09:00'});setNotice('')}
 function openEdit(row){setEditing(row.id);setForm({class_id:row.class_id||'',subject_id:row.subject_id||'',teacher_user_id:row.teacher_user_id||'',day_of_week:String(row.day_of_week),period_label:row.period_label||'Period',starts_at:String(row.starts_at||'08:00').slice(0,5),ends_at:String(row.ends_at||'09:00').slice(0,5),room:row.room||''});setNotice('')}
 async function save(e){e.preventDefault();if(!admin)return;setSaving(true);setNotice('');try{
   const payload={...form,school_id:schoolId,day_of_week:Number(form.day_of_week),class_id:form.class_id||null,subject_id:form.subject_id||null,teacher_user_id:form.teacher_user_id||null};
   const q=editing&&editing!=='new'?supabase.from('timetables').update(payload).eq('id',editing).eq('school_id',schoolId):supabase.from('timetables').insert(payload);
   const {error}=await q;if(error)throw error;
   if(payload.teacher_user_id&&payload.subject_id&&payload.class_id){
     const {error:assignmentError}=await supabase.from('teacher_subject_assignments').upsert({school_id:schoolId,teacher_user_id:payload.teacher_user_id,subject_id:payload.subject_id,class_id:payload.class_id},{onConflict:'school_id,teacher_user_id,subject_id,class_id'});
     if(assignmentError)throw assignmentError;
   }
   setEditing(null);setForm(blank);await load();
 }catch(e){setNotice(e.message)}finally{setSaving(false)}}
 async function remove(id){if(!admin)return;setSaving(true);try{const {error}=await supabase.from('timetables').delete().eq('id',id).eq('school_id',schoolId);if(error)throw error;await load();if(editing===id)setEditing(null)}catch(e){setNotice(e.message)}finally{setSaving(false)}}
 if(loading||busy)return <LoadingState label="Loading timetable…"/>;
 if(error)return <ErrorState message={error} onRetry={reload}/>;
 return <>
   <div className="app-page-head"><div><h1>{teacher?'My teaching timetable':'Class timetable'}</h1><p>{teacher?'See only the subject periods assigned to you. Timetable changes are managed by school administrators.':'Select a class to view its weekly timetable. Build and manage periods from one interactive calendar.'}</p></div></div>
   {notice&&<div className="notice error">{notice}</div>}
   {admin&&<div className="app-panel timetable-toolbar"><div className="form-label"><label>Class</label><select value={selectedClass} onChange={e=>setSelectedClass(e.target.value)}><option value="">All classes</option>{classes.map(c=><option key={c.id} value={c.id}>{c.name}</option>)}</select></div><div className="timetable-toolbar-copy"><strong>{classes.find(c=>c.id===selectedClass)?.name||'All classes'}</strong><span>{visibleRows.length} periods scheduled</span></div><button className="app-button primary" onClick={()=>openNew('1')}>Add period</button></div>}
   {teacher&&<div className="app-panel timetable-teacher-info"><strong>Teacher view</strong><span>{assignments.length} subject assignment{assignments.length===1?'':'s'} · read only</span></div>}
   <div className="app-panel timetable-panel">
    <div className="timetable-scroll"><table className="timetable-grid"><thead><tr><th className="time-col">Time</th>{days.map(([id,label])=><th key={id}>{label}</th>)}</tr></thead><tbody>
      {slots.length?slots.map(slot=><tr key={`${slot.starts_at}-${slot.ends_at}`}><td className="time-cell"><strong>{formatTime(slot.starts_at)}</strong><span>{formatTime(slot.ends_at)}</span></td>{days.map(([day])=>{const cell=visibleRows.filter(r=>String(r.day_of_week)===day&&String(r.starts_at||'').slice(0,5)===String(slot.starts_at||'').slice(0,5));return <td key={day} className="timetable-cell" onDoubleClick={()=>admin&&!cell.length&&openNew(day,slot)}>{cell.map(r=><div className="timetable-entry" key={r.id} onClick={()=>admin&&openEdit(r)}><strong>{r.subjects?.name||'Unassigned subject'}</strong><span>{r.period_label}</span><small>{r.classes?.name||'Class'}{r.room?` · ${r.room}`:''}</small>{admin&&<button type="button" onClick={e=>{e.stopPropagation();remove(r.id)}}>Remove</button>}</div>)}{admin&&!cell.length&&<button className="timetable-add-cell" onClick={()=>openNew(day,slot)}>+ Add</button>}</td>})}</tr>):<tr><td colSpan="6"><EmptyState title={teacher?'No subject periods assigned':'No timetable entries'} description={admin?'Add the first period for the selected class.':'Ask an administrator to assign your subjects and add timetable periods.'}/></td></tr>}
    </tbody></table></div>
   </div>
   {admin&&editing&&<div className="app-panel timetable-editor"><div className="app-panel-head"><h2>{editing==='new'?'Add timetable period':'Edit timetable period'}</h2><span>Only school administrators can change the timetable.</span></div><form className="data-form" onSubmit={save}><div className="form-label"><label>Class</label><select required value={form.class_id} onChange={e=>setForm({...form,class_id:e.target.value})}><option value="">Select class</option>{classes.map(c=><option key={c.id} value={c.id}>{c.name}</option>)}</select></div><div className="form-label"><label>Subject</label><select required value={form.subject_id} onChange={e=>setForm({...form,subject_id:e.target.value})}><option value="">Select subject</option>{subjects.map(s=><option key={s.id} value={s.id}>{s.name}</option>)}</select></div><div className="form-label"><label>Teacher</label><select value={form.teacher_user_id} onChange={e=>setForm({...form,teacher_user_id:e.target.value})}><option value="">Unassigned</option>{teachers.map(t=><option key={t.user_id} value={t.user_id}>{t.full_name}</option>)}</select></div><div className="form-label"><label>Day</label><select value={form.day_of_week} onChange={e=>setForm({...form,day_of_week:e.target.value})}>{days.map(([id,label])=><option key={id} value={id}>{label}</option>)}</select></div><div className="form-label"><label>Period</label><input required value={form.period_label} onChange={e=>setForm({...form,period_label:e.target.value})}/></div><div className="form-label"><label>Start</label><input required type="time" value={form.starts_at} onChange={e=>setForm({...form,starts_at:e.target.value})}/></div><div className="form-label"><label>End</label><input required type="time" value={form.ends_at} onChange={e=>setForm({...form,ends_at:e.target.value})}/></div><div className="form-label"><label>Room</label><input value={form.room} onChange={e=>setForm({...form,room:e.target.value})}/></div><div className="form-actions"><button type="button" className="app-button" onClick={()=>setEditing(null)}>Cancel</button><button className="app-button primary" disabled={saving}>{saving?'Saving…':editing==='new'?'Add period':'Save changes'}</button></div></form></div>}
 </>
}
