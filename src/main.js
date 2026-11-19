// ============================================================================
//  STUNT MOTO — точка входа: меню, кнопки, запуск цикла
// ============================================================================

import { Game } from './game/game.js';

const canvas = document.getElementById('game-canvas');
const game = new Game(canvas);

const $ = (id) => document.getElementById(id);
const menu = $('menu');

// ---------- выбор байка ----------
let selectedBike = 'yz450f';
const cards = { yz450f: $('card-450'), yz300: $('card-300') };
for (const [id, card] of Object.entries(cards)) {
  card.addEventListener('click', () => {
    selectedBike = id;
    cards.yz450f.classList.toggle('selected', id === 'yz450f');
    cards.yz300.classList.toggle('selected', id === 'yz300');
    game.spawnBike(id);        // живая смена модели на стартовой площадке
    game.state = 'menu';
  });
}

// ---------- старт ----------
$('btn-start').addEventListener('click', () => {
  menu.classList.add('hidden');
  game.startFromMenu();
});

// ---------- респаун ----------
$('btn-respawn').addEventListener('click', () => game.respawn());
$('btn-respawn-crash').addEventListener('click', () => game.respawn());

// ---------- звук ----------
$('btn-mute').addEventListener('click', () => {
  const muted = game.toggleMute();
  $('btn-mute').textContent = muted ? '🔇' : '🔊';
});

// ---------- горячие клавиши ----------
game.input.onKey = (code) => {
  if (code === 'KeyR') game.respawn();
  else if (code === 'KeyM') {
    const muted = game.toggleMute();
    $('btn-mute').textContent = muted ? '🔇' : '🔊';
  } else if (code === 'Escape') {
    if (game.state !== 'menu') {
      menu.classList.remove('hidden');
      game.backToMenu();
      $('menu-highscore').textContent = String(Math.floor(game.highscore));
    }
  }
};

$('menu-highscore').textContent = String(Math.floor(game.highscore));
$('hud-highscore').textContent = String(Math.floor(game.highscore));

// ---------- главный цикл ----------
function frame() {
  game.tick();
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
