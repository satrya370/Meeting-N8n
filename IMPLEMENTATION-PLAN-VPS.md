# Implementation plan — Meeting Notes pada VPS existing

Tanggal pemeriksaan: 13 September 2026. Status: plan; belum mengeksekusi perubahan deployment dalam turn ini.

## Target dan kondisi terverifikasi

- SSH: ubuntu@15.232.197.72, direktori /home/ubuntu/n8n-deploy.
- n8n 2.38.5 dan Chromium sedang berjalan. Port n8n terikat ke 127.0.0.1:5678.
- FFmpeg 6.0 sudah tersedia; Dockerfile menggunakan multi-stage static ffmpeg/ffprobe.
- Workflow XscXJksppe3HR3tS sudah terdaftar. Export lokal berisi 23 node.
- Dependency IG existing: xlsx, docxtemplater, pizzip serta dua folder template.
- Compose memberi peringatan GROQ_API_KEY belum diset.
- Empat request LLM menggunakan https://api.koboillm.com/v1/chat/completions; transkripsi menggunakan Groq. Penyebutan MiniMax dalam dokumentasi lama bukan acuan credential endpoint.
- Credential_information.md tersedia. Pemeriksaan kategori menemukan Kobo/Vertex/OpenAI dan Gmail; tidak menemukan label Groq atau SMTP/app password. Ketersediaan secret yang cocok dan valid belum terbukti.

## 1. Baseline dan backup

1. Ambil konfigurasi VPS terkini melalui SSH dengan penyaringan secret; jadikan baseline Dockerfile dan Compose lokal.
2. Catat digest image, mount, owner folder, kapasitas disk/RAM, status workflow aktif dan execution berjalan.
3. Buat backup bertimestamp Dockerfile, Compose dan JSON Meeting Notes sebelum mengganti file.
4. Buat backup SQLite konsisten memakai fasilitas SQLite backup atau saat n8n berhenti terkontrol; simpan konfigurasi encryption key dan binary data dalam backup privat dengan permission terbatas.
5. Jadwalkan recreate sesudah execution aktif selesai. Pertahankan mount n8n_data dan encryption key existing.

## 2. Paket deployment yang mengikuti VPS

1. Satukan Dockerfile dan docker-compose.yml utama paket dengan stack VPS existing. Hilangkan kebingungan antara Compose PostgreSQL untuk instalasi baru dan Compose SQLite existing.
2. Pin image n8n ke versi/digest yang sedang berjalan; pin sumber static FFmpeg berdasarkan image yang sudah teruji. Jangan memakai apk pada runtime n8n.
3. Pertahankan dependency IG, Chromium, mount OCR dan instalasi template. Sertakan FFmpeg/ffprobe beserta provenance image dan langkah verifikasi.
4. Sesuaikan package.json: scripts build, up, logs, validate:compose dan import:workflow mengarah ke Compose canonical yang sama. FFmpeg disediakan image Docker, bukan dependency npm.
5. Tambahkan .dockerignore untuk mengecualikan .env, database, backup, private key dan credential plaintext dari build context.
6. Pastikan workflow JSON berada dalam ./workflows dan dapat dibaca user node. Paket publik hanya memuat template konfigurasi dan workflow tersanitasi.

## 3. Compose dan kompatibilitas audio

1. Pertahankan domain, binding loopback, timezone, Chromium dan mount existing.
2. Gunakan binary filesystem dan periksa limit upload n8n serta reverse proxy yang benar untuk versi terpasang, termasuk multipart form. Selaraskan dengan batas ukuran/durasi pada form.
3. Uji akses fs/path/os/child_process dari Code node melalui task runner sebenarnya. Tes docker exec biasa tidak cukup.
4. Selaraskan task timeout dengan konversi yang saat ini mengizinkan 600 detik; tetapkan nilai eksplisit sesuai hasil uji dan kapasitas VPS.
5. Periksa izin runtime terhadap binary storage dan temporary files. Jangan menonaktifkan sandbox secara luas hanya agar konversi lolos.

## 4. Perbaikan dan import JSON

1. Ekspor versi Meeting Notes yang ada di VPS sebagai backup dan bandingkan dengan sumber lokal sebelum menimpa ID yang sama.
2. Pertahankan id dan hubungan node; perbaiki encoding UTF-8 yang terlihat rusak pada nama/komentar.
3. Perbaiki pembacaan binary agar memakai helper n8n yang didukung, jika tersedia pada runtime, alih-alih menebak lokasi filesystem-v2 melalui os.homedir(). Pertimbangkan biaya memori saat buffer digunakan.
4. Gunakan temporary directory unik dan execFileSync dengan argument array untuk ffmpeg, serta cleanup pada berhasil/gagal. Batasi ukuran dan durasi sebelum konversi besar.
5. Periksa urutan chunk saat merge, respons classifier dan tiga cabang output. Catat cabang rejected/manual-review yang belum memiliki output.
6. Audit opsi PDF di form: export yang diperiksa membangun lampiran Markdown. Jangan menyatakan PDF siap tanpa implementasi dan pengujian.
7. Import dengan ID yang telah diverifikasi dan status inactive. Hindari membuat duplikat atau menimpa edit VPS tanpa perbandingan.
8. Error workflow dari sumber harus diperiksa dan diimpor terpisah jika memang diperlukan, baru referensinya dipasang. Export sanitized saat ini menghilangkan referensi itu.

