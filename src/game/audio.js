// ============================================================================
//  STUNT MOTO — процедурный звук (Web Audio API, без внешних файлов)
//  Двигатель: два просаженных осциллятора + саб + фильтрованный шум выхлопа.
// ============================================================================

export class GameAudio {
  constructor() {
    this.ctx = null;
    this.master = null;
    this.muted = false;
    this._engineGain = null;
    this._osc1 = null;
    this._osc2 = null;
    this._sub = null;
    this._lowpass = null;
    this._noiseGain = null;
    this._noiseFilter = null;
    this._windGain = null;
    this._rpm = 0;
  }

  /** Создаём/возобновляем контекст — только по жесту пользователя */
  unlock() {
    if (this.ctx) {
      if (this.ctx.state === 'suspended') this.ctx.resume();
      return;
    }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    const ctx = new AC();
    this.ctx = ctx;

    this.master = ctx.createGain();
    this.master.gain.value = this.muted ? 0 : 0.55;
    this.master.connect(ctx.destination);

    // ---------- двигатель ----------
    this._lowpass = ctx.createBiquadFilter();
    this._lowpass.type = 'lowpass';
    this._lowpass.frequency.value = 400;
    this._lowpass.Q.value = 8;

    this._engineGain = ctx.createGain();
    this._engineGain.gain.value = 0.0;

    this._osc1 = ctx.createOscillator();
    this._osc1.type = 'sawtooth';
    this._osc2 = ctx.createOscillator();
    this._osc2.type = 'square';
    this._osc2.detune.value = -1205; // суб-октава (~октава вниз)
    this._sub = ctx.createOscillator();
    this._sub.type = 'triangle';
    this._sub.detune.value = -2400;

    const oscGain = ctx.createGain(); oscGain.gain.value = 0.5;
    this._osc1.connect(oscGain);
    this._osc2.connect(oscGain);
    this._sub.connect(oscGain);
    oscGain.connect(this._lowpass);
    this._lowpass.connect(this._engineGain);
    this._engineGain.connect(this.master);

    this._osc1.frequency.value = 55;
    this._osc2.frequency.value = 55;
    this._sub.frequency.value = 55;
    this._osc1.start(); this._osc2.start(); this._sub.start();

    // шум выхлопа (очень тихий, на высоких оборотах шипит)
    const noiseBuf = this._makeNoise(2.0);
    const exhaustNoise = ctx.createBufferSource();
    exhaustNoise.buffer = noiseBuf; exhaustNoise.loop = true;
    this._noiseFilter = ctx.createBiquadFilter();
    this._noiseFilter.type = 'bandpass';
    this._noiseFilter.frequency.value = 900;
    this._noiseFilter.Q.value = 0.7;
    this._noiseGain = ctx.createGain(); this._noiseGain.gain.value = 0;
    exhaustNoise.connect(this._noiseFilter).connect(this._noiseGain).connect(this.master);
    exhaustNoise.start();

    // ---------- ветер ----------
    const wind = ctx.createBufferSource();
    wind.buffer = noiseBuf; wind.loop = true;
    const windFilter = ctx.createBiquadFilter();
    windFilter.type = 'lowpass'; windFilter.frequency.value = 480;
    this._windGain = ctx.createGain(); this._windGain.gain.value = 0;
    wind.connect(windFilter).connect(this._windGain).connect(this.master);
    wind.start();
  }

  _makeNoise(seconds) {
    const ctx = this.ctx;
    const buf = ctx.createBuffer(1, Math.floor(ctx.sampleRate * seconds), ctx.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < data.length; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / data.length * 0.15);
    return buf;
  }

  setMuted(m) {
    this.muted = m;
    if (this.master) this.master.gain.setTargetAtTime(m ? 0 : 0.55, this.ctx.currentTime, 0.05);
  }

