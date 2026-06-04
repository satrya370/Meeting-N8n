# Software Design Document — Otomasi Meeting Notes

> Versi 1.0 · Project pertama automasi n8n · Target build: 3 hari
> Dibangun dengan bantuan AI CLI (Claude Code / OpenCode) untuk generate workflow JSON & code nodes.

---

## 1. Ringkasan & Tujuan

Sistem otomasi yang mengubah rekaman meeting menjadi notulen terstruktur secara otomatis: transkripsi → analisis AI → simpan ke Notion → notifikasi Slack → buat action items. Tujuannya menghilangkan pekerjaan manual membuat notulen yang sering terlambat atau tidak pernah dibuat.

**Definisi sukses (akhir hari 3 — single-tenant):**
- Upload/link satu file rekaman → dalam < 5 menit menghasilkan halaman Notion berisi ringkasan, keputusan, dan action items.
- Notifikasi otomatis terkirim ke channel Slack dengan link ke notulen.
- Sistem berjalan tanpa intervensi manual setelah trigger.

**Definisi sukses Fase 2 (akhir hari 6 — public trial portfolio):**
- Orang lain bisa mengakses link publik (n8n form via tunnel), upload/pilih rekaman, dan mendapat notulen.
- Visitor memakai akun **Notion & Slack mereka sendiri** (token ditempel di form per sesi, tidak disimpan) — opsional; tanpa itu tetap dapat file output.
- Output bisa diunduh sebagai **Markdown atau PDF**.
- Ditenagai model AI **gratis (GLM-4.5-Flash)** agar tidak ada biaya per-trial.
- Catatan: ini **trial portfolio, BUKAN production** — hardening seperlunya saja.

---

## 2. Scope

### Termasuk (in scope)
- Transkripsi audio/video meeting ke teks (dengan chunking untuk file panjang).
- Ekstraksi terstruktur: ringkasan, keputusan, action items, peserta, topik.
- Penyimpanan ke Notion dengan format konsisten.
- Notifikasi Slack berisi ringkasan + link.
- Multi-sumber input: upload / OneDrive / Google Drive (Hari 3).
- **Fase 2 (Hari 4-6):** model gratis GLM, config Notion/Slack per-user (runtime), output Markdown+PDF, deploy publik via tunnel.

### Tidak termasuk (out of scope)
- Real-time transcription saat meeting berlangsung.
- Speaker diarization tingkat lanjut (siapa bicara apa) — kecuali disediakan oleh tool transkripsi.
- Multi-bahasa kompleks (fokus dulu ke 1 bahasa utama meeting).
- Dashboard analitik meeting.
- **Production-grade**: multi-tenant database, billing, SSO, SLA, scaling — ini hanya trial portfolio.
- **Deploy ke Vercel sebagai host aplikasi** — Vercel serverless tidak bisa menjalankan n8n (stateful, webhook 24/7, storage). Vercel hanya opsional sebagai landing page statis.
- Auto-watch folder per-user publik (trigger n8n instance-level, tidak bisa per-visitor).
- OAuth connect Notion/Slack (pakai paste-token dulu; OAuth = stretch).

---

## 3. Arsitektur Tingkat Tinggi

```
[Ingestion 3-metode] → [Audio Conv] → [Transkripsi] → [Classifier] → [Router] → [Extract] → [Format] → [Output]
   Form + Switch          ffmpeg       Whisper(chunk)    Node 0        Switch      3 branch    Code      Notion + Slack
```

**Front-end ingestion (Hari 3) — 1 web form, 3 metode input:**

```
                          ┌─ Upload File   → (binary langsung)                        ┐
Form Trigger → Switch ───┼─ OneDrive      → Download (terbaru / spesifik)            ├→ Normalize Input → Audio Conversion → ...
(Sumber Rekaman)         └─ Google Drive  → Download (terbaru / spesifik)            ┘   (binary.recording seragam)

Sub-mode OneDrive/Drive: "File Terbaru" (auto file paling baru di folder) atau "File Spesifik" (paste link/ID)
```

Pipeline inti setelah `Normalize Input` identik untuk ketiga sumber — hanya cara mendapatkan file yang berbeda.

**Jalur routing (diputuskan Router berdasarkan output Node 0):**

