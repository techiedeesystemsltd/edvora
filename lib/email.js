export async function sendEmail({to,subject,html}){
 if(!process.env.RESEND_API_KEY||!process.env.EMAIL_FROM)return {sent:false,reason:'email_not_configured'};
 const response=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:`Bearer ${process.env.RESEND_API_KEY}`,'Content-Type':'application/json'},body:JSON.stringify({from:process.env.EMAIL_FROM,to:Array.isArray(to)?to:[to],subject,html})});const json=await response.json();if(!response.ok)throw new Error(json.message||'Email delivery failed.');return {sent:true,id:json.id};
}
