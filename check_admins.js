const SUPABASE_URL = 'https://opdeyfbbkcuqljgjldys.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wZGV5ZmJia2N1cWxqZ2psZHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxNDU1ODEsImV4cCI6MjA5NzcyMTU4MX0.ORIxfisjAaoxvKI7PWEGk0tPS_cP0rvG_Ytio7h4xCc';

async function check() {
  const adminRes = await fetch(`${SUPABASE_URL}/rest/v1/admins?select=*`, {
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${ANON_KEY}` }
  });
  console.log('admins:', await adminRes.json());

  const appRes = await fetch(`${SUPABASE_URL}/rest/v1/approved_users?select=*`, {
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${ANON_KEY}` }
  });
  console.log('approved_users:', await appRes.json());
}
check();
