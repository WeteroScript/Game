// ============================================================================
//  STUNT MOTO — построение меша трассы, окружения и декораций
// ============================================================================

import * as THREE from 'three';
import { groundHeight as gh, TRACK, JUMPS, WHOOPS, START_PAD } from './terrainMath.js';

// must mirror terrainMath internals for vertex coloring
// (we recompute with the exported helpers below)

const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const smoothstep = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };

function hash2(ix, iz) {
  let h = (ix * 374761393 + iz * 668265263) | 0;
  h = (h ^ (h >> 13)) | 0;
  h = Math.imul(h, 1274126177);
  h = (h ^ (h >> 16)) >>> 0;
  return h / 4294967295;
}
function vnoise(x, z) {
  const ix = Math.floor(x), iz = Math.floor(z);
  const fx = x - ix, fz = z - iz;
  const ux = fx * fx * (3 - 2 * fx), uz = fz * fz * (3 - 2 * fz);
  const a = hash2(ix, iz), b = hash2(ix + 1, iz), c = hash2(ix, iz + 1), d = hash2(ix + 1, iz + 1);
  return a + (b - a) * ux + (c - a) * uz + (a - b - c + d) * ux * uz;
}

// ---------------- canvas-шум для деталки ----------------
function makeNoiseTexture() {
  const s = 256;
  const c = document.createElement('canvas');
  c.width = c.height = s;
  const ctx = c.getContext('2d');
  const img = ctx.createImageData(s, s);
  for (let i = 0; i < s * s; i++) {
    const v = 200 + Math.floor(Math.random() * 55);
    img.data[i * 4] = v; img.data[i * 4 + 1] = v; img.data[i * 4 + 2] = v; img.data[i * 4 + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);
  const tex = new THREE.CanvasTexture(c);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(48, 48);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

// текстура с надписью (стартовый баннер / бигборды)
function makeBannerTexture(text, sub, bg, fg) {
  const c = document.createElement('canvas');
  c.width = 1024; c.height = 256;
  const ctx = c.getContext('2d');
  ctx.fillStyle = bg; ctx.fillRect(0, 0, 1024, 256);
  // шевроны по краям
  ctx.fillStyle = fg;
  for (let i = 0; i < 6; i++) {
    const x = 30 + i * 46;
    ctx.beginPath(); ctx.moveTo(x, 200); ctx.lineTo(x + 26, 128); ctx.lineTo(x, 56); ctx.lineTo(x + 18, 128); ctx.closePath(); ctx.fill();
    const x2 = 994 - i * 46;
    ctx.beginPath(); ctx.moveTo(x2, 200); ctx.lineTo(x2 - 26, 128); ctx.lineTo(x2, 56); ctx.lineTo(x2 - 18, 128); ctx.closePath(); ctx.fill();
  }
  ctx.fillStyle = fg;
  ctx.font = '900 120px "Avenir Next", "Segoe UI", sans-serif';
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.fillText(text, 512, sub ? 108 : 128);
  if (sub) {
    ctx.font = '700 44px "Avenir Next", sans-serif';
    ctx.globalAlpha = 0.85;
    ctx.fillText(sub, 512, 205);
  }
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 4;
  return tex;
}

// ---------------- меш земли ----------------
export function buildTerrainMesh() {
  const SIZE = 340, SEG = 176;
  const geo = new THREE.PlaneGeometry(SIZE, SIZE, SEG, SEG);
  geo.rotateX(-Math.PI / 2);

  const pos = geo.attributes.position;
  const colors = new Float32Array(pos.count * 3);
  const colGrass = new THREE.Color('#4d7c3c');
  const colGrassDry = new THREE.Color('#77894a');
  const colGrassDark = new THREE.Color('#39602f');
  const colDirt = new THREE.Color('#79552f');
  const colDirtDark = new THREE.Color('#5f4125');
  const colDirtLight = new THREE.Color('#8f6a3e');
  const colSand = new THREE.Color('#a8906a');
  const tmp = new THREE.Color();

  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), z = pos.getZ(i);
    const y = gh(x, z);
    pos.setY(i, y);

    // --- покраска ---
    const t = smoothstep(TRACK.halfWidth + 2.3, TRACK.halfWidth - 1.1, Math.abs(x - TRACK.centerX(z)));
    // пятнистость травы
    const patch = vnoise(x * 0.055 + 3.1, z * 0.055 + 9.7);
    const patch2 = vnoise(x * 0.19 + 21.0, z * 0.19 + 5.0);
    tmp.copy(colGrass);
    if (patch > 0.18) tmp.lerp(colGrassDry, clamp((patch - 0.18) * 2.1, 0, 1));
    else if (patch < -0.22) tmp.lerp(colGrassDark, clamp((-patch - 0.22) * 2.0, 0, 1));
    tmp.offsetHSL(0, 0, patch2 * 0.035);
    // песчаная кромка
    const edge = smoothstep(TRACK.halfWidth + 2.6, TRACK.halfWidth + 0.4, Math.abs(x - TRACK.centerX(z))) * (1 - t);
    tmp.lerp(colSand, edge * 0.55);
    // грунт трассы
    if (t > 0) {
      const u = vnoise(x * 0.33 + 11.0, z * 0.33 + 4.0);
      const dirt = new THREE.Color().copy(colDirt);
      if (u > 0.1) dirt.lerp(colDirtLight, clamp((u - 0.1) * 1.6, 0, 1));
      else if (u < -0.15) dirt.lerp(colDirtDark, clamp((-u - 0.15) * 1.7, 0, 1));
      // тёмные колеи
      const lane = Math.abs(Math.sin((x - TRACK.centerX(z)) * 1.35));
      dirt.offsetHSL(0, 0, -0.035 * (1 - lane) * t);
      tmp.lerp(dirt, t);
    }
    // whoops — светлее от пыли
    const wcx = Math.abs(x - (TRACK.centerX(z) + WHOOPS.offset));
    if (z > WHOOPS.z0 - 2 && z < WHOOPS.z1 + 2 && wcx < WHOOPS.halfWidth + 1) {
      const w = smoothstep(WHOOPS.halfWidth + 1.0, WHOOPS.halfWidth - 0.6, wcx) *
                smoothstep(WHOOPS.z0 - 2, WHOOPS.z0 + 2, z) * smoothstep(WHOOPS.z1 + 2, WHOOPS.z1 - 2, z);
      tmp.lerp(colDirtLight, w * 0.85);
    }
    // стартовая площадка — серый бетон-like
    if (z > START_PAD.z0 && z < START_PAD.z1 && Math.abs(x - TRACK.centerX(z)) < START_PAD.halfWidth) {
      tmp.lerp(new THREE.Color('#6f6f74'), 0.75);
    }

    colors[i * 3] = tmp.r; colors[i * 3 + 1] = tmp.g; colors[i * 3 + 2] = tmp.b;
  }
  geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  geo.computeVertexNormals();

  const mat = new THREE.MeshStandardMaterial({
    vertexColors: true,
    roughness: 0.96,
    metalness: 0.0,
    map: makeNoiseTexture(),
  });
  const mesh = new THREE.Mesh(geo, mat);
  mesh.receiveShadow = true;
  mesh.name = 'terrain';
  return mesh;
}

