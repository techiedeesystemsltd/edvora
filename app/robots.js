export default function robots(){const base=process.env.NEXT_PUBLIC_APP_URL||'https://edvora.vercel.app';return {rules:{userAgent:'*',allow:'/'},sitemap:`${base}/sitemap.xml`}}
