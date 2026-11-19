import * as THREE from 'three';
import { BikePhysics, BIKE_SPECS } from '../src/game/physics.js';
import { terrainGround, TRACK } from '../src/game/terrainMath.js';
const spec = BIKE_SPECS.yz450f;
const DEG = 180 / Math.PI;
for (const [lean, hold] of [[0.8,0.1],[0.8,0.15],[0.8,0.2],[0.8,0.25],[1.0,0.2],[0.5,0.2],[0.3,0.15],[0.0,0.2]]) {
  const p = new BikePhysics(spec, terrainGround);
  p.reset(new THREE.Vector3(TRACK.start.x, 0, TRACK.start.z), 0);
  p.vel.set(0, 0, -9);
  const dt = 1/120;
  let trace = [];
  for (let t = 0; t < 9; t += dt) {
    const thr = t < 1.15 ? 0.8 : hold;
    p.update({ throttle: thr, brake: 0, steer: 0, lean, wheelie: true }, dt);
    if (Math.round(t/dt) % 120 === 0) trace.push((p.pitch*DEG).toFixed(0)+'°');
    if (p.crashed) break;
  }
  console.log(`lean=${lean} hold=${hold}  ${trace.join(' ')}  ${p.crashed?'CRASH:'+p.crashType:'OK'}`);
}
