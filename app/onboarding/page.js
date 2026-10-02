"use client";
import {useEffect,useState} from 'react';
import {createClient} from '../../lib/supabase';
import {Logo} from '../../components/Brand';

const steps=[['School identity','Name and ownership'],['School levels','What levels does your school offer?'],['Location','Timezone and contact details'],['Academic setup','Current academic year'],['Ready','Review and create workspace']];
const ownershipOptions=[['private_school','Private school'],['federal_government','Federal government school'],['state_government','State government school'],['other_public','Other public school']];
const levelOptions=[['nursery','Nursery'],['primary','Primary'],['secondary','Secondary']];

export default function Onboarding(){
 const [step,setStep]=useState(0),[name,setName]=useState(''),[ownership,setOwnership]=useState(''),[levels,setLevels]=useState([]),[timezone,setTimezone]=useState('Africa/Lagos'),[address,setAddress]=useState(''),[phone,setPhone]=useState(''),[academicYear,setAcademicYear]=useState('2026/2027'),[error,setError]=useState(''),[loading,setLoading]=useState(true),[saving,setSaving]=useState(false);
 useEffect(()=>{(async()=>{try{const s=createClient();const {data:{user}}=await s.auth.getUser();if(!user){window.location.assign('/login?next=/onboarding');return}setLoading(false)}catch(e){setError(e.message);setLoading(false)}})()},[]);
 function next(e){
   e?.preventDefault();setError('');
   if(step===0){if(!name.trim())return setError('Enter your school name.');if(!ownership)return setError('Select a school ownership type.')}
   if(step===1&&!levels.length)return setError('Select at least one school level.');
   if(step===3&&!academicYear.trim())return setError('Enter the academic year.');
   setStep(s=>Math.min(4,s+1));
 }
 async function submit(){
   if(saving)return;setSaving(true);setError('');
   try{
     const r=await fetch('/api/onboarding/school',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name,ownership,levels,timezone,address,phone,academicYear})});
     const j=await r.json();if(!r.ok)throw new Error(j.error||'Unable to create your school workspace.');
     if(j.schoolId&&typeof window!=='undefined')localStorage.setItem('edvora.currentSchoolId',j.schoolId);window.location.assign(j.redirect||'/dashboard');
   }catch(e){setError(e.message);setSaving(false)}
 }
 const toggleLevel=(level)=>setLevels(x=>x.includes(level)?x.filter(v=>v!==level):[...x,level]);
 const goBack=()=>setStep(s=>Math.max(0,s-1));
 if(loading)return <div className="loading-page"><div className="edvora-loading"><img src="/favicon.png" alt="Edvora"/><span>Loading setup…</span></div></div>;
 return <div className="onboard-v2">
   <div className="onboard-nav"><Logo/></div>
   <div className="onboard-card">
     <div className="onboard-step">Step {step+1} of {steps.length} · {steps[step][0]}</div>
     <h1>{step===0?'Set up your school.':step===1?'What levels does your school offer?':step===2?'Where is your school based?':step===3?'Set your academic year.':'Review your school setup.'}</h1>
     <p>{steps[step][1]}</p>
     <div className="progress-v2"><span style={{width:`${((step+1)/steps.length)*100}%`}}/></div>
     {error&&<div className="notice error" role="alert">{error}</div>}

     {step===0&&<form className="data-form" onSubmit={next}>
       <div className="form-label full"><label>School name</label><input required autoFocus placeholder="e.g. Your School Name" value={name} onChange={e=>setName(e.target.value)}/></div>
       <div className="form-label full">
         <label>School ownership</label>
         <small className="field-help">Choose who owns or operates the school.</small>
         <div className="choice-grid ownership-grid" role="radiogroup" aria-label="School ownership">
           {ownershipOptions.map(([v,l])=><label className={`choice-card ${ownership===v?'selected':''}`} key={v}>
             <input type="radio" name="school-ownership" value={v} checked={ownership===v} onChange={()=>setOwnership(v)}/><span>{l}</span>
           </label>)}
         </div>
       </div>
       <div className="form-actions"><button className="app-button primary">Continue</button></div>
     </form>}

     {step===1&&<form className="data-form" onSubmit={next}>
       <div className="form-label full">
         <label>School levels</label>
         <small className="field-help">Select every level your school currently operates. You can configure individual JSS/SSS classes later.</small>
         <div className="choice-grid level-grid" aria-label="School levels">
           {levelOptions.map(([v,l])=><label className={`choice-card ${levels.includes(v)?'selected':''}`} key={v}>
             <input type="checkbox" checked={levels.includes(v)} onChange={()=>toggleLevel(v)}/><span>{l}</span>
           </label>)}
         </div>
       </div>
       <div className="form-actions"><button type="button" className="app-button" onClick={goBack}>Back</button><button className="app-button primary">Continue</button></div>
     </form>}

     {step===2&&<form className="data-form" onSubmit={next}>
       <div className="form-label full"><label>Timezone</label><select value={timezone} onChange={e=>setTimezone(e.target.value)}><option value="Africa/Lagos">Africa/Lagos</option><option value="Africa/Accra">Africa/Accra</option><option value="Africa/Abidjan">Africa/Abidjan</option></select></div>
       <div className="form-label full"><label>School address</label><input placeholder="City, state" value={address} onChange={e=>setAddress(e.target.value)}/></div>
       <div className="form-label full"><label>School phone</label><input inputMode="tel" placeholder="0800 000 0000" value={phone} onChange={e=>setPhone(e.target.value)}/></div>
       <div className="form-actions"><button type="button" className="app-button" onClick={goBack}>Back</button><button className="app-button primary">Continue</button></div>
     </form>}

     {step===3&&<form className="data-form" onSubmit={next}>
       <div className="form-label full"><label>Academic year</label><input required placeholder="2026/2027" value={academicYear} onChange={e=>setAcademicYear(e.target.value)}/></div>
       <div className="form-actions"><button type="button" className="app-button" onClick={goBack}>Back</button><button className="app-button primary">Review</button></div>
     </form>}

     {step===4&&<div className="review-list">
       <div className="data-row"><div><strong>{name}</strong><small>{ownershipOptions.find(x=>x[0]===ownership)?.[1]}</small></div></div>
       <div className="data-row"><div><strong>School levels</strong><small>{levels.map(v=>levelOptions.find(x=>x[0]===v)?.[1]).join(', ')}</small></div></div>
       <div className="data-row"><div><strong>Location</strong><small>{address||'Not provided'} · {timezone}</small></div><span>{phone||'No phone'}</span></div>
       <div className="data-row"><div><strong>Academic year</strong><small>{academicYear}</small></div></div>
       <div className="form-actions"><button className="app-button" onClick={goBack}>Back</button><button className="app-button primary" disabled={saving} onClick={submit}>{saving?'Creating workspace…':'Create school workspace'}</button></div>
     </div>}
   </div>
 </div>
}
