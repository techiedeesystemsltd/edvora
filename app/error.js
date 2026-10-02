'use client';
import {useEffect} from 'react';
import Link from 'next/link';
export default function GlobalError({error,reset}){useEffect(()=>{console.error(error)},[error]);return <main className="error-page"><div className="error-card"><div className="error-code">500</div><h1>Something went wrong</h1><p>Your work has not been lost. Try again, or return to the dashboard.</p><div className="form-actions"><button className="app-button primary" onClick={()=>reset()}>Try again</button><Link className="app-button" href="/dashboard">Dashboard</Link></div></div></main>}
