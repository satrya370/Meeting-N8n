# Credential mapping (tanpa nilai rahasia)

Workflow `XscXJksppe3HR3tS` di VPS sudah ditautkan ke credential berikut:

| Fungsi | Tipe n8n | Nama | ID pada VPS |
|---|---|---|---|
| Classify & Extract (4 node) | HTTP Header Auth | `KobiLLM Authorization - IG Content Builder` | `PDV1vyCD82gzcGNy` |
| Transcribe with Whisper | HTTP Header Auth | `Groq Authorization - Meeting Notes` | `SV7w3TfcQmjFWsXi` |
| Send Email (3 node) | Gmail OAuth2 | `Gmail OAuth2 - IG Content Builder` | `MvNkkpoXAqmWU2rZ` |

Nilai API key/OAuth tidak disimpan di repository. Credential dibuat atau dikelola dari n8n Credential Store terenkripsi. Saat memindahkan workflow ke instance n8n baru, buat credential dengan tipe dan header/provider yang sama lalu pilih ulang credential pada node.
