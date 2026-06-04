# TODO.md — Build Meeting Notes Automation (6 Hari)

> Centang `[x]` setiap task selesai. Kerjakan berurutan. Jangan lompat hari.
> Setiap hari diakhiri dengan checkpoint — pastikan checkpoint hijau sebelum lanjut.
>
> **Hari 1-3:** Core pipeline + kualitas + multi-sumber input (single-tenant, kredensial di n8n store).
> **Hari 4-6:** Ekspansi ke **public trial portfolio** — model gratis (GLM), config Notion/Slack per-user, output Markdown+PDF, deploy publik via tunnel. (Bukan production, hanya trial portfolio.)

---

## HARI 0 — Persiapan ✅ SELESAI

Setup fondasi. Tanpa ini, hari 1 akan macet.

- [x] Siapkan n8n: self-host native Windows (Node.js), berjalan di `localhost:5678`
- [x] Buat akun & dapatkan API key OpenAI/koboillm (untuk Whisper, endpoint: api.koboillm.com/v1, model: openai/whisper-1)
- [x] Ganti Claude → **MiniMax M2.7** sebagai model AI analisis
- [x] Buat Notion integration token di notion.so/my-integrations
- [x] Buat database Notion "Meeting Notes" dengan properti sesuai SDD Bagian 6.2, share ke integration
- [x] Buat Slack app & Bot Token untuk channel target
- [x] Simpan SEMUA kredensial ke n8n Credentials store (OpenAI, MiniMax, Notion, Slack)
- [x] Siapkan file rekaman meeting dari MS Teams sebagai fixture test
- [x] Inisialisasi git repo, tambahkan `.gitignore`, commit dokumen project

**✅ Checkpoint Hari 0:** Semua API key tersimpan di n8n, database Notion siap, file test ada.

---

## HARI 1 — Core Pipeline ✅ SELESAI

Tujuan: dari upload file → muncul halaman Notion.

### Pagi — Transkripsi
- [x] Buat workflow baru `meeting-notes-main` via MCP Claude Code
- [x] Tambah `Form Trigger` — field upload file audio + nama meeting (opsional)
- [x] Tambah node `Transcribe with Whisper` (HTTP Request ke api.koboillm.com/v1/audio/transcriptions)

### Siang — AI Analysis
- [x] Tambah node `Analyze with MiniMax` (model MiniMax-M2.7, temperature 0.1)
- [x] Pakai 1 prompt gabungan dulu (extract + summary jadi satu)
- [x] Tambah `Code` node `Parse AI Response` (try-catch, strip markdown fence, default values)

### Sore — Output ke Notion & Slack
- [x] Tambah `Notion` node — buat halaman di database "Meeting Notes" (ID: 53dc6a95e86845a4baf1da1691dbc581)
- [x] Tambah `Slack` node `Post to Slack` — notifikasi channel #all-satrya (C0B7S81CT8B)
- [x] Setup semua credential di n8n UI (Whisper, MiniMax, Notion, Slack)
- [x] Test end-to-end: Execution #6 ✅ — Whisper → MiniMax → Notion → Slack semua berhasil
- [ ] Commit workflow JSON ke git

**✅ Checkpoint Hari 1:** Pipeline end-to-end berjalan. Halaman Notion terbuat otomatis + Slack notif terkirim.

---

## HARI 2 — Kualitas & Notifikasi (target: output rapi + error handling)

Tujuan: classifier konten + 3-class routing + output kaya + error handling.

> ⚠️ WAJIB: Sebelum mengubah prompt atau struktur JSON, AI harus brainstorming & diskusi dengan user terlebih dahulu. Lihat SDD Bagian 14.