```
                             ┌─ meeting     → Extract - Meeting  → Parse → Notion Meeting DB → Slack
Whisper → Classify & Plan → ─┼─ one_on_one  → Extract - 1on1    → (Notion 1on1 DB) [WIP Hari 2]
          (Node 0)           ├─ non_meeting → Extract - Content  → (Notion Content DB) [WIP Hari 2]
                             ├─ ambiguous   → Slack: ⚠️ Review Manual (confidence < 0.75)
                             └─ invalid     → Slack: ❌ File Tidak Bisa Diproses
```

Node 0 (Classify & Plan) adalah "otak" pipeline — menentukan jalur routing dan memberikan `focus_instruction` + `key_focus` ke semua node Extract di bawahnya. Alur data satu arah, tidak ada loop.

---

## 4. Keputusan Teknis (Tech Decisions)

| Komponen | Pilihan | Alasan |
|---|---|---|
| Orkestrator | n8n (self-hosted native Windows, Node.js v22) | Visual, mudah maintain, punya semua node yang dibutuhkan |
| Trigger (Hari 1-2) | n8n Form Trigger (upload file) | Paling cepat untuk validasi pipeline, tanpa OAuth |
| Ingestion (Hari 3) | Form Trigger 3-metode: Upload / OneDrive link / Google Drive link → Switch | 1 web UI, user pilih sumber. Paste link (bukan auto-watch) — terkonfirmasi user |
| Transkripsi | OpenAI/KoboILLM Whisper API + **chunking** | Audio panjang dipecah per 5 menit (ffmpeg segment) → hindari 120s proxy timeout |
| AI Classifier (Node 0) | Hari 1-3: MiniMax M2.7 → **Fase 2: GLM-4.5-Flash** (temp 0.1, **max 8000 token**) | Model reasoning butuh budget besar; 600 token → output kosong (sudah diperbaiki). GLM = gratis untuk trial publik |
| AI Extract (Node 1a/b/c) | Hari 1-3: MiniMax → **Fase 2: GLM-4.5-Flash** (temp 0.1, **max 16000 token**) | Idem — reasoning + JSON panjang butuh ruang |
| Penyimpanan | Notion (Hari 1-3: credential store → **Fase 2: token user per-sesi via HTTP Request**) | Trial publik: tiap user pakai Notion sendiri, token tidak disimpan |
| Notifikasi | Slack (Hari 1-3: credential → **Fase 2: webhook URL user per-sesi**) | Idem; opsional, skip jika user tak isi |
| Output file (Fase 2) | Markdown (Code, no-dep) + PDF (md→html→pdf) | md mudah & render rapi; PDF = bagian berisiko, siapkan fallback ke md |
| Deploy publik (Fase 2) | n8n self-host + **Cloudflare Tunnel / ngrok** | Vercel tak bisa host n8n; tunnel = cara tercepat expose form publik. Vercel opsional = landing page statis |
| Model AI (Fase 2) | GLM-4.5-Flash (Zhipu/z.ai, OpenAI-compatible, gratis) | Hindari biaya per-trial; perlu API key + endpoint dari user |

**Catatan trigger:** Bangun pipeline dengan Form Trigger dulu (Hari 1). Front-end multi-sumber & config user di-extend belakangan tanpa mengubah logika inti pipeline — inilah kenapa ingestion dipisah dari pipeline.

---

## 5. Desain Komponen (Node per Node)

### 5.0 Ingestion Front-End — 3 Metode Input (Hari 3)

Satu `Form Trigger` dengan dropdown sumber, lalu `Switch` route ke jalur download yang sesuai. Semua jalur bertemu di `Normalize Input` yang menghasilkan `binary.recording` seragam.

**Form Trigger `Upload Meeting Recording` — fields:**
| Field | Tipe | Catatan |
|---|---|---|
| Sumber Rekaman | dropdown | `Upload File` \| `OneDrive` \| `Google Drive` |
| File Rekaman | file | opsional — dipakai jika "Upload File" |
| Mode Pilihan | dropdown | opsional — dipakai jika OneDrive/Drive: `File Terbaru` \| `File Spesifik` |
| Folder (link/ID) | text | opsional — folder sumber jika `File Terbaru`; kosong = default folder Recordings (dikonfigurasi di node) |
| Link / File ID | text | opsional — dipakai jika `File Spesifik` (paste share link atau file ID) |
| Nama Meeting | text | opsional |

**`Switch - Sumber Input`** — 3 output by `Sumber Rekaman`:
- **Upload File** → langsung ke Normalize (binary sudah ada di `recording`)
- **OneDrive** → `Download - OneDrive` (lihat sub-mode di bawah)
- **Google Drive** → `Download - Google Drive` (lihat sub-mode di bawah)

