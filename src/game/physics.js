// ============================================================================
//  STUNT MOTO — физическая модель мотоцикла (жёсткое тело + рэйкаст подвеска)
//
//  Все моменты считаются в ЛОКАЛЬНОЙ системе корпуса (+X вправо / тангаж,
//  +Y вверх / рысканье, +Z назад / крен) — это исключает ошибки знаков при
//  мировых осях. Корпус — свободное твёрдое тело с диагональным тензором
//  инерции. Гравитация не даёт момента про COM; «занос» носа вниз при сбросе
//  газа рождается естественно из точки приложения силы заднего колеса позади
//  центра масс.
//
//  Локальные оси байка: +X — вправо, +Y — вверх, −Z — вперёд (как в ТЗ).
//  Состояние pos — начало шасси (проектная геометрия, у земли), COM выше на
//  comDesign + сдвиг от переноса веса райдера.
// ============================================================================

import * as THREE from 'three';

export const DEG = 180 / Math.PI;

// Пороги по углу тангажа (рад)
export const BALANCE_MIN = 25 / DEG;
export const BALANCE_COMFY = 38 / DEG; // целевой угол слабого PID-стабилизатора
export const BALANCE_MAX = 55 / DEG;
export const AMBER_MAX = 72 / DEG;     // выше — LOOP OUT (опрокидывание назад)

// ---------------------------------------------------------------- специи байков
export const BIKE_SPECS = {
  yz450f: {
    id: 'yz450f',
    name: 'YAMAHA YZ450F',
    mass: 199,                 // кг (мотоцикл 108 + райдер 91)
    inertia: { x: 46, y: 88, z: 27 },
    wheelTorque: 185,
    gearRatio: [2.35, 1.78, 1.34, 1.03, 0.80],
    gearTop: [13.5, 21.5, 28.0, 35.5, 44.0],
    engineReaction: 0.85,      // доля момента на колесе, идущая в реакцию на шасси
    clutchBite: 1.0,
    comDesign: new THREE.Vector3(0, 0.60, 0.27),
    frontWheelR: 0.355,
    rearWheelR: 0.345,
  },
  yz300: {
    id: 'yz300',
    name: 'YAMAHA YZ300',
    mass: 178,
    inertia: { x: 40, y: 79, z: 24 },
    wheelTorque: 158,
    gearRatio: [2.55, 1.92, 1.45, 1.10, 0.86],
    gearTop: [14.5, 23.0, 30.0, 38.0, 46.0],
    engineReaction: 0.95,
    clutchBite: 1.18,
    comDesign: new THREE.Vector3(0, 0.585, 0.25),
    frontWheelR: 0.355,
    rearWheelR: 0.34,
  },
};

const G = 9.81;
const WHEELBASE = 1.485;
const FRONT_Z = -WHEELBASE / 2;
const REAR_Z = +WHEELBASE / 2;

// Крепления лучей подвески (chassis-local)
const RAY_ORIGIN_FRONT = new THREE.Vector3(0, 0.80, FRONT_Z + 0.02);
const RAY_ORIGIN_REAR = new THREE.Vector3(0, 0.76, REAR_Z - 0.06);
const REST_LEN_F = 0.455;
const REST_LEN_R = 0.415;
const SPRING_F = 10500, SPRING_R = 12500;
const DAMP_F = 1750, DAMP_R = 2100;
const FORCE_CAP = 9500;
const BUMPSTOP = 6600;                     // Н/м добавки в отбойник у конца хода
const MAX_TRAVEL_F = 0.27, MAX_TRAVEL_R = 0.29;

const MAX_CLUTCH_TORQUE = 290;
const MAX_PID_TORQUE = 30;                 // слабый автопилот — НЕ держит сам
const MIN_WHEELIE_SPEED = 4.2;             // м/с (~15 км/ч)
const FULL_WHEELIE_SPEED = 9.0;            // м/с (~32 км/ч)
const LOOP_OUT_PITCH = AMBER_MAX;

const GEAR_LIFT = [1.0, 0.88, 0.66, 0.45, 0.28];
const GEAR_YAW = 0.052;