### Pagi — Classifier & Routing (Node 0 + Node 1 multi-class) ✅ SELESAI
- [x] **[BRAINSTORMING SELESAI]** Diskusi 3-class routing: meeting / one_on_one / non_meeting
- [x] Tambah `Classify & Plan` (MiniMax, temp 0.1) — Node 0, deteksi jenis konten & buat focus_instruction
- [x] Tambah `Parse Classifier Output` (Code node) — parse JSON Node 0, inject transcript
- [x] Tambah `Router` (Switch node) — 5 output: Tidak Bisa Diproses / Meeting / One on One / Non Meeting / Perlu Review Manual
- [x] Rename `Analyze with MiniMax` → `Extract - Meeting` — prompt diupdate pakai context dari Node 0
- [x] Tambah `Extract - One on One` (MiniMax) — schema: person_a/b, highlights, assessment
- [x] Tambah `Extract - Non Meeting` (MiniMax) — schema: detailed_notes, main_themes, key_points
- [x] Tambah `Notify - Human Review` (Slack) — untuk konten ambiguous (confidence < 0.75)
- [x] Tambah `Notify - Tidak Bisa Diproses` (Slack) — untuk transkrip kosong/noise

### Siang — Konten Notion Lebih Lengkap
- [x] **[BRAINSTORMING SELESAI]** Diskusi struktur blok konten Notion (opsi B: heading + bullet + checklist + toggle transkrip untuk Meeting)
- [x] Tambah rich content blocks untuk **semua 3 branch** via `Format Blocks` (Code) + `Append Blocks` (HTTP Request → Notion API):
  - Meeting: H2 Ringkasan, Keputusan (bullet), Action Items (checklist), Topik Pembahasan (toggle), Pertanyaan Terbuka, Transkrip (toggle)
  - One on One: Callout peserta, H2 Ringkasan, Topik, Highlights, Assessment, Action Items, Follow-up, Transkrip (toggle)
  - Non Meeting: Callout info (Topik/Moderator/Kategori), Callout pertanyaan, H2 Ringkasan, Tema Utama (bullet), Poin Penting (numbered), Kutipan Menarik (quote), Pertanyaan Terbuka, Transkrip (toggle)
- [x] Buat Notion DB baru: `One-on-One Notes DB` — ID: `37387f7d-deee-4031-9a4b-a08ed79231fb` (9 properti: Name, Date, Session Type, Person A/B, Action Items Count, Has Action Items, Follow-up Required, Status)
- [x] Buat Notion DB baru: `Content Notes DB` — ID: `f6c7e601-8a22-4255-8f40-7b37c0c72b82` (10 properti: Name, Date, Category, Subcategory, Moderator, Question, Topic, Sub Topic, Key Point, Summarize)
- [x] Tambah `Parse - One on One` (Code) + `Create Notion Page - One on One` + `Post to Slack - One on One`
- [x] Tambah `Parse - Non Meeting` (Code) + `Create Notion Page - Non Meeting` + `Post to Slack - Non Meeting`
- [x] Update prompt `Extract - Non Meeting` — tambah field: topic, sub_topic, moderator, question
- [x] Update Slack message format — berbeda per content_class (Meeting / One on One / Non Meeting)

