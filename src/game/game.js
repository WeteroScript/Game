// ============================================================================
//  STUNT MOTO — главный класс игры: сцена, цикл, камера, скоринг, состояния
// ============================================================================

import * as THREE from 'three';
import { buildTerrainMesh, buildProps } from './terrain.js';
import { buildMotocross } from './bikeFactory.js';
import { BikePhysics, BIKE_SPECS, DEG } from './physics.js';
import { terrainGround, TRACK } from './terrainMath.js';
import { Input } from './input.js';
import { GameAudio } from './audio.js';
import { HUD } from './hud.js';

const CRASH_TEXTS = {
  loopout: { title: 'LOOP OUT!', sub: 'Газ был сильнее тебя — байк перекинуло назад' },
  endo: { title: 'ЭНДО!', sub: 'Переднее колесо воткнулось первым' },
  washout: { title: 'СНОС!', sub: 'Боковое скольжение — байк ушёл из-под тебя' },
  hard: { title: 'ЖЁСТКАЯ ПОСАДКА!', sub: 'Подвеска не приняла приземление' },
};
const CRASH_PENALTY = 250;

function makeSkyTexture() {
  const c = document.createElement('canvas');
  c.width = 32; c.height = 512;
  const ctx = c.getContext('2d');
  const g = ctx.createLinearGradient(0, 0, 0, 512);
  g.addColorStop(0.0, '#2c5a8a');
  g.addColorStop(0.42, '#5f8fb5');
  g.addColorStop(0.62, '#a8c3d4');
  g.addColorStop(0.74, '#dfe0cd');
  g.addColorStop(0.80, '#f2e3bd');
  g.addColorStop(0.88, '#cfd4c0');
  g.addColorStop(1.0, '#8a9a86');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, 32, 512);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

