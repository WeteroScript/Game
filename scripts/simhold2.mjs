import * as THREE from 'three';
import { BikePhysics, BIKE_SPECS } from '../src/game/physics.js';
import { terrainGround, TRACK } from '../src/game/terrainMath.js';
const DEG = 180 / Math.PI;
for (const hold of [0.35, 0.42, 0.5]) {
  const p = new BikePhysics(BIKE_SPECS.yz450f, terrainGround);
  p.reset(new THREE.Vector3(TRACK.start.x, 0, TRACK.start.z), 0);
  p.vel.set(0, 0, -9);
  const dt = 1/120;
  const trace = [];
  for (let t = 0; t < 12; t += dt) {
    const center = 7 * Math.sin(p.pos.z * 0.011);
    const steer = Math.max(-0.6, Math.min(0.6, (p.pos.x - center) * 0.12 - p.yaw * 0.9));
    const thr = t < 1.15 ? 0.8 : hold;
    p.update({ throttle: thr, brake: 0, steer, lean: 0.18, wheelie: true }, dt);
    if (Math.round(t/dt) % 90 === 0) trace.push((p.pitch*DEG).toFixed(0)+'°');
    if (p.crashed) break;
  }
  console.log(`hold=${hold}  ${trace.join(' ')}  ${p.crashed?'CRASH:'+p.crashType:'OK'}`);
}
