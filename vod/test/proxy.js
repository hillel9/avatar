const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');

const PORT = 3000;
const API_BASE = 'https://q7xx9hsksr96ze-8000.proxy.runpod.net';

function forwardRequest(req, res, targetUrl) {
  const target = new URL(targetUrl);
  const options = {
    hostname: target.hostname,
    port: target.port || 443,
    path: target.pathname + (target.search || ''),
    method: req.method,
    headers: {
      ...req.headers,
      host: target.host,
    },
  };

  const proto = target.protocol === 'https:' ? https : http;

  const proxyReq = proto.request(options, (proxyRes) => {
    console.log(`[proxy] ${req.method} ${req.url} → ${proxyRes.statusCode}`);
    res.writeHead(proxyRes.statusCode, {
      ...proxyRes.headers,
      'Access-Control-Allow-Origin': '*',
    });
    proxyRes.pipe(res);
  });

  proxyReq.on('error', (err) => {
    console.error('[proxy] Error contacting API:', err.message);
    res.writeHead(502);
    res.end(`Proxy error: ${err.message}`);
  });

  req.pipe(proxyReq);
}

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Serve HTML
  if (req.method === 'GET' && (req.url === '/' || req.url === '/index.html')) {
    const htmlPath = path.join(__dirname, 'index.html');
    fs.readFile(htmlPath, (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end('index.html not found — make sure it is in the same folder as proxy.js');
        return;
      }
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(data);
    });
    return;
  }

  // POST /generate
  if (req.method === 'POST' && req.url === '/generate') {
    console.log('[proxy] Forwarding POST /generate');
    forwardRequest(req, res, `${API_BASE}/generate`);
    return;
  }

  // GET /queue/status/:id
  const statusMatch = req.url.match(/^\/queue\/status\/(.+)$/);
  if (req.method === 'GET' && statusMatch) {
    console.log(`[proxy] Forwarding GET /queue/status/${statusMatch[1]}`);
    forwardRequest(req, res, `${API_BASE}/queue/status/${statusMatch[1]}`);
    return;
  }

  // GET /queue/result/:id
  const resultMatch = req.url.match(/^\/queue\/result\/(.+)$/);
  if (req.method === 'GET' && resultMatch) {
    console.log(`[proxy] Forwarding GET /queue/result/${resultMatch[1]}`);
    forwardRequest(req, res, `${API_BASE}/queue/result/${resultMatch[1]}`);
    return;
  }

  // GET /audio/:filename — serve library audio
  const audioFileMatch = req.url.match(/^\/audio\/([^/]+)$/);
  if (req.method === 'GET' && audioFileMatch) {
    const filename = decodeURIComponent(audioFileMatch[1]);
    const filepath = path.join(__dirname, 'audio', filename);
    fs.readFile(filepath, (err, data) => {
      if (err) { res.writeHead(404); res.end('Not found'); return; }
      const ext = path.extname(filename).toLowerCase();
      const mime = { '.mp3': 'audio/mpeg', '.wav': 'audio/wav', '.m4a': 'audio/mp4', '.ogg': 'audio/ogg' };
      res.writeHead(200, { 'Content-Type': mime[ext] || 'audio/mpeg' });
      res.end(data);
    });
    return;
  }

  // GET /avatars/:filename — serve library images
  const avatarMatch = req.url.match(/^\/avatars\/([^/]+)$/);
  if (req.method === 'GET' && avatarMatch) {
    const filename = decodeURIComponent(avatarMatch[1]);
    const filepath = path.join(__dirname, 'avatars', filename);
    fs.readFile(filepath, (err, data) => {
      if (err) { res.writeHead(404); res.end('Not found'); return; }
      const ext = path.extname(filename).toLowerCase();
      const mime = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg' };
      res.writeHead(200, { 'Content-Type': mime[ext] || 'application/octet-stream' });
      res.end(data);
    });
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

server.listen(PORT, () => {
  console.log(`✅ Server running!`);
  console.log(`   Open your browser and go to: http://localhost:${PORT}`);
  console.log(`   API base: ${API_BASE}`);
});
