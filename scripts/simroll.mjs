import * as THREE from 'three';
import { BikePhysics, BIKE_SPECS } from '../src/game/physics.js';
import { terrainGround, TRACK, groundRoughness } from '../src/game/terrainMath.js';
const spec = BIKE_SPECS.yz450f;
const DEG = 180 / Math.PI;
const p = new BikePhysics(spec, terrainGround);
p.reset(new THREE.Vector3(TRACK.start.x, 0, TRACK.start.z), 0);
p.vel.set(0, 0, -9);
const dt = 1/120;
for (let t = 0; t < 10; t += dt) {
  const thr = t < 1.0 ? 0.75 : Math.min(0.6, Math.max(0, 0.35 + 0.016 * ((0.61 - p.pitch) * DEG)));
  p.update({ throttle: thr, brake: 0, steer: 0, lean: 0.25, wheelie: true }, dt);
  const i = Math.round(t/dt);
  if (i % 90 === 0 || Math.abs(p.roll) > 0.35) {
    console.log(`t=${t.toFixed(2)} pitch=${(p.pitch*DEG).toFixed(1)} roll=${(p.roll*DEG).toFixed(1)} wRoll=${p.wRoll?.toFixed?.(2) ?? ''} x=${p.pos.x.toFixed(1)} z=${p.pos.z.toFixed(1)} rough=${groundRoughness(p.pos.x, p.pos.z).toFixed(2)} ${p.crashed?'CRASH:'+p.crashType:''}`);
  }
  if (p.crashed && t > 9.9) break;
}
