'use client';
export default function GlobalError({reset}){return <html lang="en"><body><main className="error-page"><div className="error-page-card"><h1>Edvora needs a refresh.</h1><p>The application hit an unexpected error. Refresh the page to continue.</p><button className="app-button primary" onClick={()=>reset()}>Try again</button></div></main></body></html>}