// ---------------- low-poly дерево ----------------
function makeTree(rnd) {
  const g = new THREE.Group();
  const trunkH = 1.1 + rnd() * 1.3;
  const trunk = new THREE.Mesh(
    new THREE.CylinderGeometry(0.14 + rnd() * 0.1, 0.2 + rnd() * 0.12, trunkH, 6),
    new THREE.MeshStandardMaterial({ color: '#5a4128', roughness: 0.95 })
  );
  trunk.position.y = trunkH / 2;
  trunk.castShadow = true;
  g.add(trunk);
  const layers = 2 + Math.floor(rnd() * 2);
  let r = 1.35 + rnd() * 0.9;
  let y = trunkH;
  const green = new THREE.Color().setHSL(0.32 + rnd() * 0.05, 0.42, 0.24 + rnd() * 0.08);
  for (let i = 0; i < layers; i++) {
    const cone = new THREE.Mesh(
      new THREE.ConeGeometry(r, 1.6 + rnd() * 0.9, 7),
      new THREE.MeshStandardMaterial({ color: green, roughness: 0.9, flatShading: true })
    );
    y += 0.95 + rnd() * 0.4;
    cone.position.y = y;
    cone.castShadow = true;
    g.add(cone);
    r *= 0.68;
  }
  return g;
}

