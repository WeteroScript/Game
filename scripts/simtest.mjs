// Headless-проверка физики уили. Запуск: npm run simtest
import * as THREE from 'three';
import { BikePhysics, BIKE_SPECS } from '../src/game/physics.js';
import { terrainGround, TRACK } from '../src/game/terrainMath.js';

const spec = BIKE_SPECS.yz450f;
const DEG = 180 / Math.PI;

function scenario(name, setup, script, duration = 6) {
  const p = new BikePhysics(spec, terrainGround);
  p.reset(new THREE.Vector3(TRACK.start.x, 5, TRACK.start.z), 0);
  setup?.(p);
  const dt = 1 / 120;
  let looped = false;
  const log = [];
  for (let t = 0; t < duration; t += dt) {
    const input = script(t, p);
    p.update(input, dt);
    log.push({ t, pitch: p.pitch * DEG, speed: p.speed * 3.6, crashed: p.crashed, wheelie: p.wheelieActive, suspR: p.suspR.compression, suspF: p.suspF.compression });
    if (p.crashed && !looped) { looped = true; }
  }
  console.log(`\n=== ${name} ===`);
  // сводка каждые 0.5 с
  for (let i = 0; i < log.length; i += Math.round(0.5 / dt)) {
    const l = log[i];
    console.log(`t=${l.t.toFixed(1)}с  pitch=${l.pitch.toFixed(1).padStart(6)}°  v=${l.speed.toFixed(0).padStart(3)}км/ч  suspR=${(l.suspR * 100).toFixed(0)}см  suspF=${(l.suspF * 100).toFixed(0)}см  ${l.crashed ? 'CRASH:' + p.crashType : l.wheelie ? 'WHEELIE' : ''}`);
  }
  return p;
}

const inputAt = (v) => (typeof v === 'function' ? v : () => v);
const base = { throttle: 0, brake: 0, steer: 0, lean: 0, wheelie: false };
const inp = (over) => ({ ...base, ...over });

// 1) Разгон с места в 1-й с уили — должен взлететь НЕ сразу, ~за 0.5–1.5 с
//    (даём байку доехать до 25 км/ч, затем жмём Shift + газ)
scenario('Разгон до 26 км/ч, затем Shift+газ (уили)', null,
  (t, p) => {
    const v = p.speed;
    if (v < 7.2) return inp({ throttle: 1 });              // разгоняемся
    return inp({ throttle: 0.75, wheelie: true, lean: 0.35 }); // удерживаем уили
  }, 8);

// 2) Удержание уили на 55% газа в балансе — должен жить, но требовать коррекции
scenario('Удержание в зоне баланса (газ ~50%)', (p) => {
  p.vel.set(0, 0, -8.5); // уже едем
}, (t, p) => inp({ throttle: t < 1.2 ? 0.9 : 0.52, wheelie: true, lean: 0.25 }), 7);

// 3) Полный газ + Shift удержанное — ожидаем LOOP OUT (слишком сильный газ)
scenario('Полный газ + Shift до отсечки (должен крутнуться)', (p) => {
  p.vel.set(0, 0, -8.5);
}, () => inp({ throttle: 1.0, wheelie: true, lean: 0.3 }), 7);

// 4) Сброс газа на 35° — нос должен плавно опуститься без падения
scenario('Уили 35° → отпустил газ (плавное опускание)', (p) => {
  p.vel.set(0, 0, -9);
}, (t, p) => {
  if (t < 1.4) return inp({ throttle: 0.95, wheelie: true, lean: 0.3 });
  return inp({ throttle: 0.0, wheelie: false, lean: -0.25 }); // сброс + вес вперёд
}, 6);

// 5) Езда без Shift — уили НЕТ даже на полном газу на низкой скорости
scenario('0–30 км/ч на полном газу БЕЗ Shift', null,
  () => inp({ throttle: 1.0 }), 6);

// 6) Крейсерские 60 км/ч без уили — устойчивая езда по прямой
scenario('Крейсер 60 км/ч', (p) => { p.vel.set(0, 0, -17); },
  () => inp({ throttle: 0.22 }), 6);

// 7) Уили + полный руль — должна быть потеря стабильности/крен
scenario('Уили + резкий руль (дестабилизация)', (p) => { p.vel.set(0, 0, -9); },
  (t, p) => inp({ throttle: 0.8, wheelie: true, steer: t > 0.8 ? 1.0 : 0, lean: 0.2 }), 5);

// 8) Уили на випах (x=+10.5, z≈0) — заметно сложнее держать
scenario('Уили на випах', (p) => {
  p.reset(new THREE.Vector3(TRACK.start.x + 10.5, 5, 20), 0);
  p.vel.set(0, 0, -8);
}, () => inp({ throttle: 0.62, wheelie: true, lean: 0.3 }), 5);

// 9) Передний тормоз во время набора уили — не должен встать
scenario('Shift + тормоз одновременно (уили запрещён)', (p) => { p.vel.set(0, 0, -9); },
  () => inp({ throttle: 0.9, brake: 0.8, wheelie: true }), 4);

console.log('\nСимуляция завершена.');
process.exit(0);
