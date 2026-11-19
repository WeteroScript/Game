// Headless smoke-тест: исполняем весь код построения сцены с заглушкой canvas.
// Ловит ошибки времени выполнения, NaN в геометрии, отсутствие частей модели.
import * as THREE from 'three';

// ---------- заглушка 2D-контекста ----------
function fakeContext2D(canvas) {
  const gradient = { addColorStop() {} };
  const ctx = {
    canvas,
    fillStyle: '#000', strokeStyle: '#000', font: '', globalAlpha: 1,
    lineWidth: 1, textAlign: 'left', textBaseline: 'alphabetic', lineCap: 'butt',
    fillRect() {}, strokeRect() {}, clearRect() {},
    beginPath() {}, closePath() {}, moveTo() {}, lineTo() {}, arc() {}, ellipse() {},
    fill() {}, stroke() {}, save() {}, restore() {}, translate() {}, scale() {}, rotate() {},
    roundRect() {}, fillText() {}, strokeText() {}, drawImage() {}, setLineDash() {},
    createLinearGradient: () => gradient,
    createRadialGradient: () => gradient,
    createImageData: (w, h) => ({ data: new Uint8ClampedArray(w * h * 4), width: w, height: h }),
    putImageData() {},
    getImageData: (x, y, w, h) => ({ data: new Uint8ClampedArray(w * h * 4) }),
  };
  return ctx;
}
function fakeCanvas() {
  const c = { width: 256, height: 256 };
  c.getContext = () => fakeContext2D(c);
  return c;
}
globalThis.document = {
  createElement(tag) {
    if (tag === 'canvas') return fakeCanvas();
    return {};
  },
};

const { buildMotocross } = await import('../src/game/bikeFactory.js');
const { buildTerrainMesh, buildProps } = await import('../src/game/terrain.js');
const { groundHeight } = await import('../src/game/terrainMath.js');

let failures = 0;
const fail = (msg) => { console.error('  ✗', msg); failures++; };
const ok = (msg) => console.log('  ✓', msg);

// ---------- проверка моделей ----------
for (const variant of ['yz450f', 'yz300']) {
  console.log(`\n=== Модель ${variant} ===`);
  const bike = buildMotocross(variant);
  const names = [];
  bike.traverse((o) => { if (o.name) names.push(o.name); });
  for (const part of ['chassis', 'swingarm', 'frontAssembly', 'forkLower', 'rearWheel', 'frontWheel', 'engine', 'exhaust']) {
    if (names.includes(part)) ok(`часть «${part}» на месте`);
    else fail(`часть «${part}» ОТСУТСТВУЕТ`);
  }
  // NaN-проверка всех вершин
  let nanVerts = 0, triCount = 0;
  bike.traverse((o) => {
    if (o.isMesh && o.geometry) {
      const pos = o.geometry.attributes.position;
      if (pos) for (let i = 0; i < pos.count; i++) {
        if (!Number.isFinite(pos.getX(i)) || !Number.isFinite(pos.getY(i)) || !Number.isFinite(pos.getZ(i))) nanVerts++;
      }
      triCount += (o.geometry.index ? o.geometry.index.count : pos?.count || 0) / 3;
    }
  });
  if (nanVerts === 0) ok('нет NaN-вершин');
  else fail(`NaN-вершин: ${nanVerts}`);
  console.log(`  · треугольников (примерно): ${Math.round(triCount)}`);

  // проверки масштабов: длина и колёсная база
  const box = new THREE.Box3().setFromObject(bike);
  const size = box.getSize(new THREE.Vector3());
  console.log(`  · габариты: ${size.x.toFixed(2)} × ${size.y.toFixed(2)} × ${size.z.toFixed(2)} м`);
  if (size.y > 1.45 || size.y < 0.8) fail(`подозрительная высота ${size.y.toFixed(2)}`);
  else ok('высота в пределах');
  if (size.z < 1.6 || size.z > 2.6) fail(`подозрительная длина ${size.z.toFixed(2)}`);
  else ok('длина в пределах');

  // мировые позиции осей колёс до произвольных трансформаций
  bike.updateMatrixWorld(true);
  const rearW = new THREE.Vector3(), frontW = new THREE.Vector3();
  bike.userData.rearWheel.getWorldPosition(rearW);
  bike.userData.frontWheel.getWorldPosition(frontW);
  console.log(`  · ось заднего колеса: (${rearW.x.toFixed(2)}, ${rearW.y.toFixed(2)}, ${rearW.z.toFixed(2)})`);
  console.log(`  · ось переднего колеса: (${frontW.x.toFixed(2)}, ${frontW.y.toFixed(2)}, ${frontW.z.toFixed(2)})`);
  if (Math.abs(frontW.z + 0.7425) > 0.02 || Math.abs(rearW.z - 0.7425) > 0.02) fail('колёсная база не совпадает с физикой!');
  else ok('колёсная база 1.485 м как в физике');
  if (Math.abs(frontW.y - 0.355) > 0.02 || Math.abs(rearW.y - 0.345) > 0.02) fail('высота осей не совпадает с физикой!');
  else ok('высота осей как в физике');

  // проверка размещения ключевых деталей
  const boxOf = (name) => {
    let b = null;
    bike.traverse((o) => {
      if (o.name === name || o.name?.startsWith(name)) {
        const bb = new THREE.Box3().setFromObject(o);
        b = b ? b.union(bb) : bb;
      }
    });
    return b;
  };
  const seatBox = boxOf('chassis'); // сидение внутри chassis — проверим геометрию вручную:
  const full = new THREE.Box3().setFromObject(bike);
  console.log('  · общий bbox y:', full.min.y.toFixed(2), '…', full.max.y.toFixed(2));
  if (full.min.y < -0.05) fail('модель проваливается ПОД землю');
  else ok('модель стоит на земле');
  if (full.max.y < 1.0) fail('руль подозрительно низко');
  else ok('высота руля в норме');
}

// ---------- проверка рельефа ----------
console.log('\n=== Рельеф ===');
let nanH = 0;
for (let x = -170; x <= 170; x += 3) {
  for (let z = -170; z <= 170; z += 3) {
    if (!Number.isFinite(groundHeight(x, z))) nanH++;
  }
}
if (nanH === 0) ok('высотная функция везде конечна');
else fail(`NaN высот: ${nanH}`);
console.log(`  · h(старт) = ${groundHeight(7 * Math.sin(118 * 0.011), 118).toFixed(3)} м`);

const terrain = buildTerrainMesh();
const tp = terrain.geometry.attributes.position;
let nanT = 0;
for (let i = 0; i < tp.count; i++) {
  if (!Number.isFinite(tp.getY(i))) nanT++;
}
if (nanT === 0) ok('меш трассы без NaN');
else fail(`NaN в меше трассы: ${nanT}`);

const scene = new THREE.Scene();
const props = buildProps(scene);
let propMeshes = 0;
props.traverse((o) => { if (o.isMesh) propMeshes++; });
ok(`декорации построены (${propMeshes} мешей)`);

// соответствие цвета вершин и высот
const colors = terrain.geometry.attributes.color;
let nanC = 0;
for (let i = 0; i < colors.count; i++) {
  if (!Number.isFinite(colors.getX(i))) nanC++;
}
if (nanC === 0) ok('вершинные цвета без NaN');
else fail(`NaN цветов: ${nanC}`);

console.log(failures === 0 ? '\nВСЁ ОК — сцена строится чисто.' : `\nОШИБКИ: ${failures}`);
process.exit(failures === 0 ? 0 : 1);