**Sub-mode `File Terbaru` vs `File Spesifik`** (untuk OneDrive & Drive):
- **File Terbaru** → sistem otomatis ambil file paling baru di folder:
  - OneDrive: list children folder → sort `lastModifiedDateTime desc` → ambil item [0] → download.
  - Google Drive: Files List dengan `q='{folderId}' in parents`, `orderBy: modifiedTime desc`, limit 1 → download.
  - Folder dari field `Folder (link/ID)`; jika kosong, pakai folder Recordings default.
- **File Spesifik** → user paste link/ID file tertentu:
  - OneDrive: resolve share link ke item ID via Microsoft Graph (`/shares/{encoded-url}/driveItem/content`) atau Download by path/ID.
  - Google Drive: extract file ID dari pola link (`/file/d/{ID}/` atau `?id={ID}`) → Download.

**`Normalize Input` (Code/Set node):** pastikan output punya `binary.recording` (audio/video) + `json.meeting_name`, apapun sumber/mode-nya. Output → `Audio Conversion` (5.2).

**Catatan implementasi:**
- File harus dapat diakses oleh akun OAuth (shared/owned).
- "File Terbaru" sebaiknya filter ke tipe audio/video saja (hindari ambil file lain di folder).
- Pipeline inti (5.2 ke bawah) TIDAK berubah — front-end ini hanya mengganti cara file masuk.

### 5.1 Trigger node
- **Hari 1-2:** `Form Trigger` — field: upload file audio + nama meeting (opsional). Single-method.
- **Hari 3:** `Form Trigger` 3-metode (lihat 5.0). Auto-watch folder OneDrive/Drive = stretch goal (entry point ke-2, event-driven).
- Output: binary file (`recording`) + `meeting_name`.

### 5.2 Audio Conversion node ✅ IMPLEMENTED (konversi + chunking)
- `Code` node (JavaScript + `child_process.execSync`) — ffmpeg ekstrak audio + segmentasi dalam satu pass.
- **Perintah ffmpeg:** `-vn -ar 16000 -ac 1 -b:a 32k -f segment -segment_time 300` → mono 16kHz **32kbps** MP3, dipotong per **5 menit/chunk**.
- Output: **array N item** (1 item/chunk), tiap item `binary.recording` + `json.chunk_index`, `total_chunks`. File pendek → 1 chunk (perilaku lama).
- `CHUNK_SECONDS=300` agar tiap chunk transkripsi < 120s (lihat 5.3). `MAX_CHUNKS=30` (~2.5 jam) → throw error jika lebih.
- tmpDir unik per eksekusi + cleanup di `finally` (termasuk saat error).
- Teruji: 74 MB MP4 (42 menit) → 9 chunk → pipeline sukses 64 detik.
- Binary data mode: `filesystem` (`N8N_DEFAULT_BINARY_DATA_MODE=filesystem`); input dibaca via path. **Catatan (audit):** output chunk saat ini inline base64 — peak RAM ≈ N×1.6MB; rencana hardening: `this.helpers.prepareBinaryData` (id-based) bila tersedia di task-runner.
- env var `NODE_FUNCTION_ALLOW_BUILTIN=*` wajib aktif untuk `path`, `fs`, `os`, `child_process`.

### 5.3 Transcription node + Merge (chunked)
- `Transcribe with Whisper` (`HTTP Request`) ke endpoint Whisper (`/v1/audio/transcriptions`), model `openai/whisper-1`, kredensial dari store.
- Menerima N chunk dari 5.2 → n8n jalankan 1× per item. Tiap chunk ≤5 menit → transkripsi ~40-50s, aman di bawah **120s Cloudflare proxy timeout** (penyebab kegagalan file panjang sebelum chunking).
- ⚠️ HTTP Request node memproses item secara **paralel** (`Promise.allSettled`), bukan sekuensial. Aman untuk burst ≤~10 chunk; untuk high-end (≥15) pertimbangkan bounded-concurrency.
- `Merge Transcripts` (Code, runOnceForAllItems) — gabung transkrip semua chunk urut by `chunk_index`. Validasi: jumlah == `total_chunks`, index kontigu 0..N-1, tiap text non-kosong → throw jika gagal. Output `{ text, total_chunks, merge_status: 'complete' }`.
- `Parse Classifier Output` membaca transkrip penuh via `$('Merge Transcripts').first().json.text`.

