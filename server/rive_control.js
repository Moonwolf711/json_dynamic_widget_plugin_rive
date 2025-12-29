// Rive Animation Control Script - Direct control of WFL Rive inputs
// Run: node rive_control.js
// Then use the REST API to control Terry/Nigel in real-time

const express = require('express');
const { WebSocketServer } = require('ws');
const http = require('http');
const path = require('path');

const PORT = Number.parseInt(process.env.PORT || '3000', 10);
const BIND_HOST = process.env.WFL_BIND_HOST || '127.0.0.1';
const CONTROL_TOKEN = process.env.WFL_CONTROL_TOKEN || '';

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

function getTokenFromRequest(req) {
  const headerToken = req.headers['x-wfl-token'];
  if (typeof headerToken === 'string' && headerToken.trim()) return headerToken.trim();
  if (typeof req.query?.token === 'string' && req.query.token.trim()) return req.query.token.trim();
  if (typeof req.body?.token === 'string' && req.body.token.trim()) return req.body.token.trim();
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

// Serve static files from public folder (optionally protected by token)
app.use((req, res, next) => {
  if (!requireHttpAuth(req, res)) return;
  next();
});
app.use(express.static(path.join(__dirname, 'public')));

const server = http.createServer(app);
const wss = new WebSocketServer({ server });

let flutterClient = null;
const webClients = new Set();
const HEARTBEAT_INTERVAL = 30000;

// Current state - mirrors Rive inputs
const state = {
  terry: {
    lip: 0,       // 0-7 mouth shape
    head: 0,      // -1 to 1
    eyes: 0,      // 0-4: open, closed, half, squint, wide
    roast: 0,     // 0=chill, 1=smirk, 2=roast
    talking: false
  },
  nigel: {
    lip: 0,
    head: 0,
    talking: false,
    eyes: 'open'  // open, closed, half, squint, wide
  },
  pupil: { x: 0, y: 0 }
};

wss.on('connection', (ws, req) => {
  if (!wsHasValidToken(req)) {
    ws.close(1008, 'Unauthorized');
    return;
  }
  ws.isAlive = true;
  ws.on('pong', () => ws.isAlive = true);

  ws.on('message', (data) => {
    const msg = data.toString();
    try {
      const parsed = JSON.parse(msg);

      // Handle ping
      if (parsed.type === 'ping') {
        ws.send(JSON.stringify({ type: 'pong' }));
        return;
      }

      // Identify client type by first message
      if (parsed.type === 'status' && parsed.riveLoaded !== undefined) {
        // This is Flutter client
        flutterClient = ws;
        ws.clientType = 'flutter';
        console.log('Flutter client connected');
        sendToFlutter('sync', { state });
      } else if (parsed.type === 'web-hello') {
        // This is a web client
        webClients.add(ws);
        ws.clientType = 'web';
        console.log('Web client connected');
        ws.send(JSON.stringify({ command: 'sync', state }));
      }

      console.log(`${ws.clientType || 'unknown'}:`, msg.slice(0, 100));
    } catch (e) {
      console.log('Raw message:', msg.slice(0, 100));
    }
  });

  ws.on('close', () => {
    if (ws.clientType === 'flutter') {
      console.log('Flutter disconnected');
      flutterClient = null;
    } else if (ws.clientType === 'web') {
      console.log('Web client disconnected');
      webClients.delete(ws);
    }
  });

  // If no identification within 1s, assume web client
  setTimeout(() => {
    if (!ws.clientType) {
      webClients.add(ws);
      ws.clientType = 'web';
      ws.send(JSON.stringify({ command: 'sync', state }));
    }
  }, 1000);
});

// Heartbeat
setInterval(() => {
  wss.clients.forEach((ws) => {
    if (!ws.isAlive) return ws.terminate();
    ws.isAlive = false;
    ws.ping();
  });
}, HEARTBEAT_INTERVAL);

function sendToFlutter(command, payload = {}) {
  if (flutterClient?.readyState === 1) {
    flutterClient.send(JSON.stringify({ command, ...payload }));
    return true;
  }
  return false;
}

// Broadcast to all web clients
function broadcastToWeb(command, payload = {}) {
  const message = JSON.stringify({ command, ...payload });
  webClients.forEach(ws => {
    if (ws.readyState === 1) {
      ws.send(message);
    }
  });
}

// ================== RIVE CONTROL API ==================

// Set Terry's mouth shape (0-7)
// GET /terry/lip?shape=2
app.get('/terry/lip', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const shape = parseFloat(req.query.shape) || 0;
  state.terry.lip = shape;
  const sent = sendToFlutter('rive', {
    input: 'lipShape',
    value: shape,
    character: 'terry'
  });
  res.json({ sent, shape });
});

