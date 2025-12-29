// idle.js - Ambient life when nobody's talking
const WebSocket = require('ws');
const ws = new WebSocket('ws://localhost:3000');

const sleep = ms => new Promise(r => setTimeout(r, ms));

function send(input, value, character) {
  ws.send(JSON.stringify({ command: 'rive', input, value, character }));
}

function lerp(a, b, t) { return a + (b - a) * t; }
function rand(min, max) { return Math.random() * (max - min) + min; }

let running = true;

// Smooth pupil wandering
async function pupilWander() {
  let x = 0, y = 0;
  let targetX = 0, targetY = 0;

  while (running) {
    targetX = rand(-12, 12);
    targetY = rand(-6, 6);

    for (let t = 0; t < 1; t += 0.05) {
      x = lerp(x, targetX, 0.1);
      y = lerp(y, targetY, 0.1);
      send('pupilX', x);
      send('pupilY', y);
      await sleep(50);
    }

    await sleep(rand(2000, 4000));
  }
}

// Random blinks
async function blinkLoop() {
  while (running) {
    await sleep(rand(3000, 7000));

    send('nigelEyes', 1);
    await sleep(100);
    send('nigelEyes', 0);

    if (Math.random() < 0.3) {
      await sleep(150);
      send('nigelEyes', 1);
      await sleep(80);
      send('nigelEyes', 0);
    }
  }
}

// Subtle head movements
async function headSway() {
  let t = 0;

  while (running) {
    t += 0.02;
    const terryAngle = Math.sin(t * 0.5) * 8;
    const nigelAngle = Math.sin(t * 0.3 + 1) * 6;

    send('terry_headTurn', terryAngle);
    send('nigel_headTurn', nigelAngle, 'nigel');

    await sleep(50);
  }
}

// Occasional micro-expressions
async function microExpressions() {
  const expressions = [
    async () => {
      send('nigelEyes', 3);
      await sleep(800);
      send('nigelEyes', 0);
    },
    async () => {
      send('lipShape', 2, 'terry');
      await sleep(600);
      send('lipShape', 0, 'terry');
    },
    async () => {
      send('pupilX', rand(-15, 15));
      await sleep(1000);
    },
  ];

  while (running) {
    await sleep(rand(8000, 15000));
    const expr = expressions[Math.floor(Math.random() * expressions.length)];
    await expr();
  }
}

ws.on('open', () => {
  console.log('Idle mode active. Ctrl+C to stop.');
  pupilWander();
  blinkLoop();
  headSway();
  microExpressions();
});

ws.on('error', () => {
  console.error('Start server first: node rive_control.js');
});

process.on('SIGINT', () => {
  running = false;
  console.log('\nResetting...');
  send('terry_headTurn', 0);
  send('nigel_headTurn', 0, 'nigel');
  send('pupilX', 0);
  send('pupilY', 0);
  send('nigelEyes', 0);
  setTimeout(() => process.exit(0), 200);
});