### 5.4 AI Pipeline (Node 0 + Node 1 per class)

**Node 0 — Classify & Plan** (MiniMax, temp 0.1, max 600 token)
- Input: teks transkrip dari Whisper
- Output JSON: `content_class`, `meeting_type`/`session_type`/`content_category`, `should_process`, `confidence`, `ambiguous`, `focus_instruction`, `key_focus`, `notion_db`, `language`
- Edge case: format 2 orang → cek sinyal audiens untuk bedakan `one_on_one` vs `non_meeting`
- Routing key: `content_class` + `ambiguous` → Switch node (5 output)

**Node 1a — Extract - Meeting** (MiniMax, temp 0.1, max 2000 token)
- Menerima: transcript + focus_instruction + key_focus dari Node 0 via `$json`
- Output schema A — lihat Bagian 6.1

**Node 1b — Extract - One on One** (MiniMax, temp 0.1, max 2000 token)
- Menerima: transcript + focus_instruction + key_focus dari Node 0 via `$json`
- Output schema C — lihat Bagian 6.1

**Node 1c — Extract - Non Meeting** (MiniMax, temp 0.1, max 2000 token)
- Menerima: transcript + focus_instruction + key_focus dari Node 0 via `$json`
- Output schema B — lihat Bagian 6.1

**Parse Classifier Output** (Code node, antara Node 0 dan Router)
- Parse JSON output MiniMax, strip markdown fence, validasi field, set default
- Inject `transcript` dari Whisper untuk dipakai Node 1

**Catatan:** Tidak menggunakan LangChain. Pipeline deterministik (sequential HTTP Request) lebih mudah di-debug dan MiniMax tidak punya native LangChain node di n8n.

### 5.5 Format node
- `Code` node (JavaScript) — susun struktur data final untuk Notion: properti halaman + blok konten.
- Validasi: pastikan semua field wajib ada; isi default jika kosong.

### 5.6 Notion node
- `Notion` node — buat halaman baru di database "Meeting Notes".
- Properti: judul, tanggal, peserta (multi-select), status.
- Konten: heading ringkasan, bullet keputusan, checklist action items, kolaps transkrip penuh.

### 5.7 Slack node
- `Slack` node — post message ke channel target.
- Isi: judul meeting, 2-3 kalimat ringkasan, jumlah action items, link ke Notion.

### 5.8 Error handler
- n8n `Error Trigger` workflow terpisah → kirim detail error ke Slack channel #automation-errors.
- Fase 2: error handler kirim ke channel **operator**, dan TIDAK menyertakan token user (lihat Bagian 10).

### 5.9 Fase 2 — Komponen Public Trial (Hari 4-6)

**Field form tambahan (Fase 2):**
| Field | Tipe | Fungsi |
|---|---|---|
| Notion Integration Token | text (opsional) | Token user; dipakai runtime, tidak disimpan |
| Notion Database ID | text (opsional) | DB tujuan milik user |
| Slack Webhook URL | text (opsional) | Incoming webhook user |
| Format Output | dropdown | `Markdown` \| `PDF` |

**Output stage (ganti node Notion/Slack store-credential → HTTP Request runtime token):**
- `Create Notion Page` / `Append Blocks` → `HTTP Request` ke `https://api.notion.com/v1/...` dengan header `Authorization: Bearer {{ token form }}`, `Notion-Version: 2022-06-28`. Skip jika token kosong.
- `Post to Slack` → `HTTP Request` POST ke `{{ webhook URL form }}`. Skip jika kosong.
- `Render Markdown` (Code) — dari JSON Extract → string Markdown (heading, bullet, checklist action items, toggle/section transkrip).
- `Generate PDF` — Markdown → HTML (Code, no-dep) → PDF. Tool ditentukan saat implementasi (pdf-lib/pdfkit / wkhtmltopdf / API eksternal); **fallback ke Markdown** jika PDF gagal.
- Kembalikan file ke user via form completion (download) atau Respond to Webhook `returnBinary`.

**Model:** node AI (Classify & Plan, Extract x3) ganti MiniMax → **GLM-4.5-Flash** (endpoint OpenAI-compatible z.ai). max_tokens longgar (8000/16000). Kredensial GLM milik operator (bukan user).

**Deploy:** n8n self-host + Cloudflare Tunnel/ngrok (lihat Bagian 12).

---

## 6. Model Data

