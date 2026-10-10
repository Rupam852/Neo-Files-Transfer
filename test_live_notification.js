const SUPABASE_URL = 'https://opdeyfbbkcuqljgjldys.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wZGV5ZmJia2N1cWxqZ2psZHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxNDU1ODEsImV4cCI6MjA5NzcyMTU4MX0.ORIxfisjAaoxvKI7PWEGk0tPS_cP0rvG_Ytio7h4xCc';

async function test() {
  try {
    const res = await fetch(`${SUPABASE_URL}/functions/v1/broadcast-notification`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${ANON_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        title: '📥 Test Download Alert',
        body: 'Test download notification',
        targetType: 'user',
        target: 'test-user-id',
        dataPayload: { type: 'download_alert' }
      })
    });
    console.log('Status:', res.status);
    const text = await res.text();
    console.log('Response:', text);
  } catch (e) {
    console.error('Fetch error:', e);
  }
}
test();
