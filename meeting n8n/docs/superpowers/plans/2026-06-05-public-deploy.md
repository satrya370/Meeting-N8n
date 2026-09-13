# Public Deploy — GitHub Pages + Cloudflare Tunnel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose the n8n meeting notes form to the public internet via a Cloudflare Named Tunnel (stable URL, Windows Service) with a GitHub Pages landing page as the entry point.

**Architecture:** `cloudflared` runs as a Windows Service creating an outbound tunnel to Cloudflare's edge — no firewall changes or port forwarding needed. Visitors land on `https://satrya370.github.io/Meeting-N8n`, click the CTA, and are forwarded to `https://<TUNNEL_UUID>.cfargotunnel.com/form/<path>` which proxies to `http://localhost:5678`. The landing page JS polls `/healthz` every 30 seconds to show live server status.

**Tech Stack:** cloudflared (Windows binary), Windows Service Manager (`sc`), GitHub Pages, `gh` CLI, PowerShell, n8n self-hosted on localhost:5678

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `D:\meeting n8n\cloudflare\cloudflared.exe` | Create | Cloudflare tunnel binary |
| `D:\meeting n8n\cloudflare\config.yml` | Create | Tunnel config (tracked in git, no secrets) |
| `C:\Users\Satz\.cloudflared\config.yml` | Create | Canonical config location for Windows Service |
| `d:\meeting n8n\.gitignore` | Modify | Exclude cloudflared.exe + any .json in cloudflare/ |
| `d:\meeting n8n\start-n8n.ps1` | Modify | Add N8N_HOST / N8N_PROTOCOL / WEBHOOK_URL env vars |
| `d:\meeting n8n\landing\index.html` | Create | Single-file landing page with status badge |

---

## Task 1: Prepare cloudflare directory + update .gitignore

**Files:**
- Create: `D:\meeting n8n\cloudflare\` (directory only — no file created by this task)
- Modify: `d:\meeting n8n\.gitignore`

- [ ] **Step 1: Create the cloudflare directory**

```powershell
New-Item -ItemType Directory -Force -Path "D:\meeting n8n\cloudflare"
```

Expected: `D:\meeting n8n\cloudflare\` directory exists. (If it already exists, command succeeds silently.)

- [ ] **Step 2: Add cloudflare entries to .gitignore**

In `d:\meeting n8n\.gitignore`, append after the `# Runtime data` section:

```
# Cloudflare tunnel binary + auto-generated credentials (no secrets in config.yml)
cloudflare/cloudflared.exe
cloudflare/*.json
```

- [ ] **Step 3: Verify gitignore syntax**

```bash
cd "D:/" && git check-ignore -v "meeting n8n/cloudflare/cloudflared.exe"
```

Expected output: `meeting n8n/.gitignore:XX:cloudflare/cloudflared.exe  meeting n8n/cloudflare/cloudflared.exe`

- [ ] **Step 4: Commit**

```bash
cd "D:/" && git add "meeting n8n/.gitignore" && git commit -m "chore: gitignore cloudflare binary and credentials"
```

---

## Task 2: Download cloudflared.exe

**Files:**
- Create: `D:\meeting n8n\cloudflare\cloudflared.exe`

- [ ] **Step 1: Download cloudflared Windows AMD64 binary**

```powershell
Invoke-WebRequest `
  -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" `
  -OutFile "D:\meeting n8n\cloudflare\cloudflared.exe"