### 6.1 Tiga Skema Output Node 1 (berdasarkan content_class)

**Schema A — Meeting** (untuk `content_class: "meeting"`)
```json
{
  "meeting_title": "string",
  "meeting_type": "standup|client_meeting|retrospective|planning|brainstorm|all_hands",
  "date": "YYYY-MM-DD",
  "participants": ["string"],
  "executive_summary": "string (3-4 kalimat)",
  "key_decisions": ["string"],
  "action_items": [{ "task": "string", "owner": "string|null", "due_date": "string|null" }],
  "discussion_topics": [{ "topic": "string", "summary": "string" }],
  "open_questions": ["string"]
}
```

**Schema B — Non-Meeting** (untuk `content_class: "non_meeting"`)
```json
{
  "content_title": "string",
  "content_category": "philosophy|science|educational_interview|podcast|lecture|comedy|casual_discussion",
  "content_subcategory": "string|null",
  "topic": "string|null (konsep/tema besar yang dijelajahi, bukan judul)",
  "sub_topic": "string|null (aspek atau angle spesifik dari topic)",
  "date": "YYYY-MM-DD",
  "participants": ["string"],
  "moderator": "string|null (host/moderator/channel jika disebutkan)",
  "question": "string|null (pertanyaan atau isu sentral landasan pembahasan)",
  "executive_summary": "string (3-4 kalimat)",
  "detailed_notes": {
    "main_themes": ["string"],
    "key_points": ["string"],
    "notable_quotes": ["string"],
    "open_questions": ["string"]
  },
  "follow_up": "string|null"
}
```
> Parse node menambah field turunan: `key_point` (= `key_points[0]`), `summarize` (= `executive_summary`) untuk Notion DB properties.

**Schema C — One on One** (untuk `content_class: "one_on_one"`)
```json
{
  "content_title": "string",
  "session_type": "interview|counseling|client_pitch|performance_review|mentoring",
  "date": "YYYY-MM-DD",
  "person_a": { "name": "string", "role": "string" },
  "person_b": { "name": "string", "role": "string" },
  "executive_summary": "string (3-4 kalimat)",
  "key_topics": ["string"],
  "highlights": ["string"],
  "assessment": "string (objektif, berbasis transkrip saja)",
  "action_items": [{ "task": "string", "owner": "string|null", "due_date": "string|null" }],
  "follow_up": "string|null"
}
```
> Parse node menambah field turunan: `action_items_count`, `has_action_items` (boolean), `follow_up_required` (boolean), `person_a_display` ("Nama (Role)"), `person_b_display`.

**Output Node 0 (Classify & Plan):**
```json
{
  "content_class": "meeting|one_on_one|non_meeting",
  "meeting_type": "string|null",
  "session_type": "string|null",
  "content_category": "string|null",
  "content_subcategory": "string|null",
  "should_process": true,
  "confidence": 0.95,
  "ambiguous": false,
  "ambiguity_reason": "string|null",
  "focus_instruction": "string",
  "key_focus": ["string"],
  "notion_db": "meeting|one_on_one|content",
  "language": "id",
  "transcript": "string (diisi oleh Parse Classifier Output)"
}
```

### 6.2 Skema Notion Databases (3 database terpisah)

**Meeting Notes DB** (ID: `53dc6a95e86845a4baf1da1691dbc581`) — sudah ada
| Properti | Tipe |
|---|---|
| Name (judul) | Title |
| Date | Date |
| Participants | Multi-select |
| Action Items Count | Number |
| Status | Select (Draft / Reviewed) |

**One-on-One Notes DB** (ID: `37387f7d-deee-4031-9a4b-a08ed79231fb`) ✅ dibuat Hari 2
| Properti | Tipe | Sumber |
|---|---|---|
| Name (judul) | Title | `content_title` |
| Date | Date | `date` |
| Session Type | Select (interview / counseling / client_pitch / performance_review / mentoring) | `session_type` |
| Person A | Rich Text | `person_a_display` ("Nama (Role)") |
| Person B | Rich Text | `person_b_display` ("Nama (Role)") |
| Action Items Count | Number | `action_items_count` |
| Has Action Items | Checkbox | `has_action_items` |
| Follow-up Required | Checkbox | `follow_up_required` |
| Status | Select (Draft / Reviewed) | otomatis = Draft |

