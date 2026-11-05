// =====================================================================
// sfx.js — sound effects, made in code with the Web Audio API.
// No audio files, so there are no licences to worry about.
// SFX.play("stamp") etc. Browsers only allow sound after the player
// has clicked something, which is always the case here.
// =====================================================================
"use strict";

const SFX = (() => {
  const KEY = "cranebonistan-muted";
  let ctx = null, master = null;
  let muted = false;
  try { muted = localStorage.getItem(KEY) === "1"; } catch (e) {}

  function audio() {
    if (!ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return null;
      ctx = new AC();
      master = ctx.createGain();
      master.gain.value = 0.5;
      master.connect(ctx.destination);
    }
    if (ctx.state === "suspended") ctx.resume();
    return ctx;
  }

  // A single tone with a quick attack and an exponential fade.
  function tone({ freq = 440, type = "sine", start = 0, dur = 0.2, vol = 0.3, slideTo = null }) {
    const t = ctx.currentTime + start;
    const osc = ctx.createOscillator();
    const g = ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t);
    if (slideTo) osc.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol, t + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    osc.connect(g).connect(master);
    osc.start(t);
    osc.stop(t + dur + 0.05);
  }
  // Filtered noise: paper, crowds, thuds.
  function noise({ start = 0, dur = 0.3, vol = 0.3, type = "bandpass", freq = 1000, q = 1, attack = 0.01, sweepTo = null }) {
    const t = ctx.currentTime + start;
    const len = Math.ceil(ctx.sampleRate * (dur + 0.05));
    const buf = ctx.createBuffer(1, len, ctx.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
    const src = ctx.createBufferSource();
    src.buffer = buf;
    const f = ctx.createBiquadFilter();
    f.type = type;
    f.frequency.setValueAtTime(freq, t);
    if (sweepTo) f.frequency.exponentialRampToValueAtTime(sweepTo, t + dur);
    f.Q.value = q;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol, t + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(f).connect(g).connect(master);
    src.start(t);
    src.stop(t + dur + 0.05);
  }

  const SOUNDS = {
    // light UI tick
    click: () => tone({ freq: 1800, type: "triangle", dur: 0.04, vol: 0.08 }),
    // rubber stamp: a new event lands on your desk
    stamp: () => { noise({ type: "lowpass", freq: 600, dur: 0.18, vol: 0.6, attack: 0.003 }); tone({ freq: 110, type: "sine", dur: 0.16, vol: 0.4, slideTo: 60 }); },
    // newspaper: monthly news
    paper: () => { noise({ type: "bandpass", freq: 2500, q: 0.7, dur: 0.35, vol: 0.25, attack: 0.08, sweepTo: 5000 }); noise({ start: 0.12, type: "highpass", freq: 3000, dur: 0.2, vol: 0.12 }); },
    // coins: budget confirmed
    coins: () => [0, 0.07, 0.13].forEach((s, i) => { tone({ freq: 2200 + i * 400, type: "square", start: s, dur: 0.09, vol: 0.05 }); tone({ freq: 3300 + i * 300, type: "sine", start: s, dur: 0.12, vol: 0.06 }); }),
    // something went your way
    good: () => [523, 659, 784].forEach((f, i) => tone({ freq: f, type: "triangle", start: i * 0.07, dur: 0.25, vol: 0.12 })),
    // something went wrong
    bad: () => { tone({ freq: 220, type: "sawtooth", dur: 0.25, vol: 0.06, slideTo: 150 }); tone({ freq: 233, type: "sawtooth", start: 0.02, dur: 0.25, vol: 0.05, slideTo: 155 }); },
    // drum roll before poll results
    poll: () => { for (let i = 0; i < 14; i++) noise({ start: i * 0.045, type: "lowpass", freq: 400, dur: 0.06, vol: 0.12 + i * 0.012, attack: 0.002 }); tone({ start: 0.66, freq: 392, type: "triangle", dur: 0.4, vol: 0.15 }); },
    // crowd cheering + fanfare
    win: () => {
      noise({ type: "bandpass", freq: 900, q: 0.5, dur: 2.2, vol: 0.25, attack: 0.4 });
      [[392, 0], [523, 0.18], [659, 0.36], [784, 0.54], [1047, 0.8]].forEach(([f, s]) => { tone({ freq: f, type: "sawtooth", start: s, dur: 0.5, vol: 0.06 }); tone({ freq: f, type: "triangle", start: s, dur: 0.6, vol: 0.12 }); });
    },
    // defeat
    lose: () => [392, 349, 311, 262].forEach((f, i) => tone({ freq: f, type: "triangle", start: i * 0.28, dur: 0.5, vol: 0.13 })),
    // big moment on the title screen
    open: () => { tone({ freq: 196, type: "triangle", dur: 0.6, vol: 0.15 }); tone({ freq: 294, type: "triangle", start: 0.1, dur: 0.6, vol: 0.12 }); tone({ freq: 392, type: "triangle", start: 0.2, dur: 0.9, vol: 0.12 }); },
  };

  return {
    play(name) {
      if (muted || !SOUNDS[name]) return;
      try { if (audio()) SOUNDS[name](); } catch (e) { /* audio unavailable */ }
    },
    get muted() { return muted; },
    toggle() {
      muted = !muted;
      try { localStorage.setItem(KEY, muted ? "1" : "0"); } catch (e) {}
      if (!muted) SFX.play("click");
      return muted;
    },
  };
})();