const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const smoothstep = (a, b, x) => {
  const t = clamp((x - a) / (b - a), 0, 1);
  return t * t * (3 - 2 * t);
};

// ============================================================ класс физики
export class BikePhysics {
  constructor(spec, ground) {
    this.spec = spec;
    this.ground = ground;
    this.reset(new THREE.Vector3(0, 0, 118), 0);
  }

  reset(spawnPos, yaw = 0) {
    this.pos = spawnPos.clone();
    this.vel = new THREE.Vector3(0, 0, 0);
    this.quat = new THREE.Quaternion().setFromEuler(new THREE.Euler(0, yaw, 0, 'YXZ'));
    this.angVel = new THREE.Vector3(0, 0, 0);

    this.throttle = 0; this.brake = 0; this.steer = 0; this.lean = 0;
    this.clutchRamp = 0;

    this.suspF = { t: REST_LEN_F, compression: 0.03, force: 0, contact: true, wheelCenter: new THREE.Vector3() };
    this.suspR = { t: REST_LEN_R, compression: 0.03, force: 0, contact: true, wheelCenter: new THREE.Vector3() };
    this._prevTF = REST_LEN_F; this._prevTR = REST_LEN_R;
    this._wasFrontContact = true; this._wasRearContact = true;
    this.impactFlash = 0;

    this.crashed = false;
    this.crashType = null;   // 'loopout' | 'endo' | 'washout' | 'hard'
    this.crashTimer = 0;

    this.speed = 0;
    this.pitch = 0;
    this.roll = 0;
    this.yaw = yaw;
    this.pitchRate = 0;
    this.gear = 1;
    this.rpm01 = 0.06;
    this.wheelieActive = false;
    this.frontAirTime = 0;
    this._wobblePhase = Math.random() * 10;

    this.settleGrounded(spawnPos, yaw);
  }

  settleGrounded(spawnPos, yaw) {
    const h = this.ground.h(spawnPos.x, spawnPos.z);
    this.pos.set(spawnPos.x, h + 0.03, spawnPos.z);
    this.vel.set(0, 0, 0);
    this.angVel.set(0, 0, 0);
  }

  // ================= главный вход =================
  update(input, dt) {
    const sub = Math.max(1, Math.min(8, Math.ceil(dt / (1 / 120))));
    const h = dt / sub;
    for (let i = 0; i < sub; i++) this.step(input, h);
    this.impactFlash = Math.max(0, this.impactFlash - dt);
  }