```

Expected: File downloads. Size should be ~30–50 MB.

- [ ] **Step 2: Verify binary runs**

```powershell
& "D:\meeting n8n\cloudflare\cloudflared.exe" --version
```

Expected output: `cloudflared version YYYY.M.X (built YYYY-MM-DD...)` — any version number is fine.

---

## Task 3: Authenticate + create Named Tunnel (MANUAL BROWSER STEP)

**Output of this task:** `TUNNEL_UUID` — a UUID string like `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`. You will use this in every subsequent task.

- [ ] **Step 1: Log in to Cloudflare (opens browser)**

```powershell
& "D:\meeting n8n\cloudflare\cloudflared.exe" tunnel login
```

Expected: A URL is printed. Open it in a browser, select your Cloudflare account, authorize. Terminal shows `You have successfully logged in.` after authorization. This writes a `cert.pem` to `C:\Users\Satz\.cloudflared\cert.pem`.

> **MANUAL ACTION REQUIRED:** Click the URL printed in the terminal and authorize in the browser. Come back here once the terminal shows success.

- [ ] **Step 2: Create the Named Tunnel**

```powershell
& "D:\meeting n8n\cloudflare\cloudflared.exe" tunnel create meeting-notes
```

Expected output (example — your UUID will differ):
```
Tunnel credentials written to C:\Users\Satz\.cloudflared\xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.json.
Created tunnel meeting-notes with id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

- [ ] **Step 3: Note your TUNNEL_UUID**

Copy the UUID from the output above. You will substitute `TUNNEL_UUID` in Tasks 4, 5, and 6 with this value.

Example: if the output shows `id a1b2c3d4-e5f6-7890-abcd-ef1234567890`, your `TUNNEL_UUID` = `a1b2c3d4-e5f6-7890-abcd-ef1234567890`.

- [ ] **Step 4: Confirm credentials file exists**

```powershell
Test-Path "C:\Users\Satz\.cloudflared\<YOUR_TUNNEL_UUID>.json"
```

Expected: `True`

---

## Task 4: Write tunnel config.yml

**Files:**
- Create: `D:\meeting n8n\cloudflare\config.yml`
- Create: `C:\Users\Satz\.cloudflared\config.yml`

> **Before starting:** substitute every occurrence of `TUNNEL_UUID` below with the actual UUID from Task 3 Step 2.

- [ ] **Step 1: Write config to the repo copy**

Create `D:\meeting n8n\cloudflare\config.yml` with this content (replacing `TUNNEL_UUID`):

```yaml
tunnel: TUNNEL_UUID
credentials-file: C:\Users\Satz\.cloudflared\TUNNEL_UUID.json

ingress:
  - hostname: TUNNEL_UUID.cfargotunnel.com
    service: http://localhost:5678
  - service: http_status:404
```

- [ ] **Step 2: Copy config to canonical location for Windows Service**

```powershell
Copy-Item "D:\meeting n8n\cloudflare\config.yml" "C:\Users\Satz\.cloudflared\config.yml" -Force
```

- [ ] **Step 3: Validate config syntax**

```powershell
& "D:\meeting n8n\cloudflare\cloudflared.exe" tunnel --config "C:\Users\Satz\.cloudflared\config.yml" ingress validate
```

Expected: `Validating rules from C:\Users\Satz\.cloudflared\config.yml` followed by `OK` for each ingress rule and `Configuration is valid.`

- [ ] **Step 4: Commit config.yml to repo**

```bash
cd "D:/" && git add "meeting n8n/cloudflare/config.yml" && git commit -m "feat: add cloudflare tunnel config"
```

---

## Task 5: Update start-n8n.ps1 with tunnel env vars

**Files:**
- Modify: `d:\meeting n8n\start-n8n.ps1` (lines 26–32, the `# --- Environment variables ---` block)

> **Before starting:** substitute `TUNNEL_UUID` with your actual UUID from Task 3.

- [ ] **Step 1: Add tunnel env vars to the environment section**

In `d:\meeting n8n\start-n8n.ps1`, find the `# --- Environment variables ---` block (line 26). Add 3 new lines immediately after the comment and before the existing `$env:NODE_FUNCTION_ALLOW_BUILTIN` line:

```powershell
# --- Environment variables ---
$env:N8N_HOST     = "TUNNEL_UUID.cfargotunnel.com"
$env:N8N_PROTOCOL = "https"
$env:WEBHOOK_URL  = "https://TUNNEL_UUID.cfargotunnel.com"
$env:NODE_FUNCTION_ALLOW_BUILTIN  = '*'
$env:NODE_FUNCTION_ALLOW_EXTERNAL = '*'
# ... rest of existing vars unchanged ...
```

- [ ] **Step 2: Also update the status output block**