### Sore — Error handling & Audio Conversion
- [x] Buat workflow terpisah `meeting-notes-error-handler` dengan `Error Trigger` — ID: `U2PZCD2RePWB2B2x`
- [x] Update channel ID #automation-errors di node "Notify - Error" (C0B8BBF1QCC) — selesai via MCP
- [x] Tambah node `Audio Conversion` (Code node + ffmpeg) antara Form Trigger dan Whisper — konversi video ke 16kHz mono 16kbps MP3, teruji 122MB → 0.59MB dalam 686ms ✅
- [x] Buat `start-n8n.ps1` + `stop-n8n.ps1` — env vars (ALLOW_BUILTIN, MAX_PAYLOAD_SIZE, BINARY_DATA_MODE) otomatis di-set setiap restart
- [ ] **[MANUAL UI]** Set Error Workflow di main pipeline: Settings → Error Workflow → pilih "Meeting Notes — Error Handler"
- [ ] **[MANUAL UI]** Set Retry On Fail pada 4 node: Transcribe with Whisper, Extract - Meeting, Extract - One on One, Extract - Non Meeting → Max Tries: 3, Wait: 5000ms
- [x] Append Blocks - Meeting credential & rich blocks teruji jalan (exec #15: page "Rapat Mingguan Keberhasilan Siswa" + 4 action items + toggle transkrip) ✅
- [ ] **[MANUAL UI]** Verifikasi credential "Notion account" pada Append Blocks - One on One & Non Meeting (Meeting sudah confirmed)
- [x] Fix `Router` — Switch crash "Wrong type: '' is a string but was expecting a boolean": tambah `singleValue:true` pada 4 operator boolean (should_process, ambiguous x3) ✅
- [x] Fix classifier JSON kosong/truncated — root cause: MiniMax M2 model reasoning menghabiskan `maxTokens` (classifier 600 → empty content). Naikkan maxTokens: Classify & Plan 600→8000, Extract nodes 2000→16000 ✅ teruji exec #14 classifier return JSON valid (583 token)
- [ ] Test error path: matikan sementara 1 API key → pastikan #automation-errors dapat notifikasi
- [ ] Commit workflow JSON ke git

**Checkpoint Hari 2:** 3-class routing berjalan, output Notion rapi per tipe konten, error tertangkap ke Slack.

---

## HARI 3 — Multi-Sumber Input & Finalisasi (target: 1 web UI, 3 metode input + deploy)

Tujuan: user bisa memberi rekaman lewat 3 cara dari SATU web form — upload langsung, paste link OneDrive, atau paste link Google Drive. Pipeline inti (Audio Conversion → Whisper chunking → Classify → Extract → Notion → Slack) TIDAK diubah; hanya front-end ingestion yang ditambah.

> ⚠️ Keputusan desain (terkonfirmasi user): OneDrive/Drive lewat **paste share link / file ID** di dalam form, BUKAN auto-watch folder. Satu Form Trigger + Switch by sumber. Lihat SDD Bagian 5.0.

### Pagi — Front-end 3-metode (Upload / OneDrive / Google Drive)
- [ ] Setup credential di n8n: Microsoft OneDrive OAuth2 + Google Drive OAuth2
- [ ] Update `Upload Meeting Recording` (Form Trigger) — tambah field:
  - `Sumber Rekaman` (dropdown): `Upload File` | `OneDrive` | `Google Drive`
  - `File Rekaman` (file, opsional — dipakai jika Upload File)
  - `Mode Pilihan` (dropdown, opsional): `File Terbaru` | `File Spesifik` — dipakai jika OneDrive/Drive
  - `Folder (link/ID)` (text, opsional): folder sumber jika `File Terbaru`; kosong = default folder Recordings
  - `Link / File ID` (text, opsional): dipakai jika `File Spesifik`
  - `Nama Meeting` (text, opsional) — sudah ada
- [ ] Tambah `Switch - Sumber Input` (3 output by `Sumber Rekaman`)
- [ ] Tambah `Download - OneDrive`:
  - mode **File Terbaru** → list children folder, sort `lastModifiedDateTime desc`, ambil [0] → download
  - mode **File Spesifik** → resolve share link/ID → download
- [ ] Tambah `Download - Google Drive`:
  - mode **File Terbaru** → Files List `q` di folder, `orderBy: modifiedTime desc`, limit 1 → download
  - mode **File Spesifik** → extract file ID dari link → download
- [ ] Tambah `Normalize Input` (Code/Set) — samakan output jadi `binary.recording` + `json.meeting_name` apapun sumber/mode → masuk ke `Audio Conversion`
- [ ] Test semua jalur: (a) upload, (b) OneDrive terbaru, (c) OneDrive spesifik, (d) Drive terbaru, (e) Drive spesifik → semua sampai Notion

### Pagi (lanjutan, opsional) — Sequential Whisper + memory hardening (dari audit GPT)
- [ ] Perbaiki loop Whisper: wiring `Loop Over Items` benar (out:0=done→Merge, out:1=loop→Whisper) — ATAU bounded-concurrency batching, bukan strict sequential
- [ ] Ganti output chunk Audio Conversion ke `this.helpers.prepareBinaryData` (id-based) jika tersedia di task-runner → turunkan peak RAM
- [ ] tmpDir pakai `$execution.id` + `crypto.randomUUID()` (bukan hanya `Date.now()`)
- [ ] Set Retry On Fail node Whisper manual di UI (Max Tries 3, Wait 5000ms)

### Siang — Action items (opsional, jika waktu cukup)
- [ ] **[BRAINSTORMING DULU]** Diskusi dengan user: simpan ke Notion database baru atau di halaman yang sama?
- [ ] Tambah loop untuk buat task dari tiap action item
- [ ] Hanya buat task jika ada owner (skip yang null)
- [ ] Test: action items jadi task dengan assignee

### Sore — Finalisasi & deploy
- [ ] Jalankan semua test case di SDD Bagian 11 (edge cases: tanpa action items, transkrip panjang, dll)
- [ ] Aktifkan workflow (toggle "Active" di n8n)
- [ ] Export final workflow JSON, commit ke git sebagai backup
- [ ] Tulis README singkat: cara pakai, cara troubleshoot

**Checkpoint Hari 3:** Dari 1 web form, user bisa pilih 3 metode input (upload / OneDrive link / Drive link) → ketiganya menghasilkan notulen Notion + notif Slack. Pipeline inti tetap utuh.

---

# FASE 2 — PUBLIC TRIAL PORTFOLIO (Hari 4-6)

> 🎯 Target: trial portfolio publik (BUKAN production). Visitor bisa coba sistem dengan akun Notion/Slack mereka sendiri, pakai model AI gratis, dan unduh hasil sebagai Markdown/PDF. Diakses publik lewat tunnel.
>
> ⚠️ WAJIB brainstorming sebelum ubah prompt/JSON (SDD Bagian 14). Keamanan token user: lihat SDD Bagian 10 (jangan persist/log token user).

## HARI 4 — Model Gratis (GLM) + Config Per-User

### Pagi — Swap MiniMax → GLM-4.5-Flash
- [ ] **[BRAINSTORMING SELESAI sebagian]** Konfirmasi API key GLM + endpoint (Zhipu/z.ai, OpenAI-compatible) dari user
- [ ] Buat credential GLM di n8n (atau HTTP header auth ke endpoint z.ai)
- [ ] Ganti node `Classify & Plan` + `Extract - Meeting/One on One/Non Meeting` dari MiniMax → GLM-4.5-Flash
- [ ] Set `max_tokens` longgar (pelajaran reasoning-token: kemungkinan GLM juga reasoning model — mulai 8000 classifier / 16000 extract, tuning saat test)
- [ ] Test: ketiga branch tetap hasilkan JSON valid dengan GLM

### Siang/Sore — Kredensial Notion/Slack per-sesi (runtime, tidak disimpan)
- [ ] Tambah field form: `Notion Integration Token` (text), `Notion Database ID` (text), `Slack Webhook URL` (text) — semua opsional
- [ ] Ganti `Create Notion Page` (semua 3 branch) dari Notion node (credential store) → **HTTP Request** ke `api.notion.com` pakai `Authorization: Bearer {{ token dari form }}`
- [ ] Ganti `Append Blocks` → tetap HTTP Request tapi token dari form, bukan credential store
- [ ] Ganti `Post to Slack` (3 branch) → HTTP Request POST ke webhook URL dari form
- [ ] Fallback: jika user tidak isi Notion/Slack, skip step itu (hanya kasih file output) — jangan error
- [ ] **KEAMANAN:** pastikan token user TIDAK masuk log node, TIDAK dipersist, TIDAK ter-commit

**Checkpoint Hari 4:** Pipeline jalan pakai model gratis GLM; user bisa pakai Notion/Slack sendiri via token yang ditempel di form (tidak tersimpan).

## HARI 5 — Output Markdown + PDF + Polish Form Publik

### Pagi — Generator output file
- [ ] **[BRAINSTORMING SELESAI]** Format: Markdown + PDF (md = nol-dependency; PDF = bagian berisiko)
- [ ] Tambah field form: `Format Output` (dropdown): `Markdown` | `PDF`
- [ ] Tambah `Render Markdown` (Code) — dari JSON hasil Extract → string Markdown rapi (heading, bullet, checklist action items, transkrip)
- [ ] Tambah `Generate PDF` — Markdown → HTML (Code, no dep) → PDF. **Pilih tool saat implementasi** (pdf-lib/pdfkit di Code node, ATAU CLI wkhtmltopdf/pandoc di host, ATAU API html→pdf eksternal). Ini titik gagal paling mungkin — siapkan fallback ke Markdown jika PDF gagal.
- [ ] Kembalikan file sebagai download di form completion (atau Respond to Webhook returnBinary)

### Siang/Sore — Polish form publik
- [ ] Susun ulang form: instruksi jelas, contoh, link cara dapat Notion token/Slack webhook
- [ ] Validasi input + pesan error ramah (file bukan audio/video, token format salah, dll)
- [ ] Loading/progress note (transkripsi bisa 1-2 menit)

**Checkpoint Hari 5:** User pilih Markdown/PDF → unduh notulen sebagai file; form publik rapi & ramah.

## HARI 6 — Auto-Restart + Tunnel + Vercel Landing Page + Finalisasi

> **Pilihan arsitektur (terkonfirmasi):** Opsi A — Vercel sebagai landing page statis saja, form submission tetap native n8n via tunnel. Error handling paling mudah: n8n handle semua, Cloudflare handle koneksi, tidak ada custom backend.

### Pagi — Auto-restart n8n + Cloudflare Tunnel sebagai Windows Service

**Auto-restart n8n saat PC menyala:**
- [ ] Buat `setup-autostart.ps1` — daftarkan n8n ke **Windows Task Scheduler** (run at logon, run as highest privilege):
  ```powershell
  # Jalankan start-n8n.ps1 saat user login
  $action  = New-ScheduledTaskAction -Execute "powershell.exe" `
               -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"D:\meeting n8n\start-n8n.ps1`""
  $trigger = New-ScheduledTaskTrigger -AtLogon
  $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 0) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
  Register-ScheduledTask -TaskName "n8n-MeetingNotes" -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Force
  ```
- [ ] Test: logout → login → cek localhost:5678 aktif tanpa manual run

**Cloudflare Tunnel sebagai Windows Service (auto-restart permanen):**
- [ ] Download `cloudflared.exe` dari `https://github.com/cloudflare/cloudflared/releases`
- [ ] Login: `cloudflared tunnel login` (buka browser, authorize)
- [ ] Buat tunnel: `cloudflared tunnel create meeting-notes`
- [ ] Buat config `C:\Users\Satz\.cloudflared\config.yml`:
  ```yaml
  tunnel: <TUNNEL_ID>
  credentials-file: C:\Users\Satz\.cloudflared\<TUNNEL_ID>.json
  ingress:
    - hostname: meeting-notes.<subdomain>.cfargotunnel.com
      service: http://localhost:5678
    - service: http_status:404
  ```
