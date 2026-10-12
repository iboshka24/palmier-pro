#if !os(macOS)
/// Timeline UI embedded into the binary so a single-file distribution works
/// even when the resource directory is absent. Regenerate from
/// Resources/Web/timeline.html via scripts/embed_web.py when the HTML changes.
enum EmbeddedWebUI {
    static let html: String = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Palmier Pro (port)</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  html, body { margin: 0; height: 100%; background: #141518; color: #e8e8ea;
    font: 13px/1.4 -apple-system, "Segoe UI", Roboto, sans-serif; overflow: hidden; }
  #topbar { height: 34px; display: flex; align-items: center; gap: 12px;
    padding: 0 12px; background: #1d1e22; border-bottom: 1px solid #2c2d33; }
  #topbar .logo { font-weight: 700; letter-spacing: .2px; }
  #topbar .logo span { color: #ff5a4e; }
  #topbar #proj { color: #9a9ba3; }
  #topbar #tc { margin-left: auto; font-variant-numeric: tabular-nums;
    font-family: ui-monospace, monospace; font-size: 14px; }
  #topbar #hint { color: #6d6e76; font-size: 12px; }
  #wrap { position: absolute; inset: 34px 0 26px 0; }
  #tl { width: 100%; height: 100%; display: block; cursor: crosshair; }
  #status { height: 26px; display: flex; align-items: center; gap: 10px;
    padding: 0 12px; background: #1d1e22; border-top: 1px solid #2c2d33;
    color: #9a9ba3; font-size: 12px; position: absolute; left: 0; right: 0; bottom: 0; }
  #err { position: absolute; inset: 34px 0 26px 0; display: none;
    align-items: center; justify-content: center; color: #ff8a80; }
</style>
</head>
<body>
<div id="topbar">
  <div class="logo">Palmier <span>Pro</span> <small style="color:#6d6e76">port</small></div>
  <div id="proj">loading…</div>
  <div id="hint">wheel: zoom · drag: scrub · click clip: select · space: play</div>
  <div id="tc">00:00:00</div>
</div>
<div id="wrap"><canvas id="tl"></canvas></div>
<div id="err"><div>Could not load /api/project. Is the core running?</div></div>
<div id="status"><span id="sel">no selection</span></div>

<script>
"use strict";
const COLORS = { video:"#3f8cff", audio:"#34b356", image:"#37b8d6", text:"#e8b62a",
  subtitle:"#9a63e8", sequence:"#7a86ff", lottie:"#e86aa8" };
const LABEL_W = 132, RULER_H = 26, TRACK_H = 44;
const cv = document.getElementById("tl"), ctx = cv.getContext("2d");
const tcEl = document.getElementById("tc"), selEl = document.getElementById("sel");

let proj = null;                 // {name, fps, timeline:{tracks}}
let pxPerFrame = 2, playhead = 0, selectedId = null;
let playing = false, lastT = 0, scrubbing = false;

function fps() { return (proj && proj.fps) || 30; }
function tracks() { return (proj && proj.timeline && proj.timeline.tracks) || []; }
function totalFrames() {
  let m = 1;
  for (const t of tracks()) for (const c of (t.clips || []))
    m = Math.max(m, c.startFrame + c.durationFrames);
  return m;
}
function fmtTC(f) {
  f = Math.max(0, Math.round(f));
  const fr = f % fps(), s = Math.floor(f / fps) % 60, m = Math.floor(f / (fps() * 60));
  const p = n => String(n).padStart(2, "0");
  return p(m) + ":" + p(s) + ":" + p(fr);
}
function resize() {
  const r = cv.parentElement.getBoundingClientRect(), dpr = window.devicePixelRatio || 1;
  cv.width = Math.max(1, Math.round(r.width * dpr));
  cv.height = Math.max(1, Math.round(r.height * dpr));
  draw(dpr);
}
window.addEventListener("resize", resize);

function xForFrame(f) { return LABEL_W + f * pxPerFrame; }
function frameAt(x) { return Math.max(0, Math.round((x - LABEL_W) / pxPerFrame)); }

