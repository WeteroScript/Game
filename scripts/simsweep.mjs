import * as THREE from 'three';
import { BikePhysics, BIKE_SPECS } from '../src/game/physics.js';
import { terrainGround, TRACK } from '../src/game/terrainMath.js';
const spec = BIKE_SPECS.yz450f;
const DEG = 180 / Math.PI;
for (const thr of [0.45, 0.5, 0.55, 0.6, 0.65]) {
  const p = new BikePhysics(spec, terrainGround);
  p.reset(new THREE.Vector3(TRACK.start.x, 0, TRACK.start.z), 0);
  p.vel.set(0, 0, -9);
  const dt = 1/120;
  let trace = [];
  for (let t = 0; t < 6; t += dt) {
    p.update({ throttle: thr, brake: 0, steer: 0, lean: 0.22, wheelie: true }, dt);
    const i = Math.round(t/dt);
    if (i % 60 === 0) trace.push(`${t.toFixed(1)}с:${(p.pitch*DEG).toFixed(0)}°`);
    if (p.crashed) { trace.push('CRASH:'+p.crashType); break; }
  }
  console.log(`газ ${thr}: ${trace.join('  ')}`);
}