- [ ] Install sebagai Windows Service: `cloudflared service install` → auto-start saat boot, auto-reconnect saat network kembali
- [ ] Route DNS: `cloudflared tunnel route dns meeting-notes meeting-notes.<subdomain>.cfargotunnel.com`
- [ ] Test: matikan PC, nyalakan → cek tunnel URL dapat diakses tanpa sentuhan manual

**Error handling saat PC mati / restart (built-in, nol koding extra):**
- Tunnel down → Cloudflare tampilkan error page sendiri ("Service Unavailable") ✅
- n8n crash mid-execution → n8n mark as error otomatis ✅
- n8n down → form tidak bisa disubmit → user lihat pesan error Cloudflare ✅
- **Tidak perlu custom error handler apapun di lapisan ini** — ini keunggulan Opsi A

### Siang — Vercel Landing Page (Opsi A — statis, tanpa backend)
- [ ] Buat repo Vercel terpisah (`meeting-notes-landing`) atau subfolder `landing/`
- [ ] Buat `index.html` statis (atau Next.js minimal) dengan:
  - Hero: nama sistem + 1 kalimat deskripsi
  - "Cara kerja" (3 langkah: upload → AI → notulen)
  - Tombol **"Coba Sekarang →"** → link langsung ke `https://meeting-notes.<domain>/form/<id>` (n8n form URL tunnel)
  - Status badge kecil: JS fetch ke `https://meeting-notes.<domain>/healthz` → tampilkan "🟢 Online" / "🔴 Offline" (5 baris JS, refresh setiap 30 detik)
  - Footer: "Trial portfolio · Server personal · Data tidak disimpan"
