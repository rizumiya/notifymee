# 🚀 Notifymee (NotifyMe) — Android Notification Gateway to Webhooks

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Kotlin](https://img.shields.io/badge/Kotlin-2.x-7F52FF?logo=kotlin&logoColor=white)](https://kotlinlang.org)
[![Android](https://img.shields.io/badge/Android-10%2B%20%7C%2014%2B%20%7C%20HyperOS-3DDC84?logo=android&logoColor=white)](https://developer.android.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-teal.svg)](LICENSE)
[![Status: Production Ready](https://img.shields.io/badge/Status-Persistent%2024%2F7-brightgreen.svg)](#arsitektur-tahan-banting-persistent)

**Notifymee** adalah gateway notifikasi Android modern dan berkinerja tinggi yang menangkap notifikasi perangkat secara *real-time* dan meneruskannya ke *webhook server*, n8n, Zapier, Make, Telegram bot, atau REST API backend kustom Anda.

Dibangun dengan arsitektur **Pure Native Interception (Kotlin)** dan antarmuka manajemen modern berbasis **Flutter Material 3**, Notifymee dirancang agar **tahan banting (persistent)** dan tetap beroperasi di latar belakang bahkan saat aplikasi ditutup atau dibersihkan dari layar *Recent Apps*.

---

## 📸 Tampilan Antarmuka (Screenshots)

<div align="center">
  <table>
    <tr>
      <td align="center"><b>Dashboard & Status Gateway</b></td>
      <td align="center"><b>Aturan & Editor Webhook Baru</b></td>
      <td align="center"><b>Menu Khusus Blacklist & Export/Import</b></td>
    </tr>
    <tr>
      <td><img src="docs/screenshots/dashboard.png" width="280" alt="Dashboard Screen"/></td>
      <td><img src="docs/screenshots/rules.png" width="280" alt="Rules & Editor Screen"/></td>
      <td><img src="docs/screenshots/blacklist.png" width="280" alt="Blacklist Screen"/></td>
    </tr>
    <tr>
      <td align="center"><b>Riwayat Log & Retry Manual</b></td>
      <td align="center"><b>Panduan Setup & OEM Resilience</b></td>
      <td align="center"><b>Koleksi Preset Siap Import</b></td>
    </tr>
    <tr>
      <td><img src="docs/screenshots/logs.png" width="280" alt="Logs Screen"/></td>
      <td><img src="docs/screenshots/guide.png" width="280" alt="Guide Screen"/></td>
      <td align="left">
        📂 <b>Folder <a href="presets/"><code>/presets/</code></a></b>:<br/><br/>
        • <code>whatsapp_chat_dan_antispam.json</code><br/>
        • <code>mutasi_qris_dana_bca_gopay.json</code><br/>
        • <code>otp_verifikasi_universal.json</code><br/>
        • <code>telegram_bot_gateway.json</code>
      </td>
    </tr>
  </table>
</div>

---

## ⚡ Fitur Utama (Core Features)

- 🔒 **Arsitektur Pure Native (Kotlin) Tahan Banting**: Logika penerimaan notifikasi (`NotificationListenerService`), pencocokan filter, dan pengiriman HTTP POST berjalan 100% di sisi Native Android (Kotlin). Webhook tetap terkirim meskipun UI utama ditutup.
- 🎯 **Rule Engine & Regex Filter**:
  - Filter berdasarkan aplikasi (`package_name`) atau semua aplikasi (`*`).
  - Filter teks menggunakan pola RegEx fleksibel dengan *Named Capture Groups* (`(?<nama>...)`) & *Numbered Groups*.
  - Ekstraksi otomatis token OTP, nominal transfer bank/QRIS, status order, dan pesan sensitif.
- 🚫 **Menu Khusus Per-Package Keyword Blacklist**:
  - Tab navigasi tersendiri (**Blacklist**) untuk mengelola kata kunci pengecualian per aplikasi maupun global (`*`) tanpa harus masuk ke menu Log terlebih dahulu.
  - Dilengkapi **Template Filter Spam 1-Ketuk** (seperti *"Memeriksa pesan baru"*, *"WhatsApp Web sedang aktif"*, *"Mencadangkan pesan"*).
- 📦 **Export & Import Pengaturan Package (Custom Filename + Koleksi `/presets/`)**:
  - Ekspor aturan webhook sekaligus daftar blacklist per aplikasi ke file `.json` dengan **nama file kustom** sesuai keinginan Anda.
  - Tersedia koleksi konfigurasi siap pakai di folder [`/presets/`](presets/) yang dapat langsung diimpor ke aplikasi.
- 💬 **WhatsApp Multi-Message Auto-Extractor**:
  - Secara cerdas membedah tumpukan notifikasi pesan WhatsApp (`MessagingStyle`) menjadi entri obrolan individual, lengkap dengan pencegah duplikasi (*Deduplication Cache*).
- 🔄 **Auto-Rebind & Keep-Alive Engine**:
  - Implementasi `onTaskRemoved` dan `onDestroy` dengan `requestRebind(ComponentName)`.
  - Terintegrasi dengan Foreground Service (`START_STICKY`), `PARTIAL_WAKE_LOCK` saat layar mati (*Doze Mode*), dan `FOREGROUND_SERVICE_SPECIAL_USE` (Android 14+ / HyperOS).
  - Fitur **Tekan Kembali 2x untuk Keluar** agar aplikasi tidak tertutup secara tidak sengaja.
- 💾 **Penyimpanan Offline SQLite Terbuka (WAL Mode)**:
  - Aturan filter, riwayat pengiriman, payload JSON, dan blacklist disimpan di SQLite lokal (`WRITE_AHEAD_LOGGING`) yang aman diakses bersamaan oleh UI dan Background Service.
- 🌐 **Bilingual (Indonesian & English)**:
  - Tersedia tombol cepat ganti bahasa langsung di AppBar tanpa harus membuka pengaturan perangkat.

---

## 📂 Koleksi Preset Siap Import (`/presets/`)

Repositori ini menyediakan kumpulan file konfigurasi JSON siap pakai di dalam folder [`/presets/`](presets/) yang menggabungkan **Aturan Webhook** dan **Blacklist Kata Kunci**:

| Nama File Preset | Target Package | Kegunaan Utama |
| :--- | :--- | :--- |
| [`whatsapp_chat_dan_antispam.json`](presets/whatsapp_chat_dan_antispam.json) | `com.whatsapp` | Meneruskan chat masuk WhatsApp + otomatis memblokir spam sistem (*"Memeriksa pesan baru"*, *"Mencadangkan pesan"*, *"WhatsApp Web sedang aktif"*). |
| [`mutasi_qris_dana_bca_gopay.json`](presets/mutasi_qris_dana_bca_gopay.json) | `id.dana, com.bca, com.gojek.app, ...` | Mengekstrak nominal Rupiah (`Rp ...`) dari notifikasi pembayaran QRIS, e-Wallet, dan mobile banking. |
| [`otp_verifikasi_universal.json`](presets/otp_verifikasi_universal.json) | `*` (Semua Aplikasi) | Mendeteksi & mengekstrak kode OTP 4–8 digit secara otomatis ke variabel `{{group1}}`. |
| [`telegram_bot_gateway.json`](presets/telegram_bot_gateway.json) | `org.telegram.messenger` | Meneruskan pesan notifikasi masuk menjadi pesan chat langsung ke Bot Telegram (`api.telegram.org`). |

---

## 🏗️ Diagram Arsitektur Sistem

```mermaid
flowchart TD
    subgraph AndroidOS["Android OS / HyperOS Framework"]
        NM["NotificationManager (WA, Bank, SMS)"]
        NLS["NotificationListenerService Binder"]
    end

    subgraph NativeService["Notifymee Native Layer (Pure Kotlin)"]
        SRV["NotificationService (START_STICKY)"]
        FGS["Foreground Service (Ongoing Status)"]
        DEDUP["Deduplication Cache (30s)"]
        DB[("Local SQLite Database\n(Rules, Logs, Blacklist)")]
        MATCHER["Rule Engine & Blacklist Filter"]
        HTTP["Async HTTP Dispatcher (HttpURLConnection)"]
    end

    subgraph External["External Webhooks & Automation"]
        N8N["n8n Workflow / Automations"]
        API["Custom REST API (Node/PHP/Python)"]
        TG["Telegram / Discord Bot"]
    end

    subgraph FlutterUI["UI Layer (Management)"]
        DASH["Dashboard & Live Metrics"]
        RULES_UI["Rule & Regex Editor"]
        BL_UI["Dedicated Blacklist Manager"]
        LOGS_UI["Log Inspector & Manual Retry"]
    end

    NM -->|Post Notification| NLS
    NLS -->|IPC Binder Event| SRV
    SRV -->|Ongoing Notification| FGS
    SRV -->|Deduplicate| DEDUP
    DEDUP -->|Check Blacklist & Rules| DB
    DB -->|Active Rules| MATCHER
    MATCHER -->|Send JSON Payload| HTTP
    HTTP -->|POST Request| N8N
    HTTP -->|POST Request| API
    HTTP -->|POST Request| TG
    HTTP -->|Record Dispatch Result| DB
    DB -.->|Live Sync| FlutterUI
```

---

## 📡 Format Payload JSON Universal

Setiap notifikasi yang cocok dengan aturan akan dikirimkan ke URL Webhook target dengan *HTTP POST (application/json)*:

```json
{
  "event": "notification_received",
  "timestamp": 1793983285397,
  "datetime": "2026-11-06T23:41:25.397+0700",
  "app": {
    "package_name": "com.whatsapp",
    "app_name": "WhatsApp"
  },
  "notification": {
    "title": "Budi Santoso",
    "text": "Halo, transfer sudah dikirim ya!",
    "big_text": "Halo, transfer sudah dikirim ya! Cek mutasi Rp 500.000",
    "sub_text": "",
    "full_content": "Budi Santoso Halo, transfer sudah dikirim ya!",
    "is_group_summary": false
  },
  "rule": {
    "id": "rule_01_wa",
    "name": "Penerus Notifikasi WhatsApp"
  },
  "matches": {
    "has_regex": true,
    "regex_pattern": "transfer.*?Rp\\s*(?<nominal>[\\d.]+)",
    "groups": [
      {
        "name": "nominal",
        "value": "500.000"
      }
    ]
  }
}
```

---

## 🛡️ Panduan Ketahanan Latar Belakang (OEM Resilience)

### Cara Menjaga Notifymee Berjalan 24/7 di Xiaomi / HyperOS / MIUI / Oppo / Vivo:
1. **Izinkan Notifikasi Notifymee**: Jangan matikan notifikasi aplikasi Notifymee di Pengaturan HP. Jika tidak ingin notifikasi mengganggu bilah status, ubah ke **Hening / Senyap (Silent)**. Notifikasi ini adalah jangkar *Foreground Service* agar layanan gateway tidak ikut mati di latar belakang saat daftar aplikasi dibersihkan.
2. **Kunci Notifymee di Layar Recent Apps**:
   - Buka layar *Recent Apps* (multitasking).
   - Tekan dan tahan (atau geser ke bawah) pada jendela kartu Notifymee.
   - Ketuk ikon **Gembok (Lock 🔒)** agar Notifymee tidak ikut mati saat tombol *"Bersihkan Semua" (Clear All)* ditekan.
3. **Mulai Otomatis (Autostart)**: Buka *Info Aplikasi* -> aktifkan *Mulai Otomatis (Autostart)*.
4. **Penghemat Baterai**: Pilih **Tidak ada pembatasan (No restrictions)**.

---

## 🛠️ Contoh Webhook Handler Server

### 1. Node.js (Express)
```javascript
const express = require('express');
const app = express();
app.use(express.json());

app.post('/webhook/notifications', (req, res) => {
  const { event, app: sourceApp, notification, rule, matches } = req.body;
  
  console.log(`[${sourceApp.app_name}] ${notification.title}: ${notification.text}`);
  
  if (matches.has_regex) {
    console.log("Matched Groups:", matches.groups);
  }

  res.status(200).json({ status: 'ok', received_at: new Date().toISOString() });
});

app.listen(3000, () => console.log('Webhook server running on port 3000'));
```

### 2. Python (FastAPI)
```python
from fastapi import FastAPI, Request
import uvicorn

app = FastAPI()

@app.post("/webhook/notifications")
async def receive_notification(request: Request):
    payload = await request.json()
    app_info = payload.get("app", {})
    notif = payload.get("notification", {})
    
    print(f"[{app_info.get('app_name')}] {notif.get('title')}: {notif.get('text')}")
    return {"status": "success"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

### 3. PHP
```php
<?php
header('Content-Type: application/json');

$input = file_get_contents('php://input');
$data = json_decode($input, true);

if ($data) {
    $appName = $data['app']['app_name'] ?? 'Unknown';
    $title = $data['notification']['title'] ?? '';
    $text = $data['notification']['text'] ?? '';
    
    file_put_contents('notifications.log', date('c') . " - [$appName] $title: $text\n", FILE_APPEND);
    echo json_encode(['status' => 'success']);
} else {
    http_response_code(400);
    echo json_encode(['status' => 'invalid_json']);
}
```

---

## 📦 Cara Membangun dari Source Code

### Prasyarat
- Flutter SDK 3.24+
- Android SDK 34 / 35
- Java 17

### Perintah Build
```bash
# Clone repository
git clone https://github.com/rizumiya/notifymee.git
cd notifymee

# Unduh dependencies Flutter
flutter pub get

# Jalankan unit & widget tests
flutter test

# Build APK Debug (Khusus ARM64)
flutter build apk --target-platform android-arm64 --debug

# Install ke perangkat via ADB
adb install -r -d build/app/outputs/flutter-apk/app-debug.apk
```

---

## 📄 Lisensi

Proyek ini dirilis di bawah lisensi [MIT](LICENSE). Bebas digunakan, dimodifikasi, dan didistribusikan untuk keperluan pribadi maupun komersial.
