// ============================================================================
//  STUNT MOTO — процедурные game-ready модели Yamaha YZ450F / YZ300
//  Никаких внешних ассетов: вся геометрия генерируется кодом, декали — canvas.
//  Иерархия частей (готова к риггингу подвески и вращению колёс):
//    bike
//    ├─ chassis          (рама, двигатель, пластик, выхлоп — статика)
//    ├─ swingarm         ( pivot: ось маятника → )
//    │   └─ rearWheel    (pivot-ось колеса → спин вращения: rearWheelSpin)
//    └─ frontAssembly    ( pivot: рулевая колонка, ось — вдоль вилки )
//        └─ forkLower    (сжатие вилки вдоль её оси)
//            └─ frontWheel (frontWheelSpin)
//  Масштаб 1 unit = 1 м, вперёд = −Z, земля y=0.
// ============================================================================

import * as THREE from 'three';

// ------------------------------------------------------------------ утилиты
const V3 = (x, y, z) => new THREE.Vector3(x, y, z);

function srgb(tex) { tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 4; return tex; }

// ---------- canvas-текстуры ----------
function makeCanvas(w, h, draw) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  return srgb(new THREE.CanvasTexture(c));
}

// Tuning-fork логотип Yamaha (стилизованный)
function drawTuningForks(ctx, cx, cy, scale, color) {
  if (typeof ctx.roundRect !== 'function') {
    ctx.roundRect = function (x, y, w, h, r) {
      const rr = Math.min(r, w / 2, h / 2);
      this.moveTo(x + rr, y);
      this.arcTo(x + w, y, x + w, y + h, rr);
      this.arcTo(x + w, y + h, x, y + h, rr);
      this.arcTo(x, y + h, x, y, rr);
      this.arcTo(x, y, x + w, y, rr);
      this.closePath();
    };
  }
  ctx.save();
  ctx.translate(cx, cy);
  ctx.scale(scale, scale);
  ctx.strokeStyle = color;
  ctx.fillStyle = color;
  ctx.lineWidth = 7;
  ctx.beginPath(); ctx.arc(0, 0, 44, 0, Math.PI * 2); ctx.stroke();
  // вилка: стержень + две прорези
  const prong = (dx) => {
    ctx.beginPath();
    ctx.roundRect(dx - 7, -8, 14, 40, 6);
    ctx.fill();
  };
  ctx.beginPath(); ctx.roundRect(-9, -34, 18, 30, 4); ctx.fill();
  prong(-15); prong(15);
  ctx.restore();
}

// номерная табличка (боковая/передняя)
function makePlateTexture(mainText, subText, accent = '#1641a8') {
  return makeCanvas(512, 512, (ctx, w, h) => {
    // белый фон с лёгкими потёртостями
    ctx.fillStyle = '#f4f5f7'; ctx.fillRect(0, 0, w, h);
    ctx.globalAlpha = 0.08;
    for (let i = 0; i < 260; i++) {
      ctx.fillStyle = Math.random() < 0.5 ? '#333' : '#888';
      ctx.fillRect(Math.random() * w, Math.random() * h, 2 + Math.random() * 8, 1 + Math.random() * 3);
    }
    ctx.globalAlpha = 1;
    ctx.strokeStyle = '#101318'; ctx.lineWidth = 18;
    ctx.strokeRect(14, 14, w - 28, h - 28);
    // акцентная полоса внизу
    ctx.fillStyle = accent; ctx.fillRect(14, h - 74, w - 28, 60);
    ctx.fillStyle = '#fff';
    ctx.font = '900 34px "Avenir Next", "Segoe UI", sans-serif';
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText(subText, w / 2, h - 44);
    // главный текст
    ctx.fillStyle = '#101318';
    ctx.font = '900 216px "Avenir Next", "Segoe UI", sans-serif';
    ctx.fillText(mainText, w / 2, h / 2 - 26);
  });
}

// обод-Decal: крупная надпись YAMAHA поперёк
function makeShroudTexture(modelText) {
  return makeCanvas(1024, 256, (ctx, w, h) => {
    const grad = ctx.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, '#1b46c0'); grad.addColorStop(0.55, '#1641a8'); grad.addColorStop(1, '#0e2c78');
    ctx.fillStyle = grad; ctx.fillRect(0, 0, w, h);
    // потёртости
    ctx.globalAlpha = 0.10;
    for (let i = 0; i < 200; i++) {
      ctx.fillStyle = '#dfe6ef';
      ctx.fillRect(Math.random() * w, Math.random() * h, 3 + Math.random() * 14, 1 + Math.random() * 3);
    }
    ctx.globalAlpha = 1;
    drawTuningForks(ctx, 116, 128, 1.05, '#f4f5f7');
    ctx.fillStyle = '#f4f5f7';
    ctx.font = 'italic 900 106px "Avenir Next", "Segoe UI", sans-serif';
    ctx.textAlign = 'left'; ctx.textBaseline = 'middle';
    ctx.fillText('YAMAHA', 220, 106);
    ctx.font = '800 44px "Avenir Next", "Segoe UI", sans-serif';
    ctx.fillStyle = '#ffd23f';
    ctx.fillText(modelText, 224, 196);
  });
}

