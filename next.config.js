/** @type {import('next').NextConfig} */
const nextConfig={
  reactStrictMode:true,
  poweredByHeader:false,
  async headers(){return [{source:'/:path*',headers:[
    {key:'X-Content-Type-Options',value:'nosniff'},
    {key:'X-Frame-Options',value:'DENY'},
    {key:'Referrer-Policy',value:'strict-origin-when-cross-origin'},
    {key:'Permissions-Policy',value:'camera=(),microphone=(),geolocation=()'},
    {key:'Strict-Transport-Security',value:'max-age=31536000; includeSubDomains'},
    {key:'X-DNS-Prefetch-Control',value:'on'},
    {key:'Content-Security-Policy',value:"default-src 'self'; img-src 'self' data: blob: https:; font-src 'self' data: https://fonts.gstatic.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self' https: wss:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"}
  ]}]}
};
module.exports=nextConfig;