function draw(dpr) {
  dpr = dpr || window.devicePixelRatio || 1;
  const W = cv.width / dpr, H = cv.height / dpr;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.fillStyle = "#141518"; ctx.fillRect(0, 0, W, H);

  // track lanes + labels
  const ts = tracks();
  ts.forEach((t, i) => {
    const y = RULER_H + i * TRACK_H;
    ctx.fillStyle = i % 2 ? "#17181c" : "#191a1f";
    ctx.fillRect(0, y, W, TRACK_H);
    ctx.fillStyle = "#202127"; ctx.fillRect(0, y, LABEL_W, TRACK_H);
    ctx.fillStyle = "#c9cad0"; ctx.font = "12px sans-serif";
    ctx.fillText((t.name || t.type || "track") + (t.muted ? " (muted)" : ""), 10, y + 26);
    ctx.strokeStyle = "#2c2d33"; ctx.beginPath();
    ctx.moveTo(0, y + TRACK_H + .5); ctx.lineTo(W, y + TRACK_H + .5); ctx.stroke();
    for (const c of (t.clips || [])) {
      const x = xForFrame(c.startFrame), w = Math.max(3, c.durationFrames * pxPerFrame);
      if (x + w < LABEL_W || x > W) continue;
      ctx.fillStyle = COLORS[c.mediaType] || "#888";
      ctx.globalAlpha = 0.85;
      roundRect(x + 1, y + 5, w - 2, TRACK_H - 10, 4); ctx.fill();
      ctx.globalAlpha = 1;
      if (c.id === selectedId) {
        ctx.strokeStyle = "#fff"; ctx.lineWidth = 2;
        roundRect(x + 1, y + 5, w - 2, TRACK_H - 10, 4); ctx.stroke();
      }
      if (w > 24) {
        ctx.fillStyle = "rgba(0,0,0,.75)"; ctx.font = "11px sans-serif";
        const label = (c.textContent || base(c.mediaRef));
        ctx.fillText(label.slice(0, Math.floor(w / 7)), x + 6, y + 25, w - 10);
      }
    }
  });

  // ruler
  ctx.fillStyle = "#1d1e22"; ctx.fillRect(0, 0, W, RULER_H);
  ctx.strokeStyle = "#2c2d33"; ctx.beginPath();
  ctx.moveTo(0, RULER_H - .5); ctx.lineTo(W, RULER_H - .5); ctx.stroke();
  const steps = [1,2,5,10,15,30,60,150,300,600,1800,3600,7200];
  const step = steps.find(s => s * pxPerFrame >= 90) || 7200;
  ctx.fillStyle = "#9a9ba3"; ctx.font = "10px sans-serif"; ctx.textBaseline = "top";
  const f0 = frameAt(0);
  for (let f = Math.floor(f0 / step) * step; xForFrame(f) < W; f += step) {
    if (f < 0) continue;
    const x = xForFrame(f);
    ctx.strokeStyle = "#3a3b42"; ctx.beginPath();
    ctx.moveTo(x + .5, RULER_H - 8); ctx.lineTo(x + .5, RULER_H); ctx.stroke();
    ctx.fillText(fmtTC(f), x + 4, 4);
  }
  ctx.textBaseline = "alphabetic";

  // playhead
  const px = xForFrame(playhead);
  ctx.strokeStyle = "#ff5a4e"; ctx.lineWidth = 1.5; ctx.beginPath();
  ctx.moveTo(px, 0); ctx.lineTo(px, H); ctx.stroke();
  ctx.fillStyle = "#ff5a4e";
  ctx.beginPath(); ctx.moveTo(px - 6, 0); ctx.lineTo(px + 6, 0); ctx.lineTo(px, 9); ctx.fill();

  tcEl.textContent = fmtTC(playhead);
}

function roundRect(x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}
function base(ref) { return String(ref || "clip").split("/").pop(); }

function hitClip(x, y) {
  const ts = tracks();
  const i = Math.floor((y - RULER_H) / TRACK_H);
  if (i < 0 || i >= ts.length) return null;
  for (const c of (ts[i].clips || [])) {
    if (x >= xForFrame(c.startFrame) && x <= xForFrame(c.startFrame + c.durationFrames)) return c;
  }
  return null;
}
function pos(e) {
  const r = cv.getBoundingClientRect();
  return { x: e.clientX - r.left, y: e.clientY - r.top };
}
cv.addEventListener("mousedown", e => {
  const { x, y } = pos(e);
  scrubbing = true;
  playhead = frameAt(x);
  const c = hitClip(x, y);
  selectedId = c ? c.id : null;
  describe(c);
  draw();
});
window.addEventListener("mousemove", e => {
  if (!scrubbing) return;
  playhead = frameAt(pos(e).x);
  draw();
});
window.addEventListener("mouseup", () => { scrubbing = false; });
cv.addEventListener("wheel", e => {
  e.preventDefault();
  const { x } = pos(e);
  const anchor = frameAt(x);
  pxPerFrame = Math.min(40, Math.max(0.02, pxPerFrame * (e.deltaY > 0 ? 0.9 : 1.1)));
  void anchor;
  draw();
}, { passive: false });
window.addEventListener("keydown", e => {
  if (e.code === "Space") { e.preventDefault(); togglePlay(); }
});
function togglePlay() {
  playing = !playing;
  lastT = performance.now();
  if (playing) requestAnimationFrame(tick);
}
function tick(t) {
  if (!playing) return;
  playhead += (t - lastT) / 1000 * fps();
  lastT = t;
  if (playhead >= totalFrames()) { playhead = 0; }
  draw();
  requestAnimationFrame(tick);
}
function describe(c) {
  if (!c) { selEl.textContent = "no selection"; return; }
  selEl.textContent = (c.textContent || base(c.mediaRef)) +
    " · " + c.mediaType + " · start " + c.startFrame +
    " · dur " + c.durationFrames + "f (" + (c.durationFrames / fps()).toFixed(2) + "s)";
}

fetch("/api/project").then(r => {
  if (!r.ok) throw new Error("http " + r.status);
  return r.json();
}).then(p => {
  proj = p;
  document.getElementById("proj").textContent = p.name + " · " + p.fps + "fps";
  const W = cv.parentElement.getBoundingClientRect().width;
  pxPerFrame = Math.min(40, Math.max(0.02, (W - LABEL_W - 16) / totalFrames()));
  resize();
}).catch(err => {
  document.getElementById("err").style.display = "flex";
  document.getElementById("proj").textContent = String(err);
});
</script>
</body>
</html>
"""
}
#endif
