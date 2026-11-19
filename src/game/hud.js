// ============================================================================
//  STUNT MOTO — HUD: спидометр, передача, дуга-индикатор угла уили с зонами,
//  предупреждение об LOOP OUT, всплывающие очки, комбо
// ============================================================================

const DEG = 180 / Math.PI;

// углы дуги: pitch −10° … 90°  →  φ −80° … +80° (0° = вертикаль)
const vToPhi = (v) => ((v + 10) / 100) * 160 - 80;
const phiToRad = (p) => (p * Math.PI) / 180;

function arcPath(cx, cy, r, v0, v1) {
  const a0 = phiToRad(vToPhi(v0)), a1 = phiToRad(vToPhi(v1));
  const p0 = [cx + r * Math.sin(a0), cy - r * Math.cos(a0)];
  const p1 = [cx + r * Math.sin(a1), cy - r * Math.cos(a1)];
  const large = Math.abs(v1 - v0) > 63 ? 1 : 0;
  return `M ${p0[0].toFixed(1)} ${p0[1].toFixed(1)} A ${r} ${r} 0 ${large} 1 ${p1[0].toFixed(1)} ${p1[1].toFixed(1)}`;
}

export class HUD {
  constructor() {
    const $ = (id) => document.getElementById(id);
    this.el = {
      hud: $('hud'),
      score: $('hud-score'),
      combo: $('hud-combo'),
      bestWheelie: $('hud-best-wheelie'),
      highscore: $('hud-highscore'),
      speed: $('hud-speed'),
      gear: $('hud-gear'),
      rpmFill: $('hud-rpm-fill'),
      gaugeZones: $('gauge-zones'),
      gaugeCrit: $('gauge-crit'),
      gaugeNeedle: $('gauge-needle'),
      gaugeText: $('gauge-angle-text'),
      gaugeBox: $('wheelie-gauge'),
      wheelieState: $('wheelie-state'),
      hint: $('wheelie-hint'),
      loopout: $('loopout-warning'),
      toastLayer: $('toast-layer'),
      keysHint: $('keys-hint'),
      crashOverlay: $('crash-overlay'),
      crashTitle: $('crash-title'),
      crashSub: $('crash-sub'),
      crashPenalty: $('crash-penalty'),
    };
    this._buildGauge();
    this._comboShown = 1;
    this._toastCount = 0;
  }

  _buildGauge() {
    // дуговые зоны: серая (падение) → зелёная (баланс) → янтарная (опасно) → красная (loop out)
    const zones = [
      { v: [-10, 25], color: '#3a4756', width: 15 },
      { v: [25, 55], color: '#2fd57f', width: 15 },
      { v: [55, 72], color: '#ffb020', width: 15 },
      { v: [72, 90], color: '#ff3b30', width: 16 },
    ];
    this.el.gaugeZones.innerHTML = zones
      .map((z) => `<path d="${arcPath(150, 160, 96, z.v[0], z.v[1])}" stroke="${z.color}" stroke-width="${z.width}" fill="none" stroke-linecap="round" opacity="0.92"/>`)
      .join('');
    // критическая метка и подписи внутри видимой дуги
    const critPhi = phiToRad(vToPhi(72));
    const cx = 150, cy = 160;
    const x0 = cx + 76 * Math.sin(critPhi), y0 = cy - 76 * Math.cos(critPhi);
    const x1 = cx + 116 * Math.sin(critPhi), y1 = cy - 116 * Math.cos(critPhi);
    this.el.gaugeCrit.innerHTML =
      `<line x1="${x0.toFixed(1)}" y1="${y0.toFixed(1)}" x2="${x1.toFixed(1)}" y2="${y1.toFixed(1)}" stroke="#ff6b5e" stroke-width="4" stroke-dasharray="5 4"/>` +
      `<circle cx="${x1.toFixed(1)}" cy="${y1.toFixed(1)}" r="4.5" fill="#ff3b30"/>`;
    // подписи зон
    const label = (v, txt, color) => {
      const phi = phiToRad(vToPhi(v));
      const x = cx + 126 * Math.sin(phi), y = cy - 126 * Math.cos(phi);
      return `<text x="${x.toFixed(1)}" y="${y.toFixed(1)}" fill="${color}" font-size="10" font-weight="700" text-anchor="middle" dominant-baseline="middle">${txt}</text>`;
    };
    this.el.gaugeZones.innerHTML +=
      label(37, 'БАЛАНС', '#7df0b2') + label(81, '72°', '#ff8a7a');
  }

  show() { this.el.hud.classList.remove('hidden'); }
  hide() { this.el.hud.classList.add('hidden'); }

  setSpeed(kmh) { this.el.speed.textContent = String(Math.round(kmh)); }
  setGear(g) { this.el.gear.textContent = String(g); }
  setRpm(v) { this.el.rpmFill.style.width = `${Math.round(8 + v * 92)}%`; }

  setScore(points) { this.el.score.textContent = String(Math.floor(points)); }

  setCombo(n) {
    this.el.combo.textContent = `КОМБО ×${n}`;
    if (n !== this._comboShown) {
      this._comboShown = n;
      this.el.combo.classList.remove('pop');
      void this.el.combo.offsetWidth;
      this.el.combo.classList.add('pop');
    }
  }

  setBestWheelie(m) { this.el.bestWheelie.textContent = `${m.toFixed(0)} м`; }
  setHighscore(v) { this.el.highscore.textContent = String(Math.floor(v)); }

  /** pitchDeg — угол тангажа; frontAir — колесо в воздухе */
  setGauge(pitchDeg, frontAir) {
    const v = Math.max(-10, Math.min(90, pitchDeg));
    const phi = vToPhi(v);
    this.el.gaugeNeedle.setAttribute('transform', `rotate(${phi.toFixed(2)} 150 160)`);
    this.el.gaugeText.textContent = `${Math.round(pitchDeg)}°`;
    const danger = pitchDeg >= 55;
    const inBalance = pitchDeg >= 25 && pitchDeg <= 55;
    this.el.gaugeBox.classList.toggle('critical', pitchDeg >= 62);
    const ws = this.el.wheelieState;
    ws.classList.toggle('active', frontAir && !danger && inBalance);
    ws.classList.toggle('danger', danger);
    ws.textContent = danger ? 'LOOP OUT?' : 'WHEELIE';
  }

  setLoopoutWarning(on) { this.el.loopout.classList.toggle('hidden', !on); }

  showHint(html) {
    this.el.hint.innerHTML = html;
    this.el.hint.classList.remove('hidden');
  }
  hideHint() { this.el.hint.classList.add('hidden'); }

  toast(text, kind = 'good') {
    const div = document.createElement('div');
    div.className = `toast${kind === 'bad' ? ' bad' : kind === 'gold' ? ' gold' : ''}`;
    div.textContent = text;
    this.el.toastLayer.appendChild(div);
    this._toastCount++;
    if (this._toastCount > 4) this.el.toastLayer.firstChild?.remove();
    setTimeout(() => div.remove(), 1700);
  }

  showCrash(title, sub, penalty) {
    this.el.crashTitle.textContent = title;
    this.el.crashSub.textContent = sub;
    this.el.crashPenalty.textContent = penalty;
    this.el.crashOverlay.classList.remove('hidden');
  }
  hideCrash() { this.el.crashOverlay.classList.add('hidden'); }

  fadeKeysHint() { this.el.keysHint.classList.add('fade'); }
}
