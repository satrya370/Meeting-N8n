# Public Deploy Design — GitHub Pages + Cloudflare Tunnel

**Goal:** Expose n8n meeting notes form ke publik via Cloudflare Tunnel (auto-restart sebagai Windows Service) + landing page statis di GitHub Pages, sepenuhnya dijalankan oleh Claude Code CLI kecuali satu langkah browser authorization.

**Architecture:**
Visitor mengakses GitHub Pages → klik tombol → diarahkan ke Cloudflare Tunnel URL → n8n form di localhost:5678 → pipeline berjalan → browser download MD/PDF. Tidak ada backend tambahan, tidak ada custom server.

**Tech Stack:** cloudflared (Windows), GitHub Pages, gh CLI, PowerShell, Windows Service

---

## Komponen 1 — Cloudflare Tunnel

### Cara kerja
`cloudflared` berjalan di PC sebagai Windows Service, membuat koneksi outbound ke server Cloudflare. Tidak perlu port forwarding atau firewall rules. Cloudflare menjadi proxy publik yang meneruskan traffic ke `localhost:5678`.

### Named Tunnel (bukan Quick Tunnel)
Pakai **Named Tunnel** agar URL tetap stabil antar restart:
- Quick Tunnel (`cloudflared tunnel --url`): URL random berubah setiap jalan → tidak cocok untuk portfolio
- Named Tunnel: dapat subdomain tetap `<nama>.cfargotunnel.com`

### File yang dibuat
- `D:\meeting n8n\cloudflare\config.yml` — konfigurasi tunnel
- `C:\Users\Satz\.cloudflared\<TUNNEL_ID>.json` — credentials tunnel (auto-generated oleh cloudflared)

### Config tunnel
```yaml
tunnel: <TUNNEL_ID>
credentials-file: C:\Users\Satz\.cloudflared\<TUNNEL_ID>.json
ingress:
  - hostname: <TUNNEL_ID>.cfargotunnel.com
    service: http://localhost:5678
  - service: http_status:404
```

### Langkah setup (urutan)
1. Download `cloudflared.exe` ke `D:\meeting n8n\cloudflare\`
2. `cloudflared tunnel login` → **1 langkah manual**: buka browser, authorize akun Cloudflare
3. `cloudflared tunnel create meeting-notes` → dapat TUNNEL_ID
4. Tulis `config.yml` dengan TUNNEL_ID
5. `cloudflared service install` → register sebagai Windows Service (perlu admin)
6. `sc start cloudflared` → jalankan service
7. Verifikasi: curl tunnel URL → dapat response dari n8n

### Auto-restart behavior
- Windows Service: auto-start saat boot (`START_TYPE: AUTO_START`)
- Jika koneksi putus: cloudflared auto-reconnect tanpa intervensi
- Jika n8n down: tunnel tetap hidup, Cloudflare tampilkan error page otomatis

---

## Komponen 2 — GitHub Pages Landing Page

### Struktur file
```
landing/
  index.html    ← satu file, semua inline (CSS + JS)
```

### Konten `index.html`
- **Hero section**: nama sistem + tagline singkat
- **Cara kerja** (3 langkah): Upload → AI Analisis → Download Notulen
- **Tombol CTA**: "Coba Sekarang →" → href ke tunnel URL + path form n8n
- **Status badge**: JS fetch ke `<tunnel-url>/healthz` setiap 30 detik → tampilkan 🟢 Online / 🔴 Offline
- **Footer**: "Trial portfolio · Server personal · Data tidak disimpan"

### Cara deploy
- Folder `landing/` sudah ada di repo `d:\meeting n8n` (git repo yang ada)
- `gh repo view` untuk dapat nama repo → enable Pages via `gh api`
- GitHub Pages serve dari branch `master`, folder `/landing`
- URL hasil: `https://minju.github.io/meeting-n8n` (atau nama repo yang ada)

### Yang dikerjakan CLI
1. Tulis `landing/index.html`
2. `git add landing/` + `git commit`
3. `git push origin master`
4. `gh api` untuk enable GitHub Pages dengan source `landing/` folder
5. Verifikasi URL aktif

---

## Update `start-n8n.ps1`

Tambah env vars yang diperlukan saat tunnel aktif:
```powershell
$env:N8N_HOST = "<TUNNEL_ID>.cfargotunnel.com"
$env:N8N_PROTOCOL = "https"
$env:WEBHOOK_URL = "https://<TUNNEL_ID>.cfargotunnel.com"
```
Ini memastikan form URL di n8n mengarah ke tunnel (bukan localhost) saat diakses publik.

---

## Langkah Manual (hanya 2)

| # | Langkah | Waktu |
|---|---|---|
| 1 | `cloudflared tunnel login` — klik link di terminal, authorize di browser | ~30 detik |
| 2 | Jalankan `cloudflared service install` di terminal **sebagai Administrator** | ~10 detik |

Semua langkah lain dikerjakan oleh Claude Code CLI.

---

## Batasan & Catatan

- URL tunnel bersifat **publik** — siapa saja yang punya link bisa akses form
- n8n editor (`/`) dan REST API (`/rest`) ikut ter-expose; **rekomendasi**: set `N8N_EDITOR_BASE_URL` atau blokir path via Cloudflare Access (stretch goal, bukan blocker untuk trial)
- Jika PC mati: form tidak bisa diakses, Cloudflare tampilkan "Service Unavailable" otomatis
- GitHub Pages URL aktif dalam ~1-2 menit setelah push pertama

---

## Tidak Termasuk (out of scope)

- Custom domain (perlu beli domain)
- Cloudflare Access / auth untuk lindungi n8n editor
- Multi-PC atau cloud hosting n8n
- SSL certificate management (sudah otomatis via Cloudflare)
