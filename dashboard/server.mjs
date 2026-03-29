import { createServer } from 'http';
import { createSocket } from 'dgram';
import { readFileSync, existsSync } from 'fs';
import { join, extname } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import { WebSocketServer } from 'ws';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PUBLIC_DIR = join(__dirname, 'public');

const HTTP_PORT = 3000;
const UDP_PORT = 4210;

/* ── Packet rate tracking ──────────────────────────────── */
let packetCount = 0;
let packetRate = 0;
setInterval(() => {
  packetRate = packetCount;
  packetCount = 0;
}, 1000);

/* ── MIME types ─────────────────────────────────────────── */
const MIME = {
  '.html': 'text/html',
  '.css':  'text/css',
  '.js':   'application/javascript',
  '.json': 'application/json',
  '.png':  'image/png',
  '.svg':  'image/svg+xml',
};

/* ── HTTP server ───────────────────────────────────────── */
const httpServer = createServer((req, res) => {
  let filePath = join(PUBLIC_DIR, req.url === '/' ? 'index.html' : req.url);

  if (!existsSync(filePath)) {
    res.writeHead(404);
    res.end('Not found');
    return;
  }

  const ext = extname(filePath);
  const mime = MIME[ext] || 'application/octet-stream';

  try {
    const data = readFileSync(filePath);
    res.writeHead(200, { 'Content-Type': mime });
    res.end(data);
  } catch {
    res.writeHead(500);
    res.end('Server error');
  }
});

/* ── WebSocket server (same port as HTTP) ──────────────── */
const wss = new WebSocketServer({ server: httpServer });

wss.on('connection', (ws) => {
  console.log(`[ws] client connected (total: ${wss.clients.size})`);
  ws.on('close', () => {
    console.log(`[ws] client disconnected (total: ${wss.clients.size})`);
  });
});

function broadcast(data) {
  const msg = JSON.stringify(data);
  for (const client of wss.clients) {
    if (client.readyState === 1) {
      client.send(msg);
    }
  }
}

/* ── Binary protocol constants ─────────────────────────── */
const SYNC1 = 0xAA;
const SYNC2 = 0x55;
const PKT_EULER_STATE = 0x83;
const PKT_FULL_STATE  = 0x80;

function decodeBinaryTelemetry(buf) {
  if (buf.length < 5) return null;
  if (buf[0] !== SYNC1 || buf[1] !== SYNC2) return null;

  const length = buf[2];
  const type = buf[3];
  if (buf.length < 4 + length + 1) return null;

  /* Verify XOR checksum */
  let checksum = buf[2];
  for (let i = 3; i < 4 + length; i++) checksum ^= buf[i];
  if (checksum !== buf[4 + length]) return null;

  const payload = buf.slice(4, 4 + length);

  if (type === PKT_EULER_STATE && length >= 37) {
    return {
      att: [payload.readFloatLE(0), payload.readFloatLE(4), payload.readFloatLE(8)],
      pos: [0, payload.readFloatLE(12), 0],
      vel: [payload.readFloatLE(16), payload.readFloatLE(20), payload.readFloatLE(24)],
      hdg: payload.readFloatLE(28),
      spd: payload.readFloatLE(32),
      active: payload[36] !== 0,
    };
  }

  if (type === PKT_FULL_STATE && length >= 40) {
    return {
      pos: [payload.readFloatLE(0), payload.readFloatLE(4), payload.readFloatLE(8)],
      vel: [payload.readFloatLE(12), payload.readFloatLE(16), payload.readFloatLE(20)],
      quat: [payload.readFloatLE(24), payload.readFloatLE(28), payload.readFloatLE(32), payload.readFloatLE(36)],
      active: true,
    };
  }

  return null;
}

/* ── UDP listener ──────────────────────────────────────── */
const udp = createSocket({ type: 'udp4', reuseAddr: true });

udp.on('message', (buf) => {
  packetCount++;

  /* Auto-detect: binary (0xAA 0x55) or JSON */
  let telemetry = null;
  if (buf.length >= 2 && buf[0] === SYNC1 && buf[1] === SYNC2) {
    telemetry = decodeBinaryTelemetry(buf);
  } else {
    try {
      telemetry = JSON.parse(buf.toString());
    } catch {
      /* ignore malformed packets */
    }
  }

  if (telemetry) {
    broadcast({ type: 'telemetry', data: telemetry, rate: packetRate });
  }
});

udp.on('listening', () => {
  const addr = udp.address();
  console.log(`[udp] listening on ${addr.address}:${addr.port}`);
});

udp.bind(UDP_PORT);

/* ── Start ─────────────────────────────────────────────── */
httpServer.listen(HTTP_PORT, () => {
  console.log(`[http] dashboard at http://localhost:${HTTP_PORT}`);
  console.log(`[udp]  waiting for Godot telemetry on port ${UDP_PORT}`);
});
