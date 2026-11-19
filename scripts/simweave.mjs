import * as THREE from 'three';
import { BikePhysics, BIKE_SPECS } from '../src/game/physics.js';
import { terrainGround, TRACK } from '../src/game/terrainMath.js';
const DEG = 180 / Math.PI;
const p = new BikePhysics(BIKE_SPECS.yz450f, terrainGround);
p.reset(new THREE.Vector3(TRACK.start.x, 0, TRACK.start.z), 0);
p.vel.set(0, 0, -9);
const dt = 1/120;
for (let t = 0; t < 12; t += dt) {
  const center = 7 * Math.sin(p.pos.z * 0.011);
  const steer = Math.max(-0.6, Math.min(0.6, (center - p.pos.x) * 0.12 - p.yaw * 0.9));
  p.update({ throttle: 0.55, brake: 0, steer, lean: 0, wheelie: false }, dt);
  const i = Math.round(t/dt);
  if (t > 7.5 && i % 30 === 0) console.log(`t=${t.toFixed(2)} x=${p.pos.x.toFixed(2)} c=${center.toFixed(2)} yaw=${(p.yaw*DEG).toFixed(1)} roll=${(p.roll*DEG).toFixed(1)} pitch=${(p.pitch*DEG).toFixed(1)} v=${(p.speed*3.6).toFixed(0)}k rough=${p.pos.y.toFixed(2)}`);
  if (p.crashed) { console.log('CRASH', p.crashType, 'at t=', t.toFixed(2)); break; }
}
