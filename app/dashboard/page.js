"use client";
import Link from 'next/link';
import {useEffect,useState} from 'react';
import {createClient} from '../../lib/supabase';
import AppShell from '../../components/AppShell';
import {Icon,Logo} from '../../components/Brand';

export default function Dashboard(){
 const [school,setSchool]=useState(null),[stats,setStats]=useState({students:0,classes:0,fees:0}),[loading,setLoading]=useState(true),[error,setError]=useState('');
  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const supabase = createClient();
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) {
          window.location.assign('/login');
          return;
        }

        const urlParamSchoolId = typeof window !== 'undefined' ? new URLSearchParams(window.location.search).get('school') : null;
        const preferredSchoolId = urlParamSchoolId || (typeof window !== 'undefined' ? localStorage.getItem('edvora.currentSchoolId') : null);
        const membershipQuery = () => supabase
          .from('school_memberships')
          .select('school_id,schools(id,name,slug,logo_path,currency,timezone,status),created_at')
          .eq('user_id', user.id)
          .eq('status', 'active');

        let membership = null;
        if (preferredSchoolId) {
          const { data, error: membershipError } = await membershipQuery().eq('school_id', preferredSchoolId).maybeSingle();
          if (!membershipError && data) membership = data;
        }

        if (!membership) {
          const { data, error: membershipError } = await membershipQuery().order('created_at', { ascending: false }).limit(1).maybeSingle();
          if (membershipError) throw membershipError;
          membership = data;
        }

        if (!membership) {
          if (typeof window !== 'undefined') localStorage.removeItem('edvora.currentSchoolId');
          window.location.assign('/onboarding');
          return;
        }

        if (!active) return;
        localStorage.setItem('edvora.currentSchoolId', membership.school_id);
        setSchool(membership.schools);

        try {
          const [{ count: students }, { count: classes }, { data: fees }] = await Promise.all([
            supabase.from('students').select('*', { count: 'exact', head: true }).eq('school_id', membership.school_id),
            supabase.from('classes').select('*', { count: 'exact', head: true }).eq('school_id', membership.school_id),
            supabase.from('fee_invoices').select('amount,amount_paid').eq('school_id', membership.school_id)
          ]);
          if (active) {
            setStats({
              students: students || 0,
              classes: classes || 0,
              fees: (fees || []).reduce((a, x) => a + Number(x.amount || 0) - Number(x.amount_paid || 0), 0)
            });
          }
        } catch (statsErr) {
          console.warn('Unable to load full dashboard stats:', statsErr);
        }
      } catch (err) {
        if (active) setError(err?.message || 'Unable to load your workspace.');
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => { active = false; };
  }, []);
 async function logout(){try{await createClient().auth.signOut()}finally{window.location.assign('/login')}}
 if(loading)return <div className="loading-page"><Logo/><div className="loading-bar"><span/></div></div>;
 if(error)return <main className="error-page"><div className="error-page-card"><h1>Workspace unavailable.</h1><p>{error}</p><div className="error-page-actions"><button className="app-button primary" onClick={()=>window.location.reload()}>Try again</button><button className="app-button" onClick={logout}>Sign out</button></div></div></main>;
 return <AppShell active="Overview" schoolName={school?.name} onLogout={logout}>
  <div className="app-page-head"><div><h1>Good morning, Admin</h1><p>Here’s what’s happening across {school?.name} today.</p></div><div className="app-head-actions"><button className="app-button">This term</button><Link className="app-button primary" href="/students"><Icon name="plus" size={15}/> Add student</Link></div></div>
  <div className="app-grid-4"><div className="app-stat"><div className="app-stat-top"><span className="stat-icon blue-icon"><Icon name="users" size={16}/></span></div><small>Total students</small><strong>{stats.students.toLocaleString()}</strong><em>+12% from last term</em></div><div className="app-stat"><div className="app-stat-top"><span className="stat-icon lime-icon"><Icon name="users" size={16}/></span></div><small>Active classes</small><strong>{stats.classes}</strong><em>+4% from last term</em></div><div className="app-stat"><div className="app-stat-top"><span className="stat-icon yellow-icon"><Icon name="calendar" size={16}/></span></div><small>Attendance rate</small><strong>96%</strong><em>+2.4% from last term</em></div><div className="app-stat"><div className="app-stat-top"><span className="stat-icon coral-icon"><Icon name="wallet" size={16}/></span></div><small>Outstanding fees</small><strong>₦{stats.fees.toLocaleString()}</strong><em>Needs attention</em></div></div>
  <div className="app-content-grid"><div className="app-panel"><div className="app-panel-head"><h2>Student progress</h2><span>January - June</span></div><div className="bar-chart"><i style={{height:'32%'}}/><i style={{height:'44%'}}/><i style={{height:'51%'}}/><i style={{height:'63%'}}/><i style={{height:'71%'}}/><i style={{height:'88%'}}/></div><div className="bar-labels"><span>Jan</span><span>Feb</span><span>Mar</span><span>Apr</span><span>May</span><span>Jun</span></div></div><div className="app-panel"><div className="app-panel-head"><h2>Today's activity</h2><span>View all</span></div><div className="activity-list"><div className="activity-item"><span className="activity-avatar blue-icon">AO</span><div><strong>New student enrollment</strong><p>Amaka Okafor · SS2A</p></div><time>2h</time></div><div className="activity-item"><span className="activity-avatar lime-icon">RM</span><div><strong>Results published</strong><p>Mathematics · JSS3B</p></div><time>4h</time></div><div className="activity-item"><span className="activity-avatar yellow-icon">PA</span><div><strong>Parent payment recorded</strong><p>₦85,000 · INV-1048</p></div><time>6h</time></div></div></div></div>
  <div className="app-content-grid"><div className="app-panel"><div className="app-panel-head"><h2>Attention required</h2><span>4 items</span></div><div className="attention-list"><Link href="/attendance" className="attention"><span className="attention-mark yellow-icon"><Icon name="calendar" size={15}/></span><div><strong>Attendance is missing</strong><small>JSS2A · today</small></div></Link><Link href="/results" className="attention"><span className="attention-mark coral-icon"><Icon name="chart" size={15}/></span><div><strong>Results need review</strong><small>Mathematics · SS2</small></div></Link><Link href="/fees" className="attention"><span className="attention-mark coral-icon"><Icon name="wallet" size={15}/></span><div><strong>Fee balances overdue</strong><small>12 invoices · 30+ days</small></div></Link></div></div><div className="app-panel"><div className="app-panel-head"><h2>Start here</h2><span>Core setup</span></div><div className="attention-list"><Link href="/students" className="attention"><span className="attention-mark blue-icon"><Icon name="users" size={15}/></span><div><strong>Add students</strong><small>Build the school register</small></div></Link><Link href="/classes" className="attention"><span className="attention-mark lime-icon"><Icon name="class" size={15}/></span><div><strong>Create classes</strong><small>Set up the academic structure</small></div></Link><Link href="/fees" className="attention"><span className="attention-mark yellow-icon"><Icon name="wallet" size={15}/></span><div><strong>Set up fees</strong><small>Track invoices and balances</small></div></Link></div></div></div>
 </AppShell>
}