// тормозной диск с перфорацией
function makeDiscTexture() {
  return makeCanvas(256, 256, (ctx, w, h) => {
    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = '#b9bec6';
    ctx.beginPath(); ctx.arc(128, 128, 124, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#878d96';
    ctx.beginPath(); ctx.arc(128, 128, 52, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#c9ced6';
    ctx.beginPath(); ctx.arc(128, 128, 40, 0, Math.PI * 2); ctx.fill();
    // перфорация
    ctx.fillStyle = '#2b2e34';
    for (const rr of [66, 84, 102]) {
      const n = Math.round(rr * 0.55);
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2 + rr;
        ctx.beginPath(); ctx.arc(128 + Math.cos(a) * rr, 128 + Math.sin(a) * rr, 5.5, 0, Math.PI * 2); ctx.fill();
      }
    }
    // болты центра
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * Math.PI * 2;
      ctx.beginPath(); ctx.arc(128 + Math.cos(a) * 34, 128 + Math.sin(a) * 34, 5, 0, Math.PI * 2); ctx.fill();
    }
  });
}

// текстура седла (grip-ромбики)
function makeSeatTexture() {
  const tex = makeCanvas(256, 256, (ctx, w, h) => {
    ctx.fillStyle = '#141518'; ctx.fillRect(0, 0, w, h);
    ctx.strokeStyle = '#26282d'; ctx.lineWidth = 6;
    const s = 34;
    for (let y = -1; y < h / s + 1; y++) {
      for (let x = -1; x < w / s + 1; x++) {
        const ox = (y % 2) * (s / 2);
        ctx.beginPath();
        ctx.moveTo(x * s + ox + s / 2, y * s);
        ctx.lineTo(x * s + ox + s, y * s + s / 2);
        ctx.lineTo(x * s + ox + s / 2, y * s + s);
        ctx.lineTo(x * s + ox, y * s + s / 2);
        ctx.closePath(); ctx.stroke();
      }
    }
  });
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(3, 6);
  return tex;
}

// радиатор с решёткой
function makeRadiatorTexture() {
  return makeCanvas(128, 128, (ctx, w, h) => {
    ctx.fillStyle = '#0c0d10'; ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = '#23262c';
    for (let y = 6; y < h; y += 9) ctx.fillRect(0, y, w, 4);
    ctx.fillStyle = '#31353d';
    for (let x = 4; x < w; x += 12) ctx.fillRect(x, 0, 3, h);
  });
}

// ---------- материалы ----------
function makeMaterials(variant) {
  const plateTex = makePlateTexture(variant === 'yz300' ? '300' : '450', variant === 'yz300' ? 'YZ300' : 'YZ450F');
  const shroudTex = makeShroudTexture(variant === 'yz300' ? 'YZ300 2T' : 'YZ450F 4T');
  const discTex = makeDiscTexture();
  const seatTex = makeSeatTexture();
  const radTex = makeRadiatorTexture();
  return {
    plasticBlue: new THREE.MeshStandardMaterial({ color: '#1641a8', metalness: 0.12, roughness: 0.32, envMapIntensity: 1.1 }),
    plasticBlueDark: new THREE.MeshStandardMaterial({ color: '#0e2c78', metalness: 0.12, roughness: 0.38 }),
    plasticWhite: new THREE.MeshStandardMaterial({ color: '#f2f3f5', metalness: 0.05, roughness: 0.30 }),
    plasticBlack: new THREE.MeshStandardMaterial({ color: '#17181d', metalness: 0.10, roughness: 0.55 }),
    aluminum: new THREE.MeshStandardMaterial({ color: '#b9bec6', metalness: 0.95, roughness: 0.28 }),
    aluminumDark: new THREE.MeshStandardMaterial({ color: '#6b7078', metalness: 0.9, roughness: 0.38 }),
    steel: new THREE.MeshStandardMaterial({ color: '#d7dade', metalness: 1.0, roughness: 0.18 }),
    gold: new THREE.MeshStandardMaterial({ color: '#d8a83e', metalness: 1.0, roughness: 0.30 }),
    engineMetal: new THREE.MeshStandardMaterial({ color: '#8a8f98', metalness: 0.9, roughness: 0.42 }),
    engineDark: new THREE.MeshStandardMaterial({ color: '#3a3d44', metalness: 0.75, roughness: 0.52 }),
    rubber: new THREE.MeshStandardMaterial({ color: '#161616', metalness: 0.0, roughness: 0.95 }),
    chainMat: new THREE.MeshStandardMaterial({ color: '#555a63', metalness: 0.9, roughness: 0.35 }),
    rimBlack: new THREE.MeshStandardMaterial({ color: '#101114', metalness: 0.55, roughness: 0.42 }),
    spokeSilver: new THREE.MeshStandardMaterial({ color: '#cfd4da', metalness: 1.0, roughness: 0.22 }),
    springMat: new THREE.MeshStandardMaterial({ color: variant === 'yz300' ? '#d84f3a' : '#e8c832', metalness: 0.35, roughness: 0.4 }),
    plateMat: new THREE.MeshStandardMaterial({ map: plateTex, metalness: 0.05, roughness: 0.42 }),
    shroudMat: new THREE.MeshStandardMaterial({ map: shroudTex, metalness: 0.1, roughness: 0.34 }),
    discMat: new THREE.MeshStandardMaterial({ map: discTex, transparent: true, metalness: 0.85, roughness: 0.35, side: THREE.DoubleSide }),
    seatMat: new THREE.MeshStandardMaterial({ map: seatTex, metalness: 0.0, roughness: 0.92 }),
    radiatorMat: new THREE.MeshStandardMaterial({ map: radTex, metalness: 0.6, roughness: 0.6 }),
  };
}

