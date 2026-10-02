import Link from 'next/link';
import {createClient} from '@supabase/supabase-js';

export function publicSupabase(){
  const url=process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
  const key=(process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY||process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY||process.env.SUPABASE_ANON_KEY)?.trim();
  if(!url||!key) throw new Error('Supabase public configuration is missing.');
  return createClient(url,key,{auth:{autoRefreshToken:false,persistSession:false}});
}

export async function getPublicSchool(slug){
 const supabase=publicSupabase();
 const {data:school,error}=await supabase.from('schools').select('id,name,slug,status,logo_path').eq('slug',slug).in('status',['active','trialing']).maybeSingle();
 if(error) throw error;
 if(!school) return null;
 const [w,p,n,g,st]=await Promise.all([
  supabase.from('website_settings').select('*').eq('school_id',school.id).eq('is_published',true).maybeSingle(),
  supabase.from('website_pages').select('*').eq('school_id',school.id).eq('published',true).order('sort_order').order('title'),
  supabase.from('website_news').select('*').eq('school_id',school.id).eq('published',true).order('published_at',{ascending:false}).limit(6),
  supabase.from('website_gallery').select('*').eq('school_id',school.id).eq('published',true).order('sort_order').limit(12),
  supabase.from('website_staff').select('*').eq('school_id',school.id).eq('published',true).order('sort_order').limit(12)
 ]);
 for(const x of [w,p,n,g,st]) if(x.error) throw x.error;
 if(!w.data) return {school,web:null,pages:[],news:[],gallery:[],staff:[]};
 const web=w.data;
 const asset=(path)=>{if(!path)return '';return supabase.storage.from('school-branding').getPublicUrl(path).data?.publicUrl||''};
 return {school,web,pages:p.data||[],news:n.data||[],gallery:g.data||[],staff:st.data||[],logoUrl:asset(school.logo_path),heroUrl:asset(web.hero_image_path),ogUrl:asset(web.og_image_path)};
}

export default function PublicSchoolSite({data}){
 if(!data) return <main className="public-school"><div className="public-school-inner"><h1>School not found</h1><p>The school website you requested does not exist or is not publicly available.</p><Link href="/">Return to Edvora</Link></div></main>;
 const {school,web,pages,news,gallery,staff,logoUrl,heroUrl}=data;
 if(!web) return <main className="public-school"><div className="public-school-inner"><h1>{school.name}</h1><p>This school website is not published yet.</p><Link href="/">Powered by Edvora</Link></div></main>;
 const primary=web.primary_color||'#3882F6', accent=web.accent_color||'#A3E635';
 const socials=web.social_links||{};
 return <main className="public-school" style={{'--school-primary':primary,'--school-accent':accent}}>
  <nav className="public-school-nav"><Link className="public-school-brand" href={`/school/${school.slug}`} aria-label={`${school.name} home`}>{logoUrl?<img src={logoUrl} alt=""/>:<span className="public-school-logo-fallback"/>}<strong>{school.name}</strong></Link><div className="public-school-links">{pages.map(p=><a href={`#${p.slug}`} key={p.slug}>{p.title}</a>)}{web.admissions_enabled&&<Link href={`/school/${school.slug}/apply`}>Apply</Link>}<Link href={`/contact/${school.slug}`}>Contact</Link></div></nav>
  <section className="public-school-hero" style={heroUrl?{backgroundImage:`url(${heroUrl})`,backgroundSize:'cover',backgroundPosition:'center'}:{}}><div className="public-school-hero-overlay"/><div className="public-school-hero-content"><div><span>{web.site_title||school.name}</span><h1>{web.headline||'Everything your child needs to thrive.'}</h1><p>{web.subheadline||'A modern learning community built around every student.'}</p><div className="public-school-actions">{web.admissions_enabled&&<Link href={`/school/${school.slug}/apply`} className="app-button primary">Apply for admission</Link>}<Link href={`/contact/${school.slug}`} className="app-button">Contact school</Link></div></div></div></section>
  {web.welcome_message&&<section className="public-school-section intro"><p>{web.welcome_message}</p></section>}
  {web.principal_message&&<section className="public-school-section"><div className="public-school-copy"><span className="public-eyebrow">Principal's message</span><h2>Welcome to {school.name}</h2><p>{web.principal_message}</p></div></section>}
  {(pages||[]).map(p=><section className="public-school-section" id={p.slug} key={p.id}><div className="public-school-copy"><span className="public-eyebrow">{p.title}</span><h2>{p.title}</h2><p>{p.body}</p></div></section>)}
  {staff.length>0&&<section className="public-school-section"><div className="public-school-copy"><span className="public-eyebrow">Our people</span><h2>Meet the school team</h2></div><div className="public-card-grid">{staff.map(x=>{const photo=x.photo_path?supabaseAsset(x.photo_path):'';return <article className="public-card" key={x.id}>{photo&&<img src={photo} alt={x.name}/>}<h3>{x.name}</h3><strong>{x.role_title||'Staff'}</strong>{x.bio&&<p>{x.bio}</p>}</article>})}</div></section>}
  {news.length>0&&<section className="public-school-section"><div className="public-school-copy"><span className="public-eyebrow">School news</span><h2>What's happening</h2></div><div className="public-card-grid">{news.map(x=><article className="public-card" key={x.id}><small>{x.published_at?new Date(x.published_at).toLocaleDateString():''}</small><h3>{x.title}</h3><p>{x.excerpt||x.body.slice(0,180)}</p></article>)}</div></section>}
  {gallery.length>0&&<section className="public-school-section"><div className="public-school-copy"><span className="public-eyebrow">Gallery</span><h2>School life</h2></div><div className="public-gallery">{gallery.map(x=><img key={x.id} src={supabaseAsset(x.image_path)} alt={x.alt_text||x.caption||school.name}/>)}</div></section>}
  <section className="public-school-section public-cta"><div><h2>Ready to learn more?</h2><p>Speak with {school.name} about admissions, tours and the school year.</p></div><div className="public-school-actions">{web.admissions_enabled&&<Link href={`/school/${school.slug}/apply`} className="app-button primary">Apply now</Link>}<Link href={`/contact/${school.slug}`} className="app-button">Contact</Link></div></section>
  <footer className="public-school-footer"><div><strong>{school.name}</strong><span>{web.address||''}</span></div><div><span>{web.contact_email||''}</span><span>{web.contact_phone||''}</span></div><div>{Object.entries(socials).filter(([,v])=>v).map(([k,v])=><a key={k} href={String(v)} target="_blank" rel="noreferrer">{k}</a>)}</div><small>Powered by Edvora</small></footer>
 </main>;
}

function supabaseAsset(path){
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL?.trim(); const key=(process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY||process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY||process.env.SUPABASE_ANON_KEY)?.trim();
 if(!url||!key||!path)return ''; return createClient(url,key,{auth:{persistSession:false}}).storage.from('school-branding').getPublicUrl(path).data?.publicUrl||'';
}