**Content Notes DB** (ID: `f6c7e601-8a22-4255-8f40-7b37c0c72b82`) ✅ dibuat Hari 2
| Properti | Tipe | Sumber |
|---|---|---|
| Name (judul) | Title | `content_title` |
| Date | Date | `date` |
| Category | Select (philosophy / science / educational_interview / podcast / lecture / comedy / casual_discussion) | `content_category` |
| Subcategory | Rich Text | `content_subcategory` |
| Moderator | Rich Text | `moderator` |
| Question | Rich Text | `question` |
| Topic | Rich Text | `topic` |
| Sub Topic | Rich Text | `sub_topic` |
| Key Point | Rich Text | `key_point` (= `key_points[0]`) |
| Summarize | Rich Text | `summarize` (= `executive_summary`) |

---

## 7. Desain Prompt AI

### Prompt 1 — Extract (temperature 0.1)
```
Kamu adalah asisten notulen profesional. Dari transkrip meeting berikut,
ekstrak informasi dalam format JSON murni (tanpa teks lain, tanpa markdown).

Skema yang harus dikembalikan:
{ meeting_title, date, participants[], key_decisions[],
  action_items[{task, owner, due_date}], discussion_topics[{topic, summary}],
  open_questions[] }

Aturan:
- Jika owner atau due_date tidak disebut, isi null. Jangan mengarang.
- participants: hanya nama yang benar-benar muncul di transkrip.
- key_decisions: hanya keputusan final, bukan opsi yang dibahas.

Transkrip:
"""
{{ TRANSCRIPT }}
"""
```

### Prompt 2 — Narrate (temperature 0.3)
```
Berdasarkan data terstruktur berikut, tulis executive summary 3-4 kalimat.
Tone: faktual dan ringkas, bukan spekulatif. Jangan menambah informasi
yang tidak ada di data.

Data:
{{ EXTRACTED_JSON }}
```

**Prinsip:** AI hanya menganalisis transkrip nyata, tidak pernah menjadi sumber informasi. Selalu inject transkrip asli. Temperature rendah untuk akurasi.

---

## 8. Integrasi & Kredensial

| Service | Kredensial dibutuhkan | Cara dapat |
|---|---|---|
| OpenAI/KoboILLM (Whisper) | API key | `api.koboillm.com/v1`, model `openai/whisper-1` |
| MiniMax (Classifier + Extract) | API key | MiniMax M2.7, temp 0.1 |
| Notion | Integration token + database share | notion.so/my-integrations; 3 DB sudah ada |
| Slack | Bot token | api.slack.com/apps; channel #all-satrya & #automation-errors |
| Microsoft OneDrive (Hari 3) | OAuth2 | Azure app registration / Microsoft 365 — untuk metode "OneDrive (link)" download |
| Google Drive (Hari 3) | OAuth2 | Google Cloud Console — untuk metode "Google Drive (link)" download |

**Semua kredensial disimpan di n8n Credentials store — TIDAK pernah di-hardcode di node atau code.**

---

## 9. Penanganan Error

- Setiap node penting (transkripsi, AI, Notion) di-set `Continue On Fail = false` agar error langsung terdeteksi.
- Workflow `Error Trigger` terpisah menangkap kegagalan → kirim ke Slack dengan: nama workflow, node yang gagal, pesan error, timestamp.
- Retry: transkripsi & AI node di-set retry 2x dengan jeda 5 detik (untuk error sementara).
- File > 25 MB tanpa chunking → tangkap lebih awal, beri pesan jelas.

---

## 10. Keamanan

**Single-tenant (Hari 1-3):**
- Kredensial sistem (Whisper, GLM/MiniMax) hanya di n8n Credentials store — tidak pernah di-hardcode.
- File rekaman dihapus dari storage sementara setelah diproses (tmpDir unik + cleanup `finally`).
- Akses Notion integration dibatasi hanya ke database "Meeting Notes".
- n8n instance di belakang HTTPS; webhook pakai header secret untuk validasi sumber.
- Jangan log transkrip penuh ke console node (data sensitif).

