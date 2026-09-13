// Code node source for "Audio Conversion".
// n8n provides binary data through this.helpers; do not reconstruct filesystem-v2 paths.
const path = require('path');
const fs = require('fs');
const os = require('os');
const { execFileSync } = require('child_process');

const CHUNK_SECONDS = 300;
const MAX_CHUNKS = 30;
const BITRATE = '32k';
const item = $input.first();
const binaryKey = 'recording';
if (!item.binary || !item.binary[binaryKey]) {
  throw new Error('No recording binary data found');
}

const binaryData = item.binary[binaryKey];
const origName = binaryData.fileName || 'recording.mp4';
const tmpDir = path.join(os.tmpdir(), 'n8n_mtg_' + Date.now());
fs.mkdirSync(tmpDir, { recursive: true });

let inputFile;
const out = [];
try {
  // This works for both memory and filesystem-v2 binary storage.
  const inputBuffer = await this.helpers.getBinaryDataBuffer(0, binaryKey);
  const ext = path.extname(origName) || '.mp4';
  inputFile = path.join(tmpDir, 'input' + ext);
  fs.writeFileSync(inputFile, inputBuffer);

  const fileSizeMB = (fs.statSync(inputFile).size / 1024 / 1024).toFixed(2);
  const outPattern = path.join(tmpDir, 'chunk_%03d.mp3');
  execFileSync('ffmpeg', [
    '-i', inputFile,
    '-vn', '-ar', '16000', '-ac', '1', '-b:a', BITRATE,
    '-f', 'segment', '-segment_time', String(CHUNK_SECONDS),
    outPattern, '-y'
  ], { timeout: 600000, stdio: 'pipe' });

  const chunkFiles = fs.readdirSync(tmpDir)
    .filter((f) => f.startsWith('chunk_') && f.endsWith('.mp3'))
    .sort();
  if (chunkFiles.length === 0) throw new Error('ffmpeg menghasilkan 0 chunk');
  if (chunkFiles.length > MAX_CHUNKS) {
    throw new Error('Audio terlalu panjang: ' + chunkFiles.length +
      ' chunk, batas ' + MAX_CHUNKS + ' (~' +
      (MAX_CHUNKS * CHUNK_SECONDS / 60).toFixed(0) + ' menit max)');
  }

  const baseName = origName.replace(/\.[^/.]+$/, '');
  chunkFiles.forEach((fname, idx) => {
    const buf = fs.readFileSync(path.join(tmpDir, fname));
    out.push({
      json: {
        meeting_name: item.json.meeting_name || '',
        originalFileName: origName,
        originalFileSizeMB: parseFloat(fileSizeMB),
        chunk_index: idx,
        total_chunks: chunkFiles.length
      },
      binary: {
        recording: {
          data: buf.toString('base64'),
          mimeType: 'audio/mpeg',
          fileName: baseName + '_chunk' + String(idx).padStart(3, '0') + '.mp3',
          fileSize: buf.length
        }
      }
    });
  });
} finally {
  try { fs.rmSync(tmpDir, { recursive: true, force: true }); } catch (_) {}
}

return out;
