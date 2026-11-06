#!/usr/bin/env python3
"""
Test Webhook Server (Python 3)
Server sederhana untuk menguji dan menerima webhook dari NotifWebhook Gateway.
Jalankan: python test_server.py
"""
import http.server
import json
import datetime

PORT = 5000

class WebhookHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length).decode('utf-8')

        print("\n" + "=" * 60)
        print(f"[{datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] WEBHOOK DITERIMA!")
        print(f"Endpoint: {self.path}")
        
        sig = self.headers.get('X-Webhook-Signature')
        if sig:
            print(f"Signature (HMAC-SHA256): {sig}")

        try:
            payload = json.loads(post_data)
            app_info = payload.get('app', {})
            notif = payload.get('notification', {})
            rule = payload.get('rule', {})
            matches = payload.get('matches', {})

            print(f"Aplikasi : {app_info.get('app_name')} ({app_info.get('package_name')})")
            print(f"Aturan   : {rule.get('name')}")
            print(f"Judul    : {notif.get('title')}")
            print(f"Pesan    : {notif.get('text')}")
            if matches.get('groups'):
                print(f"Grup Regex: {matches.get('groups')}")
            print("-" * 60)
            print("Raw JSON Payload:")
            print(json.dumps(payload, indent=2))
        except Exception as e:
            print("Raw Data (Non-JSON):", post_data)

        print("=" * 60 + "\n")

        # Response HTTP 200
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        response = json.dumps({
            "status": "success",
            "message": "Webhook diterima dengan baik oleh test server",
            "received_at": datetime.datetime.now().isoformat()
        })
        self.wfile.write(response.encode('utf-8'))

    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{"status":"ready","message":"Test webhook server is running"}')

if __name__ == '__main__':
    server = http.server.HTTPServer(('0.0.0.0', PORT), WebhookHandler)
    print(f"=== TEST WEBHOOK SERVER AKTIF DI PORT {PORT} ===")
    print(f"Gunakan URL ini di HP Anda (ganti IP dengan IP LAN komputer Anda):")
    print(f"http://<IP_KOMPUTER_ANDA>:{PORT}/api/webhook")
    print("Menunggu webhook masuk... (Tekan Ctrl+C untuk berhenti)\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer dihentikan.")

