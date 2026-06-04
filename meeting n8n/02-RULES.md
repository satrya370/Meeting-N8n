# RULES.md — Aturan untuk AI CLI Agent

> File ini dibaca oleh AI CLI (Claude Code / OpenCode) sebagai konteks & aturan kerja
> saat membangun otomasi meeting notes. Letakkan di root project. Untuk Claude Code,
> bisa juga di-rename menjadi CLAUDE.md.

---

## Konteks Project

Kamu membantu membangun **otomasi meeting notes** menggunakan n8n. Pipeline-nya:
rekaman → transkripsi (Whisper) → analisis (Claude API) → Notion + Slack.

Baca `01-SDD-meeting-notes.md` untuk desain lengkap sebelum mulai. Ikuti `03-TODO.md`
untuk urutan pengerjaan. Jangan melompat ke task yang belum waktunya.

Deliverable utama: file workflow n8n dalam format JSON yang bisa di-import, plus
kode untuk Code node dan dokumentasi prompt.

---

## Aturan Wajib (Hard Rules)

### Keamanan & kredensial
- JANGAN PERNAH hardcode API key, token, atau secret di workflow JSON atau code node.
- Semua kredensial direferensikan via n8n Credentials store (gunakan placeholder nama credential, bukan nilai asli).
- Jangan menulis transkrip atau isi meeting ke file log atau commit ke git.
- File `.env` dan kredensial masuk `.gitignore`.

### n8n workflow
- Setiap node WAJIB punya nama deskriptif (mis. "Transcribe with Whisper", bukan "HTTP Request").
- Alur harus linear & satu arah sesuai SDD. Tidak ada loop kecuali untuk chunking file besar.
- Node penting (transkripsi, AI, Notion) di-set `Continue On Fail = false`.
- Selalu sertakan Error Trigger workflow terpisah untuk menangkap kegagalan.
- Workflow JSON harus valid dan bisa di-import ke n8n tanpa error parsing.

### Code node (JavaScript)
- Tulis kode yang defensif: validasi input ada sebelum dipakai, beri default jika kosong.
- Bungkus parsing JSON dari AI dalam try-catch (output AI bisa tidak valid).
- Strip markdown fence (```json) dari output AI sebelum parsing.
- Jangan pakai library eksternal yang tidak tersedia di n8n Code node.
- Beri komentar singkat hanya untuk logika yang tidak jelas — jangan over-comment.

### Prompt AI
- Selalu inject transkrip ASLI ke prompt. AI tidak boleh jadi sumber data.
- Temperature rendah (0.1-0.3) untuk ekstraksi faktual.
- Prompt ekstraksi minta output JSON murni tanpa teks tambahan.
- Instruksikan AI mengisi `null` untuk data yang tidak ada — jangan mengarang.

---

## Aturan Kerja (Workflow Rules)

### Sebelum menulis kode
- Konfirmasi dulu tahap mana di TODO yang sedang dikerjakan.
- Jika butuh keputusan desain yang belum ada di SDD, tanya dulu — jangan asumsi.

### Saat menulis
- Kerjakan satu tahap TODO sampai selesai sebelum lanjut.
- Setiap kali menghasilkan workflow JSON, jelaskan node apa saja yang ditambah/diubah.
- Untuk Code node, sertakan contoh input & expected output di komentar atau penjelasan.

### Setelah menulis
- Selalu ingatkan langkah manual yang harus dilakukan user di n8n UI (setup credential, mapping, test).
- Update checklist di `03-TODO.md` jika diminta — tandai yang sudah selesai.
- Jangan klaim sesuatu "sudah jalan" jika belum dites di n8n. Sebut sebagai "siap dites".

---

## Yang TIDAK Boleh Dilakukan

- Jangan membangun fitur di luar scope SDD (Bagian 2) tanpa diminta.
- Jangan mengganti tech stack yang sudah diputuskan (Bagian 4 SDD) tanpa diskusi.
- Jangan menggabung semua tahap sekaligus — ikuti pembagian harian di TODO.
- Jangan auto-publish atau auto-kirim ke production tanpa konfirmasi user.
- Jangan generate workflow JSON yang sangat besar dalam satu output jika bisa dipecah per fase.

---

## Konvensi Penamaan

- Workflow: `meeting-notes-main` (pipeline utama), `meeting-notes-error-handler` (error).
- Node: Title Case deskriptif + kata kerja ("Build Notion Payload", "Post to Slack").
- Credential placeholder: `{{CRED_OPENAI}}`, `{{CRED_ANTHROPIC}}`, `{{CRED_NOTION}}`, `{{CRED_SLACK}}`.
- File: prefix angka untuk urutan (`01-`, `02-`, `03-`).

---

## Definisi "Selesai" (Definition of Done)

Sebuah tahap dianggap selesai jika:
1. Workflow JSON valid & bisa di-import.
2. Code node sudah ada validasi & error handling.
3. User sudah diberi tahu langkah manual yang diperlukan di UI.
4. Tahap tersebut sudah dites dengan minimal 1 data nyata (oleh user).
5. Checklist TODO yang relevan sudah ditandai.
