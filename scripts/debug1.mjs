import * as THREE from 'three';
import { BikePhysics, BIKE_SPECS } from '../src/game/physics.js';
import { terrainGround, TRACK } from '../src/game/terrainMath.js';
const p = new BikePhysics(BIKE_SPECS.yz450f, terrainGround);
p.reset(new THREE.Vector3(TRACK.start.x, 0, TRACK.start.z), 0);
const dt = 1/120;
const inp = { throttle: 0, brake: 0, steer: 0, lean: 0, wheelie: false };
for (let t = 0; t < 4; t += dt) {
  p.update(inp, dt);
  if (Math.abs(p.pos.y % 0.02) < 1) { /* noop */ }
  const i = Math.round(t/dt);
  if (i % 12 === 0) {
    console.log(`t=${t.toFixed(2)} y=${p.pos.y.toFixed(3)} vy=${p.vel.y.toFixed(3)} pitch=${(p.pitch*180/Math.PI).toFixed(2)} roll=${(p.roll*180/Math.PI).toFixed(2)} wRoll=${(p.angVel.length()).toFixed(3)} sR=${(p.suspR.compression*100).toFixed(1)} sF=${(p.suspF.compression*100).toFixed(1)} fR=${p.suspR.force.toFixed(0)} fF=${p.suspF.force.toFixed(0)}`);
  }
}
