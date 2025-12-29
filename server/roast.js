// roast.js - Complete roast choreography
const WebSocket = require('ws');
const ws = new WebSocket('ws://localhost:3000');

const sleep = ms => new Promise(r => setTimeout(r, ms));

function send(input, value, character = 'terry') {
  ws.send(JSON.stringify({ command: 'rive', input, value, character }));
}

async function intro() {
  console.log('Phase: INTRO');
  send('terry_headTurn', 0);
  send('nigel_headTurn', 0, 'nigel');
  send('pupilX', 0);
  send('pupilY', 0);
  await sleep(500);

  send('terry_headTurn', -35);
  send('pupilX', -15);
  await sleep(300);

  send('nigel_headTurn', -25, 'nigel');
  await sleep(1000);
}

async function reaction(type) {
  console.log(`Phase: REACTION - ${type}`);

  switch (type) {
    case 'disgust':
      send('terry_headTurn', -20);
      send('lipShape', 5, 'terry');
      send('nigelEyes', 3);
      await sleep(800);
      break;

    case 'shock':
      send('lipShape', 4, 'terry');
      send('lipShape', 4, 'nigel');
      send('nigelEyes', 4);
      send('pupilY', -5);
      await sleep(600);
      break;

    case 'confused':
      send('terry_headTurn', 15);
      send('nigel_headTurn', -15, 'nigel');
      send('nigelEyes', 2);
      await sleep(700);
      break;
  }
}

async function terryRoast(lines) {
  console.log('Phase: TERRY ROAST');
  send('terry_headTurn', 5);
  send('isTalking', true, 'terry');

  for (const line of lines) {
    for (const char of line) {
      const shape = 'aeiou'.includes(char.toLowerCase())
        ? 'aeiou'.indexOf(char.toLowerCase()) + 1
        : Math.random() < 0.5 ? 6 : 7;
      send('lipShape', shape, 'terry');
      await sleep(50);
    }
    send('lipShape', 0, 'terry');
    await sleep(200);
  }

  send('isTalking', false, 'terry');
}

async function nigelReact() {
  console.log('Phase: NIGEL REACT');

  for (let i = 0; i < 3; i++) {
    send('nigel_headTurn', 15, 'nigel');
    await sleep(100);
    send('nigel_headTurn', -15, 'nigel');
    await sleep(100);
  }
  send('nigel_headTurn', 0, 'nigel');

  send('isTalking', true, 'nigel');
  for (let i = 0; i < 10; i++) {
    send('lipShape', Math.floor(Math.random() * 7) + 1, 'nigel');
    await sleep(60);
  }
  send('lipShape', 0, 'nigel');
  send('isTalking', false, 'nigel');
}

async function outro() {
  console.log('Phase: OUTRO');
  send('terry_headTurn', 0);
  send('nigel_headTurn', 0, 'nigel');
  send('pupilX', 0);
  send('pupilY', 0);
  send('lipShape', 2, 'terry');
  send('nigelEyes', 3);
  await sleep(1500);

  send('lipShape', 0, 'terry');
  send('nigelEyes', 0);
}

async function runRoast() {
  await intro();
  await sleep(500);

  await reaction('shock');
  await sleep(300);

  await terryRoast([
    "Yo what is this",
    "This dude really thought he did something",
    "Nah this is crazy"
  ]);
  await sleep(200);

  await nigelReact();
  await sleep(300);

  await reaction('disgust');
  await sleep(500);

  await outro();

  console.log('Roast complete!');
  process.exit(0);
}

ws.on('open', runRoast);
ws.on('error', () => console.error('Start server first: node rive_control.js'));
