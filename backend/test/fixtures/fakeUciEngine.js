// Minimal stand-in for a UCI engine, used so PikafishProcess's protocol
// handling can be unit-tested without depending on the real (large) Pikafish
// binary. Deliberately deterministic: always proposes the same two lines
// for MultiPV, and stalls forever on "go" until it receives "stop" - which
// lets the pikafishProcess timeout/grace-period path be exercised too.
const readline = require('node:readline');

let multiPv = 1;
let stalling = false;

const rl = readline.createInterface({ input: process.stdin });

function say(line) {
  process.stdout.write(`${line}\n`);
}

rl.on('line', (raw) => {
  const line = raw.trim();

  if (line === 'uci') {
    say('id name FakeUci');
    say('id author test');
    say('uciok');
    return;
  }

  if (line.startsWith('setoption name MultiPV value')) {
    multiPv = Number(line.split(' ').pop());
    return;
  }

  if (line.startsWith('setoption')) {
    return; // Threads / Hash / EvalFile: accepted, ignored
  }

  if (line === 'isready') {
    say('readyok');
    return;
  }

  if (line.startsWith('position')) {
    return;
  }

  if (line === 'go depth 999') {
    stalling = true;
    return; // never responds until "stop" - for timeout tests
  }

  if (line.startsWith('go')) {
    for (let pv = 1; pv <= multiPv; pv++) {
      say(`info depth 8 seldepth 10 multipv ${pv} score cp ${100 - pv * 10} nodes 1000 nps 50000 hashfull 12 tbhits 0 time 5 pv e3e4 e6e5`);
    }
    say('bestmove e3e4 ponder e6e5');
    return;
  }

  if (line === 'stop') {
    if (stalling) {
      stalling = false;
      say('bestmove e3e4 ponder e6e5');
    }
    return;
  }

  if (line === 'quit') {
    process.exit(0);
  }
});
