// ============================================================================
//  STUNT MOTO — ввод: клавиатура + тач-экран
//  input: { throttle, brake, steer, lean, wheelie }
//   throttle/brake 0..1 (плавная подача), steer/lean −1..+1
//   lean > 0 — вес НАЗАД (помогает уили), lean < 0 — вперёд
// ============================================================================

export class Input {
  constructor() {
    this.keys = new Set();
    this.touch = { steer: 0, throttle: 0, brake: 0, wheelie: false, lean: 0 };
    this.isTouch = false;

    window.addEventListener('keydown', (e) => {
      if (e.repeat) return;
      this.keys.add(e.code);
      if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space'].includes(e.code)) e.preventDefault();
      this.onKey?.(e.code);
    });
    window.addEventListener('keyup', (e) => this.keys.delete(e.code));
    window.addEventListener('blur', () => this.keys.clear());

    this._bindTouch();
  }

  _bindTouch() {
    const bind = (id, onDown, onUp) => {
      const el = document.getElementById(id);
      if (!el) return;
      const down = (e) => {
        e.preventDefault();
        el.setPointerCapture?.(e.pointerId);
        this.isTouch = true;
        document.body.classList.add('touch-mode');
        onDown();
      };
      const up = (e) => { e.preventDefault(); onUp?.(); };
      el.addEventListener('pointerdown', down);
      el.addEventListener('pointerup', up);
      el.addEventListener('pointercancel', up);
      el.addEventListener('lostpointercapture', up);
      el.addEventListener('contextmenu', (e) => e.preventDefault());
    };
    bind('tc-left', () => (this.touch.steer = 1), () => { if (this.touch.steer > 0) this.touch.steer = 0; });
    bind('tc-right', () => (this.touch.steer = -1), () => { if (this.touch.steer < 0) this.touch.steer = 0; });
    bind('tc-gas', () => (this.touch.throttle = 1), () => (this.touch.throttle = 0));
    bind('tc-brake', () => (this.touch.brake = 1), () => (this.touch.brake = 0));
    bind('tc-wheelie', () => (this.touch.wheelie = true), () => (this.touch.wheelie = false));
    bind('tc-leanback', () => (this.touch.lean = 1), () => { if (this.touch.lean > 0) this.touch.lean = 0; });
    bind('tc-leanfwd', () => (this.touch.lean = -1), () => { if (this.touch.lean < 0) this.touch.lean = 0; });

    window.addEventListener('touchstart', () => {
      this.isTouch = true;
      document.body.classList.add('touch-mode');
    }, { once: true, passive: true });
  }

  /** Полное состояние для физики. steer: +1 = влево (как A/←) */
  sample() {
    const k = this.keys;
    const throttle = (k.has('KeyW') || k.has('ArrowUp') ? 1 : 0) || this.touch.throttle;
    const brake = (k.has('KeyS') || k.has('ArrowDown') ? 1 : 0) || this.touch.brake;
    const steerLeft = k.has('KeyA') || k.has('ArrowLeft');
    const steerRight = k.has('KeyD') || k.has('ArrowRight');
    let steer = (steerLeft ? 1 : 0) + (steerRight ? -1 : 0);
    if (this.touch.steer !== 0) steer = this.touch.steer;
    const leanBack = k.has('KeyZ');
    const leanFwd = k.has('KeyX');
    let lean = (leanBack ? 1 : 0) + (leanFwd ? -1 : 0);
    if (this.touch.lean !== 0) lean = this.touch.lean;
    const wheelie = k.has('ShiftLeft') || k.has('ShiftRight') || this.touch.wheelie;
    return { throttle, brake, steer, lean, wheelie };
  }
}
