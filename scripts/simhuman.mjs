import * as THREE from 'three';
import { BikePhysics, BIKE_SPECS } from '../src/game/physics.js';
import { terrainGround, TRACK } from '../src/game/terrainMath.js';
const spec = BIKE_SPECS.yz450f;
const DEG = 180 / Math.PI;
// человеческая модель: газ = база + k*(цель - pitch)  (цель ~35°)
for (const k of [0.010, 0.016, 0.024]) {
  const p = new BikePhysics(spec, terrainGround);
  p.reset(new THREE.Vector3(TRACK.start.x, 0, TRACK.start.z), 0);
  p.vel.set(0, 0, -9);
  const dt = 1/120;
  const trace = [];
  let inZone = 0, t_in = 0;
  for (let t = 0; t < 10; t += dt) {
    const target = 0.61; // рад (35°)
    let thr = t < 1.0 ? 0.75 : 0.35 + k * ((target - p.pitch) * DEG);
    thr = Math.max(0, Math.min(0.6, thr));
    p.update({ throttle: thr, brake: 0, steer: 0, lean: 0.25, wheelie: true }, dt);
    const pd = p.pitch * DEG;
    if (pd >= 25 && pd <= 55) { inZone++; t_in += dt; }
    if (Math.round(t/dt) % 90 === 0) trace.push(pd.toFixed(0)+'°');
    if (p.crashed) break;
  }
  console.log(`k=${k}  ${trace.join(' ')}  время_в_зоне=${t_in.toFixed(1)}с  ${p.crashed?'CRASH:'+p.crashType:'OK'}`);
}
