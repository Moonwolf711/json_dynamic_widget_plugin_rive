// reactions.js - Quick emotion triggers
// Usage: node reactions.js terry_laugh
const WebSocket = require('ws');
const ws = new WebSocket('ws://localhost:3000');

const sleep = ms => new Promise(r => setTimeout(r, ms));

function send(input, value, character = 'terry') {
  ws.send(JSON.stringify({ command: 'rive', input, value, character }));
}

const reactions = {
  terry_shocked: async () => {
    send('terry_headTurn', -5);
    send('lipShape', 4);
    send('pupilX', 0);
    send('pupilY', -8);
    await sleep(800);
    send('lipShape', 0);
  },

  terry_laugh: async () => {
    send('isTalking', true, 'terry');
    for (let i = 0; i < 8; i++) {
      send('lipShape', 1);
      send('terry_headTurn', -5 + Math.random() * 10);
      await sleep(100);
      send('lipShape', 7);
      await sleep(100);
    }
    send('lipShape', 0);
    send('terry_headTurn', 0);
    send('isTalking', false, 'terry');
  },

  terry_disgust: async () => {
    send('terry_headTurn', -25);
    send('lipShape', 5);
    send('pupilX', -15);
    await sleep(500);
  },

  terry_nod: async () => {
    for (let i = 0; i < 3; i++) {
      send('pupilY', 5);
      await sleep(150);
      send('pupilY', -5);
      await sleep(150);
    }
    send('pupilY', 0);
  },

  nigel_skeptical: async () => {
    send('nigel_headTurn', 15, 'nigel');
    send('nigelEyes', 3);
    send('pupilX', 10);
    await sleep(600);
  },

  nigel_impressed: async () => {
    send('nigelEyes', 4);
    send('nigel_headTurn', -10, 'nigel');
    send('lipShape', 4, 'nigel');
    await sleep(400);
    send('lipShape', 0, 'nigel');
  },

  nigel_blink: async () => {
    send('nigelEyes', 1);
    await sleep(150);
    send('nigelEyes', 0);
  },

  nigel_eyeroll: async () => {
    send('pupilY', -8);
    send('nigelEyes', 2);
    await sleep(300);
    for (let x = -15; x <= 15; x += 5) {
      send('pupilX', x);
      await sleep(50);
    }
    send('pupilX', 0);
    send('pupilY', 0);
    send('nigelEyes', 0);
  },

  both_look_camera: async () => {
    send('terry_headTurn', 0);
    send('nigel_headTurn', 0, 'nigel');
    send('pupilX', 0);
    send('pupilY', 0);
  },

  both_look_each_other: async () => {
    send('terry_headTurn', 30);
    send('nigel_headTurn', -30, 'nigel');
    send('pupilX', 0);
  },

  reset: async () => {
    send('terry_headTurn', 0);
    send('nigel_headTurn', 0, 'nigel');
    send('lipShape', 0, 'terry');
    send('lipShape', 0, 'nigel');
    send('pupilX', 0);
    send('pupilY', 0);
    send('nigelEyes', 0);
    send('isTalking', false, 'terry');
    send('isTalking', false, 'nigel');
  }
};

const reaction = process.argv[2];

ws.on('open', async () => {
  if (reactions[reaction]) {
    console.log(`Playing: ${reaction}`);
    await reactions[reaction]();
    await sleep(500);
    process.exit(0);
  } else {
    console.log('Available reactions:');
    Object.keys(reactions).forEach(r => console.log(`  ${r}`));
    process.exit(1);
  }
});

ws.on('error', () => {
  console.error('Start server first: node rive_control.js');
});
