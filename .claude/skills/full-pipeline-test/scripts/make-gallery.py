#!/usr/bin/env python3
"""Build a self-contained HTML gallery from a pipeline run's screenshots.

Reads a JSON manifest describing the run and the frames worth showing, downscales
each PNG to a progressive JPEG, inlines it as a data URI, and writes one HTML file
ready to hand to the Artifact tool. No external assets, so it survives the
Artifact CSP.

    python3 make-gallery.py manifest.json out.html

Manifest shape (every key optional except "src" and "phases"):

    {
      "title":   "Ionix pipeline run - 5 Aug 2026",
      "eyebrow": "Ionix ISO - release validation",
      "heading": "Full pipeline run",
      "lede":    "One paragraph on what the run covered.",
      "verdict": "Passed end to end",          // omit for a failed run
      "verdict_state": "pass",                  // pass | fail
      "facts":   [["ISO", "ionix-2026.08.05-x86_64.iso"], ["Size", "3.9 GB"]],
      "notes":   ["<p>Free-form HTML shown under the facts.</p>"],
      "src":     "/home/ion/.ionix-vm",
      "phases": [
        {"num": "2", "title": "Headless install", "lede": "...",
         "shots": [{"file": "01-boot.png", "title": "...", "note": "HTML allowed"}]}
      ]
    }

Notes are rendered as raw HTML so <code>, <strong> and <em> work; everything else
is escaped. Keep the total under ~16 MB (base64 inflates by a third) -- at 1920px
and quality 88 that is roughly 100 frames.
"""

import base64
import html
import io
import json
import os
import sys

from PIL import Image

MAXW = 1920
QUALITY = 88