// Set Terry's head angle (-40 to 40)
// GET /terry/head?angle=-20
app.get('/terry/head', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const angle = Math.max(-40, Math.min(40, parseFloat(req.query.angle) || 0));
  state.terry.head = angle;
  const sent = sendToFlutter('rive', {
    input: 'terry_headTurn',
    value: angle,
    character: 'terry'
  });
  res.json({ sent, angle });
});

// Set Terry talking state
// GET /terry/talk?on=true
app.get('/terry/talk', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const talking = req.query.on === 'true' || req.query.on === '1';
  state.terry.talking = talking;
  const sent = sendToFlutter('rive', {
    input: 'isTalking',
    value: talking,
    character: 'terry'
  });
  res.json({ sent, talking });
});

// Set Nigel's mouth shape
// GET /nigel/lip?shape=3
app.get('/nigel/lip', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const shape = parseFloat(req.query.shape) || 0;
  state.nigel.lip = shape;
  const sent = sendToFlutter('rive', {
    input: 'lipShape',
    value: shape,
    character: 'nigel'
  });
  res.json({ sent, shape });
});

// Set Nigel's head angle
// GET /nigel/head?angle=15
app.get('/nigel/head', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const angle = Math.max(-40, Math.min(40, parseFloat(req.query.angle) || 0));
  state.nigel.head = angle;
  const sent = sendToFlutter('rive', {
    input: 'nigel_headTurn',
    value: angle,
    character: 'nigel'
  });
  res.json({ sent, angle });
});

// Set Nigel talking state
// GET /nigel/talk?on=true
app.get('/nigel/talk', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const talking = req.query.on === 'true' || req.query.on === '1';
  state.nigel.talking = talking;
  const sent = sendToFlutter('rive', {
    input: 'isTalking',
    value: talking,
    character: 'nigel'
  });
  res.json({ sent, talking });
});

// Set Nigel's eyes
// GET /nigel/eyes?state=squint
app.get('/nigel/eyes', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const eyeState = req.query.state || 'open';
  state.nigel.eyes = eyeState;
  const sent = sendToFlutter('rive', {
    input: 'nigelEyes',
    value: eyeState,
    character: 'nigel'
  });
  res.json({ sent, eyes: eyeState });
});

// Set Terry's eyes (0=open, 1=closed, 2=half, 3=squint, 4=wide)
// GET /terry/eyes?state=0-4
app.get('/terry/eyes', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const eyeState = parseFloat(req.query.state) || 0;
  state.terry.eyes = eyeState;
  const sent = sendToFlutter('rive', {
    input: 'terryEyes',
    value: eyeState,
    character: 'terry'
  });
  res.json({ sent, eyes: eyeState });
});

// Set Terry's roast attitude (0=chill, 1=smirk, 2=roast, etc)
// GET /terry/roast?level=2
app.get('/terry/roast', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const level = parseFloat(req.query.level) || 0;
  state.terry.roast = level;
  const sent = sendToFlutter('rive', {
    input: 'terryRoast',
    value: level,
    character: 'terry'
  });
  res.json({ sent, roast: level });
});

// Set both characters' pupil position
// GET /pupils?x=10&y=-5
app.get('/pupils', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const x = Math.max(-20, Math.min(20, parseFloat(req.query.x) || 0));
  const y = Math.max(-10, Math.min(10, parseFloat(req.query.y) || 0));
  state.pupil = { x, y };
  const sent = sendToFlutter('rive', {
    input: 'pupil',
    x, y
  });
  res.json({ sent, x, y });
});

// ================== ANIMATION SEQUENCES ==================