In `start-n8n.ps1`, after the `Write-Host "  URL  : http://localhost:5678"` line (line 53), add:

```powershell
Write-Host "  Publik: https://$env:N8N_HOST" -ForegroundColor Cyan
```

- [ ] **Step 3: Verify the file looks correct**

```powershell
Select-String -Path "D:\meeting n8n\start-n8n.ps1" -Pattern "N8N_HOST|N8N_PROTOCOL|WEBHOOK_URL"
```

Expected: 3 lines found, each with your `TUNNEL_UUID` in them.

- [ ] **Step 4: Commit**

```bash
cd "D:/" && git add "meeting n8n/start-n8n.ps1" && git commit -m "feat: expose tunnel URL in n8n env vars"
```

---

## Task 6: Create landing/index.html

**Files:**
- Create: `D:\meeting n8n\landing\index.html`

> **Before starting:** substitute `TUNNEL_UUID` with your actual UUID from Task 3. The form path `36283c3b-8f86-458c-a43d-36142925402f` is the n8n Form Trigger path — do not change it.

- [ ] **Step 1: Create landing directory**

```powershell
New-Item -ItemType Directory -Force -Path "D:\meeting n8n\landing"
```

- [ ] **Step 2: Write index.html** (replace `TUNNEL_UUID` before saving)

Create `D:\meeting n8n\landing\index.html` with this exact content:

```html
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Meeting Notes AI — Portfolio Trial</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: #0f172a; color: #e2e8f0;
      min-height: 100vh; display: flex; flex-direction: column;
      align-items: center; padding: 48px 24px;
    }
    .badge {
      display: inline-flex; align-items: center; gap: 8px;
      background: #1e293b; border: 1px solid #334155;
      border-radius: 9999px; padding: 6px 16px;
      font-size: 13px; margin-bottom: 32px;
    }
    .dot { width: 8px; height: 8px; border-radius: 50%; background: #64748b; }
    .dot.online  { background: #22c55e; animation: pulse 2s infinite; }
    .dot.offline { background: #ef4444; }
    @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:.5} }
    h1 {
      font-size: clamp(28px, 5vw, 48px); font-weight: 700; text-align: center;
      background: linear-gradient(135deg, #e2e8f0 0%, #94a3b8 100%);
      -webkit-background-clip: text; -webkit-text-fill-color: transparent;
      background-clip: text; margin-bottom: 16px;
    }
    .tagline {
      font-size: 18px; color: #94a3b8; text-align: center;
      margin-bottom: 48px; max-width: 480px; line-height: 1.6;
    }
    .steps {
      display: flex; gap: 24px; margin-bottom: 48px;
      flex-wrap: wrap; justify-content: center;
    }
    .step {
      background: #1e293b; border: 1px solid #334155; border-radius: 12px;
      padding: 24px; max-width: 200px; text-align: center;
    }
    .step-num  { font-size: 28px; margin-bottom: 12px; }
    .step h3   { font-size: 15px; font-weight: 600; margin-bottom: 8px; color: #e2e8f0; }
    .step p    { font-size: 13px; color: #64748b; line-height: 1.5; }
    .cta {
      display: inline-block; background: #3b82f6; color: white;
      font-size: 17px; font-weight: 600; padding: 16px 40px;
      border-radius: 10px; text-decoration: none;
      transition: background .2s, transform .1s; margin-bottom: 48px;
    }
    .cta:hover { background: #2563eb; transform: translateY(-1px); }
    .cta.disabled { background: #334155; color: #64748b; cursor: not-allowed; pointer-events: none; }
    footer { font-size: 12px; color: #475569; text-align: center; line-height: 1.8; }
  </style>
</head>
<body>
  <div class="badge">
    <span class="dot" id="dot"></span>
    <span id="status-text">Memeriksa status...</span>
  </div>

  <h1>Meeting Notes AI</h1>
  <p class="tagline">
    Upload rekaman rapat, dapatkan notulen terstruktur dalam hitungan menit.
    Didukung Whisper + Groq AI.
  </p>

  <div class="steps">
    <div class="step">
      <div class="step-num">🎙️</div>
      <h3>1. Upload</h3>
      <p>Unggah rekaman audio rapat Anda (MP4, MP3, M4A)</p>
    </div>
    <div class="step">
      <div class="step-num">🤖</div>
      <h3>2. AI Analisis</h3>
      <p>Whisper transkrip · Groq ekstrak poin, keputusan, action items</p>
    </div>
    <div class="step">
      <div class="step-num">📄</div>
      <h3>3. Unduh</h3>
      <p>Download notulen Markdown · tersimpan otomatis ke Notion</p>
    </div>
  </div>

  <a href="#" class="cta disabled" id="cta-btn">Memeriksa server...</a>

  <footer>
    Trial portfolio · Server personal (bisa offline) · Data tidak disimpan permanen<br>
    Dibuat dengan n8n + Claude Code
  </footer>

  <script>
    const TUNNEL_URL = 'https://TUNNEL_UUID.cfargotunnel.com';
    const FORM_PATH  = '/form/36283c3b-8f86-458c-a43d-36142925402f';
    const dot  = document.getElementById('dot');
    const text = document.getElementById('status-text');
    const btn  = document.getElementById('cta-btn');

    async function checkStatus() {
      try {
        const r = await fetch(TUNNEL_URL + '/healthz', {
          signal: AbortSignal.timeout(5000)
        });
        if (r.ok) {
          dot.className  = 'dot online';
          text.textContent = 'Server Online';
          btn.href = TUNNEL_URL + FORM_PATH;
          btn.textContent = 'Coba Sekarang →';
          btn.classList.remove('disabled');
        } else {
          throw new Error('not ok');
        }
      } catch {
        dot.className  = 'dot offline';
        text.textContent = 'Server Offline';
        btn.textContent = 'Server sedang offline';
        btn.classList.add('disabled');
      }
    }

    checkStatus();
    setInterval(checkStatus, 30000);
  </script>
</body>
</html>
```

