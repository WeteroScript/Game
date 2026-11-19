import * as THREE from 'three';
import { BikePhysics, BIKE_SPECS } from '../src/game/physics.js';
import { terrainGround, TRACK } from '../src/game/terrainMath.js';
const spec = BIKE_SPECS.yz450f;
const DEG = 180 / Math.PI;
for (const hold of [0.28, 0.32, 0.36, 0.40, 0.44]) {
  const p = new BikePhysics(spec, terrainGround);
  p.reset(new THREE.Vector3(TRACK.start.x, 0, TRACK.start.z), 0);
  p.vel.set(0, 0, -9);
  const dt = 1/120;
  let liftTick = -1, settled = [];
  for (let t = 0; t < 8; t += dt) {
    // фаза подъёма: 0.78; дальше держим hold
    const thr = (liftTick < 0 && t < 1.15) ? 0.78 : hold;
    p.update({ throttle: thr, brake: 0, steer: 0, lean: 0.18, wheelie: true }, dt);
    if (p.pitch > 0.28 && liftTick < 0) liftTick = t;
    if (t > 6 && !p.crashed) settled.push(p.pitch * DEG);
    if (p.crashed) break;
  }
  const avg = settled.length ? settled.reduce((a,b)=>a+b,0)/settled.length : NaN;
  console.log(`hold=${hold}  lift@${liftTick<0?'—':liftTick.toFixed(2)+'s'}  settled(6-8s)=${isNaN(avg)?'CRASH:'+p.crashType:avg.toFixed(1)+'°'}  final=${isNaN(avg)?'':(p.pitch*DEG).toFixed(1)+'°'}`);
}
