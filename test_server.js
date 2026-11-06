/**
 * Test Webhook Server (Node.js)
 * Server lokal mandiri tanpa dependensi luar untuk menguji webhook NotifWebhook Gateway.
 * Jalankan: node test_server.js
 */

const http = require('http');
const PORT = 5000;

const server = http.createServer((req, res) => {
  if (req.method === 'POST') {
    let body = '';

    req.on('data', chunk => {
      body += chunk.toString();
    });

    req.on('end', () => {
      const timestamp = new Date().toISOString();
      console.log('\n' + '='.repeat(60));
      console.log(`[${timestamp}] WEBHOOK DITERIMA!`);
      console.log(`Endpoint: ${req.url}`);

      const signature = req.headers['x-webhook-signature'];
      if (signature) {
        console.log(`Signature (HMAC-SHA256): ${signature}`);
      }

      try {
        const payload = JSON.parse(body);
        const appInfo = payload.app || {};
        const notif = payload.notification || {};
        const rule = payload.rule || {};
        const matches = payload.matches || {};

        console.log(`Aplikasi : ${appInfo.app_name || '-'} (${appInfo.package_name || '-'})`);
        console.log(`Aturan   : ${rule.name || '-'}`);
        console.log(`Judul    : ${notif.title || '(Kosong)'}`);
        console.log(`Pesan    : ${notif.text || '-'}`);
        if (matches.groups && matches.groups.length > 0) {
          console.log(`Grup Regex:`, matches.groups);
        }
        console.log('-'.repeat(60));
        console.log('Raw JSON Payload:');
        console.log(JSON.stringify(payload, null, 2));
      } catch (e) {
        console.log('Raw Body (Bukan JSON):', body);
      }

      console.log('='.repeat(60) + '\n');

      // Kirim respon HTTP 200 OK
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        status: 'success',
        message: 'Webhook diterima dengan baik oleh server Node.js',
        received_at: timestamp
      }));
    });
  } else {
    // GET request untuk health check
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ready', message: 'Test webhook server is running' }));
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`=== TEST WEBHOOK SERVER AKTIF DI PORT ${PORT} ===`);
  console.log(`Gunakan URL ini di HP Anda (ganti IP dengan IP LAN komputer Anda):`);
  console.log(`http://<IP_KOMPUTER_ANDA>:${PORT}/api/webhook`);
  console.log('Menunggu webhook masuk... (Tekan Ctrl+C untuk berhenti)\n');
});