CSS = """
  :root {
    --ground:#0f0a18; --panel:#1a1025; --panel-2:#221634; --hairline:#2f2445;
    --muted:#8578a0; --text:#c4b5fd; --bright:#e2d9f3;
    --accent:#a855f7; --accent-2:#c084fc; --pass:#2ecc71; --fail:#e74c3c;
    --shadow:0 1px 2px rgb(0 0 0 / .5), 0 12px 32px -18px rgb(0 0 0 / .8);
    --mono:ui-monospace,"JetBrains Mono","SFMono-Regular",Menlo,Consolas,monospace;
    --sans:system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",sans-serif;
  }
  @media (prefers-color-scheme: light) {
    :root {
      --ground:#f4f1fa; --panel:#fff; --panel-2:#f7f4fc; --hairline:#e0d8ee;
      --muted:#6b5f80; --text:#3b2d55; --bright:#1e1430;
      --accent:#7c3aed; --accent-2:#6d28d9; --pass:#12924b; --fail:#c0392b;
      --shadow:0 1px 2px rgb(40 20 70 / .06), 0 12px 30px -20px rgb(40 20 70 / .35);
    }
  }
  :root[data-theme="light"] {
    --ground:#f4f1fa; --panel:#fff; --panel-2:#f7f4fc; --hairline:#e0d8ee;
    --muted:#6b5f80; --text:#3b2d55; --bright:#1e1430;
    --accent:#7c3aed; --accent-2:#6d28d9; --pass:#12924b; --fail:#c0392b;
    --shadow:0 1px 2px rgb(40 20 70 / .06), 0 12px 30px -20px rgb(40 20 70 / .35);
  }
  :root[data-theme="dark"] {
    --ground:#0f0a18; --panel:#1a1025; --panel-2:#221634; --hairline:#2f2445;
    --muted:#8578a0; --text:#c4b5fd; --bright:#e2d9f3;
    --accent:#a855f7; --accent-2:#c084fc; --pass:#2ecc71; --fail:#e74c3c;
    --shadow:0 1px 2px rgb(0 0 0 / .5), 0 12px 32px -18px rgb(0 0 0 / .8);
  }

  body {
    background:var(--ground); color:var(--text); font-family:var(--sans);
    font-size:16px; line-height:1.6; margin:0;
    padding:0 clamp(16px,4vw,48px) 96px; -webkit-font-smoothing:antialiased;
  }
  .wrap { max-width:1180px; margin:0 auto; }

  .masthead { padding:clamp(40px,7vw,76px) 0 0; }
  .eyebrow {
    font-family:var(--mono); font-size:12px; letter-spacing:.16em;
    text-transform:uppercase; color:var(--muted); margin:0 0 18px;
  }
  .masthead h1 {
    font-family:var(--mono); font-weight:600; font-size:clamp(30px,5.2vw,50px);
    line-height:1.1; letter-spacing:-.02em; color:var(--bright);
    margin:0 0 18px; text-wrap:balance;
  }
  .masthead p.lede { max-width:64ch; margin:0 0 28px; font-size:17px; }
  .verdict {
    display:inline-flex; align-items:center; gap:10px; font-family:var(--mono);
    font-size:13px; letter-spacing:.1em; text-transform:uppercase;
    color:var(--pass); border-radius:999px; padding:7px 16px 7px 13px;
    border:1px solid color-mix(in srgb, var(--pass) 40%, transparent);
    background:color-mix(in srgb, var(--pass) 12%, transparent);
  }
  .verdict::before {
    content:""; width:8px; height:8px; border-radius:50%; background:var(--pass);
    box-shadow:0 0 0 3px color-mix(in srgb, var(--pass) 22%, transparent);
  }
  .verdict.fail {
    color:var(--fail);
    border-color:color-mix(in srgb, var(--fail) 40%, transparent);
    background:color-mix(in srgb, var(--fail) 12%, transparent);
  }
  .verdict.fail::before {
    background:var(--fail);
    box-shadow:0 0 0 3px color-mix(in srgb, var(--fail) 22%, transparent);
  }

  .facts {
    display:grid; gap:1px; background:var(--hairline);
    border:1px solid var(--hairline); border-radius:12px; overflow:hidden;
    grid-template-columns:repeat(auto-fit,minmax(180px,1fr)); margin:36px 0 8px;
  }
  .fact { background:var(--panel); padding:16px 18px; }
  .fact dt {
    font-family:var(--mono); font-size:11px; letter-spacing:.13em;
    text-transform:uppercase; color:var(--muted); margin:0 0 6px;
  }
  .fact dd {
    margin:0; font-family:var(--mono); font-size:14px; color:var(--bright);
    font-variant-numeric:tabular-nums; word-break:break-word;
  }

  .note-block {
    margin:28px 0 0; padding:18px 20px; border-radius:12px;
    background:var(--panel); border:1px solid var(--hairline);
    border-left:3px solid var(--accent);
  }
  .note-block p { margin:0; }
  .note-block p + p { margin-top:10px; }
  .note-block strong { color:var(--bright); font-weight:600; }

  .phase { margin-top:clamp(56px,8vw,88px); }
  .phase-head { border-top:1px solid var(--hairline); padding-top:22px; margin-bottom:30px; }
  .phase-num {
    display:block; font-family:var(--mono); font-size:12px; letter-spacing:.16em;
    text-transform:uppercase; color:var(--accent-2); margin-bottom:8px;
  }
  .phase-head h2 {
    font-family:var(--mono); font-weight:600; font-size:clamp(21px,3vw,27px);
    letter-spacing:-.015em; color:var(--bright); margin:0 0 8px; text-wrap:balance;
  }
  .phase-lede { margin:0; max-width:62ch; color:var(--muted); }

  .grid { display:grid; gap:22px; grid-template-columns:repeat(auto-fill,minmax(330px,1fr)); }

  .shot {
    margin:0; background:var(--panel); border:1px solid var(--hairline);
    border-radius:12px; overflow:hidden; box-shadow:var(--shadow);
    display:flex; flex-direction:column;
  }
  .shot-view {
    display:block; padding:0; margin:0; border:0; width:100%;
    background:var(--panel-2); cursor:zoom-in; line-height:0;
    border-bottom:1px solid var(--hairline);
  }
  .shot-view img { width:100%; height:auto; display:block; }
  .shot-view:focus-visible { outline:2px solid var(--accent); outline-offset:-2px; }
  figcaption { padding:15px 17px 17px; }
  .shot-title {
    margin:0 0 6px; font-family:var(--mono); font-size:14px; font-weight:600;
    color:var(--bright); letter-spacing:-.005em;
  }
  .shot-idx {
    color:var(--accent-2); margin-right:9px; font-variant-numeric:tabular-nums; font-weight:500;
  }
  .shot-note { margin:0; font-size:14px; line-height:1.55; color:var(--muted); }
  .shot-note code {
    font-family:var(--mono); font-size:.9em; color:var(--text);
    background:color-mix(in srgb, var(--accent) 14%, transparent);
    padding:1px 5px; border-radius:4px;
  }
  .shot-note strong { color:var(--bright); font-weight:600; }
  .shot-note em { color:var(--text); font-style:italic; }

  #lightbox {
    position:fixed; inset:0; z-index:50; display:none; align-items:center;
    justify-content:center; padding:22px; background:rgb(6 3 12 / .93); cursor:zoom-out;
  }
  #lightbox.open { display:flex; }
  #lightbox img {
    max-width:100%; max-height:100%; object-fit:contain; border-radius:6px;
    box-shadow:0 24px 70px -20px rgb(0 0 0 / .9);
  }
  #lightbox .hint {
    position:absolute; bottom:18px; left:50%; transform:translateX(-50%);
    font-family:var(--mono); font-size:12px; letter-spacing:.1em;
    text-transform:uppercase; color:#8578a0;
  }
  @media (prefers-reduced-motion: reduce) { * { animation:none !important; transition:none !important; } }
"""