- [ ] Deploy ke Vercel: `vercel --prod` → URL `meeting-notes-<username>.vercel.app`
- [ ] **Tidak ada backend Vercel apapun** — murni statis, tidak bisa error dari sisi Vercel

**Kenapa Opsi A error handling-nya paling mudah:**
- Vercel: static file, tidak bisa fail kecuali Vercel sendiri down (SLA 99.99%)
- Tunnel: Cloudflare handle, auto-reconnect, error page otomatis
- n8n form: native, built-in validation, built-in completion page
- Pipeline error: Error Trigger workflow sudah ada → kirim ke Slack #automation-errors
- **Zero custom error code di layer baru**

### Sore — Hardening ringan + finalisasi
- [ ] Turunkan `N8N_FORMDATA_FILE_SIZE_MAX` ke `200` (cukup untuk meeting hingga ~2 jam) — update `start-n8n.ps1`
- [ ] Verifikasi env var `N8N_HOST=meeting-notes.<domain>`, `N8N_PROTOCOL=https`, `WEBHOOK_URL=https://meeting-notes.<domain>` di `start-n8n.ps1` agar form URL benar
- [ ] Test end-to-end dari HP/device lain: buka Vercel URL → klik Coba → form n8n → submit file → hasil
- [ ] Export final workflow JSON, commit ke git
- [ ] Tulis README portfolio: link Vercel, cara kerja, limitasi trial, arsitektur singkat

