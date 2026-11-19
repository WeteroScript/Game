// ============================================================================
//  STUNT MOTO — чистая математика трассы (без three.js, чтобы гонять headless)
//  Ось трассы идёт вдоль Z. Старт — на z = +124, финишная зона — к z = −140.
// ============================================================================

const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const smoothstep = (a, b, x) => {
  const t = clamp((x - a) / (b - a), 0, 1);
  return t * t * (3 - 2 * t);
};

// ---------------- детерминированный value-noise ----------------
function hash2(ix, iz) {
  let h = (ix * 374761393 + iz * 668265263) | 0;
  h = (h ^ (h >> 13)) | 0;
  h = Math.imul(h, 1274126177);
  h = (h ^ (h >> 16)) >>> 0;
  return h / 4294967295;
}
function valueNoise(x, z) {
  const ix = Math.floor(x), iz = Math.floor(z);
  const fx = x - ix, fz = z - iz;
  const ux = fx * fx * (3 - 2 * fx), uz = fz * fz * (3 - 2 * fz);
  const a = hash2(ix, iz), b = hash2(ix + 1, iz), c = hash2(ix, iz + 1), d = hash2(ix + 1, iz + 1);
  return (a + (b - a) * ux + (c - a) * uz + (a - b - c + d) * ux * uz) * 2 - 1; // [-1..1]
}

// ---------------- геометрия трассы ----------------
export const TRACK_START_Z = 118;
export const trackCenterX = (z) => 7 * Math.sin(z * 0.011);
export const TRACK = {
  start: { x: trackCenterX(TRACK_START_Z), z: TRACK_START_Z, yaw: 0 },
  halfWidth: 4.3,
  centerX: trackCenterX,
};

export const JUMPS = [
  { z: 58, amp: 1.15, width: 2.35 },
  { z: 6, amp: 1.55, width: 2.65 },
  { z: -52, amp: 2.05, width: 2.95 },
];

export const WHOOPS = { z0: -26, z1: 26, offset: 10.5, halfWidth: 2.5, amp: 0.22, spacing: 1.18 };

export const START_PAD = { z0: 104, z1: 132, halfWidth: 7 };

const onTrackFactor = (x, z) => {
  const d = Math.abs(x - TRACK.centerX(z));
  return smoothstep(TRACK.halfWidth + 2.2, TRACK.halfWidth - 1.2, d); // 1 = на трассе
};

const whoopsFactor = (x, z) => {
  if (z < WHOOPS.z0 - 2 || z > WHOOPS.z1 + 2) return 0;
  const cx = TRACK.centerX(z) + WHOOPS.offset;
  const d = Math.abs(x - cx);
  const lat = smoothstep(WHOOPS.halfWidth + 1.0, WHOOPS.halfWidth - 0.6, d);
  const lon = smoothstep(WHOOPS.z0 - 2, WHOOPS.z0 + 2, z) * smoothstep(WHOOPS.z1 + 2, WHOOPS.z1 - 2, z);
  return lat * lon;
};

const jumpBump = (x, z) => {
  const cx = TRACK.centerX(z);
  const dx = x - cx;
  const lat = Math.exp(-(dx * dx) / 14.5); // боковое затухание (трапеция ~ гаусс)
  let y = 0;
  for (const j of JUMPS) {
    const dz = z - j.z;
    y += j.amp * Math.exp(-(dz * dz) / (j.width * j.width));
  }
  return y * lat;
};

const startPadFactor = (x, z) => {
  if (z < START_PAD.z0 || z > START_PAD.z1) return 0;
  return smoothstep(START_PAD.halfWidth + 1.5, START_PAD.halfWidth - 1.0, Math.abs(x - TRACK.centerX(z)));
};

// ---------------- высота грунта ----------------
export function groundHeight(x, z) {
  // базовое волновое поле
  let y = 1.05 * valueNoise(x * 0.013, z * 0.013)
        + 0.38 * valueNoise(x * 0.047 + 13.7, z * 0.047 + 7.3)
        + 0.09 * valueNoise(x * 0.16 + 31.0, z * 0.16 + 17.0);

  // на трассе — ровнее
  const t = onTrackFactor(x, z);
  y *= (1 - 0.86 * t);

  // стартовая площадка — идеально плоская
  const pad = startPadFactor(x, z);
  if (pad > 0) y *= (1 - 0.97 * pad);

  // трамплины основной трассы
  y += jumpBump(x, z) * (1 - 0.25 * (1 - t)); // вне трассы трамплина ниже

  // «вumps» / whoops — отдельная полоса справа
  const w = whoopsFactor(x, z);
  if (w > 0.001) {
    const u = (z - WHOOPS.z0) / WHOOPS.spacing;
    const frac = u - Math.floor(u);
    const hump = Math.pow(Math.sin(Math.PI * frac), 1.55);
    y += WHOOPS.amp * hump * w;
    y += 0.05 * valueNoise(x * 0.9, z * 0.9) * w; // мелкая расколбас
  }

  return y;
}

// ---------------- сцепление ----------------
export function groundGrip(x, z) {
  const t = onTrackFactor(x, z);
  const w = whoopsFactor(x, z);
  const dirt = 0.97, grass = 0.72;
  let mu = grass + (dirt - grass) * t;
  if (w > 0.1) mu = 0.90 - 0.10 * w;
  return mu;
}

// ---------------- «жёсткость» покрытия (возмущения) ----------------
export function groundRoughness(x, z) {
  const t = onTrackFactor(x, z);
  const w = whoopsFactor(x, z);
  let r = 0.18 + (1 - t) * 0.42;   // трава неровнее
  r = Math.max(r, w * 1.45);        // випы — совсем плохо для уили
  return r;
}

/** Объект для физики */
export const terrainGround = {
  h: groundHeight,
  grip: groundGrip,
  roughness: groundRoughness,
  normal(x, z, out) {
    const e = 0.42;
    const hx1 = groundHeight(x + e, z), hx0 = groundHeight(x - e, z);
    const hz1 = groundHeight(x, z + e), hz0 = groundHeight(x, z - e);
    out.set(hx0 - hx1, 2 * e, hz0 - hz1).normalize();
    return out;
  },
};
