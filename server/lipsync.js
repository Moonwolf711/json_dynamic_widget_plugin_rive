// lipsync.js - Drive mouths from phoneme timing data
const WebSocket = require('ws');

const ws = new WebSocket('ws://localhost:3000');

// Phoneme to lip shape mapping
const PHONEME_MAP = {
  'AA': 1, 'AE': 1, 'AH': 1, 'AO': 1, 'AW': 1, // a
  'EH': 2, 'ER': 2, 'EY': 2,                    // e
  'IH': 3, 'IY': 3,                              // i
  'OW': 4, 'OY': 4,                              // o
  'UH': 5, 'UW': 5,                              // u
  'F': 6, 'V': 6,                                // f
  'M': 7, 'B': 7, 'P': 7,                        // m
  'L': 3, 'N': 2, 'T': 2, 'D': 2, 'S': 2, 'Z': 2,
  'SIL': 0, 'sp': 0, '': 0                       // silence
};

// Example timing data (from Gentle/Rhubarb/etc)
const lipSyncData = [
  { time: 0.0, phoneme: 'SIL' },
  { time: 0.1, phoneme: 'HH' },
  { time: 0.15, phoneme: 'EH' },
  { time: 0.25, phoneme: 'L' },
  { time: 0.35, phoneme: 'OW' },
  { time: 0.5, phoneme: 'SIL' },
];

function send(command, payload) {
  ws.send(JSON.stringify({ command, ...payload }));
}

async function playLipSync(character, cues) {
  console.log(`Playing lip sync for ${character}`);

  send('rive', { input: 'isTalking', value: true, character });

  let lastTime = 0;
  for (const cue of cues) {
    const delay = (cue.time - lastTime) * 1000;
    await sleep(delay);

    const shape = PHONEME_MAP[cue.phoneme] || 0;
    send('rive', { input: 'lipShape', value: shape, character });
    console.log(`${cue.time.toFixed(2)}s: ${cue.phoneme} → shape ${shape}`);

    lastTime = cue.time;
  }

  send('rive', { input: 'lipShape', value: 0, character });
  send('rive', { input: 'isTalking', value: false, character });
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

ws.on('open', () => {
  console.log('Connected to WFL');
  playLipSync('terry', lipSyncData);
});

ws.on('error', (err) => {
  console.error('Connection failed. Start the server first: node rive_control.js');
});
