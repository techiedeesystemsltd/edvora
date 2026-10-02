'use client';
import { useEffect, useState } from 'react';
import { getCurrentContext } from './school';

export function useSchoolContext(){
  const [ctx,setCtx]=useState(null); const [loading,setLoading]=useState(true); const [error,setError]=useState('');
  async function load(){setLoading(true);setError('');try{setCtx(await getCurrentContext())}catch(e){setError(e?.message||'Unable to load your school.')}finally{setLoading(false)}}
  useEffect(()=>{load()},[]);
  return {...(ctx||{}),loading,error,reload:load};
}