  /** Основной параметр тика — вызывать каждый кадр */
  updateEngine({ rpm01, throttle, speed01, wheelie, crashed }) {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    // частота: грубая аппроксимация оборотов от rpm01 + чуть throttle-резотклика
    const target = 42 + rpm01 * 132 + throttle * 14;
    this._rpm += (target - this._rpm) * 0.14;
    const f = this._rpm;
    this._osc1.frequency.setTargetAtTime(f, t, 0.03);
    this._osc2.frequency.setTargetAtTime(f, t, 0.03);
    this._sub.frequency.setTargetAtTime(f, t, 0.03);
    this._lowpass.frequency.setTargetAtTime(340 + rpm01 * 2400 + throttle * 900, t, 0.05);
    const eg = crashed ? 0.02 : 0.055 + rpm01 * 0.075 + throttle * 0.035;
    this._engineGain.gain.setTargetAtTime(eg, t, 0.06);
    this._noiseGain.gain.setTargetAtTime(crashed ? 0 : rpm01 * rpm01 * 0.05 + throttle * 0.012, t, 0.08);
    this._noiseFilter.frequency.setTargetAtTime(700 + rpm01 * 1500, t, 0.08);
    this._windGain.gain.setTargetAtTime(speed01 * speed01 * 0.075, t, 0.15);
  }

  /** Глухой удар (приземление / касание) */
  thump(strength = 1) {
    if (!this.ctx) return;
    const ctx = this.ctx, t = ctx.currentTime;
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.type = 'sine';
    o.frequency.setValueAtTime(82, t);
    o.frequency.exponentialRampToValueAtTime(34, t + 0.22);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(0.5 * strength, t + 0.012);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 0.3);
    o.connect(g).connect(this.master);
    o.start(t); o.stop(t + 0.32);
  }

  /** Металлический скрежет / падение */
  crash() {
    if (!this.ctx) return;
    const ctx = this.ctx, t = ctx.currentTime;
    // шумовой удар
    const src = ctx.createBufferSource();
    src.buffer = this._makeNoise(0.9);
    const bp = ctx.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = 750; bp.Q.value = 0.6;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(0.7, t + 0.02);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 0.85);
    src.connect(bp).connect(g).connect(this.master);
    src.start(t);
    // низкий удар
    this.thump(1.6);
    // металлический звон
    for (const [freq, delay, amp] of [[1204, 0.06, 0.16], [1867, 0.13, 0.11], [2633, 0.21, 0.07]]) {
      const o = ctx.createOscillator(), og = ctx.createGain();
      o.type = 'square';
      o.frequency.value = freq;
      og.gain.setValueAtTime(0.0001, t + delay);
      og.gain.exponentialRampToValueAtTime(amp, t + delay + 0.01);
      og.gain.exponentialRampToValueAtTime(0.0001, t + delay + 0.5);
      o.connect(og).connect(this.master);
      o.start(t + delay); o.stop(t + delay + 0.55);
    }
  }

  /** Короткое «дзинь» набора комбо */
  comboPing(n = 1) {
    if (!this.ctx) return;
    const ctx = this.ctx, t = ctx.currentTime;
    const base = 620 * Math.pow(1.25, Math.min(n - 1, 6));
    for (const [mult, amp, dur] of [[1, 0.24, 0.3], [1.5, 0.17, 0.4]]) {
      const o = ctx.createOscillator(), g = ctx.createGain();
      o.type = 'sine';
      o.frequency.value = base * mult;
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(amp, t + 0.012);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      o.connect(g).connect(this.master);
      o.start(t); o.stop(t + dur + 0.02);
    }
  }

  /** Негативный сигнал (потеря комбо) */
  badBuzz() {
    if (!this.ctx) return;
    const ctx = this.ctx, t = ctx.currentTime;
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.type = 'sawtooth';
    o.frequency.setValueAtTime(170, t);
    o.frequency.exponentialRampToValueAtTime(85, t + 0.4);
    g.gain.setValueAtTime(0.22, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 0.45);
    o.connect(g).connect(this.master);
    o.start(t); o.stop(t + 0.48);
  }
}