function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---------------- покрышки (стеки) ----------------
function makeTireStack(n = 3) {
  const g = new THREE.Group();
  const tireGeo = new THREE.TorusGeometry(0.34, 0.148, 9, 18);
  const tireMat = new THREE.MeshStandardMaterial({ color: '#17181a', roughness: 0.92 });
  const paintMat = new THREE.MeshStandardMaterial({ color: '#c8372d', roughness: 0.6 });
  for (let i = 0; i < n; i++) {
    const t = new THREE.Mesh(tireGeo, i === n - 1 && Math.random() < 0.6 ? paintMat : tireMat);
    t.rotation.x = Math.PI / 2;
    t.position.y = 0.155 + i * 0.30;
    t.castShadow = true;
    g.add(t);
  }
  return g;
}

// ---------------- флагшток ----------------
function makeFlagPole(color) {
  const g = new THREE.Group();
  const pole = new THREE.Mesh(
    new THREE.CylinderGeometry(0.05, 0.06, 3.4, 6),
    new THREE.MeshStandardMaterial({ color: '#c8ccd2', metalness: 0.85, roughness: 0.35 })
  );
  pole.position.y = 1.7;
  g.add(pole);
  const flag = new THREE.Mesh(
    new THREE.PlaneGeometry(1.05, 0.62),
    new THREE.MeshStandardMaterial({ color, side: THREE.DoubleSide, roughness: 0.8 })
  );
  flag.position.set(0.55, 2.95, 0);
  g.add(flag);
  return g;
}

// ---------------- бигборд ----------------
function makeBillboard(text, sub, bg, fg) {
  const g = new THREE.Group();
  const legMat = new THREE.MeshStandardMaterial({ color: '#3a3d44', metalness: 0.6, roughness: 0.5 });
  for (const dx of [-1.9, 1.9]) {
    const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.14, 2.6, 8), legMat);
    leg.position.set(dx, 1.3, 0);
    leg.castShadow = true;
    g.add(leg);
  }
  const board = new THREE.Mesh(
    new THREE.BoxGeometry(5.2, 1.5, 0.18),
    new THREE.MeshStandardMaterial({ color: '#101318', roughness: 0.6 })
  );
  board.position.y = 3.35;
  board.castShadow = true;
  g.add(board);
  const face = new THREE.Mesh(
    new THREE.PlaneGeometry(5.0, 1.3),
    new THREE.MeshStandardMaterial({ map: makeBannerTexture(text, sub, bg, fg), roughness: 0.55, emissive: '#ffffff', emissiveMap: makeBannerTexture(text, sub, bg, fg), emissiveIntensity: 0.32 })
  );
  face.position.set(0, 3.35, 0.101);
  g.add(face);
  return g;
}