// Make character speak with lip sync
// GET /speak?character=terry&text=Hello
app.get('/speak', async (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const { character = 'terry', text = '' } = req.query;

  // Simple phoneme mapping for demo
  const phonemes = text.toLowerCase().split('').map(char => {
    if ('aeiou'.includes(char)) return { shape: 'aeiou'.indexOf(char) + 1, duration: 80 };
    if ('lmnrs'.includes(char)) return { shape: 6, duration: 50 };
    if ('fvw'.includes(char)) return { shape: 7, duration: 60 };
    return { shape: 0, duration: 40 };
  });

  // Start talking
  sendToFlutter('rive', { input: 'isTalking', value: true, character });

  // Animate through phonemes
  for (const p of phonemes) {
    sendToFlutter('rive', { input: 'lipShape', value: p.shape, character });
    await sleep(p.duration);
  }

  // Stop talking
  sendToFlutter('rive', { input: 'lipShape', value: 0, character });
  sendToFlutter('rive', { input: 'isTalking', value: false, character });

  res.json({ done: true, phonemes: phonemes.length });
});

// Look at a direction
// GET /look?direction=left|right|up|down|center
app.get('/look', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const dir = req.query.direction || 'center';
  let x = 0, y = 0;

  switch(dir) {
    case 'left': x = -15; break;
    case 'right': x = 15; break;
    case 'up': y = -8; break;
    case 'down': y = 8; break;
    case 'upleft': x = -10; y = -5; break;
    case 'upright': x = 10; y = -5; break;
    case 'downleft': x = -10; y = 5; break;
    case 'downright': x = 10; y = 5; break;
  }

  state.pupil = { x, y };
  sendToFlutter('rive', { input: 'pupil', x, y });
  res.json({ direction: dir, x, y });
});

// Head shake animation
// GET /shake?character=terry&intensity=20
app.get('/shake', async (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const { character = 'terry', intensity = '20' } = req.query;
  const int = parseFloat(intensity);
  const input = character === 'nigel' ? 'nigel_headTurn' : 'terry_headTurn';

  for (let i = 0; i < 4; i++) {
    sendToFlutter('rive', { input, value: int, character });
    await sleep(100);
    sendToFlutter('rive', { input, value: -int, character });
    await sleep(100);
  }
  sendToFlutter('rive', { input, value: 0, character });

  res.json({ done: true });
});

// Nod animation
// GET /nod?character=nigel
app.get('/nod', async (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const { character = 'terry' } = req.query;

  // Simulate nod with pupil movement
  for (let i = 0; i < 2; i++) {
    sendToFlutter('rive', { input: 'pupil', x: 0, y: -5 });
    await sleep(150);
    sendToFlutter('rive', { input: 'pupil', x: 0, y: 5 });
    await sleep(150);
  }
  sendToFlutter('rive', { input: 'pupil', x: 0, y: 0 });

  res.json({ done: true });
});

// ================== DIRECT ANIMATION CONTROL ==================
// For Rive files without State Machine inputs

// List all available animations
// GET /anims
app.get('/anims', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  sendToFlutter('listAnims', {});
  res.json({ requested: true, note: 'Check Flutter logs for animation list' });
});

// Play a specific animation by name
// GET /anim/play?name=nigel_head_shake
app.get('/anim/play', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const name = req.query.name || '';
  if (!name) {
    return res.status(400).json({ error: 'name required' });
  }
  const sent = sendToFlutter('playAnim', { name });
  res.json({ sent, animation: name, action: 'play' });
});

// Stop a specific animation by name
// GET /anim/stop?name=nigel_head_shake
app.get('/anim/stop', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const name = req.query.name || '';
  if (!name) {
    return res.status(400).json({ error: 'name required' });
  }
  const sent = sendToFlutter('stopAnim', { name });
  res.json({ sent, animation: name, action: 'stop' });
});

// ================== STATUS ==================

app.get('/status', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  res.json({
    flutter: flutterClient !== null,
    webClients: webClients.size,
    state
  });
});

// ================== FORM SUBMIT - REAL-TIME DUB ==================

// POST /submit - Accept form with name + video URL, trigger roast
app.post('/submit', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const name = req.body.name || 'Unknown';
  const videoUrl = req.body.video || req.body.videoUrl;
  const character = req.body.character || 'terry';

  console.log(`Roast submitted: ${name} → ${videoUrl}`);

  const sent = sendToFlutter('roast', {
    target: name,
    footage: videoUrl,
    character: character
  });

  res.json({ received: true, sent, target: name });
});