JS = """
  (function () {
    var box = document.getElementById('lightbox');
    var full = box.querySelector('img');
    document.querySelectorAll('.shot-view').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var img = btn.querySelector('img');
        full.src = img.src; full.alt = img.alt;
        box.classList.add('open');
      });
    });
    function close() { box.classList.remove('open'); full.removeAttribute('src'); }
    box.addEventListener('click', close);
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && box.classList.contains('open')) close();
    });
  })();
"""


def encode(path):
    im = Image.open(path).convert("RGB")
    if im.width > MAXW:
        im = im.resize((MAXW, round(im.height * MAXW / im.width)),
                       Image.Resampling.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=QUALITY, optimize=True, progressive=True)
    return base64.b64encode(buf.getvalue()).decode(), im.width, im.height


def build(man):
    src = man["src"]
    sections, payload, count = [], 0, 0

    for phase in man["phases"]:
        figures = []
        for i, shot in enumerate(phase["shots"], 1):
            path = os.path.join(src, shot["file"])
            if not os.path.exists(path):
                print(f"  ! missing, skipped: {shot['file']}", file=sys.stderr)
                continue
            b64, w, h = encode(path)
            payload += len(b64)
            count += 1
            title = html.escape(shot["title"])
            figures.append(f'''
      <figure class="shot">
        <button class="shot-view" type="button" aria-label="View {title} full size">
          <img src="data:image/jpeg;base64,{b64}" width="{w}" height="{h}" alt="{title}" loading="lazy">
        </button>
        <figcaption>
          <p class="shot-title"><span class="shot-idx">{i:02d}</span>{title}</p>
          <p class="shot-note">{shot.get("note", "")}</p>
        </figcaption>
      </figure>''')
        lede = phase.get("lede", "")
        sections.append(f'''
  <section class="phase">
    <header class="phase-head">
      <span class="phase-num">Phase {html.escape(str(phase["num"]))}</span>
      <h2>{html.escape(phase["title"])}</h2>
      {f'<p class="phase-lede">{html.escape(lede)}</p>' if lede else ''}
    </header>
    <div class="grid">{"".join(figures)}
    </div>
  </section>''')

    facts = "".join(
        f'<div class="fact"><dt>{html.escape(str(k))}</dt>'
        f'<dd>{html.escape(str(v))}</dd></div>'
        for k, v in man.get("facts", [])
    )
    facts_html = f'<dl class="facts">{facts}</dl>' if facts else ""

    verdict = ""
    if man.get("verdict"):
        state = " fail" if man.get("verdict_state") == "fail" else ""
        verdict = f'<p class="verdict{state}">{html.escape(man["verdict"])}</p>'

    notes = "".join(f'<div class="note-block">{n}</div>' for n in man.get("notes", []))
    lede = man.get("lede", "")

    doc = f'''<title>{html.escape(man.get("title", "Pipeline run"))}</title>
<style>{CSS}</style>

<div class="wrap">
  <header class="masthead">
    <p class="eyebrow">{html.escape(man.get("eyebrow", "Ionix ISO"))}</p>
    <h1>{html.escape(man.get("heading", "Full pipeline run"))}</h1>
    {f'<p class="lede">{html.escape(lede)}</p>' if lede else ''}
    {verdict}
    {facts_html}
    {notes}
  </header>
{"".join(sections)}
</div>

<div id="lightbox" role="dialog" aria-modal="true" aria-label="Full size screenshot">
  <img alt="">
  <span class="hint">Click anywhere or press Esc to close</span>
</div>

<script>{JS}</script>
'''
    return doc, count, payload


def main():
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} MANIFEST.json OUT.html")
    with open(sys.argv[1]) as fh:
        man = json.load(fh)
    doc, count, payload = build(man)
    with open(sys.argv[2], "w") as fh:
        fh.write(doc)
    mb = os.path.getsize(sys.argv[2]) / 1024 / 1024
    print(f"{count} frames, {payload / 1024 / 1024:.1f} MB base64 -> {sys.argv[2]} ({mb:.1f} MB)")
    if mb > 15:
        print("WARNING: over 15 MB; lower MAXW/QUALITY or drop frames", file=sys.stderr)


if __name__ == "__main__":
    main()