**Public trial — kredensial user per-sesi (Fase 2, Hari 4-6):**
- Token Notion + Slack webhook user **diterima runtime dari form**, dipakai dalam eksekusi itu, lalu dibuang. TIDAK disimpan ke n8n Credentials store, TIDAK dipersist ke DB.
- **JANGAN** log token user ke console node, output node, atau error message. Error handler hanya kirim metadata (nama node, pesan error) ke channel error MILIK OPERATOR — bukan menyertakan token user.
- Karena binary data mode = filesystem, pastikan file rekaman & file output user dibersihkan pasca-eksekusi (jangan menumpuk di `~/.n8n/binaryData/`).
- Tunnel hanya expose endpoint form publik; editor n8n & REST API JANGAN ikut ter-expose tanpa auth.
- Trial-level: tidak ada penyimpanan data user jangka panjang. Catat di UI bahwa ini trial & data tidak disimpan permanen.
- Kredensial sistem trial (GLM key, Whisper key) tetap milik operator di credential store — bukan dibagikan ke user.

---

## 11. Rencana Testing

1. **Unit per node:** uji tiap node dengan data dummy (transkrip pendek).
2. **Integrasi:** jalankan pipeline penuh dengan 1 file rekaman pendek (~2 menit).
3. **Edge cases:** file tanpa suara, transkrip sangat panjang, meeting tanpa action items, bahasa campuran.
4. **Validasi output:** cek halaman Notion terbentuk benar, Slack notif terkirim, JSON tidak rusak.
5. **Error path:** sengaja matikan API key untuk memastikan error handler bekerja.

File test: siapkan 1 rekaman meeting pendek nyata sebagai fixture.

---

## 12. Deployment

- **Development (aktif):** n8n native Windows — `node D:\npm-global\node_modules\n8n\bin\n8n start` via `start-n8n.ps1`.
- **Startup script:** `start-n8n.ps1` (project root) — set env vars, pastikan `~/.n8n/binaryData/` ada, jalankan n8n hidden, simpan PID ke `n8n.pid`.
- **Public trial (Fase 2, Hari 6):** n8n tetap self-host native Windows, di-expose publik via **Cloudflare Tunnel** (gratis, domain stabil, HTTPS otomatis). Tunnel → `localhost:5678`.

### Arsitektur public trial — Opsi A (dipilih: error handling termudah)

```
Visitor → Vercel landing page (static) → klik "Coba Sekarang" → n8n Form URL (Cloudflare Tunnel)
                                                                        ↓
                                                               n8n proses pipeline
                                                                        ↓
                                                           n8n form completion page (hasil/download)
```

**Kenapa Opsi A paling mudah untuk error handling:**
- Vercel: static HTML, SLA 99.99%, tidak bisa gagal dari sisi developer
- Cloudflare Tunnel: jika n8n down → Cloudflare tampilkan error page sendiri (otomatis)
- n8n form: validasi input, completion page, error display — semua sudah built-in
- Pipeline error: Error Trigger workflow existing → kirim ke Slack operator
- **Zero custom error code di lapisan baru** — tidak ada backend Vercel, tidak ada proxy

**Auto-restart (PC restart/crash recovery):**
- n8n → **Windows Task Scheduler** (run at logon, restart on failure 3×)
- Cloudflare Tunnel → **Windows Service** via `cloudflared service install` (auto-start saat boot, auto-reconnect)
- Gabungan: PC menyala → keduanya hidup otomatis dalam <30 detik, tanpa sentuhan

**Vercel landing page (statis murni):**
- `index.html` atau Next.js export statis
- Tombol "Coba Sekarang" → link ke `https://<tunnel-domain>/form/<webhookId>`
- Status badge: JS fetch ke `/healthz` → "🟢 Online" / "🔴 Offline" (30 baris JS, refresh 30s)
- Tidak ada Vercel API route, tidak ada backend — murni statis

**Keamanan expose:**
- Cloudflare Tunnel hanya route path tertentu; editor n8n (`/`) & REST API (`/rest`, `/api`) tidak perlu di-expose karena tunnel di-config dengan ingress rule spesifik
- Set env: `N8N_HOST=<tunnel-domain>`, `N8N_PROTOCOL=https`, `WEBHOOK_URL=https://<tunnel-domain>`
- Export workflow sebagai JSON, simpan di git repo sebagai backup & version control.
- Aktifkan workflow; monitor execution log.

### Environment Variables Wajib