// HTML form page for easy testing
app.get('/form', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const token = typeof req.query.token === 'string' ? req.query.token : '';
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>WFL Roast Submit</title>
      <style>
        body { background: #1a1a2e; color: white; font-family: sans-serif; padding: 40px; }
        input, select { width: 100%; padding: 12px; margin: 8px 0; border-radius: 8px; border: none; }
        button { background: #e94560; color: white; padding: 16px 32px; border: none; border-radius: 8px; cursor: pointer; font-size: 18px; }
        button:hover { background: #ff6b6b; }
        .container { max-width: 500px; margin: 0 auto; }
        h1 { color: #e94560; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>🔥 WFL ROAST SUBMIT</h1>
        <form action="/submit" method="POST">
          <input type="hidden" name="token" value="${token}">
          <label>Target Name:</label>
          <input type="text" name="name" placeholder="Who we roasting?" required>

          <label>Video/Audio URL:</label>
          <input type="url" name="video" placeholder="https://..." required>

          <label>Character:</label>
          <select name="character">
            <option value="terry">Terry</option>
            <option value="nigel">Nigel</option>
          </select>

          <br><br>
          <button type="submit">🎤 ROAST 'EM</button>
        </form>
      </div>
    </body>
    </html>
  `);
});

// ================== BONE CONTROLS ==================

// Enter bone edit mode
app.get('/bones', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const sent = sendToFlutter('bones', {});
  res.json({ sent, mode: 'bone_edit' });
});

// Rotate a bone by name
// GET /bone?name=terry_head&angle=25
app.get('/bone', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const { name, angle } = req.query;
  const sent = sendToFlutter('bone', {
    name,
    angle: parseFloat(angle) || 0
  });
  res.json({ sent, name, angle: parseFloat(angle) || 0 });
});

app.get('/reset', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  // Reset all to neutral
  state.terry = { lip: 0, head: 0, talking: false };
  state.nigel = { lip: 0, head: 0, talking: false, eyes: 'open' };
  state.pupil = { x: 0, y: 0 };

  sendToFlutter('rive', { input: 'lipShape', value: 0, character: 'terry' });
  sendToFlutter('rive', { input: 'lipShape', value: 0, character: 'nigel' });
  sendToFlutter('rive', { input: 'terry_headTurn', value: 0 });
  sendToFlutter('rive', { input: 'nigel_headTurn', value: 0 });
  sendToFlutter('rive', { input: 'pupil', x: 0, y: 0 });
  sendToFlutter('rive', { input: 'isTalking', value: false, character: 'terry' });
  sendToFlutter('rive', { input: 'isTalking', value: false, character: 'nigel' });

  res.json({ reset: true, state });
});

// ================== ADMIN CONFIG ==================

// Admin config state
const adminConfig = {
  riveUrl: null,  // Remote .riv file URL
  theme: 'dark',
  autoConnect: true
};

// GET /admin - Admin page
app.get('/admin', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const token = typeof req.query.token === 'string' ? req.query.token : '';
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>WFL Admin</title>
      <style>
        body { background: #0a0a15; color: white; font-family: system-ui; padding: 40px; }
        .container { max-width: 600px; margin: 0 auto; }
        h1 { color: #e94560; }
        .section { background: rgba(255,255,255,0.05); padding: 20px; border-radius: 12px; margin: 20px 0; }
        h2 { color: #e94560; font-size: 1.2rem; margin-bottom: 15px; }
        label { display: block; color: #aaa; margin-bottom: 5px; }
        input, select { width: 100%; padding: 12px; border-radius: 8px; border: 1px solid #333; background: #1a1a2e; color: white; margin-bottom: 15px; }
        button { background: #e94560; color: white; border: none; padding: 12px 24px; border-radius: 8px; cursor: pointer; font-size: 16px; }
        button:hover { background: #ff6b6b; }
        .status { padding: 10px; border-radius: 8px; margin: 10px 0; }
        .status.success { background: #1db954; }
        .status.error { background: #e94560; }
        .current { color: #1db954; font-family: monospace; word-break: break-all; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>WFL Admin Panel</h1>

        <div class="section">
          <h2>Rive Animation Source</h2>
          <p>Current: <span class="current">${adminConfig.riveUrl || 'Local (assets/wfl.riv)'}</span></p>
          <form action="/admin/rive-url" method="POST">
            <input type="hidden" name="token" value="${token}">
            <label>Remote .riv URL (GitHub raw, Firebase, etc)</label>
            <input type="url" name="url" placeholder="https://raw.githubusercontent.com/user/repo/main/wfl.riv" value="${adminConfig.riveUrl || ''}">
            <button type="submit">Update Rive URL</button>
          </form>
          <form action="/admin/rive-url" method="POST" style="margin-top: 10px;">
            <input type="hidden" name="token" value="${token}">
            <input type="hidden" name="url" value="">
            <button type="submit" style="background: #4a4a6a;">Reset to Local</button>
          </form>
        </div>

        <div class="section">
          <h2>Connection Status</h2>
          <p>Flutter: <span style="color: ${flutterClient ? '#1db954' : '#e94560'}">${flutterClient ? 'Connected' : 'Disconnected'}</span></p>
          <p>Web Clients: <span style="color: #1db954">${webClients.size}</span></p>
        </div>

        <div class="section">
          <h2>Quick Actions</h2>
          <button onclick="fetch('${token ? ('/admin/reload-rive?token=' + encodeURIComponent(token)) : '/admin/reload-rive'}').then(r=>r.json()).then(d=>alert(d.message))">Reload Rive in Flutter</button>
          <button onclick="fetch('${token ? ('/reset?token=' + encodeURIComponent(token)) : '/reset'}').then(()=>alert('Reset!'))" style="margin-left: 10px; background: #4a4a6a;">Reset Animation</button>
        </div>

        <div class="section">
          <h2>Upload Rive to GitHub</h2>
          <p style="color: #aaa; font-size: 14px;">
            1. Push wfl.riv to your GitHub repo<br>
            2. Use raw URL: <code>https://raw.githubusercontent.com/USER/REPO/main/assets/wfl.riv</code><br>
            3. Paste above and click Update
          </p>
        </div>
      </div>
    </body>
    </html>
  `);
});

// POST /admin/rive-url - Set remote Rive URL
app.post('/admin/rive-url', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const url = req.body.url || null;
  adminConfig.riveUrl = url && url.trim() ? url.trim() : null;

  // Tell Flutter to reload with new URL
  const sent = sendToFlutter('setRiveUrl', { url: adminConfig.riveUrl });

  console.log(`Admin: Rive URL set to ${adminConfig.riveUrl || 'local'}`);
  const token = typeof req.body.token === 'string' ? req.body.token : '';
  res.redirect(token ? `/admin?token=${encodeURIComponent(token)}` : '/admin');
});

// GET /admin/reload-rive - Tell Flutter to reload Rive file
app.get('/admin/reload-rive', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  const sent = sendToFlutter('reloadRive', { url: adminConfig.riveUrl });
  res.json({ sent, message: sent ? 'Reload command sent!' : 'Flutter not connected' });
});

