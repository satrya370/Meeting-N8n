# Output File Download Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tambah kemampuan download file (Markdown / PDF-via-HTML) di semua branch pipeline, di samping Notion+Slack yang tetap berjalan.

**Architecture:** Form Trigger ditambah field `Format Output` (Markdown|PDF) dan `responseMode` diubah ke `responseNode` agar browser menunggu output file. Setelah setiap branch selesai (Post to Slack), ditambah node `Render Markdown - [Type]` (Code) yang generate file binary, lalu `Respond to Webhook - [Type]` yang mengirim file ke browser sebagai attachment download. PDF format menghasilkan HTML berformat yang bisa di-print-to-PDF dari browser (fallback — tidak memerlukan library eksternal).

**Tech Stack:** n8n MCP tools (`n8n_update_partial_workflow`), n8n Code node (JS), n8n Respond to Webhook node. Workflow ID: `XscXJksppe3HR3tS`.

---

## Context & Node Map

Workflow saat ini (terminal nodes — semua belum ada Respond to Webhook):
```
Router(0) → Notify - Tidak Bisa Diproses        [terminal]
Router(1) → Extract - Meeting → Parse AI Response → Create Notion Page → Format Blocks - Meeting → Append Blocks - Meeting → Post to Slack  [terminal]
Router(2) → Extract - One on One → Parse - One on One → Create Notion Page - One on One → Format Blocks - One on One → Append Blocks - One on One → Post to Slack - One on One  [terminal]
Router(3) → Extract - Non Meeting → Parse - Non Meeting → Create Notion Page - Non Meeting → Format Blocks - Non Meeting → Append Blocks - Non Meeting → Post to Slack - Non Meeting  [terminal]
Router(4) → Notify - Human Review               [terminal]
```

Form fields saat ini (fieldName):
- `recording` (file)
- `drive_link` (text)
- `meeting_name` (text)

Data akses di Render Markdown nodes:
- Meeting data: `$('Parse AI Response').first().json`
- OON data: `$('Parse - One on One').first().json`
- NM data: `$('Parse - Non Meeting').first().json`
- Format pilihan: `$('Upload Meeting Recording').first().json.format_output`

---

## Task 1: Update Form Trigger

**Files / Nodes:**
- Modify: node `Upload Meeting Recording` (n8n Form Trigger)

- [ ] **Step 1.1: Update formFields + responseMode via MCP**

  Operasi: `n8n_update_partial_workflow` dengan dua `setNodeParameter`:
  - Tambah field Format Output ke `formFields/values` (index 3)
  - Set `responseMode` ke `responseNode`

  ```json
  [
    {
      "type": "setNodeParameter",
      "nodeName": "Upload Meeting Recording",
      "path": "/formFields",
      "value": {
        "values": [
          { "fieldLabel": "File Rekaman Meeting (opsional jika pakai Google Drive)", "fieldType": "file", "fieldName": "recording", "acceptFileTypes": ".mp4,.mp3,.m4a,.wav,.webm,.ogg,.mkv,.mov" },
          { "fieldLabel": "Link Google Drive (opsional jika upload langsung)", "fieldName": "drive_link", "placeholder": "https://drive.google.com/file/d/..." },
          { "fieldLabel": "Nama Meeting (opsional)", "fieldName": "meeting_name" },
          { "fieldLabel": "Format Output", "fieldType": "dropdown", "fieldName": "format_output", "fieldOptions": { "values": [{ "option": "Markdown" }, { "option": "PDF" }] } }
        ]
      }
    },
    {
      "type": "setNodeParameter",
      "nodeName": "Upload Meeting Recording",
      "path": "/responseMode",
      "value": "responseNode"
    }
  ]
  ```

- [ ] **Step 1.2: Verify form di browser**

  Buka `http://localhost:5678/form/36283c3b-8f86-458c-a43d-36142925402f`
  Expected: muncul dropdown "Format Output" dengan opsi Markdown dan PDF.

- [ ] **Step 1.3: Commit checkpoint**

  ```bash
  git add -A && git commit -m "feat: add Format Output field + responseNode mode to form trigger"
  ```

---

## Task 2: Add Render Markdown - Meeting

**Files / Nodes:**
- Create: node `Render Markdown - Meeting` (Code, setelah `Post to Slack`)
- Create: node `Respond to Webhook - Meeting` (Respond to Webhook)