// ---------- экструзия бокового профиля (z-y) на толщину вдоль X ----------
function extrudeProfile(shapePts, depth, bevel = 0.012) {
  const shape = new THREE.Shape();
  shapePts.forEach(([z, y], i) => (i === 0 ? shape.moveTo(z, y) : shape.lineTo(z, y)));
  shape.closePath();
  const geo = new THREE.ExtrudeGeometry(shape, {
    depth, bevelEnabled: true, bevelThickness: bevel, bevelSize: bevel, bevelSegments: 2, curveSegments: 6,
  });
  geo.translate(0, 0, -depth / 2);
  geo.rotateY(-Math.PI / 2); // толщина → вдоль X, длина профиля остаётся вдоль Z
  return geo;
}

const mesh = (geo, mat, x = 0, y = 0, z = 0, shadow = true) => {
  const m = new THREE.Mesh(geo, mat);
  m.position.set(x, y, z);
  m.castShadow = shadow;
  return m;
};

// ============================================================ КОЛЕСО
function buildWheel(R, tireTube, mats, discSide = -1, rimColor = 'rimBlack') {
  const group = new THREE.Group();
  const spin = new THREE.Group();
  group.add(spin);

  // покрышка (тор с утолщениями-шашками)
  const tire = mesh(new THREE.TorusGeometry(R - tireTube, tireTube, 10, 26), mats.rubber);
  tire.rotation.y = Math.PI / 2; // ось вдоль X
  spin.add(tire);

  // шашки протектора (instanced)
  const knob = new THREE.BoxGeometry(0.030, 0.024, 0.026);
  const knobCount = Math.floor((R * 2 * Math.PI) / 0.055);
  const knobs = new THREE.InstancedMesh(knob, mats.rubber, knobCount * 3);
  const dummy = new THREE.Object3D();
  let ki = 0;
  for (let row = -1; row <= 1; row++) {
    const rowOffset = row * tireTube * 0.72;
    for (let i = 0; i < knobCount; i++) {
      const a = (i / knobCount) * Math.PI * 2 + (row === 0 ? 0 : Math.PI / knobCount);
      const rr = R - tireTube + tireTube * (row === 0 ? 1.02 : 0.78);
      dummy.position.set(rowOffset, Math.cos(a) * rr, Math.sin(a) * rr);
      dummy.rotation.set(0, 0, a + (row === 0 ? 0 : 0.35 * row));
      dummy.updateMatrix();
      knobs.setMatrixAt(ki++, dummy.matrix);
    }
  }
  knobs.count = ki;
  knobs.castShadow = true;
  spin.add(knobs);

  // обод (двойной как у маунтин-байков)
  const rim = mesh(new THREE.CylinderGeometry(R - tireTube - 0.018, R - tireTube - 0.018, 0.052, 20, 1, true), mats[rimColor]);
  rim.rotation.z = Math.PI / 2;
  spin.add(rim);
  const rimLipF = mesh(new THREE.TorusGeometry(R - tireTube - 0.006, 0.011, 6, 20), mats[rimColor]);
  rimLipF.rotation.y = Math.PI / 2; rimLipF.position.x = 0.028; spin.add(rimLipF);
  const rimLipR = rimLipF.clone(); rimLipR.position.x = -0.028; spin.add(rimLipR);

  // ступица
  const hub = mesh(new THREE.CylinderGeometry(0.052, 0.052, 0.085, 12), mats.aluminumDark);
  hub.rotation.z = Math.PI / 2;
  spin.add(hub);

  // спицы — два скрещённых ряда
  const spokeGeo = new THREE.CylinderGeometry(0.0055, 0.0055, R - tireTube - 0.02, 5);
  const spokeLen = R - tireTube - 0.02;
  for (const side of [-1, 1]) {
    for (let i = 0; i < 12; i++) {
      const a = (i / 12) * Math.PI * 2;
      for (const skew of [1, -1]) {
        const sp = mesh(spokeGeo, mats.spokeSilver, 0, 0, 0, false);
        const rimR = R - tireTube - 0.025;
        const midA = a + skew * 0.42;
        sp.position.set(side * 0.022, Math.cos((a + midA) / 2) * rimR * 0.5, Math.sin((a + midA) / 2) * rimR * 0.5);
        // ориентируем от ступицы к ободу
        const from = V3(side * 0.026, Math.cos(a) * 0.05, Math.sin(a) * 0.05);
        const to = V3(side * 0.026, Math.cos(midA) * rimR, Math.sin(midA) * rimR);
        sp.position.copy(from.clone().add(to).multiplyScalar(0.5));
        const dir = to.clone().sub(from);
        sp.scale.y = dir.length() / spokeLen;
        sp.quaternion.setFromUnitVectors(V3(0, 1, 0), dir.normalize());
        spin.add(sp);
      }
    }
  }

  // тормозной диск
  const disc = new THREE.Mesh(new THREE.CircleGeometry(0.088, 20), mats.discMat);
  disc.position.x = discSide * 0.055;
  disc.rotation.y = discSide * -Math.PI / 2;
  spin.add(disc);

  group.userData.spin = spin;
  return group;
}

