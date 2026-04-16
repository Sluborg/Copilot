const url = process.env.FLOW_WEBHOOK_URL;
fetch(url, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ text: 'node test' })
}).then(r => console.log('status:', r.status)).catch(e => console.log('error:', e.message));