  // ================= один физический шаг =================
  step(input, dt) {
    const s = this.spec;
    const q = this.quat;
    const qInv = q.clone().invert();

    // ---------- сглаживание входов ----------
    const rise = (cur, tgt, rate) => cur + clamp(tgt - cur, -rate * dt, rate * dt);
    this.throttle = rise(this.throttle, this.crashed ? 0 : clamp(input.throttle, 0, 1), 6.5);
    this.brake = rise(this.brake, this.crashed ? 0 : clamp(input.brake, 0, 1), 9.0);
    this.steer = rise(this.steer, this.crashed ? 0 : clamp(input.steer, -1, 1), 4.2);
    this.lean = rise(this.lean, this.crashed ? 0 : clamp(input.lean, -1, 1), 2.6);

    const clutchTgt = (!this.crashed && input.wheelie) ? 1 : 0;
    this.clutchRamp = rise(this.clutchRamp, clutchTgt, clutchTgt > this.clutchRamp ? 1 / 0.30 : 1 / 0.16);

    // ---------- ориентация (Эйлер YXZ: x=тангаж, y=рысканье, z=крен) ----------
    const eul = new THREE.Euler().setFromQuaternion(q, 'YXZ');
    const pitch = eul.x, roll = eul.z;
    this.yaw = eul.y;
    this.pitch = pitch; this.roll = roll;

    const fwd = new THREE.Vector3(0, 0, -1).applyQuaternion(q);
    const rightv = new THREE.Vector3(1, 0, 0).applyQuaternion(q);
    const upv = new THREE.Vector3(0, 1, 0).applyQuaternion(q);

    const hSpeed = Math.hypot(this.vel.x, this.vel.z);
    this.speed = this.vel.length();

    // ---------- передача и обороты ----------
    const tops = s.gearTop;
    let gear = 1;
    for (let g = 0; g < tops.length; g++) {
      const loLimit = g === 0 ? 0 : tops[g - 1] * 0.82;
      if (hSpeed >= loLimit && hSpeed < tops[g]) gear = g + 1;
    }
    if (hSpeed >= tops[tops.length - 1] * 0.82) gear = tops.length;
    this.gear = clamp(gear, 1, 5);
    const lo = this.gear === 1 ? 0 : tops[this.gear - 2] * 0.82;
    const hi = tops[this.gear - 1];
    this.rpm01 = clamp((hSpeed - lo) / Math.max(1, hi - lo), 0.06, 1);

    // ---------- сдвиг COM (перенос веса райдера) ----------
    const leanZ = this.lean * 0.30;
    const leanY = this.lean * 0.025;
    const comLocal = new THREE.Vector3(0, s.comDesign.y + leanY, s.comDesign.z + leanZ);
    const comPos = comLocal.applyQuaternion(q).add(this.pos);

    // угловая скорость в локальном кадре
    const wLocal = this.angVel.clone().applyQuaternion(qInv);
    const wPitch = wLocal.x, wYaw = wLocal.y, wRoll = wLocal.z;
    this.pitchRate = wPitch;

    // ---------- накопители ----------
    const F = new THREE.Vector3(0, -s.mass * G, 0);  // мировые силы (линейка)
    let tauX = 0, tauY = 0, tauZ = 0;                // ЛОКАЛЬНЫЕ моменты про COM

    const applyAt = (fWorld, appWorld) => {
      F.add(fWorld);
      const r = appWorld.clone().sub(comPos).applyQuaternion(qInv);
      const fL = fWorld.clone().applyQuaternion(qInv);
      tauX += r.y * fL.z - r.z * fL.y;
      tauY += r.z * fL.x - r.x * fL.z;
      tauZ += r.x * fL.y - r.y * fL.x;
    };

    const groundH = (x, z) => this.ground.h(x, z);
    const frontR = s.frontWheelR, rearR = s.rearWheelR;

    // ============ подвеска ============
    let frontContact = false, rearContact = false;
    let nFront = 0, nRear = 0;

    const forkRake = 27 / DEG;
    const solveWheel = (rayOriginLocal, restLen, wheelR, spring, damp, prevRawT, axis) => {
      const hp = rayOriginLocal.clone().applyQuaternion(q).add(this.pos);
      // axis: 'fork' — вдоль перьев вилки (рак 27°, anti-dive), 'world' — вертикально
      // (задний маятник почти горизонтален → сила реакции почти вертикальна)
      const dir = axis === 'fork'
        ? new THREE.Vector3(0, -Math.cos(forkRake), -Math.sin(forkRake)).applyQuaternion(q)
        : new THREE.Vector3(0, -1, 0);
      let t = prevRawT;
      for (let it = 0; it < 3; it++) {
        const px = hp.x + dir.x * t, pz = hp.z + dir.z * t;
        const targetY = groundH(px, pz) + wheelR;
        const denom = -dir.y;
        t = denom > 0.08 ? (hp.y - targetY) / denom : restLen * 1.5;
      }
      const tRaw = Math.max(t, 0);
      const tClamped = clamp(tRaw, 0, restLen);
      const wheelCenter = hp.clone().addScaledVector(dir, tClamped);
      const compression = restLen - tClamped;
      const compVel = clamp((prevRawT - tRaw) / dt, -3.2, 3.2);
      let force = 0;
      if (compression > 0) {
        force = spring * compression + damp * compVel;
        const over = compression - (restLen - 0.10);
        if (over > 0) force += over * BUMPSTOP;
        force = clamp(force, 0, FORCE_CAP);
      }
      return { t: tClamped, tRaw, compression, force, wheelCenter };
    };

    const fS = solveWheel(RAY_ORIGIN_FRONT, REST_LEN_F, frontR, SPRING_F, DAMP_F, this._prevTF, 'fork');
    const rS = solveWheel(RAY_ORIGIN_REAR, REST_LEN_R, rearR, SPRING_R, DAMP_R, this._prevTR, 'world');
    this._prevTF = fS.tRaw; this._prevTR = rS.tRaw;

    if (fS.force > 0.5) {
      frontContact = true; nFront = fS.force;
      applyAt(new THREE.Vector3(0, Math.cos(forkRake), Math.sin(forkRake)).applyQuaternion(q).multiplyScalar(fS.force), fS.wheelCenter);
    }
    if (rS.force > 0.5) {
      rearContact = true; nRear = rS.force;
      applyAt(new THREE.Vector3(0, 1, 0).multiplyScalar(rS.force), rS.wheelCenter);
    }

    const groundPoint = (wc) => new THREE.Vector3(wc.x, groundH(wc.x, wc.z) + 0.005, wc.z);
    const cF = frontContact ? groundPoint(fS.wheelCenter) : null;
    const cR = rearContact ? groundPoint(rS.wheelCenter) : null;

    const pointVel = (cPt) => {
      const r = cPt.clone().sub(comPos);
      return this.vel.clone().add(new THREE.Vector3().crossVectors(this.angVel, r));
    };

    const groundFrame = (cPt) => {
      const e = 0.45;
      const hx1 = groundH(cPt.x + e, cPt.z), hx0 = groundH(cPt.x - e, cPt.z);
      const hz1 = groundH(cPt.x, cPt.z + e), hz0 = groundH(cPt.x, cPt.z - e);
      const nrm = new THREE.Vector3(hx0 - hx1, 2 * e, hz0 - hz1).normalize();
      const fwdT = fwd.clone().addScaledVector(nrm, -fwd.dot(nrm));
      if (fwdT.lengthSq() < 1e-6) fwdT.set(0, 0, -1); else fwdT.normalize();
      const latT = new THREE.Vector3().crossVectors(nrm, fwdT).normalize().negate();
      return { nrm, fwdT, latT };
    };

    const gripAt = (x, z) => this.ground.grip(x, z);
    const roughAt = (x, z) => this.ground.roughness(x, z);

    // ============ тяга / тормоза / сопротивление ============
    const top = tops[this.gear - 1];
    const falloff = clamp(1 - 0.72 * Math.pow(hSpeed / top, 2), 0.10, 1);
    const wheelTorqueNow = this.throttle * s.wheelTorque * s.gearRatio[this.gear - 1] * falloff;
    let driveForce = wheelTorqueNow / rearR;

    const muR = gripAt(rS.wheelCenter.x, rS.wheelCenter.z);
    const tractionLimit = Math.max(0, nRear) * muR * 1.30 + 120;
    driveForce = clamp(driveForce, 0, tractionLimit);

    if (rearContact && cR) {
      const { fwdT } = groundFrame(cR);
      applyAt(fwdT.clone().multiplyScalar(driveForce), cR);
    }

    // реакция двигателя — момент, задирающий нос (локальная X)
    const driveReaction = wheelTorqueNow * s.engineReaction;

    // торможение
    const brakeFall = clamp(hSpeed / 2.5, 0, 1);
    if (this.brake > 0.02) {
      const fFront = this.brake * 2350 * brakeFall;
      const fRear = this.brake * 1750 * brakeFall;
      if (frontContact && cF) {
        const { fwdT } = groundFrame(cF);
        applyAt(fwdT.clone().multiplyScalar(-fFront), cF);
      }
      if (rearContact && cR) {
        const { fwdT } = groundFrame(cR);
        applyAt(fwdT.clone().multiplyScalar(-fRear), cR);
      }
      // передний тормоз «клюёт» нос — убивает уили
      const noseDive = this.brake * 165 * clamp(pitch + 0.35, 0, 1.3);
      tauX -= noseDive;
    }

    // двигательное торможение при сбросе газа
    if (this.throttle < 0.06 && hSpeed > 2 && rearContact && cR) {
      const { fwdT } = groundFrame(cR);
      applyAt(fwdT.clone().multiplyScalar(-42), cR);
    }

    // сопротивление воздуха и качения
    if (this.speed > 0.2) {
      const drag = 0.40 * this.speed * this.speed + 28;
      F.addScaledVector(this.vel, -drag / this.speed);
    }

    // ============ боковое сцепление ============
    const lateralGrip = (cPt, nLoad) => {
      if (!cPt) return;
      const { latT } = groundFrame(cPt);
      const v = pointVel(cPt);
      const vLat = v.dot(latT);
      const mu = gripAt(cPt.x, cPt.z);
      let f = -vLat * clamp(nLoad * 0.16, 60, 2600);
      f = clamp(f, -mu * nLoad * 1.12, mu * nLoad * 1.12);
      applyAt(latT.clone().multiplyScalar(f), cPt);
    };
    lateralGrip(cF, nFront);
    lateralGrip(cR, nRear);

    // ============ рысканье (руль) ============
    if (frontContact && hSpeed > 1.4) {
      const yawTarget = this.steer * clamp(hSpeed * GEAR_YAW, 0, 1.05);
      tauY += clamp((yawTarget - wYaw) * s.inertia.y * 2.0, -260, 260);
    } else {
      // в уили/воздухе руль не разворачивает, но выбивает равновесие
      tauZ += this.steer * (16 + hSpeed * 0.55) * 0.9;   // крен
      tauX += Math.abs(this.steer) * 6.5;                 // и чуть носом
      tauY += -wYaw * s.inertia.y * 1.1;                  // затухание рысканья
    }

    // ============ уили: момент сцепления ============
    const speedFactor = smoothstep(MIN_WHEELIE_SPEED, FULL_WHEELIE_SPEED, hSpeed);
    const gearFactor = GEAR_LIFT[this.gear - 1];
    const brakeKill = this.brake > 0.15 ? 0.10 : 1.0;
    const throttleBite = 0.22 + 0.78 * this.throttle;
    const steerPenalty = 1 - 0.45 * Math.abs(this.steer) * (pitch > 0.1 ? 1 : 0.3);
    const highSoftCap = clamp(1.35 - Math.max(0, pitch - 0.45) / 0.9, 0.35, 1);
    const clutchTorque = this.clutchRamp * MAX_CLUTCH_TORQUE
      * throttleBite * speedFactor * gearFactor * brakeKill * s.clutchBite * steerPenalty * highSoftCap;

    tauX += driveReaction + clutchTorque;

    // ============ слабый PID «зоны баланса» (только когда колесо в воздухе) ============
    const frontAir = !frontContact;
    if (frontAir && pitch > 0.10 && !this.crashed) {
      let pid = 42 * (BALANCE_COMFY - pitch) - 15 * wPitch;
      pid = clamp(pid, -MAX_PID_TORQUE, MAX_PID_TORQUE);
      tauX += pid;
    }

    // ============ кочки / бездорожье: возмущения (только при контакте с грунтом!) ============
    const rough = clamp(roughAt(this.pos.x, this.pos.z), 0, 1.6);
    const anyContact = frontContact || rearContact;
    if (anyContact && rough > 0.25 && !this.crashed) {
      this._wobblePhase += dt * (9 + hSpeed * 0.55);
      const noise = Math.sin(this._wobblePhase) * 0.6 + Math.sin(this._wobblePhase * 2.7 + 1.3) * 0.4;
      tauX += noise * rough * 12.0;
      tauZ += Math.cos(this._wobblePhase * 1.7) * rough * 8.0;
    }

    // ============ стабилизация крена (trail-эффект), отрицательная обратная связь ============
    const stabAuthority = (frontContact || rearContact) ? clamp(hSpeed / 4, 0.45, 1) : 0.34;
    const rollK = this.crashed ? 8 : 60;
    const rollD = this.crashed ? 3 : 28;
    tauZ += (-rollK * roll - rollD * wRoll) * stabAuthority;

    // в воздухе райдер гасит раскачку корпуса
    const airborne = !(frontContact || rearContact);
    if (airborne) { tauX += -16.0 * wPitch; tauZ += -8.0 * wRoll; }
    // аэродинамическое затухание вращения
    tauX += -0.045 * wPitch;
    tauY += -0.045 * wYaw;
    tauZ += -0.045 * wRoll;


    // ============ интегрирование: линейное ============
    const a = F.divideScalar(s.mass);
    this.vel.addScaledVector(a, dt);
    if (this.vel.lengthSq() > 70 * 70) this.vel.setLength(70);
    this.pos.addScaledVector(this.vel, dt);

    // ============ интегрирование: угловое (локальный тензор диагонален) ============
    wLocal.x += (tauX / s.inertia.x) * dt;
    wLocal.y += (tauY / s.inertia.y) * dt;
    wLocal.z += (tauZ / s.inertia.z) * dt;
    wLocal.multiplyScalar(Math.max(0, 1 - 0.05 * dt));
    this.angVel.copy(wLocal.applyQuaternion(q));

    // интегрирование кватерниона: dq/dt = 0.5 · ω_мир ⊗ q
    {
      const wx = this.angVel.x, wy = this.angVel.y, wz = this.angVel.z;
      const qx = q.x, qy = q.y, qz = q.z, qw = q.w;
      const half = 0.5 * dt;
      q.set(
        qx + half * (wx * qw + wy * qz - wz * qy),
        qy + half * (wy * qw + wz * qx - wx * qz),
        qz + half * (wz * qw + wx * qy - wy * qx),
        qw + half * (-wx * qx - wy * qy - wz * qz),
      );
      q.normalize();
    }

    // ============ статусы подвески ============
    this.suspF.t = fS.t; this.suspF.compression = clamp(fS.compression, 0, MAX_TRAVEL_F);
    this.suspF.force = fS.force; this.suspF.contact = frontContact; this.suspF.wheelCenter.copy(fS.wheelCenter);
    this.suspR.t = rS.t; this.suspR.compression = clamp(rS.compression, 0, MAX_TRAVEL_R);
    this.suspR.force = rS.force; this.suspR.contact = rearContact; this.suspR.wheelCenter.copy(rS.wheelCenter);

    if (frontContact && !this._wasFrontContact && this.vel.y < -3.4) this.impactFlash = 0.5;
    if (rearContact && !this._wasRearContact && this.vel.y < -3.4) this.impactFlash = 0.5;
    this._wasFrontContact = frontContact; this._wasRearContact = rearContact;

    this.frontAirTime = frontContact ? 0 : this.frontAirTime + dt;
    this.wheelieActive = !frontContact && pitch > 0.16 && !this.crashed;

    // ============ падения (относительно уклона трассы) ============
    const impactVy = this.vel.y;
    const hAhead = groundH(this.pos.x + fwd.x * 1.15, this.pos.z + fwd.z * 1.15);
    const hBehind = groundH(this.pos.x - fwd.x * 1.15, this.pos.z - fwd.z * 1.15);
    const slopePitch = Math.atan2(hBehind - hAhead, 2.3);
    const relPitch = pitch - slopePitch;
    if (!this.crashed) {
      if (relPitch > LOOP_OUT_PITCH) this._crash('loopout');
      else if (relPitch < -0.58) this._crash('endo');
      else if (Math.abs(roll) > 1.22 && (frontContact || rearContact)) this._crash('washout');
      else if (Math.abs(roll) > 1.5) this._crash('washout');
      else if ((frontContact || rearContact) && impactVy < -13.5) this._crash('hard');
    } else {
      this.crashTimer += dt;
    }
  }

  _crash(type) {
    this.crashed = true;
    this.crashType = type;
    this.crashTimer = 0;
    this.clutchRamp = 0;
  }

  comWorld(out = new THREE.Vector3()) {
    const s = this.spec;
    const leanZ = this.lean * 0.30, leanY = this.lean * 0.025;
    return out.set(0, s.comDesign.y + leanY, s.comDesign.z + leanZ)
      .applyQuaternion(this.quat).add(this.pos);
  }

  frontWheelHeight() {
    const wc = this.suspF.wheelCenter;
    return wc.y - this.spec.frontWheelR - this.ground.h(wc.x, wc.z);
  }
}
