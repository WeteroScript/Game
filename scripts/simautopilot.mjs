import * as THREE from 'three';
import { BikePhysics, BIKE_SPECS } from '../src/game/physics.js';
import { terrainGround, TRACK } from '../src/game/terrainMath.js';
const DEG = 180 / Math.PI;
for (const [kc, ky, maxs] of [[0.12, 0.9, 0.6], [0.08, 0.6, 0.4], [0.2, 1.2, 0.8]]) {
  const p = new BikePhysics(BIKE_SPECS.yz450f, terrainGround);
  p.reset(new THREE.Vector3(TRACK.start.x, 0, TRACK.start.z), 0);
  p.vel.set(0, 0, -9);
  const dt = 1/120;
  const trace = [];
  for (let t = 0; t < 14; t += dt) {
    const center = 7 * Math.sin(p.pos.z * 0.011);
    // знак: steer>0 — поворот влево (к -x)
    const steer = Math.max(-maxs, Math.min(maxs, (p.pos.x - center) * kc - p.yaw * ky));
    p.update({ throttle: 0.55, brake: 0, steer, lean: 0, wheelie: false }, dt);
    const i = Math.round(t/dt);
    if (i % 360 === 0) trace.push(`${t.toFixed(0)}s:${(p.speed*3.6).toFixed(0)}k x=${p.pos.x.toFixed(1)} c=${center.toFixed(1)} ${p.crashed?'❌'+p.crashType:'✓'}`);
    if (p.crashed) break;
  }
  console.log(`kc=${kc} ky=${ky} maxs=${maxs}:\n   ${trace.join('\n   ')}\n   ${p.crashed?'CRASH:'+p.crashType:'OK — 14с чистой езды'}`);
}
