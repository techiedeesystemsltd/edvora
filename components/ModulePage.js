import Link from 'next/link';
import {Icon} from './Brand';
import AppShell from './AppShell';

export default function ModulePage({active,title,description,icon='home',accent='blue',actions=[],children,schoolName='Your school',role='School admin'}){
 return <AppShell active={active} schoolName={schoolName} role={role}><div className="app-page-head"><div><h1>{title}</h1><p>{description}</p></div>{actions.length>0&&<div className="app-head-actions">{actions.map((a,i)=>a.href?<Link key={i} href={a.href} className={`app-button ${a.primary?'primary':''}`}>{a.label}</Link>:<button key={i} className={`app-button ${a.primary?'primary':''}`} onClick={a.onClick}>{a.label}</button>)}</div>}</div>{children||<div className="module-placeholder"><div className={`placeholder-icon ${accent==='lime'?'lime-icon':''}`}><Icon name={icon} size={24}/></div><h2>This workspace is ready for the next module.</h2><p>The visual system and navigation are in place so the workflow can be connected without changing the Edvora experience.</p></div>}</AppShell>
}