| Variabel | Nilai | Fungsi |
|---|---|---|
| `NODE_FUNCTION_ALLOW_BUILTIN` | `*` | Izinkan `path`, `fs`, `os`, `child_process` di Code node |
| `NODE_FUNCTION_ALLOW_EXTERNAL` | `*` | Izinkan npm module eksternal di Code node |
| `N8N_PAYLOAD_SIZE_MAX` | `600` (dev) / `200` (public) | Limit body JSON/raw request (MB) |
| `N8N_FORMDATA_FILE_SIZE_MAX` | `600` (dev) / `200` (public) | **Limit upload file via Form (MB)** — turunkan ke 200 saat public trial |
| `N8N_DEFAULT_BINARY_DATA_MODE` | `filesystem` | Simpan binary di disk, bukan memory (wajib file > ~50 MB) |
| `N8N_HOST` | `<tunnel-domain>` | Hostname publik; wajib di-set agar form URL benar saat tunnel aktif |
| `N8N_PROTOCOL` | `https` | Pastikan URL form pakai HTTPS (tunnel Cloudflare selalu HTTPS) |
| `WEBHOOK_URL` | `https://<tunnel-domain>` | Base URL untuk semua webhook/form trigger |

> **Catatan penting:** nama env var adalah `N8N_PAYLOAD_SIZE_MAX` (bukan `N8N_MAX_PAYLOAD_SIZE`). Untuk upload file via Form, yang menentukan adalah `N8N_FORMDATA_FILE_SIZE_MAX` (default 200 MB), bukan payload size. Gunakan **production form URL** (`/form/<id>`), bukan test URL (`/form-test/<id>`) yang hanya aktif saat klik "Test workflow".

> **Penting:** env var harus di-set di session PowerShell yang sama sebelum `Start-Process` — **bukan** via `[System.Environment]::SetEnvironmentVariable(..., 'User')` (registry write tidak diwariskan ke spawned process).

---

## 13. Peran AI CLI dalam Build

AI CLI (Claude Code / OpenCode) digunakan untuk:
- Generate kerangka workflow JSON n8n yang bisa di-import.
- Menulis JavaScript untuk Code node (format & validasi data).
- Menyusun & mengiterasi prompt AI.
- Menulis script test dan dokumentasi.

**Penting:** AI CLI menghasilkan draft; refinement final tetap dilakukan di n8n UI karena beberapa konfigurasi node (kredensial, mapping) lebih mudah & aman lewat UI. Ini pekerjaan hybrid, bukan 100% CLI.

---

## 14. Aturan Brainstorming Sebelum Implementasi JSON & Prompt

### Prinsip Utama

**Setiap perubahan atau pembuatan struktur JSON dan desain prompt AI WAJIB melalui fase brainstorming dan diskusi dengan user terlebih dahulu.** AI tidak boleh langsung mengeksekusi perubahan di area ini tanpa persetujuan eksplisit dari user setelah diskusi.

### Area yang Wajib Brainstorming

1. **Struktur JSON output AI** (Bagian 6.1)
   - Penambahan atau penghapusan field
   - Perubahan tipe data field (string → array, dll)
   - Perubahan skema action_items, discussion_topics, atau open_questions

2. **Desain prompt AI** (Bagian 7)
   - Prompt baru untuk node Extract, Refine, atau Narrate
   - Perubahan instruksi, aturan, atau contoh di dalam prompt
   - Perubahan temperature atau parameter AI lainnya

3. **Struktur konten Notion** (blok halaman)
   - Urutan dan hierarki heading
   - Format action items (checklist vs bullet)
   - Apa yang ditampilkan vs disembunyikan (collapsed)

### Alur yang Harus Diikuti AI

```
AI ingin ubah JSON/prompt
        ↓
AI STOP — jangan eksekusi dulu
        ↓
AI ajukan pertanyaan brainstorming ke user:
  - "Apa tujuan perubahan ini?"
  - "Apakah ada field yang perlu ditambah/dihapus?"
  - "Bagaimana output yang kamu harapkan?"
        ↓
User jawab & beri persetujuan
        ↓
AI boleh implementasi
```

### Pertanyaan Brainstorming yang Harus Diajukan

Sebelum mengubah prompt, AI wajib tanyakan minimal:
- Apakah bahasa output yang diinginkan (Indonesia / Inggris / sesuai transkrip)?
- Apakah ada field tambahan yang diinginkan di JSON?
- Apakah format action items sudah sesuai kebutuhan?
- Apakah ada konteks khusus meeting (standup, client, retro) yang perlu dipertimbangkan?

### Yang TIDAK Boleh Dilakukan

- Langsung menulis prompt baru tanpa tanya user terlebih dahulu
- Mengubah skema JSON tanpa konfirmasi bahwa perubahan tidak merusak node downstream
- Menganggap hasil brainstorming sebelumnya masih berlaku di sesi baru — selalu konfirmasi ulang
