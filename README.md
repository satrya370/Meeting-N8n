# Meeting Notes n8n — AWS/VPS package

This package runs the **Meeting Notes — Main Pipeline** workflow on a VPS with Docker, PostgreSQL, persistent binary files, and `ffmpeg` for audio conversion.

## Contents

- `workflows/meeting-notes-main-pipeline.json` — sanitized workflow export; no API keys or n8n credentials are included.
- `Dockerfile` — adds `ffmpeg`, required by the **Audio Conversion** Code node.
- `docker-compose.yml` — n8n + PostgreSQL deployment.
- `.env.example` — configuration template.

## VPS deployment

1. Install Docker Engine and Docker Compose Plugin on the VPS, then clone this repository.
2. Copy `.env.example` to `.env` and replace every `replace-with-...` value. Set `N8N_HOST`, `N8N_EDITOR_BASE_URL`, and `WEBHOOK_URL` to your real HTTPS domain.
3. Start the stack:

   ```bash
   docker compose --env-file .env up -d --build
   ```

4. Put n8n behind an HTTPS reverse proxy (Caddy, Nginx, or an AWS load balancer). Do not expose port 5678 directly to the internet.
5. Open n8n, create the owner account, then import the workflow:

   ```bash
   docker compose exec n8n n8n import:workflow --input=/workflows/meeting-notes-main-pipeline.json
   ```

6. In the imported workflow, configure these credentials before activating it:
   - HTTP Header Auth for the three MiniMax/LLM request nodes (or recreate the credential referred to by your environment).
   - SMTP for the three email nodes.
   - `GROQ_API_KEY` in `.env` is already referenced by the Whisper node as an n8n expression.
   - Re-select or recreate the configured error workflow, if you use one.
7. Save and activate the workflow. The form URL will use `WEBHOOK_URL`.

## Security notes

- Never commit `.env`, `.n8n`, database files, or exported credentials.
- The original hard-coded Groq key was removed from this export. Rotate that key in Groq because it existed in the local workflow configuration.
- Back up both Docker volumes (`n8n-data` and `postgres-data`) before upgrades.

## Commands

```bash
npm run up
npm run logs
npm run import:workflow
npm run down
```

`npm` is optional; each command just wraps Docker Compose.

## Add Meeting Notes to an existing n8n VPS stack

If your VPS already runs n8n with the IG Content Builder and Chromium, use the files made specifically for that stack instead of replacing its database or existing `n8n_data` directory.

1. Copy `Dockerfile.meeting-notes` over the VPS `Dockerfile`. It preserves the existing IG template setup and adds `ffmpeg`.
2. Copy `docker-compose.meeting-notes.override.yml` into the same directory as the existing `docker-compose.yml`.
3. Create a server-only `.env` entry: `GROQ_API_KEY=...`.
4. Copy `workflows/meeting-notes-main-pipeline.json` to `./workflows/` on the VPS.
5. Rebuild while retaining the existing `./n8n_data` volume:

   ```bash
   docker compose -f docker-compose.yml -f docker-compose.meeting-notes.override.yml up -d --build
   docker compose -f docker-compose.yml -f docker-compose.meeting-notes.override.yml exec n8n n8n import:workflow --input=/workflows/meeting-notes-main-pipeline.json
   ```

The imported workflow still needs its SMTP and LLM HTTP credentials configured in the n8n UI before activation.