// ============================================================ МОНОАМОРТИЗАТОР (пружина — helix tube)
function buildShock(mats, springLength = 0.30) {
  const group = new THREE.Group();
  const body = mesh(new THREE.CylinderGeometry(0.024, 0.024, springLength * 0.75, 10), mats.aluminum);
  group.add(body);
  const piston = mesh(new THREE.CylinderGeometry(0.017, 0.017, springLength * 0.6, 8), mats.engineDark);
  piston.position.y = -springLength * 0.42;
  group.add(piston);
  // пружина
  const coils = 6.5, coilR = 0.038, tubeR = 0.0085;
  const pts = [];
  const steps = 130;
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const ang = t * coils * Math.PI * 2;
    pts.push(V3(Math.cos(ang) * coilR, (t - 0.5) * springLength, Math.sin(ang) * coilR));
  }
  const spring = new THREE.Mesh(
    new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 220, tubeR, 6, false),
    mats.springMat
  );
  spring.castShadow = true;
  group.add(spring);
  return group;
}

// ============================================================ ГЛАВНАЯ ФАБРИКА
export function buildMotocross(variant = 'yz450f') {
  const is450 = variant === 'yz450f';
  const mats = makeMaterials(variant);

  const bike = new THREE.Group();
  bike.name = variant;

  const chassis = new THREE.Group();
  chassis.name = 'chassis';
  bike.add(chassis);

  // ============ РАМА (алюминиевый perimeter twin-spar) ============
  const sparGeo = extrudeProfile([
    [-0.46, 0.86], [-0.30, 0.88], [0.06, 0.78], [0.30, 0.60], [0.34, 0.44], [0.18, 0.36], [-0.05, 0.52], [-0.24, 0.68],
  ], 0.045, 0.008);
  for (const side of [-1, 1]) {
    const spar = mesh(sparGeo, mats.aluminum, side * 0.062, 0, 0);
    chassis.add(spar);
  }
  // рулевая колонка / head stock
  const headTube = mesh(new THREE.CylinderGeometry(0.030, 0.034, 0.16, 10), mats.aluminum, 0, 0.825, -0.447);
  headTube.quaternion.setFromUnitVectors(V3(0, 1, 0), V3(0, Math.cos(0.47), Math.sin(0.47)));
  chassis.add(headTube);
  // подрамник (стальной)
  const subframe = mesh(extrudeProfile([[0.05, 0.82], [0.42, 0.86], [0.52, 0.78], [0.28, 0.74], [0.08, 0.72]], 0.028, 0.006), mats.plasticBlack);
  chassis.add(subframe);

  // ============ ДВИГАТЕЛЬ ============
  const engine = new THREE.Group();
  engine.name = 'engine';
  // картер
  engine.add(mesh(new THREE.CylinderGeometry(0.085, 0.085, 0.16, 14), mats.engineMetal, 0.02, 0.33, 0.02));
  engine.children[0].rotation.z = Math.PI / 2;
  engine.add(mesh(new THREE.BoxGeometry(0.20, 0.13, 0.24), mats.engineDark, 0, 0.325, 0.0));
  // цилиндр (наклонён вперёд)
  const cylGroup = new THREE.Group();
  cylGroup.position.set(0, 0.44, -0.075);
  cylGroup.rotation.x = is450 ? 0.30 : 0.16;
  const cyl = mesh(new THREE.CylinderGeometry(0.062, 0.068, 0.19, 12), mats.engineMetal);
  cyl.position.y = 0.09;
  cylGroup.add(cyl);
  // рёбра охлаждения
  for (let i = 0; i < 5; i++) {
    const fin = mesh(new THREE.CylinderGeometry(0.072 + (i % 2) * 0.004, 0.072 + (i % 2) * 0.004, 0.008, 12), mats.engineDark, 0, 0.03 + i * 0.034, 0, false);
    cylGroup.add(fin);
  }
  if (is450) {
    // клапанная крышка 4-тактника
    const cover = mesh(new THREE.CylinderGeometry(0.056, 0.062, 0.045, 12), mats.engineDark, 0, 0.20, 0);
    cylGroup.add(cover);
  }
  engine.add(cylGroup);
  // крышка сцепления (справа) / крышка статора (слева)
  const clutchCover = mesh(new THREE.CylinderGeometry(0.058, 0.058, 0.018, 14), mats.engineMetal, 0.105, 0.315, 0.035);
  clutchCover.rotation.z = Math.PI / 2;
  engine.add(clutchCover);
  const stator = mesh(new THREE.CylinderGeometry(0.048, 0.048, 0.018, 14), mats.engineDark, -0.105, 0.315, 0.035);
  stator.rotation.z = Math.PI / 2;
  engine.add(stator);
  // картер мостика / над колесом
  engine.add(mesh(new THREE.BoxGeometry(0.13, 0.09, 0.16), mats.engineMetal, 0, 0.245, 0.02));
  chassis.add(engine);

  // ============ РАДИАТОРЫ ============
  for (const side of [-1, 1]) {
    const rad = mesh(new THREE.BoxGeometry(0.028, 0.145, 0.185), mats.radiatorMat, side * 0.088, 0.60, -0.215, false);
    rad.rotation.x = -0.10;
    chassis.add(rad);
    // расширительный бачок (правая сторона)
    if (side === 1) chassis.add(mesh(new THREE.CapsuleGeometry(0.021, 0.045, 4, 8), mats.plasticWhite, side * 0.088, 0.72, -0.19, false));
  }

  // ============ ВИХЛОП ============
  const exhaust = new THREE.Group();
  exhaust.name = 'exhaust';
  if (is450) {
    // header: загнутая труба от головки вниз и назад
    const headerPts = [
      V3(0, 0.52, -0.155), V3(0.02, 0.40, -0.20), V3(0.075, 0.27, -0.16),
      V3(0.105, 0.225, 0.02), V3(0.115, 0.25, 0.22), V3(0.125, 0.38, 0.42),
    ];
    const header = new THREE.Mesh(
      new THREE.TubeGeometry(new THREE.CatmullRomCurve3(headerPts), 40, 0.035, 10, false),
      mats.steel
    );
    header.castShadow = true;
    exhaust.add(header);
    // глушитель (титан, с теплозащитой)
    const silencer = mesh(new THREE.CylinderGeometry(0.052, 0.062, 0.42, 12), mats.aluminum, 0.125, 0.50, 0.60);
    silencer.rotation.x = Math.PI / 2 - 0.16;
    exhaust.add(silencer);
    const silencerCap = mesh(new THREE.CylinderGeometry(0.030, 0.052, 0.06, 12), mats.engineDark, 0.125, 0.535, 0.805);
    silencerCap.rotation.x = Math.PI / 2 - 0.16;
    exhaust.add(silencerCap);
    const tip = mesh(new THREE.CylinderGeometry(0.017, 0.017, 0.012, 10), new THREE.MeshStandardMaterial({ color: '#08090a' }), 0.125, 0.545, 0.828, false);
    tip.rotation.x = Math.PI / 2 - 0.16;
    exhaust.add(tip);
  } else {
    // ДОВЗВЫШКА (expansion chamber) — ключевой элемент 2-тактника
    const chamberSegs = [
      { r0: 0.032, r1: 0.036, len: 0.16 },
      { r0: 0.036, r1: 0.088, len: 0.15 }, // расширяющийся конус
      { r0: 0.088, r1: 0.088, len: 0.06 }, // «брюхо»
      { r0: 0.088, r1: 0.034, len: 0.24 }, // сужение (belly→stinger)
    ];
    const chamberCurve = [];
    // собираем по прямой, потом гнём группу — так проще
    let y = 0.485, z = -0.135;
    const chamberGroup = new THREE.Group();
    for (const seg of chamberSegs) {
      const segMesh = mesh(new THREE.CylinderGeometry(seg.r1, seg.r0, seg.len, 12), mats.steel);
      segMesh.position.set(0, 0, seg.len / 2);
      const segAnchor = new THREE.Group();
      segAnchor.position.set(0, y, z);
      // небольшой наклон вниз-вперёд→дуга
      segAnchor.rotation.x = -0.35 + (z < 0 ? 0 : 0.1);
      segAnchor.add(segMesh);
      chamberGroup.add(segAnchor);
      z += seg.len * 0.92;
      y -= seg.len * 0.30;
    }
    // направляем трубу вниз-вперёд, затем под двигатель и назад: аппроксимируем двумя кусками
    chamberGroup.position.set(0.02, 0, -0.02);
    chamberGroup.rotation.y = 0.06;
    exhaust.add(chamberGroup);
    // колено к глушению
    const belly = mesh(new THREE.CapsuleGeometry(0.088, 0.16, 6, 12), mats.steel, 0, 0.225, 0.10);
    belly.rotation.z = Math.PI / 2.4;
    exhaust.add(belly);
    const stinger = mesh(new THREE.CylinderGeometry(0.031, 0.034, 0.34, 10), mats.steel, 0.06, 0.235, 0.32);
    stinger.rotation.x = Math.PI / 2 - 0.10;
    exhaust.add(stinger);
    // глушак
    const silencer = mesh(new THREE.CylinderGeometry(0.048, 0.058, 0.34, 12), mats.aluminum, 0.085, 0.375, 0.585);
    silencer.rotation.x = Math.PI / 2 - 0.14;
    exhaust.add(silencer);
    const tip = mesh(new THREE.CylinderGeometry(0.016, 0.016, 0.012, 10), new THREE.MeshStandardMaterial({ color: '#08090a' }), 0.085, 0.40, 0.755, false);
    tip.rotation.x = Math.PI / 2 - 0.14;
    exhaust.add(tip);
  }
  chassis.add(exhaust);

  // ============ АБСОРБЕР (по центру рамы, наклонён) ============
  const shock = buildShock(mats, 0.30);
  shock.position.set(0, 0.475, 0.155);
  shock.quaternion.setFromUnitVectors(V3(0, 1, 0), V3(0, 1.05, -0.52).normalize());
  chassis.add(shock);

  // балка маятника (pivot у рамы)
  const swingarm = new THREE.Group();
  swingarm.name = 'swingarm';
  swingarm.position.set(0, 0.345, 0.295);
  chassis.add(swingarm);
  const armGeo = extrudeProfile([[0, 0.035], [0.44, 0.012], [0.47, -0.012], [0.03, -0.035]], 0.028, 0.006);
  for (const side of [-1, 1]) {
    const arm = mesh(armGeo, mats.aluminum, side * 0.052, 0, 0);
    swingarm.add(arm);
  }
  const pivot = mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.13, 10), mats.aluminumDark, 0, 0, 0);
  pivot.rotation.z = Math.PI / 2;
  swingarm.add(pivot);

  // ============ ЗАДНЕЕ КОЛЕСО ============
  const rearWheel = buildWheel(0.345, 0.098, mats, -1);
  rearWheel.name = 'rearWheel';
  rearWheel.position.set(0, 0.345 - 0.345, 0.7425 - 0.295); // относительно пивота маятника (в проектной стойке)
  rearWheel.position.set(0, 0, 0.7425 - 0.295);
  swingarm.add(rearWheel);

  // ============ ТОПЛИВНЫЙ БАК + ОБТЕКАТЕЛИ ============
  const tank = mesh(extrudeProfile([
    [-0.44, 0.845], [-0.28, 0.87], [-0.10, 0.885], [0.13, 0.83], [0.16, 0.735], [-0.02, 0.70], [-0.28, 0.735], [-0.42, 0.785],
  ], 0.175, 0.02), mats.plasticBlue, 0, 0, 0);
  chassis.add(tank);
  // пробка бака
  chassis.add(mesh(new THREE.CylinderGeometry(0.028, 0.028, 0.012, 12), mats.plasticBlack, 0, 0.885, -0.13, false));
  // радиаторные обтекатели (shrouds) с фирменной графикой
  const shroudGeo = extrudeProfile([
    [-0.485, 0.835], [-0.365, 0.845], [-0.225, 0.775], [-0.19, 0.60], [-0.295, 0.565], [-0.43, 0.685],
  ], 0.028, 0.008);
  for (const side of [-1, 1]) {
    chassis.add(mesh(shroudGeo, mats.shroudMat, side * 0.095, 0, 0));
  }

  // ============ СИДЕНЬЕ ============
  const seat = mesh(extrudeProfile([
    [-0.05, 0.845], [0.28, 0.862], [0.485, 0.83], [0.50, 0.795], [0.26, 0.795], [-0.04, 0.795],
  ], 0.125, 0.014), mats.seatMat);
  chassis.add(seat);

  // ============ ЗАДНЕЕ КРЫЛО + БОКОВЫЕ НОМЕРНЫЕ ТАБЛИЧКИ ============
  const rearFender = mesh(extrudeProfile([
    [0.42, 0.845], [0.68, 0.90], [0.92, 0.885], [1.03, 0.83], [0.985, 0.775], [0.66, 0.815], [0.44, 0.80],
  ], 0.075, 0.012), mats.plasticBlue);
  chassis.add(rearFender);
  // боковые таблички (белые вставки)
  const sidePanel = extrudeProfile([
    [0.33, 0.80], [0.72, 0.80], [0.78, 0.655], [0.55, 0.615], [0.33, 0.66],
  ], 0.012, 0.004);
  for (const side of [-1, 1]) {
    chassis.add(mesh(sidePanel, mats.plasticWhite, side * 0.085, 0, 0));
    const decal = new THREE.Mesh(new THREE.PlaneGeometry(0.34, 0.17), mats.plateMat);
    decal.position.set(side * 0.0935, 0.705, 0.55);
    decal.rotation.y = side * Math.PI / 2;
    chassis.add(decal);
  }

  // ============ ЦЕПЬ + ЗВЁЗДЫ ============
  const frontSprocket = mesh(new THREE.CylinderGeometry(0.032, 0.032, 0.012, 10), mats.chainMat, -0.075, 0.315, 0.115);
  frontSprocket.rotation.z = Math.PI / 2;
  chassis.add(frontSprocket);
  // задняя звезда — дочерняя колесу (вращается вместе с ним)
  const rearSprocket = mesh(new THREE.CylinderGeometry(0.075, 0.075, 0.010, 18), mats.chainMat, -0.062, 0, 0);
  rearSprocket.rotation.z = Math.PI / 2;
  rearWheel.userData.spin.add(rearSprocket);
  // ветви цепи
  const chainRun = (z0, y0, z1, y1, sag) => {
    const len = Math.hypot(z1 - z0, y1 - y0);
    const run = mesh(new THREE.BoxGeometry(0.011, 0.008, len), mats.chainMat, -0.069, (y0 + y1) / 2 + sag, (z0 + z1) / 2, false);
    run.rotation.x = -Math.atan2(y1 - y0, z1 - z0);
    return run;
  };
  chassis.add(chainRun(0.115, 0.335, 0.7425, 0.395, 0.012));
  chassis.add(chainRun(0.115, 0.295, 0.7425, 0.30, -0.02));

  // ============ ПОДНОЖКИ / РЫЧАГИ ============
  for (const side of [-1, 1]) {
    const peg = mesh(new THREE.CylinderGeometry(0.011, 0.011, 0.075, 8), mats.engineDark, side * 0.155, 0.275, 0.02);
    peg.rotation.z = Math.PI / 2;
    chassis.add(peg);
  }
  const shiftLever = mesh(new THREE.CylinderGeometry(0.007, 0.007, 0.11, 6), mats.steel, -0.17, 0.335, -0.075, false);
  shiftLever.rotation.x = Math.PI / 2.3;
  chassis.add(shiftLever);
  const brakePedal = mesh(new THREE.BoxGeometry(0.05, 0.012, 0.075), mats.steel, 0.155, 0.315, 0.135, false);
  chassis.add(brakePedal);
  // задний тормозной диск (крепится к колесу)
  const rearDisc = new THREE.Mesh(new THREE.CircleGeometry(0.075, 18), mats.discMat);
  rearDisc.position.set(0.045, 0, 0);
  rearDisc.rotation.y = Math.PI / 2;
  rearWheel.userData.spin.add(rearDisc);

  // ============ ПЕРЕДНЯЯ ВИЛКА (frontAssembly) ============
  // Система координат сборки = оси байка (origin = рулевая колонка, верх).
  // Рак вилки задаётся ПОЛОЖЕНИЕМ частей вдоль оси вилки, а не поворотом родителя —
  // это упрощает анимацию сжатия (скольжение вдоль оси) и руления (поворот вокруг оси вилки).
  const forkRake = 27 / 180 * Math.PI;
  const forkUp = V3(0, Math.cos(forkRake), Math.sin(forkRake));       // ось вилки вверх-назад
  const forkDown = forkUp.clone().negate();
  const axlePos = V3(0, 0.355, -0.7425);
  const forkLen = 0.621;
  const headTop = axlePos.clone().addScaledVector(forkUp, forkLen);   // (0, 0.908, -0.461)
  const qFork = new THREE.Quaternion().setFromUnitVectors(V3(0, 1, 0), forkUp);

  const frontAssembly = new THREE.Group();
  frontAssembly.name = 'frontAssembly';
  frontAssembly.position.copy(headTop);
  bike.add(frontAssembly);

  // --- перья (верхние серебристые) ---
  const tubeAlongFork = (r, len, mat) => {
    const t = mesh(new THREE.CylinderGeometry(r, r, len, 10), mat);
    t.quaternion.copy(qFork);
    return t;
  };
  for (const side of [-1, 1]) {
    const upper = tubeAlongFork(0.0235, 0.30, mats.aluminum);
    upper.position.copy(forkDown.clone().multiplyScalar(0.16)).add(V3(side * 0.048, 0, 0));
    frontAssembly.add(upper);
    const adj = mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.02, 8), mats.engineDark, side * 0.048, 0.022, 0, false);
    frontAssembly.add(adj);
  }
  // траверсы (перпендикулярно вилке)
  const clampTop = mesh(new THREE.BoxGeometry(0.155, 0.026, 0.088), mats.aluminumDark, 0, 0.012, 0);
  clampTop.quaternion.copy(qFork);
  frontAssembly.add(clampTop);
  const clampLow = mesh(new THREE.BoxGeometry(0.145, 0.022, 0.078), mats.aluminumDark, 0, 0, 0);
  clampLow.position.copy(forkDown.clone().multiplyScalar(0.155));
  clampLow.quaternion.copy(qFork);
  frontAssembly.add(clampLow);
  // защитные накладки перьев (белые)
  for (const side of [-1, 1]) {
    const guard = tubeAlongFork(0.027, 0.17, mats.plasticWhite);
    guard.position.copy(forkDown.clone().multiplyScalar(0.28)).add(V3(side * 0.048, 0, 0));
    frontAssembly.add(guard);
  }

  // --- forkLower: скользит вдоль вилки при сжатии ---
  const forkLower = new THREE.Group();
  forkLower.name = 'forkLower';
  frontAssembly.add(forkLower);
  const forkToAxle = axlePos.clone().sub(headTop); // локальный вектор от колонки к оси колеса
  for (const side of [-1, 1]) {
    const lower = tubeAlongFork(0.0195, 0.36, mats.gold);
    lower.position.copy(forkToAxle.clone().multiplyScalar(0.62)).add(V3(side * 0.048, 0, 0));
    forkLower.add(lower);
  }
  // держатель оси
  const axleBlock = mesh(new THREE.BoxGeometry(0.135, 0.05, 0.05), mats.aluminumDark, 0, 0, 0);
  axleBlock.position.copy(forkToAxle);
  axleBlock.quaternion.copy(qFork);
  forkLower.add(axleBlock);
  // передний тормозной суппорт (левая сторона)
  const caliper = mesh(new THREE.BoxGeometry(0.035, 0.075, 0.055), mats.engineDark, -0.075, 0, -0.005, false);
  caliper.position.copy(forkToAxle.clone().multiplyScalar(0.88)).add(V3(-0.075, 0.02, -0.005));
  caliper.quaternion.copy(qFork);
  forkLower.add(caliper);

  // --- переднее колесо ---
  const frontWheel = buildWheel(0.355, 0.093, mats, -1);
  frontWheel.name = 'frontWheel';
  frontWheel.position.copy(forkToAxle);
  forkLower.add(frontWheel);

  // --- руль (Renthal) с кросс-баром ---
  const barGroup = new THREE.Group();
  barGroup.position.set(0, 0.075, 0);
  const barCenter = mesh(new THREE.CylinderGeometry(0.0135, 0.0135, 0.16, 10), mats.aluminum, 0, 0, 0);
  barCenter.rotation.z = Math.PI / 2;
  barGroup.add(barCenter);
  for (const side of [-1, 1]) {
    const bend = mesh(new THREE.CylinderGeometry(0.0135, 0.0135, 0.155, 8), mats.aluminum, side * 0.145, 0.012, 0.012);
    bend.rotation.z = Math.PI / 2;
    bend.rotation.y = side * 0.35;
    barGroup.add(bend);
    // грипсы
    const grip = mesh(new THREE.CylinderGeometry(0.0165, 0.0165, 0.105, 10), mats.rubber, side * 0.235, 0.022, 0.038);
    grip.rotation.z = Math.PI / 2;
    grip.rotation.y = side * 0.35;
    barGroup.add(grip);
    // пульты + мастер-цилиндры
    barGroup.add(mesh(new THREE.BoxGeometry(0.045, 0.024, 0.038), mats.plasticBlack, side * 0.185, 0.035, 0.025, false));
    // рычаги
    const lever = mesh(new THREE.BoxGeometry(0.008, 0.008, 0.105), mats.aluminum, side * 0.235, 0.032, 0.085, false);
    barGroup.add(lever);
    // зеркала не ставим (гонка)
  }
  // кросс-бар + пэд
  const crossBar = mesh(new THREE.CylinderGeometry(0.009, 0.009, 0.235, 8), mats.engineDark, 0, -0.012, -0.012, false);
  crossBar.rotation.z = Math.PI / 2;
  barGroup.add(crossBar);
  const barPad = mesh(new THREE.CylinderGeometry(0.019, 0.019, 0.085, 10), mats.plasticBlack, 0, -0.012, -0.012, false);
  barPad.rotation.z = Math.PI / 2;
  barGroup.add(barPad);
  frontAssembly.add(barGroup);

  // тросы газа/сцепления — тонкие дуги вниз
  const cableMat = new THREE.MeshStandardMaterial({ color: '#0a0a0c', roughness: 0.8 });
  for (const side of [-1, 1]) {
    const cablePts = [V3(side * 0.19, 0.075, 0.02).applyQuaternion(new THREE.Quaternion()), V3(side * 0.13, -0.10, -0.02), V3(side * 0.07, -0.34, -0.09)];
    const cable = new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(cablePts), 12, 0.0042, 5, false), cableMat);
    frontAssembly.add(cable);
  }

  // --- переднее крыло («клюв») — к нижним перьям ---
  // профиль в байк-координатах (z вперёд = −Z), клюв смотрит вперёд
  const frontFender = mesh(extrudeProfile([
    [0.16, 0.615], [0.05, 0.662], [-0.14, 0.685], [-0.33, 0.662], [-0.42, 0.608], [-0.30, 0.60], [-0.10, 0.632], [0.08, 0.585],
  ], 0.052, 0.01), mats.plasticWhite);
  // переводим в локальные координаты forkLower (оси совпадают с осями байка, origin = голова вилки)
  frontFender.position.set(0, 0.615 - headTop.y, -0.72 - headTop.z);
  forkLower.add(frontFender);

  // --- передняя номерная табличка (на верхней траверсе, ракнут назад) ---
  const plateQ = new THREE.Quaternion().setFromUnitVectors(V3(0, 0, 1), V3(0, Math.sin(forkRake), -Math.cos(forkRake)).normalize().negate());
  // нормаль таблички должна смотреть вперёд-вверх вдоль вилки
  const plateNormal = V3(0, Math.sin(forkRake), -Math.cos(forkRake));
  plateQ.setFromUnitVectors(V3(0, 0, 1), plateNormal);
  const plateGroup = new THREE.Group();
  const plateBox = mesh(new THREE.BoxGeometry(0.135, 0.215, 0.014), mats.plasticWhite, 0, 0, 0);
  const plateDecal = new THREE.Mesh(new THREE.PlaneGeometry(0.118, 0.195), mats.plateMat);
  plateDecal.position.z = 0.0095;
  plateGroup.add(plateBox, plateDecal);
  plateGroup.quaternion.copy(plateQ);
  // положение: перед верхней траверсой (в локальных осях frontAssembly)
  plateGroup.position.set(0, -0.02, -0.085);
  frontAssembly.add(plateGroup);

  // ============ сборка / масштаб / ориентация ============
  bike.traverse((o) => { if (o.isMesh) o.castShadow = o.castShadow !== false; });

  // пользовательские данные для игрового кода
  bike.userData = {
    variant,
    wheelbase: 1.485,
    forkRake,
    headTop,        // точка рулевой колонки (world при нулевом повороте шасси)
    forkLower,
    swingarm,
    frontAssembly,
    rearWheel,
    frontWheel,
    rearSpin: rearWheel.userData.spin,
    frontSpin: frontWheel.userData.spin,
    swingarmPivot: V3(0, 0.345, 0.295),
    swingarmLength: 0.443,
  };
  return bike;
}
