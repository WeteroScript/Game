import * as THREE from 'three';
import { BikePhysics, BIKE_SPECS } from '../src/game/physics.js';
import { terrainGround, TRACK } from '../src/game/terrainMath.js';
const DEG = 180 / Math.PI;
const torque = Number(process.argv[2] || 260);
const spec = { ...BIKE_SPECS.yz450f };
// обездвижим байк на трассе: рулим чтобы остаться на центре
for (const hold of [0.35, 0.4, 0.45, 0.5, 0.55]) {
  const p = new BikePhysics(spec, terrainGround);
  p.reset(new THREE.Vector3(TRACK.start.x, 0, TRACK.start.z), 0);
  p.vel.set(0, 0, -9);
  const dt = 1/120;
  const trace = [];
  const zc = 0; // руление по центру
  for (let t = 0; t < 10; t += dt) {
    const thr = t < 1.15 ? 0.8 : hold;
    const center = 7 * Math.sin(p.pos.z * 0.011);
    const steer = Math.max(-1, Math.min(1, (center - p.pos.x) * 0.35 - p.yaw * 1.6));
    p.update({ throttle: thr, brake: 0, steer, lean: 0.18, wheelie: true }, dt);
    if (Math.round(t/dt) % 90 === 0) trace.push((p.pitch*DEG).toFixed(0)+'°');
    if (p.crashed) break;
  }
  console.log(`hold=${hold}  ${trace.join(' ')}  ${p.crashed?'CRASH:'+p.crashType:'OK'}`);
}