## 5. Pemasangan credential privat

1. Parse Credential_information.md lokal secara privat untuk mengambil pasangan endpoint/key yang sesuai; jangan mencetak nilai, menyalin seluruh file ke VPS, atau memasukkannya ke GitHub.
2. Inventaris credential n8n VPS berdasarkan metadata saja dan gunakan ulang credential yang cocok. Jangan mengubah credential bersama workflow lain.
3. Buat credential Header Auth khusus Koboillm jika key tersedia; hubungkan ke Classify & Plan dan ketiga node Extract.
4. Untuk Groq, gunakan credential Header Auth khusus bila key yang valid tersedia. Ini memungkinkan penghapusan ketergantungan $env.GROQ_API_KEY tanpa membuka akses environment secara luas. Jangan memasukkan key Koboillm ke endpoint Groq.
5. Bila Groq belum tersedia, tandai transkripsi blocked dan minta pengguna menaruh key di file privat atau credential UI. Key lama yang pernah tertanam tidak otomatis dianggap layak dipakai kembali.
6. Untuk email, periksa apakah tersedia SMTP host/port/TLS, username dan app password yang sesuai. Alamat Gmail atau password login biasa tidak membuktikan SMTP siap.
7. Hubungkan credential SMTP ke tiga node email dan set fromEmail sesuai akun yang sah. Jangan mengirim email uji sebelum pengguna menentukan penerima serta mengizinkan pengiriman.
8. Import credential melalui mekanisme n8n yang didukung versi VPS, bukan edit database langsung. Bila perlu file perantara, beri permission ketat, transfer lewat SSH dan hapus plaintext setelah import berhasil.

## 6. Deploy dan verifikasi

1. Validasi JSON, koneksi node dan Compose tanpa menampilkan resolved secrets.
2. Build image lalu tes ffmpeg/ffprobe, encoder MP3, modul npm dan kedua template IG dalam container uji.
3. Uji audio sintetis kecil melalui Code node/task runner untuk membuktikan akses binary, konversi, output chunk dan cleanup.
4. Recreate service n8n secara terkontrol dan cek HTTP health, runner registration serta workflow existing kembali aktif.
5. Uji autentikasi provider memakai payload sintetis minimal; gunakan rekaman uji non-sensitif untuk transkripsi dan hasil ekstraksi. Catat biaya request uji dan jangan memakai recording pengguna tanpa keperluan.
6. Uji meeting, one-on-one, non-meeting, input invalid, audio multichunk, dan Google Drive dengan fixture yang sesuai. Verifikasi lampiran tanpa mengirim email.
7. Aktifkan workflow setelah dependensi wajib valid. Jika credential belum lengkap, biarkan inactive dan laporkan kebutuhan spesifik; jangan menyebut end-to-end selesai.
8. Sinkronkan file non-secret ke D:\meeting n8n\meeting-n8n-aws dan repository Meeting-N8n. Sertakan README berisi deployment aktual dan status pengujian.

## Kriteria selesai dan rollback

- Dockerfile/Compose paket sesuai VPS; image build dan health check lulus.
- FFmpeg berhasil mengonversi recording melalui workflow, bukan hanya tampil versi.
- JSON terimpor dengan ID yang tepat dan credential terhubung sesuai provider.
- Tiga jalur ekstraksi menghasilkan struktur dan lampiran yang benar. Batasan PDF/manual review dinyatakan eksplisit.
- Workflow IG dan OCR existing tetap dapat digunakan setelah deploy.
- Tidak ada secret dalam GitHub, JSON publik, output log pengujian atau build context.
- Jika deployment gagal, kembalikan konfigurasi dan image sebelumnya. Restore data hanya bila perlu, dari backup konsisten dan setelah menghentikan service; jangan downgrade image terhadap database termigrasi secara sembarang.

## Keputusan yang masih memerlukan data saat eksekusi

- Groq API key valid belum teridentifikasi dalam file credential yang dirujuk.
- Detail SMTP/app password belum teridentifikasi.
- Penerima dan izin pengiriman email uji belum diberikan; validasi awal berhenti pada penyusunan lampiran.
