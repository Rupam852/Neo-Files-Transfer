const SUPABASE_URL = 'https://opdeyfbbkcuqljgjldys.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wZGV5ZmJia2N1cWxqZ2psZHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxNDU1ODEsImV4cCI6MjA5NzcyMTU4MX0.ORIxfisjAaoxvKI7PWEGk0tPS_cP0rvG_Ytio7h4xCc';

async function check() {
  const tRes = await fetch(`${SUPABASE_URL}/rest/v1/user_fcm_tokens?select=*`, {
    headers: {
      'apikey': ANON_KEY,
      'Authorization': `Bearer ${ANON_KEY}`
    }
  });
  console.log('user_fcm_tokens status:', tRes.status, await tRes.json());

  const lRes = await fetch(`${SUPABASE_URL}/rest/v1/file_download_logs?select=*&order=downloaded_at.desc&limit=5`, {
    headers: {
      'apikey': ANON_KEY,
      'Authorization': `Bearer ${ANON_KEY}`
    }
  });
  console.log('file_download_logs status:', lRes.status, await lRes.json());
}
check();
