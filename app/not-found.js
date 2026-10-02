import Link from 'next/link';
import {Logo} from '../components/Brand';
export default function NotFound(){return <main className="error-page"><Logo/><div className="error-card"><div className="error-code">404</div><h1>Page not found</h1><p>The page you requested does not exist or has moved.</p><div className="form-actions"><Link className="app-button primary" href="/">Go to Edvora</Link><Link className="app-button" href="/dashboard">Open dashboard</Link></div></div></main>}