- [ ] **Step 3: Verify TUNNEL_UUID was substituted**

```powershell
# Should return 0 results — confirms no leftover placeholder
Select-String -Path "D:\meeting n8n\landing\index.html" -Pattern "TUNNEL_UUID"
# Should return 1 result — confirms real UUID is present
Select-String -Path "D:\meeting n8n\landing\index.html" -Pattern "cfargotunnel\.com"
```

Expected: First command returns **no output** (0 matches). Second command returns 1 line showing `const TUNNEL_URL = 'https://<your-actual-uuid>.cfargotunnel.com'`.

---

## Task 7: Push landing page + enable GitHub Pages

**Files:**
- Modify: `D:\meeting n8n\landing\index.html` (already created in Task 6)

- [ ] **Step 1: Stage and commit landing page**

```bash
cd "D:/" && git add "meeting n8n/landing/index.html" && git commit -m "feat: add GitHub Pages landing page"
```

- [ ] **Step 2: Push to GitHub**

```bash
cd "D:/" && git push origin master
```

Expected: `master -> master` confirmation.

- [ ] **Step 3: Verify gh CLI is authenticated**

```bash
gh auth status
```

Expected: `Logged in to github.com as satrya370` (or whatever the account). If not logged in, run `gh auth login` first.

- [ ] **Step 4: Enable GitHub Pages with /landing as source**

```bash
gh api repos/satrya370/Meeting-N8n/pages \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  -f "source[branch]=master" \
  -f "source[path]=/landing"
```

Expected: JSON response with `"url": "https://api.github.com/repos/satrya370/Meeting-N8n/pages"` and `"status": "queued"` or `"built"`.

If Pages is already enabled (returns 409 Conflict), update instead:

```bash
gh api repos/satrya370/Meeting-N8n/pages \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -f "source[branch]=master" \
  -f "source[path]=/landing"
```

- [ ] **Step 5: Wait ~2 minutes, then open the Pages URL**

```bash
gh api repos/satrya370/Meeting-N8n/pages --jq '.html_url'
```

Expected output: `https://satrya370.github.io/Meeting-N8n`