### Sore — Finalisasi portfolio
- [ ] Test end-to-end publik dari device lain (bukan localhost)
- [ ] README + writeup portfolio: arsitektur, demo link, batasan trial
- [ ] Export final workflow JSON, commit ke git

**Checkpoint Hari 6:** PC restart → n8n + tunnel hidup otomatis (tanpa sentuhan). Orang lain buka Vercel landing page → klik "Coba" → form n8n (tunnel) → upload/pilih rekaman → pakai Notion/Slack sendiri (opsional) → unduh notulen Markdown/PDF. Zero custom error code di lapisan baru. Trial portfolio siap dipamerkan.

---

## Stretch Goals (jika ada sisa waktu / setelah 6 hari)

- [x] ~~Chunking file > 25 MB untuk meeting panjang~~ → **SELESAI** sebagai Audio Conversion node (konversi ke MP3, bukan chunking) — mendukung file hingga ratusan MB
- [ ] Auto-watch folder OneDrive/Google Drive (event-driven trigger) sebagai entry point ke-2 — file baru di folder Recordings otomatis diproses tanpa buka form
- [ ] Output format tambahan: TXT & DOCX (DOCX butuh library docx) — saat ini hanya Markdown + PDF
- [ ] Config user via OAuth connect (Notion/Slack) menggantikan paste-token — lebih mulus tapi butuh OAuth app + callback
- [ ] Custom frontend Next.js di Vercel (bukan hanya form n8n) yang panggil webhook n8n — wajah portfolio lebih profesional
- [ ] Speaker diarization (siapa bicara apa)
- [ ] Deteksi bahasa otomatis untuk meeting multi-bahasa (sudah ada `language` field di Node 0)
- [ ] Template Notion berbeda per tipe meeting (standup vs client vs retro) — sudah ada `meeting_type` di Node 0
- [ ] Ringkasan mingguan: gabungkan semua meeting dalam seminggu jadi 1 digest
- [ ] Refine node (Node 2) — validasi & rapikan action items sebelum Narrate
- [ ] Narrate node (Node 3) — tulis executive summary dari JSON yang sudah bersih

---

## Catatan Penting

- Jika Hari 1 belum dites sepenuhnya, JANGAN lanjut ke Hari 2 — perbaiki dulu fondasinya.
- Milestone paling kritis adalah checkpoint Hari 1. Sisanya adalah peningkatan.
- AI CLI menghasilkan draft via MCP; test final & setup credential tetap manual di n8n UI.
- Backup workflow JSON ke git setiap akhir hari.
- **Perubahan prompt atau JSON WAJIB brainstorming dengan user dulu — lihat SDD Bagian 14.**