// ---------------- весь декор ----------------
export function buildProps(scene) {
  const rnd = mulberry32(1337);
  const group = new THREE.Group();
  group.name = 'props';

  const place = (obj, x, z, yOffset = 0, rotY = 0) => {
    obj.position.set(x, gh(x, z) + yOffset, z);
    obj.rotation.y = rotY;
    group.add(obj);
  };

  // --- стартовая арка ---
  const gate = new THREE.Group();
  const postMat = new THREE.MeshStandardMaterial({ color: '#d8dde4', metalness: 0.7, roughness: 0.4 });
  for (const dx of [-3.4, 3.4]) {
    const post = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.18, 3.1, 8), postMat);
    post.position.set(dx, 1.55, 0);
    post.castShadow = true;
    gate.add(post);
  }
  const banner = new THREE.Mesh(
    new THREE.PlaneGeometry(6.8, 1.05),
    new THREE.MeshStandardMaterial({ map: makeBannerTexture('STUNT MOTO', 'ПАРК АКРОБАТИКИ', '#0e2233', '#57e0ff'), side: THREE.DoubleSide, roughness: 0.6, emissive: '#ffffff', emissiveMap: makeBannerTexture('STUNT MOTO', 'ПАРК АКРОБАТИКИ', '#0e2233', '#57e0ff'), emissiveIntensity: 0.35 })
  );
  banner.position.y = 2.75;
  gate.add(banner);
  place(gate, TRACK.centerX(124), 124, 0, 0);

  // --- флаги у старта и трамплинов ---
  const flagColors = ['#ff5a3c', '#57e0ff', '#ffd23f'];
  let fi = 0;
  for (const j of JUMPS) {
    const cx = TRACK.centerX(j.z);
    place(makeFlagPole(flagColors[fi++ % 3]), cx - 6.2, j.z + 2, 0, rnd() * 3);
    place(makeFlagPole(flagColors[fi++ % 3]), cx + 6.2, j.z + 2, 0, rnd() * 3);
  }
  place(makeFlagPole('#57e0ff'), TRACK.centerX(112) - 6.0, 112, 0, 0.4);
  place(makeFlagPole('#ff5a3c'), TRACK.centerX(112) + 6.0, 112, 0, -0.4);

  // --- стеки покрышек: вход/выход whoops и приземления ---
  const tireLine = [
    [TRACK.centerX(WHOOPS.z1 + 3) + WHOOPS.offset - 3.4, WHOOPS.z1 + 3],
    [TRACK.centerX(WHOOPS.z1 + 3) + WHOOPS.offset + 3.4, WHOOPS.z1 + 3],
    [TRACK.centerX(WHOOPS.z0 - 3) + WHOOPS.offset - 3.4, WHOOPS.z0 - 3],
    [TRACK.centerX(WHOOPS.z0 - 3) + WHOOPS.offset + 3.4, WHOOPS.z0 - 3],
  ];
  for (const j of JUMPS) {
    const cx = TRACK.centerX(j.z);
    tireLine.push([cx - 5.6, j.z - j.width * 1.9], [cx + 5.6, j.z - j.width * 1.9]);
  }
  for (const [x, z] of tireLine) place(makeTireStack(2 + Math.floor(rnd() * 2)), x, z, 0, rnd() * 3);

  // --- бигборды ---
  place(makeBillboard('YZ450F', 'BLUE THUNDER', '#10265c', '#ffffff'), TRACK.centerX(88) - 10.5, 88, 0, 0.5);
  place(makeBillboard('WHEELIE ZONE', 'ТОЛЬКО ДЛЯ СВОИХ', '#231303', '#ffd23f'), TRACK.centerX(-18) + 10.5, -18, 0, -0.55);
  place(makeBillboard('YZ300 2T', 'EXPANSION POWER', '#10165c', '#ffd23f'), TRACK.centerX(-88) - 10.5, -88, 0, 0.45);

  // --- деревья по периметру ---
  for (let i = 0; i < 110; i++) {
    const x = (rnd() - 0.5) * 320;
    const z = (rnd() - 0.5) * 320;
    const dTrack = Math.abs(x - TRACK.centerX(z));
    if (dTrack < TRACK.halfWidth + 6.5) continue;
    if (Math.abs(x - (TRACK.centerX(z) + WHOOPS.offset)) < WHOOPS.halfWidth + 3) continue;
    if (z > START_PAD.z0 - 4 && Math.abs(x - TRACK.centerX(z)) < START_PAD.halfWidth + 3) continue;
    const tree = makeTree(rnd);
    const s = 0.75 + rnd() * 1.15;
    tree.scale.setScalar(s);
    place(tree, x, z, 0, rnd() * Math.PI * 2);
  }

  // --- кусты ---
  const bushMat = new THREE.MeshStandardMaterial({ color: '#3c5c2e', roughness: 0.95, flatShading: true });
  for (let i = 0; i < 60; i++) {
    const x = (rnd() - 0.5) * 300, z = (rnd() - 0.5) * 300;
    if (Math.abs(x - TRACK.centerX(z)) < TRACK.halfWidth + 3.5) continue;
    const bush = new THREE.Mesh(new THREE.IcosahedronGeometry(0.35 + rnd() * 0.5, 0), bushMat);
    bush.position.set(x, gh(x, z) + 0.25, z);
    bush.scale.y = 0.7;
    bush.castShadow = true;
    group.add(bush);
  }

  // --- далёкие холмы (на горизонте) ---
  const hillMat = new THREE.MeshStandardMaterial({ color: '#5d6f66', roughness: 1, flatShading: true });
  for (let i = 0; i < 14; i++) {
    const ang = (i / 14) * Math.PI * 2 + rnd() * 0.3;
    const dist = 165 + rnd() * 45;
    const h = 22 + rnd() * 26;
    const hill = new THREE.Mesh(new THREE.ConeGeometry(38 + rnd() * 34, h, 7), hillMat);
    hill.position.set(Math.cos(ang) * dist, h * 0.18, Math.sin(ang) * dist);
    group.add(hill);
  }

  scene.add(group);
  return group;
}
