"use client";
import Link from 'next/link';
import {useState} from 'react';
import {Logo,Icon} from './Brand';

export default function MarketingNav(){
 const [open,setOpen]=useState(false);
 const close=()=>setOpen(false);
 return <header className="marketing-nav">
   <div className="marketing-nav-inner">
     <Logo />
     <nav className={`marketing-links ${open?'open':''}`} aria-label="Primary navigation">
       <a href="#features" onClick={close}>Features</a>
       <a href="#solutions" onClick={close}>Solutions</a>
       <a href="#pricing" onClick={close}>Pricing</a>
       <Link href="/login" onClick={close}>Login</Link>
       <Link href="/signup" className="nav-cta" onClick={close}>Get Started <Icon name="arrow" size={16}/></Link>
     </nav>
     <button className="mobile-menu" aria-label={open?'Close menu':'Open menu'} onClick={()=>setOpen(!open)}><Icon name={open?'close':'menu'} size={22}/></button>
   </div>
 </header>
}