Open in browser — should show the landing page. The CTA button will say "Server Offline" at this point (tunnel not yet running) — that's expected.

---

## Task 8: Install cloudflared as Windows Service (MANUAL — Admin required)

> **MANUAL ACTION REQUIRED:** This task must be run in a PowerShell terminal opened as Administrator (right-click PowerShell → "Run as administrator").

- [ ] **Step 1: Open an Administrator PowerShell** (manual)

Right-click the Start menu → "Windows PowerShell (Admin)" or "Terminal (Admin)".

- [ ] **Step 2: Install cloudflared as a Windows Service**

```powershell
& "D:\meeting n8n\cloudflare\cloudflared.exe" --config "C:\Users\Satz\.cloudflared\config.yml" service install
```

Expected: `INFO Installing cloudflared Windows service` followed by `INFO cloudflared service installed successfully.`

- [ ] **Step 3: Start the service**

```powershell
Start-Service cloudflared
```

Expected: No error. If it returns immediately, the service started.

- [ ] **Step 4: Verify service is running**

```powershell
Get-Service cloudflared
```

Expected:
```
Status   Name               DisplayName
------   ----               -----------
Running  cloudflared        Cloudflare Tunnel: cloudflared
```

- [ ] **Step 5: Verify service start type is Automatic**

```powershell
Get-Service cloudflared | Select-Object StartType
```

Expected: `StartType: Automatic` — this means cloudflared starts automatically on Windows boot.

---

## Task 9: End-to-end verification

> **Before this task:** n8n must be running (`.\start-n8n.ps1` in the project folder). The cloudflared service from Task 8 should be Running.

- [ ] **Step 1: Start n8n with the new env vars**

```powershell
& "D:\meeting n8n\start-n8n.ps1"
```

Expected: Shows `n8n berjalan!` with both `URL: http://localhost:5678` and `Publik: https://<TUNNEL_UUID>.cfargotunnel.com`.

- [ ] **Step 2: Test the tunnel proxies to n8n healthcheck**

```powershell
$r = Invoke-WebRequest "https://TUNNEL_UUID.cfargotunnel.com/healthz" -UseBasicParsing
$r.StatusCode; $r.Content
```

Expected: `200` and `{"status":"ok"}` (n8n health endpoint).

- [ ] **Step 3: Test the form is reachable through the tunnel**

Open a browser and navigate to:
```
https://TUNNEL_UUID.cfargotunnel.com/form/36283c3b-8f86-458c-a43d-36142925402f
```

Expected: n8n form UI loads in the browser with the upload fields.

- [ ] **Step 4: Test the landing page status badge**

Open: `https://satrya370.github.io/Meeting-N8n`

Expected:
- Green pulsing dot next to "Server Online"
- "Coba Sekarang →" button is clickable and links to the tunnel form URL
- Clicking the button opens the n8n form

- [ ] **Step 5: Test auto-restart behavior (optional sanity check)**

```powershell
# Stop and restart the service to confirm it auto-reconnects
Restart-Service cloudflared
Start-Sleep -Seconds 10
$r = Invoke-WebRequest "https://TUNNEL_UUID.cfargotunnel.com/healthz" -UseBasicParsing
$r.StatusCode
```

Expected: `200` — tunnel reconnects within a few seconds.

---

## Notes

- **PC must be on + n8n running** for the form to be accessible. If the PC is off, Cloudflare serves an error page — the landing page's JS will show "Server Offline" automatically.
- **Tunnel URL is permanent.** `<TUNNEL_UUID>.cfargotunnel.com` is stable as long as the Named Tunnel `meeting-notes` exists in your Cloudflare account. It does not change on restart.
- **n8n editor is also exposed** at `https://<TUNNEL_UUID>.cfargotunnel.com/`. To restrict access to just the form, set `N8N_EDITOR_BASE_URL=http://localhost:5678` in `start-n8n.ps1` so the editor only binds to localhost. (Stretch goal — not blocking for trial.)
- **Cloudflare account link:** `cert.pem` at `C:\Users\Satz\.cloudflared\cert.pem` ties the tunnel to your account. Don't delete it.
