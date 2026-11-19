import * as THREE from 'three';
import { BikePhysics, BIKE_SPECS } from '../src/game/physics.js';
import { terrainGround, TRACK } from '../src/game/terrainMath.js';
const spec = BIKE_SPECS.yz450f;
const DEG = 180 / Math.PI;
const p = new BikePhysics(spec, terrainGround);
p.reset(new THREE.Vector3(TRACK.start.x, 0, TRACK.start.z), 0);
p.vel.set(0, 0, -9);
const dt = 1/120;
let minPitch = 99, maxPitch = -99;
for (let t = 0; t < 10; t += dt) {
  // фаза 1 (0-1.2c): сильный газ чтобы поднять; дальше фиксированный средний газ
  const thr = t < 1.15 ? 0.78 : (t < 1.3 ? 0.78 : 0.34);
  const lean = t < 1.15 ? 0.4 : 0.15;
  p.update({ throttle: thr, brake: 0, steer: 0, lean, wheelie: true }, dt);
  if (t > 1.4 && !p.crashed) { minPitch = Math.min(minPitch, p.pitch*DEG); maxPitch = Math.max(maxPitch, p.pitch*DEG); }
  const i = Math.round(t/dt);
  if (i % 30 === 0) console.log(`t=${t.toFixed(2)} pitch=${(p.pitch*DEG).toFixed(1)} roll=${(p.roll*57.3).toFixed(2)} v=${(p.speed*3.6).toFixed(0)}км/ч suspR=${(p.suspR.compression*100).toFixed(0)}см ${p.crashed?'CRASH:'+p.crashType:''}`);
}
console.log(`\nПосле подъёма: pitch ∈ [${minPitch.toFixed(1)}°, ${maxPitch.toFixed(1)}°], crashed=${p.crashed}`);