// GET /admin/config - Get current config as JSON
app.get('/admin/config', (req, res) => {
  if (!requireHttpAuth(req, res)) return;
  res.json(adminConfig);
});

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

server.listen(PORT, BIND_HOST, () => {
  const authNote = CONTROL_TOKEN ? 'auth=enabled' : 'auth=disabled';
  if (!CONTROL_TOKEN && BIND_HOST !== '127.0.0.1' && BIND_HOST !== 'localhost') {
    console.warn('WARNING: WFL_CONTROL_TOKEN is not set and the server is not bound to localhost. This enables network access to control endpoints.');
  }
  console.log(`
╔══════════════════════════════════════════════════════════════╗
║        WFL RIVE CONTROL SERVER - ${BIND_HOST}:${PORT} (${authNote})        ║
╠══════════════════════════════════════════════════════════════╣
║  TERRY CONTROLS:                                             ║
║    GET /terry/lip?shape=0-7                                  ║
║    GET /terry/head?angle=-40..40                             ║
║    GET /terry/talk?on=true|false                             ║
║                                                              ║
║  NIGEL CONTROLS:                                             ║
║    GET /nigel/lip?shape=0-7                                  ║
║    GET /nigel/head?angle=-40..40                             ║
║    GET /nigel/talk?on=true|false                             ║
║    GET /nigel/eyes?state=open|closed|half|squint|wide        ║
║                                                              ║
║  SHARED CONTROLS:                                            ║
║    GET /pupils?x=-20..20&y=-10..10                           ║
║    GET /look?direction=left|right|up|down|center             ║
║                                                              ║
║  ANIMATIONS:                                                 ║
║    GET /speak?character=terry&text=Hello                     ║
║    GET /shake?character=terry&intensity=20                   ║
║    GET /nod?character=nigel                                  ║
║                                                              ║
║  STATUS:                                                     ║
║    GET /status    - Check connection & state                 ║
║    GET /reset     - Reset all to neutral                     ║
╚══════════════════════════════════════════════════════════════╝
  `);
});