- [ ] **Step 2.1: Add Code node `Render Markdown - Meeting`**

  ```javascript
  const d = $('Parse AI Response').first().json;
  const fmt = ($('Upload Meeting Recording').first().json.format_output || 'Markdown').toLowerCase();
  const title = d.meeting_title || 'Notulen Meeting';
  const date = d.date || new Date().toLocaleDateString('en-CA', {timeZone: 'Asia/Jakarta'});

  // --- Build Markdown ---
  let md = `# ${title}\n\n`;
  md += `| Field | Value |\n|---|---|\n`;
  md += `| Tanggal | ${date} |\n`;
  md += `| Tipe | ${d.meeting_type || '-'} |\n\n`;

  if (d.participants?.length)
    md += `## Peserta\n${d.participants.map(p => `- ${p}`).join('\n')}\n\n`;
  if (d.executive_summary)
    md += `## Ringkasan Eksekutif\n${d.executive_summary}\n\n`;
  if (d.key_decisions?.length)
    md += `## Keputusan Penting\n${d.key_decisions.map(k => `- ${k}`).join('\n')}\n\n`;
  if (d.action_items?.length) {
    md += `## Action Items\n`;
    for (const ai of d.action_items) {
      const owner = ai.owner ? ` *(${ai.owner})*` : '';
      const due = ai.due_date ? ` — ${ai.due_date}` : '';
      md += `- [ ] ${ai.task}${owner}${due}\n`;
    }
    md += '\n';
  }
  if (d.discussion_topics?.length) {
    md += `## Topik Pembahasan\n`;
    for (const t of d.discussion_topics)
      md += `### ${t.topic}\n${t.summary}\n\n`;
  }
  if (d.open_questions?.length)
    md += `## Pertanyaan Terbuka\n${d.open_questions.map(q => `- ${q}`).join('\n')}\n\n`;

  const safeName = title.replace(/[^\wÀ-ɏ\s-]/g, '').trim().replace(/\s+/g, '_').slice(0, 40);
  const baseFilename = `${safeName}_${date}`;

  let buf, ext, contentType;

  if (fmt === 'pdf') {
    // HTML siap print-to-PDF (no external deps)
    let html = `<!DOCTYPE html><html lang="id"><head><meta charset="UTF-8"><title>${title}</title>
  <style>body{font-family:Arial,sans-serif;max-width:760px;margin:40px auto;padding:0 20px;line-height:1.6;color:#222}
  h1{border-bottom:2px solid #333;padding-bottom:8px}h2{color:#444;margin-top:28px;border-left:3px solid #888;padding-left:8px}
  h3{color:#666}table{border-collapse:collapse;margin-bottom:16px}td,th{padding:4px 12px;border:1px solid #ddd}
  ul{padding-left:20px}li{margin:3px 0}.checklist{list-style:none;padding-left:0}
  .checklist li::before{content:"☐ "}.owner{color:#888;font-style:italic;font-size:.9em}
  @media print{body{margin:0 20px}}</style></head><body>`;

    html += `<h1>${title}</h1><table><tr><td><b>Tanggal</b></td><td>${date}</td></tr><tr><td><b>Tipe</b></td><td>${d.meeting_type||'-'}</td></tr></table>`;
    if (d.participants?.length) html += `<h2>Peserta</h2><ul>${d.participants.map(p=>`<li>${p}</li>`).join('')}</ul>`;
    if (d.executive_summary) html += `<h2>Ringkasan Eksekutif</h2><p>${d.executive_summary}</p>`;
    if (d.key_decisions?.length) html += `<h2>Keputusan Penting</h2><ul>${d.key_decisions.map(k=>`<li>${k}</li>`).join('')}</ul>`;
    if (d.action_items?.length) {
      html += `<h2>Action Items</h2><ul class="checklist">`;
      for (const ai of d.action_items) {
        const own = ai.owner?`<span class="owner"> (${ai.owner})</span>`:'';
        const due = ai.due_date?` — ${ai.due_date}`:'';
        html += `<li>${ai.task}${own}${due}</li>`;
      }
      html += `</ul>`;
    }
    if (d.discussion_topics?.length) {
      html += `<h2>Topik Pembahasan</h2>`;
      for (const t of d.discussion_topics) html += `<h3>${t.topic}</h3><p>${t.summary}</p>`;
    }
    if (d.open_questions?.length) html += `<h2>Pertanyaan Terbuka</h2><ul>${d.open_questions.map(q=>`<li>${q}</li>`).join('')}</ul>`;
    html += `</body></html>`;

    buf = Buffer.from(html, 'utf-8');
    ext = 'html'; contentType = 'text/html';
  } else {
    buf = Buffer.from(md, 'utf-8');
    ext = 'md'; contentType = 'text/markdown';
  }

  const bin = await this.helpers.prepareBinaryData(buf, `${baseFilename}.${ext}`, contentType);
  return [{ json: { filename: baseFilename, ext, contentType }, binary: { data: bin } }];
  ```

- [ ] **Step 2.2: Add `Respond to Webhook - Meeting` node**

  Parameters:
  ```json
  {
    "respondWith": "binary",
    "inputFieldName": "data",
    "options": {
      "responseCode": 200,
      "responseHeaders": {
        "entries": [
          {
            "name": "Content-Disposition",
            "value": "={{ 'attachment; filename=\"' + $json.filename + '.' + $json.ext + '\"' }}"
          },
          {
            "name": "Content-Type",
            "value": "={{ $json.contentType }}"
          }
        ]
      }
    }
  }
  ```

- [ ] **Step 2.3: Connect nodes**
  - `Post to Slack` → `Render Markdown - Meeting` → `Respond to Webhook - Meeting`

---

## Task 3: Add Render Markdown - One on One

- [ ] **Step 3.1: Add Code node `Render Markdown - One on One`**

  ```javascript
  const d = $('Parse - One on One').first().json;
  const fmt = ($('Upload Meeting Recording').first().json.format_output || 'Markdown').toLowerCase();
  const title = d.content_title || 'One on One';
  const date = d.date || new Date().toLocaleDateString('en-CA', {timeZone: 'Asia/Jakarta'});
  const pA = d.person_a ? `${d.person_a.name} (${d.person_a.role})` : '-';
  const pB = d.person_b ? `${d.person_b.name} (${d.person_b.role})` : '-';

  let md = `# ${title}\n\n`;
  md += `| Field | Value |\n|---|---|\n`;
  md += `| Tanggal | ${date} |\n| Tipe Sesi | ${d.session_type||'-'} |\n`;
  md += `| Person A | ${pA} |\n| Person B | ${pB} |\n\n`;
  if (d.executive_summary) md += `## Ringkasan\n${d.executive_summary}\n\n`;
  if (d.key_topics?.length) md += `## Topik Utama\n${d.key_topics.map(t=>`- ${t}`).join('\n')}\n\n`;
  if (d.highlights?.length) md += `## Highlights\n${d.highlights.map(h=>`- ${h}`).join('\n')}\n\n`;
  if (d.assessment) md += `## Penilaian\n${d.assessment}\n\n`;
  if (d.action_items?.length) {
    md += `## Action Items\n`;
    for (const ai of d.action_items) {
      const own = ai.owner ? ` *(${ai.owner})*` : '';
      const due = ai.due_date ? ` — ${ai.due_date}` : '';
      md += `- [ ] ${ai.task}${own}${due}\n`;
    }
    md += '\n';
  }
  if (d.follow_up) md += `## Follow Up\n${d.follow_up}\n\n`;

  const safeName = title.replace(/[^\wÀ-ɏ\s-]/g, '').trim().replace(/\s+/g, '_').slice(0, 40);
  const baseFilename = `${safeName}_${date}`;

  let buf, ext, contentType;
  if (fmt === 'pdf') {
    let html = `<!DOCTYPE html><html lang="id"><head><meta charset="UTF-8"><title>${title}</title>
  <style>body{font-family:Arial,sans-serif;max-width:760px;margin:40px auto;padding:0 20px;line-height:1.6;color:#222}
  h1{border-bottom:2px solid #333;padding-bottom:8px}h2{color:#444;margin-top:28px;border-left:3px solid #888;padding-left:8px}
  table{border-collapse:collapse;margin-bottom:16px}td,th{padding:4px 12px;border:1px solid #ddd}
  ul{padding-left:20px}li{margin:3px 0}.checklist{list-style:none;padding-left:0}
  .checklist li::before{content:"☐ "}.owner{color:#888;font-style:italic;font-size:.9em}
  @media print{body{margin:0 20px}}</style></head><body>`;
    html += `<h1>${title}</h1><table>
      <tr><td><b>Tanggal</b></td><td>${date}</td></tr>
      <tr><td><b>Tipe Sesi</b></td><td>${d.session_type||'-'}</td></tr>
      <tr><td><b>Person A</b></td><td>${pA}</td></tr>
      <tr><td><b>Person B</b></td><td>${pB}</td></tr></table>`;
    if (d.executive_summary) html += `<h2>Ringkasan</h2><p>${d.executive_summary}</p>`;
    if (d.key_topics?.length) html += `<h2>Topik Utama</h2><ul>${d.key_topics.map(t=>`<li>${t}</li>`).join('')}</ul>`;
    if (d.highlights?.length) html += `<h2>Highlights</h2><ul>${d.highlights.map(h=>`<li>${h}</li>`).join('')}</ul>`;
    if (d.assessment) html += `<h2>Penilaian</h2><p>${d.assessment}</p>`;
    if (d.action_items?.length) {
      html += `<h2>Action Items</h2><ul class="checklist">`;
      for (const ai of d.action_items) {
        const own = ai.owner?`<span class="owner"> (${ai.owner})</span>`:'';
        const due = ai.due_date?` — ${ai.due_date}`:'';
        html += `<li>${ai.task}${own}${due}</li>`;
      }
      html += `</ul>`;
    }
    if (d.follow_up) html += `<h2>Follow Up</h2><p>${d.follow_up}</p>`;
    html += `</body></html>`;
    buf = Buffer.from(html, 'utf-8'); ext = 'html'; contentType = 'text/html';
  } else {
    buf = Buffer.from(md, 'utf-8'); ext = 'md'; contentType = 'text/markdown';
  }

  const bin = await this.helpers.prepareBinaryData(buf, `${baseFilename}.${ext}`, contentType);
  return [{ json: { filename: baseFilename, ext, contentType }, binary: { data: bin } }];
  ```

- [ ] **Step 3.2: Add `Respond to Webhook - One on One` (same config as Task 2.2)**

- [ ] **Step 3.3: Connect** `Post to Slack - One on One` → `Render Markdown - One on One` → `Respond to Webhook - One on One`

---

## Task 4: Add Render Markdown - Non Meeting

- [ ] **Step 4.1: Add Code node `Render Markdown - Non Meeting`**

  ```javascript
  const d = $('Parse - Non Meeting').first().json;
  const fmt = ($('Upload Meeting Recording').first().json.format_output || 'Markdown').toLowerCase();
  const title = d.content_title || 'Catatan Konten';
  const date = d.date || new Date().toLocaleDateString('en-CA', {timeZone: 'Asia/Jakarta'});

  let md = `# ${title}\n\n`;
  md += `| Field | Value |\n|---|---|\n`;
  md += `| Tanggal | ${date} |\n| Kategori | ${d.content_category||'-'} |\n`;
  if (d.moderator) md += `| Moderator | ${d.moderator} |\n`;
  if (d.topic) md += `| Topik | ${d.topic} |\n`;
  md += '\n';

  if (d.executive_summary) md += `## Ringkasan\n${d.executive_summary}\n\n`;
  if (d.question) md += `## Pertanyaan Sentral\n> ${d.question}\n\n`;
  const dn = d.detailed_notes || {};
  if (dn.main_themes?.length) md += `## Tema Utama\n${dn.main_themes.map(t=>`- ${t}`).join('\n')}\n\n`;
  if (dn.key_points?.length) md += `## Poin Penting\n${dn.key_points.map((p,i)=>`${i+1}. ${p}`).join('\n')}\n\n`;
  if (dn.notable_quotes?.length) md += `## Kutipan Menarik\n${dn.notable_quotes.map(q=>`> ${q}`).join('\n\n')}\n\n`;
  if (dn.open_questions?.length) md += `## Pertanyaan Terbuka\n${dn.open_questions.map(q=>`- ${q}`).join('\n')}\n\n`;
  if (d.follow_up) md += `## Follow Up\n${d.follow_up}\n\n`;

  const safeName = title.replace(/[^\wÀ-ɏ\s-]/g, '').trim().replace(/\s+/g, '_').slice(0, 40);
  const baseFilename = `${safeName}_${date}`;

  let buf, ext, contentType;
  if (fmt === 'pdf') {
    let html = `<!DOCTYPE html><html lang="id"><head><meta charset="UTF-8"><title>${title}</title>
  <style>body{font-family:Arial,sans-serif;max-width:760px;margin:40px auto;padding:0 20px;line-height:1.6;color:#222}
  h1{border-bottom:2px solid #333;padding-bottom:8px}h2{color:#444;margin-top:28px;border-left:3px solid #888;padding-left:8px}
  table{border-collapse:collapse;margin-bottom:16px}td,th{padding:4px 12px;border:1px solid #ddd}
  ul,ol{padding-left:20px}li{margin:3px 0}blockquote{border-left:3px solid #ccc;margin:8px 0;padding:4px 12px;color:#555}
  @media print{body{margin:0 20px}}</style></head><body>`;
    html += `<h1>${title}</h1><table>
      <tr><td><b>Tanggal</b></td><td>${date}</td></tr>
      <tr><td><b>Kategori</b></td><td>${d.content_category||'-'}</td></tr>
      ${d.moderator?`<tr><td><b>Moderator</b></td><td>${d.moderator}</td></tr>`:''}
      ${d.topic?`<tr><td><b>Topik</b></td><td>${d.topic}</td></tr>`:''}</table>`;
    if (d.executive_summary) html += `<h2>Ringkasan</h2><p>${d.executive_summary}</p>`;
    if (d.question) html += `<h2>Pertanyaan Sentral</h2><blockquote>${d.question}</blockquote>`;
    if (dn.main_themes?.length) html += `<h2>Tema Utama</h2><ul>${dn.main_themes.map(t=>`<li>${t}</li>`).join('')}</ul>`;
    if (dn.key_points?.length) html += `<h2>Poin Penting</h2><ol>${dn.key_points.map(p=>`<li>${p}</li>`).join('')}</ol>`;
    if (dn.notable_quotes?.length) html += `<h2>Kutipan Menarik</h2>${dn.notable_quotes.map(q=>`<blockquote>${q}</blockquote>`).join('')}`;
    if (dn.open_questions?.length) html += `<h2>Pertanyaan Terbuka</h2><ul>${dn.open_questions.map(q=>`<li>${q}</li>`).join('')}</ul>`;
    if (d.follow_up) html += `<h2>Follow Up</h2><p>${d.follow_up}</p>`;
    html += `</body></html>`;
    buf = Buffer.from(html, 'utf-8'); ext = 'html'; contentType = 'text/html';
  } else {
    buf = Buffer.from(md, 'utf-8'); ext = 'md'; contentType = 'text/markdown';
  }

  const bin = await this.helpers.prepareBinaryData(buf, `${baseFilename}.${ext}`, contentType);
  return [{ json: { filename: baseFilename, ext, contentType }, binary: { data: bin } }];
  ```

- [ ] **Step 4.2: Add `Respond to Webhook - Non Meeting` (same config as Task 2.2)**

- [ ] **Step 4.3: Connect** `Post to Slack - Non Meeting` → `Render Markdown - Non Meeting` → `Respond to Webhook - Non Meeting`

---

## Task 5: Add Respond to Webhook untuk Error Branches

- [ ] **Step 5.1: Add `Respond to Webhook - Review` setelah `Notify - Human Review`**

  Parameters:
  ```json
  {
    "respondWith": "text",
    "responseBody": "⚠️ Konten ini memerlukan review manual. Tim kami akan menghubungi Anda.",
    "options": { "responseCode": 200 }
  }
  ```
  Connect: `Notify - Human Review` → `Respond to Webhook - Review`

- [ ] **Step 5.2: Add `Respond to Webhook - Invalid` setelah `Notify - Tidak Bisa Diproses`**

  Parameters:
  ```json
  {
    "respondWith": "text",
    "responseBody": "❌ File tidak dapat diproses. Pastikan file berisi audio/video yang jelas.",
    "options": { "responseCode": 422 }
  }
  ```
  Connect: `Notify - Tidak Bisa Diproses` → `Respond to Webhook - Invalid`

---

## Task 6: Test End-to-End

- [ ] **Step 6.1: Test dengan Markdown format**
  - Buka form, pilih Format Output = Markdown
  - Upload `D:\meeting n8n\videoplayback.mp4`
  - Expected: browser download file `*.md` setelah proses selesai

- [ ] **Step 6.2: Test dengan PDF format**
  - Pilih Format Output = PDF
  - Expected: browser download file `*.html` (siap print-to-PDF)

- [ ] **Step 6.3: Verify Notion + Slack masih berjalan**
  - Buka Notion DB, pastikan page baru terbuat
  - Buka Slack, pastikan notifikasi terkirim

---

## Notes & Limitations

- **PDF format** menghasilkan `.html` (bukan `.pdf` binary) — user buka file → Ctrl+P → Save as PDF. True PDF generation butuh `pdfkit` yang belum ter-install. Bisa ditambahkan di iterasi berikutnya dengan `npm install pdfkit -g`.
- **Response timeout**: workflow bisa 2-5 menit untuk file panjang. Browser menunggu selama ini. Ini acceptable untuk portfolio demo.
- **Notion + Slack tetap berjalan**: tidak ada perubahan pada node-node yang sudah ada.
