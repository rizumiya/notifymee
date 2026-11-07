# 📦 Kumpulan Preset Pengaturan Package Notifymee (`/presets`)

Folder ini berisi kumpulan file konfigurasi `.json` (**Aturan Webhook + Blacklist Kata Kunci per Package**) yang siap diimpor langsung ke dalam aplikasi **Notifymee**.

## Daftar File Preset Siap Pakai

| Nama File | Target Package | Deskripsi |
| :--- | :--- | :--- |
| [`whatsapp_chat_dan_antispam.json`](./whatsapp_chat_dan_antispam.json) | `com.whatsapp` | Meneruskan pesan masuk WhatsApp ke webhook sekaligus mem-blacklist notifikasi sistem seperti *"Memeriksa pesan baru"*, *"Checking for new messages"*, *"WhatsApp Web sedang aktif"*, dan *"Mencadangkan pesan"*. |
| [`mutasi_qris_dana_bca_gopay.json`](./mutasi_qris_dana_bca_gopay.json) | `id.dana, com.bca, com.gojek.app, com.ovo.id` | Mengekstrak nominal pembayaran QRIS / transfer (`Rp ...`) secara otomatis ke variabel `{{nominal}}` dan mengabaikan notifikasi promo/voucher. |
| [`otp_verifikasi_universal.json`](./otp_verifikasi_universal.json) | `*` (Semua Aplikasi) | Mengekstrak kode OTP 4–8 digit secara otomatis ke variabel `{{otp}}` dari SMS, WhatsApp, Telegram, atau Email. |
| [`telegram_bot_gateway.json`](./telegram_bot_gateway.json) | `org.telegram.messenger` | Meneruskan pesan Telegram ke endpoint webhook dengan filter status koneksi latar belakang (*"Updating..."*, *"Connecting..."*). |

## Cara Mengimpor ke Aplikasi Notifymee

1. Buka aplikasi **Notifymee** -> masuk ke tab **Aturan** atau **Blacklist**.
2. Ketuk ikon **Impor Package (`📥`)** di pojok kanan atas.
3. Anda dapat:
   - Memilih langsung dari daftar **Preset Siap Pakai** di dalam dialog aplikasi,
   - Memilih file `.json` yang sudah diunduh dari folder `presets/` ini melalui tombol **Pilih File JSON**, atau
   - Menempelkan isi JSON secara langsung.
4. Sesuaikan `webhookUrl` dengan URL endpoint server Anda (misalnya n8n, Make, Zapier, atau REST API pribadi).

## Cara Mengekspor Pengaturan Package Anda Sendiri

1. Buka tab **Aturan** -> ketuk ikon **Ekspor Package (`📤`)** di pojok kanan atas.
2. Masukkan **Nama File Export** sesuai keinginan Anda (misal: `pengaturan_toko_saya.json`).
3. Pilih apakah ingin mengekspor **Semua Package** atau **Package Tertentu** beserta daftar **Blacklist Kata Kunci**-nya.
4. Ketuk **Simpan File (.json)** untuk menyimpan file ke perangkat atau **Salin JSON**.