export class Game {
  constructor(canvas) {
    this.canvas = canvas;
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.75));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.05;

    this.scene = new THREE.Scene();
    this.scene.background = makeSkyTexture();
    this.scene.fog = new THREE.Fog(0xbccbb8, 80, 275);

    this.camera = new THREE.PerspectiveCamera(62, 1, 0.1, 600);
    this.camera.position.set(6, 2.2, 130);

    // ---------- свет ----------
    const hemi = new THREE.HemisphereLight(0xdfeaf4, 0x3d4a35, 0.95);
    this.scene.add(hemi);
    const sun = new THREE.DirectionalLight(0xfff2dc, 1.85);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    sun.shadow.camera.near = 2;
    sun.shadow.camera.far = 80;
    sun.shadow.camera.left = -26; sun.shadow.camera.right = 26;
    sun.shadow.camera.top = 26; sun.shadow.camera.bottom = -26;
    sun.shadow.bias = -0.00042;
    sun.shadow.normalBias = 0.02;
    this.sun = sun;
    this.scene.add(sun);
    this.scene.add(sun.target);

    // ---------- мир ----------
    this.scene.add(buildTerrainMesh());
    buildProps(this.scene);

    // ---------- модули ----------
    this.input = new Input();
    this.audio = new GameAudio();
    this.hud = new HUD();

    // ---------- состояние ----------
    this.state = 'menu';          // menu | playing | crashed
    this.bikeId = 'yz450f';
    this.bike = null;
    this.physics = null;
    this.score = 0;
    this.combo = 1;
    this.bestWheelie = 0;
    this.wheelieDist = 0;
    this.wasWheelie = false;
    this.crashOverlayShown = false;
    this.crashPenaltyApplied = false;
    this.elapsed = 0;
    this.keysHintTimer = 0;
    try {
      this.highscore = Number(localStorage.getItem('stuntmoto_highscore') || 0);
    } catch {
      this.highscore = 0;
    }

    this._camPos = new THREE.Vector3(6, 2.2, 130);
    this._camTarget = new THREE.Vector3();
    this._shake = 0;
    this._fov = 62;
    this._wheelSpinF = 0;
    this._wheelSpinR = 0;
    this._steerVis = 0;

    this.spawnBike(this.bikeId);
    this.state = 'menu';          // spawnBike → resetToStart ставит 'playing'; меню главнее

    this.clock = new THREE.Clock();
    window.addEventListener('resize', () => this.resize());
    this.resize();
  }

  // ================= спавн / выбор байка =================
  spawnBike(bikeId) {
    if (this.bike) {
      this.scene.remove(this.bike);
      this.bike.traverse((o) => {
        o.geometry?.dispose?.();
        const mats = Array.isArray(o.material) ? o.material : [o.material];
        for (const m of mats) {
          if (!m) continue;
          for (const key of Object.keys(m)) { const v = m[key]; if (v && v.isTexture) v.dispose?.(); }
          m.dispose?.();
        }
      });
    }
    this.bikeId = bikeId;
    this.bike = buildMotocross(bikeId);
    this.scene.add(this.bike);
    this.physics = new BikePhysics(BIKE_SPECS[bikeId], terrainGround);
    this.resetToStart();
  }

  resetToStart() {
    const spawn = TRACK.start;
    this.physics.reset(new THREE.Vector3(spawn.x, 0, spawn.z), spawn.yaw);
    this._syncBikeMeshes(0);
    this.state = 'playing';
    this.wheelieDist = 0;
    this.wasWheelie = false;
    this.crashOverlayShown = false;
    this.crashPenaltyApplied = false;
    this.hud.hideCrash();
    this.hud.setLoopoutWarning(false);
  }

  startFromMenu() {
    this.audio.unlock();
    this.hud.show();
    this.resetToStart();
    this.keysHintTimer = 0;
  }

  backToMenu() {
    this.resetToStart();       // байк обратно на старт для витрины
    this.state = 'menu';
    this.hud.hide();
    this.hud.hideCrash();
  }

  // ================= главный цикл =================
  tick() {
    const dt = Math.min(this.clock.getDelta(), 0.05);
    this.elapsed += dt;

    if (this.state === 'menu') {
      this._updateMenuOrbit(dt);
      this._spinWheelsIdle(dt);
    } else {
      this._updatePlaying(dt);
    }

    this._updateSun();
    this.renderer.render(this.scene, this.camera);
  }

  _updateMenuOrbit(dt) {
    // медленная орбита вокруг байка на стартовой площадке
    const spawn = TRACK.start;
    const t = this.elapsed * 0.32;
    const r = 4.1;
    const cx = spawn.x + Math.cos(t) * r;
    const cz = spawn.z + Math.sin(t) * r;
    const h = 1.35 + Math.sin(this.elapsed * 0.21) * 0.22;
    this._camPos.set(cx, this.physics.pos.y + h, cz);
    this.camera.position.lerp(this._camPos, 0.055);
    this._camTarget.set(spawn.x, this.physics.pos.y + 0.62, spawn.z);
    this.camera.up.set(0, 1, 0);
    this.camera.lookAt(this._camTarget);
    this._setFov(56);
    // байк чуть «дышит» (стоит на боковой подножке — покачивание не нужно)
  }

  _spinWheelsIdle(dt) {
    // в меню колёса неподвижны — ничего не делаем
  }

  _updatePlaying(dt) {
    const phys = this.physics;
    const input = this.input.sample();

    phys.update(input, dt);

    // ---------- скоринг ----------
    const pitchDeg = phys.pitch * DEG;
    if (phys.wheelieActive) {
      const v = phys.speed;
      this.wheelieDist += v * dt;
      this.score += v * dt * 2.1 * this.combo;
    } else if (this.wasWheelie) {
      const d = this.wheelieDist;
      if (d >= 12) {
        this.combo = Math.min(5, this.combo + 1);
        const bonus = 120 * this.combo;
        this.score += bonus;
        this.hud.toast(`+${bonus} · УИЛИ ${d.toFixed(0)} м`, 'gold');
        this.audio.comboPing(this.combo);
      } else if (d >= 3.5) {
        const bonus = Math.round(40 * d);
        this.score += bonus;
        this.hud.toast(`+${bonus}`, 'good');
      }
      this.bestWheelie = Math.max(this.bestWheelie, d);
      this.hud.setBestWheelie(this.bestWheelie);
      this.wheelieDist = 0;
    }
    this.wasWheelie = phys.wheelieActive;

    // ---------- падение ----------
    if (phys.crashed && this.state === 'playing') {
      this.state = 'crashed';
      if (!this.crashPenaltyApplied) {
        this.crashPenaltyApplied = true;
        this.score = Math.max(0, this.score - CRASH_PENALTY);
        this.combo = 1;
        this.audio.crash();
        this._shake = Math.max(this._shake, 0.85);
      }
    }
    if (this.state === 'crashed') {
      if (phys.crashTimer > 0.85 && !this.crashOverlayShown) {
        this.crashOverlayShown = true;
        const t = CRASH_TEXTS[phys.crashType] || CRASH_TEXTS.washout;
        this.hud.showCrash(t.title, t.sub, `−${CRASH_PENALTY} · комбо потеряно`);
        this.audio.badBuzz();
      }
    }

    // рекорд (localStorage может быть недоступен в sandbox-iframe)
    if (this.score > this.highscore) {
      this.highscore = this.score;
      try { localStorage.setItem('stuntmoto_highscore', String(Math.floor(this.highscore))); } catch { /* noop */ }
      this.hud.setHighscore(this.highscore);
    }

    // ---------- HUD ----------
    this.hud.setSpeed(phys.speed * 3.6);
    this.hud.setGear(phys.gear);
    this.hud.setRpm(phys.rpm01);
    this.hud.setScore(this.score);
    this.hud.setCombo(this.combo);
    this.hud.setGauge(pitchDeg, !phys.suspF.contact && !phys.crashed);
    this.hud.setLoopoutWarning(pitchDeg > 55 && !phys.crashed);

    // подсказка при входе в уили на малом угле
    if (phys.wheelieActive && pitchDeg < 22 && !phys.crashed) {
      this.hud.showHint('<span class="hint-key">W</span> добавляет угол — <span class="hint-key">отпусти</span>, чтобы опустить колесо');
    } else {
      this.hud.hideHint();
    }

    // затемнение подсказки клавиш
    this.keysHintTimer += dt;
    if (this.keysHintTimer > 10) this.hud.fadeKeysHint();

    // ---------- звук ----------
    this.audio.updateEngine({
      rpm01: phys.rpm01,
      throttle: phys.throttle,
      speed01: Math.min(phys.speed / 32, 1),
      wheelie: phys.wheelieActive,
      crashed: phys.crashed,
    });
    if (phys.impactFlash > 0.44) { this.audio.thump(0.7); phys.impactFlash = 0.2; }
    if (phys.impactFlash > 0) this._shake = Math.max(this._shake, phys.impactFlash * 0.28);

    // ---------- визуал байка ----------
    this._syncBikeMeshes(dt);

    // ---------- камера ----------
    this._updateChaseCamera(dt, input);
  }

  // ================= синхронизация меша с физикой =================
  _syncBikeMeshes(dt) {
    const phys = this.physics;
    const bike = this.bike;
    if (!bike || !phys) return;

    bike.position.copy(phys.pos);
    bike.quaternion.copy(phys.quat);

    const ud = bike.userData;

    // сжатие вилки вдоль её оси (локальные оси assembly совпадают с осями байка)
    const forkUp = new THREE.Vector3(0, Math.cos(ud.forkRake), Math.sin(ud.forkRake));
    ud.forkLower.position.copy(forkUp).multiplyScalar(phys.suspF.compression);

    // качание маятника (axle поднимается при сжатии)
    ud.swingarm.rotation.x = -(phys.suspR.compression / ud.swingarmLength) * 0.92;

    // руление вокруг оси вилки
    this._steerVis += (phys.steer * 0.38 - this._steerVis) * Math.min(1, dt * 9 + 0.2);
    ud.frontAssembly.quaternion.setFromAxisAngle(forkUp, this._steerVis);

    // вращение колёс
    if (dt > 0) {
      const wF = phys.speed / 0.355;
      const spinBoost = phys.wheelieActive ? phys.throttle * 5.5 : 0;
      const wR = phys.speed / 0.345 + spinBoost;
      this._wheelSpinF -= wF * dt;
      this._wheelSpinR -= wR * dt;
      ud.frontSpin.rotation.x = this._wheelSpinF;
      ud.rearSpin.rotation.x = this._wheelSpinR;
    }

    // лёгкое визуальное проседание райдера-невидимки не требуется — байк один
  }

  // ================= камера погони =================
  _updateChaseCamera(dt, input) {
    const phys = this.physics;
    const fwd = new THREE.Vector3(0, 0, -1).applyQuaternion(phys.quat);
    const vel = phys.vel;

    // желаемая позиция: сзади-сверху относительно КУРСА (yaw), не полного крена
    const yawQ = new THREE.Quaternion().setFromEuler(new THREE.Euler(0, phys.yaw, 0, 'YXZ'));
    const back = new THREE.Vector3(0, 0, 1).applyQuaternion(yawQ);
    const speed = phys.speed;
    const dist = 4.35 + speed * 0.028;
    const height = 2.18 + speed * 0.008 - Math.sin(Math.max(phys.pitch, 0)) * 0.75;

    const desired = phys.pos.clone()
      .addScaledVector(back, dist)
      .add(new THREE.Vector3(0, height, 0));

    if (this.state === 'crashed') {
      desired.y += 1.6;
      desired.addScaledVector(back, 1.2);
    }

    // сглаживание (критически демпфированное приближение)
    const k = this.state === 'crashed' ? 2.1 : 4.6;
    this._camPos.lerp(desired, 1 - Math.exp(-k * dt));

    // тряска (приземления / падение)
    this._shake = Math.max(0, this._shake - dt * 1.35);
    const shakeAmp = this._shake * this._shake * 0.30;
    const shakeOffset = shakeAmp > 0.001
      ? new THREE.Vector3((Math.sin(this.elapsed * 71) + Math.sin(this.elapsed * 39)) * shakeAmp,
                          (Math.sin(this.elapsed * 83 + 1.7)) * shakeAmp,
                          (Math.sin(this.elapsed * 47 + 0.6)) * shakeAmp)
      : new THREE.Vector3();

    this.camera.position.copy(this._camPos).add(shakeOffset);

    // цель взгляда — чуть впереди точки над байком; при уили — выше
    const target = phys.pos.clone()
      .add(new THREE.Vector3(0, 0.66 + Math.sin(Math.max(phys.pitch, 0)) * 1.15, 0))
      .addScaledVector(fwd, 1.35)
      .addScaledVector(vel, 0.06);
    this._camTarget.lerp(target, 1 - Math.exp(-6.2 * dt));

    // НАКЛОН КАМЕРЫ с креном байка (спека: визуальный эффект наклона камеры)
    const bikeUp = new THREE.Vector3(0, 1, 0).applyQuaternion(phys.quat);
    const up = new THREE.Vector3(0, 1, 0).lerp(bikeUp, 0.34).normalize();
    this.camera.up.copy(up);
    this.camera.lookAt(this._camTarget);

    // FOV: шире с скоростью и чуть шире в уили
    const speed01 = Math.min(speed / 31, 1);
    const wheelieKick = phys.wheelieActive ? 2.5 : 0;
    this._setFov(62 + speed01 * 11 + wheelieKick);
  }

  _setFov(fov) {
    if (Math.abs(fov - this._fov) > 0.05) {
      this._fov = fov;
      this.camera.fov = fov;
      this.camera.updateProjectionMatrix();
    }
  }

  // ================= свет, следующий за байком =================
  _updateSun() {
    const p = this.physics ? this.physics.pos : { x: 0, y: 0, z: 0 };
    this.sun.position.set(p.x + 17, p.y + 24, p.z + 11);
    this.sun.target.position.set(p.x, p.y, p.z);
    this.sun.target.updateMatrixWorld();
  }

  resize() {
    const w = window.innerWidth, h = window.innerHeight;
    this.renderer.setSize(w, h);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
  }

  // ================= публичные действия =================
  respawn() {
    if (this.state === 'menu') return;
    this.resetToStart();
  }

  toggleMute() {
    this.audio.setMuted(!this.audio.muted);
    return this.audio.muted;
  }
}
