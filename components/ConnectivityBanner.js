"use client";
import {useEffect,useState} from 'react';
export default function ConnectivityBanner(){const [offline,setOffline]=useState(false);useEffect(()=>{const sync=()=>setOffline(!navigator.onLine);sync();window.addEventListener('online',sync);window.addEventListener('offline',sync);return()=>{window.removeEventListener('online',sync);window.removeEventListener('offline',sync)}},[]);if(!offline)return null;return <div className="connectivity-banner" role="status" aria-live="polite">You’re offline. Edvora will keep supported entries locally until your connection returns.</div>}
