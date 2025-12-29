// WFL WebSocket Server - Control Flutter app from Node.js
const express = require('express');
const { WebSocketServer } = require('ws');
const http = require('http');

const PORT = Number.parseInt(process.env.PORT || '3000', 10);
const BIND_HOST = process.env.WFL_BIND_HOST || '127.0.0.1';
const CONTROL_TOKEN = process.env.WFL_CONTROL_TOKEN || '';

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

let flutterClient = null;

function getTokenFromRequest(req) {
  const headerToken = req.headers['x-wfl-token'];
  if (typeof headerToken === 'string' && headerToken.trim()) return headerToken.trim();
  if (typeof req.query?.token === 'string' && req.query.token.trim()) return req.query.token.trim();
  return '';
}

function requireHttpAuth(req, res) {
  if (!CONTROL_TOKEN) return true;
  const token = getTokenFromRequest(req);
  if (token !== CONTROL_TOKEN) {
    res.status(401).json({ error: 'unauthorized' });
    return false;
  }
  return true;
}

function wsHasValidToken(req) {
  if (!CONTROL_TOKEN) return true;
  try {
    const url = new URL(req.url, 'http://localhost');
    return url.searchParams.get('token') === CONTROL_TOKEN;
  } catch {
    return false;
  }
}

// Ping-pong heartbeat to keep connection alive
const HEARTBEAT_INTERVAL = 30000; // 30 seconds

wss.on('connection', (ws, req) => {
  if (!wsHasValidToken(req)) {
    ws.close(1008, 'Unauthorized');
    return;
  }
  console.log('Flutter client connected');
  flutterClient = ws;
  ws.isAlive = true;

  ws.on('pong', () => {
    ws.isAlive = true;
  });

  ws.on('message', (data) => {
    const msg = data.toString();
    // Handle ping from client
    if (msg === '{"type":"ping"}') {
      ws.send(JSON.stringify({ type: 'pong' }));
      return;
    }
    console.log('From Flutter:', msg);
  });

  ws.on('close', () => {
    console.log('Flutter disconnected');
    flutterClient = null;
  });
});

// Heartbeat interval - ping clients every 30s
const heartbeatInterval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) {
      console.log('Client timed out, terminating');
      return ws.terminate();
    }
    ws.isAlive = false;
    ws.ping();
  });
}, HEARTBEAT_INTERVAL);

wss.on('close', () => {
  clearInterval(heartbeatInterval);
});

// Send command to Flutter
function sendToFlutter(command, payload = {}) {
  if (flutterClient && flutterClient.readyState === 1) {
    flutterClient.send(JSON.stringify({ command, ...payload }));
  }
}

// REST endpoints to trigger Flutter actions
app.get('/play', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  sendToFlutter('play', { track: req.query.track || 'default' });
  res.json({ sent: true });
});

app.get('/roast', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  sendToFlutter('roast', {
    video: req.query.video,
    character: req.query.character || 'terry'
  });
  res.json({ sent: true });
});

app.get('/lip', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  sendToFlutter('lip', {
    shape: req.query.shape || 'x',
    character: req.query.character || 'terry'
  });
  res.json({ sent: true });
});

app.get('/head', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  sendToFlutter('head', {
    angle: parseFloat(req.query.angle) || 0,
    character: req.query.character || 'terry'
  });
  res.json({ sent: true });
});

app.get('/pupil', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  sendToFlutter('pupil', {
    x: parseFloat(req.query.x) || 0,
    y: parseFloat(req.query.y) || 0
  });
  res.json({ sent: true });
});

app.get('/talk', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  sendToFlutter('talk', {
    talking: req.query.on === 'true' || req.query.on === '1'
  });
  res.json({ sent: true });
});

app.get('/warp', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  sendToFlutter('warp', { path: req.query.path });
  res.json({ sent: true });
});

app.get('/export', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  sendToFlutter('export', { filename: req.query.filename });
  res.json({ sent: true });
});

app.get('/status', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  res.json({
    connected: flutterClient !== null,
    readyState: flutterClient?.readyState
  });
});

server.listen(PORT, BIND_HOST, () => {
  const authNote = CONTROL_TOKEN ? 'auth=enabled' : 'auth=disabled';
  console.log(`WFL Server running on http://${BIND_HOST}:${PORT} (${authNote})`);
  if (!CONTROL_TOKEN && BIND_HOST !== '127.0.0.1' && BIND_HOST !== 'localhost') {
    console.warn('WARNING: WFL_CONTROL_TOKEN is not set and the server is not bound to localhost. This enables network access to control endpoints.');
  }
  console.log('Endpoints:');
  console.log('  GET /status - Check Flutter connection');
  console.log('  GET /roast?video=path&character=terry|nigel');
  console.log('  GET /lip?shape=a|e|i|o|u|x&character=terry|nigel');
  console.log('  GET /head?angle=-40..40&character=terry|nigel');
  console.log('  GET /pupil?x=-20..20&y=-10..10');
  console.log('  GET /talk?on=true|false');
  console.log('  GET /warp?path=video/path');
  console.log('  GET /export?filename=output');
});
