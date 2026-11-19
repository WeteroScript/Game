import * as THREE from 'three';
import { BikePhysics, BIKE_SPECS } from '../src/game/physics.js';
import { terrainGround, TRACK } from '../src/game/terrainMath.js';
const spec = BIKE_SPECS.yz450f;
const DEG = 180 / Math.PI;
for (const [lean, hold] of [[0.5,0.4],[0.8,0.35],[1.0,0.32],[0.8,0.45],[1.0,0.4],[0.6,0.5]]) {
  const p = new BikePhysics(spec, terrainGround);
  p.reset(new THREE.Vector3(TRACK.start.x, 0, TRACK.start.z), 0);
  p.vel.set(0, 0, -9);
  const dt = 1/120;
  let peak = 0;
  for (let t = 0; t < 8; t += dt) {
    const thr = t < 1.15 ? 0.8 : hold;
    p.update({ throttle: thr, brake: 0, steer: 0, lean, wheelie: true }, dt);
    peak = Math.max(peak, p.pitch * DEG);
    if (p.crashed) break;
  }
  console.log(`lean=${lean} hold=${hold}  final=${(p.pitch*DEG).toFixed(1)}°  peak=${peak.toFixed(0)}°  ${p.crashed?'CRASH:'+p.crashType:'OK'}`);
}
